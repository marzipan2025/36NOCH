import AppKit
import Foundation
import SwiftUI

/// 인앱 업데이트. 02rapi의 AppUpdater 방식을 따른다.
/// GitHub 릴리스(marzipan2025/36NOCH, 공개)의 latest 태그를 현재 버전과 비교하고, 첨부된 zip을 내려받아
/// 실행 중인 앱 번들(Bundle.main.bundleURL)을 바꾼 뒤 다시 띄운다.
/// 주의: 실행 중인 번들 자리를 바꾸므로, build/ 의 시험 빌드를 띄운 채 업데이트하면 /Applications가 아니라 그 사본이 바뀐다.
struct AppRelease: Sendable {
    let version: String
    let zipURL: URL
}

@MainActor
final class UpdateFeed: ObservableObject {
    enum State: Equatable { case idle, checking, installing, failed(String) }

    @Published private(set) var available: AppRelease?
    @Published private(set) var state: State = .idle
    /// 업데이트 뒤 첫 실행에서 노치 왼쪽 아이콘을 파랗게 빛내는 동안 true
    @Published private(set) var flash = false

    /// 업데이트 직전에 새 버전을 적어 두는 키. 새로 뜬 앱이 자기 버전과 같으면 "업데이트됨"으로 보고 지운다.
    private static let updatedKey = "updatedToVersion"

    private static let latestReleaseAPI = URL(string: "https://api.github.com/repos/marzipan2025/36NOCH/releases/latest")!
    /// 처음 확인은 실행 10초 뒤(캘린더 권한 창 등과 겹치지 않게), 그 뒤로 6시간마다
    private static let firstDelay: TimeInterval = 10
    private static let interval: TimeInterval = 6 * 60 * 60
    private var timer: Timer?

    /// 시험용: NOCH_UPDATE_CURRENT_VERSION=0.0.1 로 띄우면 현재 버전을 그 값으로 본다
    static var currentVersion: String {
        ProcessInfo.processInfo.environment["NOCH_UPDATE_CURRENT_VERSION"]
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0"
    }

    /// `swift build`로 띄운 실행 파일(.app이 아님)은 바꿀 번들이 없으니 확인하지 않는다
    static var isEnabled: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    /// 시험용: `--test-update` 로 띄우면 바로 확인하고, 새 버전이 있으면 묻지 않고 설치한다.
    /// 예: NOCH_UPDATE_CURRENT_VERSION=0.0.1 <사본>/36NOCH.app/Contents/MacOS/NOCH --test-update
    private static let testUpdate = CommandLine.arguments.contains("--test-update")
    /// 시험용: `--test-update-flash` 로 띄우면 업데이트 뒤처럼 아이콘을 한 번 빛낸다
    private static let testFlash = CommandLine.arguments.contains("--test-update-flash")

    func start() {
        if Self.consumeJustUpdated() || Self.testFlash { flashOnce() }
        guard Self.isEnabled else { return }
        if Self.testUpdate {
            Task { if await check() == true { install() } }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.firstDelay) { [weak self] in
            Task { await self?.check() }
        }
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { await self?.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// 새 버전이 있으면 available에 넣는다. 결과(있음/없음, 실패면 nil)를 돌려준다.
    @discardableResult
    func check() async -> Bool? {
        guard Self.isEnabled, state != .installing else { return nil }
        state = .checking
        var request = URLRequest(url: Self.latestReleaseAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]] else {
            state = .failed("릴리스 정보를 받지 못했습니다")
            say("업데이트: 확인 실패")
            return nil
        }
        state = .idle
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard Self.isVersion(version, newerThan: Self.currentVersion),
              let zip = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".zip") == true }),
              let urlString = zip["browser_download_url"] as? String,
              let url = URL(string: urlString) else {
            available = nil
            say("업데이트: 최신(\(Self.currentVersion), 릴리스 \(version))")
            return false
        }
        available = AppRelease(version: version, zipURL: url)
        say("업데이트: \(Self.currentVersion) → \(version) 있음")
        return true
    }

    /// 업데이트 완료 표시: 앱이 다 뜨고 1초 뒤 파랗게 켜서 1초 두었다가 서서히 원래 색으로
    private func flashOnce() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            withAnimation(.easeIn(duration: 0.15)) { self?.flash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                withAnimation(.easeOut(duration: 0.6)) { self?.flash = false }
            }
        }
    }

    /// 업데이트 직후 첫 실행이면 true(한 번만)
    private static func consumeJustUpdated() -> Bool {
        guard let v = UserDefaults.standard.string(forKey: updatedKey) else { return false }
        UserDefaults.standard.removeObject(forKey: updatedKey)
        return v == currentVersion
    }

    /// 내려받아 바꾸고 다시 띄운다. 성공하면 이 프로세스는 끝난다.
    func install() {
        guard let release = available, state != .installing else { return }
        state = .installing
        Task {
            do {
                let installed = try await Self.downloadAndInstall(release)
                UserDefaults.standard.set(release.version, forKey: Self.updatedKey)
                Self.relaunch(bundle: installed.bundle, leftover: installed.leftover)
            } catch {
                state = .failed(error.localizedDescription)
                say("업데이트: 설치 실패", error.localizedDescription)
            }
        }
    }

    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: 설치

    /// zip 다운로드 → 풀기 → 앱 번들 옆에 스테이징 → 번들 교체.
    /// 교체된 번들 경로와, 옛 번들이 옮겨진 스테이징 폴더를 돌려준다. 스테이징 폴더는 실행 중인 옛 번들이라
    /// 여기서 지우지 않고 relaunch가 종료 뒤에 지운다.
    nonisolated private static func downloadAndInstall(_ release: AppRelease) async throws -> (bundle: URL, leftover: URL) {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("36noch-update-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        // 1. 다운로드
        let (downloaded, response) = try await URLSession.shared.download(from: release.zipURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let zip = work.appendingPathComponent("36NOCH.zip")
        try fm.moveItem(at: downloaded, to: zip)

        // 2. 풀기
        let unzipped = work.appendingPathComponent("unzipped")
        try await run("/usr/bin/ditto", ["-x", "-k", zip.path, unzipped.path])
        guard let appName = try fm.contentsOfDirectory(atPath: unzipped.path).first(where: { $0.hasSuffix(".app") }) else {
            throw CocoaError(.fileNoSuchFile)
        }

        // 3. 현재 번들 옆에 스테이징(같은 볼륨이어야 replaceItemAt이 원자적으로 동작)
        let target = Bundle.main.bundleURL
        let staging = target.deletingLastPathComponent().appendingPathComponent(".36noch-update-\(UUID().uuidString)")
        let staged = staging.appendingPathComponent(target.lastPathComponent)
        do {
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)
            try await run("/usr/bin/ditto", [unzipped.appendingPathComponent(appName).path, staged.path])
            // 4. 다른 앱이 섞여 들어오지 않았는지 번들 ID 확인
            guard let newID = Bundle(url: staged)?.bundleIdentifier,
                  newID == Bundle.main.bundleIdentifier else { throw CocoaError(.fileReadCorruptFile) }
            // 5. 교체(옛 번들은 staged 자리로 옮겨짐)
            try? await run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", staged.path])
            _ = try fm.replaceItemAt(target, withItemAt: staged, backupItemName: nil, options: .usingNewMetadataOnly)
        } catch {
            try? fm.removeItem(at: staging)
            throw error
        }
        return (target, staging)
    }

    /// 이 프로세스가 끝나기를 기다렸다가 옛 번들을 지우고 새 번들을 연다
    private static func relaunch(bundle: URL, leftover: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "while /bin/kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; /bin/rm -rf \"$1\"; /usr/bin/open \"$0\"",
                          bundle.path, leftover.path]
        try? task.run()
        NSApp.terminate(nil)
    }

    nonisolated private static func run(_ path: String, _ args: [String]) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: path)
            p.arguments = args
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            p.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    cont.resume()
                } else {
                    cont.resume(throwing: NSError(domain: "UpdateFeed", code: Int(proc.terminationStatus),
                                                  userInfo: [NSLocalizedDescriptionKey: "\(path) 실패"]))
                }
            }
            do { try p.run() } catch { cont.resume(throwing: error) }
        }
    }
}

/// 출력이 파일로 갈 때 버퍼에 묶이지 않게 표준 오류로 바로 쓴다
private func say(_ items: Any...) {
    let line = items.map { "\($0)" }.joined(separator: " ") + "\n"
    FileHandle.standardError.write(line.data(using: .utf8)!)
}
