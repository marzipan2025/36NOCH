import AppKit
import EventKit
import SwiftUI
import Foundation

/// 구글 캘린더 일정. 구글 API를 직접 부르지 않고, 맥 캘린더 앱에 넣어 둔 구글 계정을 EventKit으로 읽는다.
/// 시스템 설정 > 인터넷 계정에 구글 계정이 있어야 하고, 첫 실행 때 캘린더 접근을 한 번 허용해야 한다.
/// 권한 요청은 Info.plist의 NSCalendarsFullAccessUsageDescription이 있어야 하므로 .app으로 실행할 때만 된다.
@MainActor
final class CalendarFeed: ObservableObject {
    /// 이 계정(캘린더 앱의 계정 이름)에 속한 캘린더만 읽는다
    static let account = "artbrainbyeongsu@gmail.com"
    /// 회의가 시작한 뒤 00:00을 깜빡이는 시간과, 그 뒤 닫힘 모션까지 다음 회의로 넘어가지 않고 붙들어 두는 시간
    static let blink: TimeInterval = 10
    static let linger: TimeInterval = 12

    struct Item: Identifiable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let allDay: Bool
    }

    enum Status { case unknown, denied, noAccount, ready }

    /// 맥 캘린더 앱에 있는 계정 하나(캘린더가 있는 것만). 팝업의 계정 고르기 목록에 쓴다.
    struct Account: Identifiable, Equatable {
        let id: String          // EKSource.sourceIdentifier. 맥마다 다르다
        let title: String       // 구글 계정은 이메일이 아니라 "Google"
        let calendars: [String]
    }

    @Published private(set) var status: Status = .unknown
    @Published private(set) var today: [Item] = []
    /// 지금 이후 처음 시작하는 회의(종일 일정 제외). 며칠 뒤여도 된다. 남은 시간 표시에 쓴다.
    @Published private(set) var next: Item?
    /// 팝업에서 계정을 고르는 중인지. 고르는 동안은 마우스와 상관없이 팝업을 열어 둔다.
    @Published private(set) var picking = false
    @Published private(set) var accounts: [Account] = []
    /// 목록 끝 "Later"를 누르면 이번 실행 동안은 계정 고르기를 저절로 띄우지 않는다
    private var pickingDismissed = false

    /// 고른 계정(EKSource.sourceIdentifier)을 저장하는 키
    private static let sourceKey = "calendarSourceID"
    var selectedID: String? { UserDefaults.standard.string(forKey: Self.sourceKey) }

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?

    func start() {
        say("캘린더: 권한 상태", EKEventStore.authorizationStatus(for: .event).rawValue)
        guard Bundle.main.object(forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription") != nil else {
            say("캘린더: Info.plist에 권한 문구가 없어 건너뜀(.app으로 실행할 것)")
            return
        }
        // 메뉴 막대 앱은 늘 비활성이라 권한 창이 앞에 안 뜰 수 있다. 물을 때만 앞으로 가져온다.
        if EKEventStore.authorizationStatus(for: .event) == .notDetermined { NSApp.activate() }
        store.requestFullAccessToEvents { [weak self] granted, error in
            Task { @MainActor in
                guard let self else { return }
                if !granted {
                    self.status = .denied
                    self.offerPicking()  // 팝업에서 "시스템 설정 열기"를 안내
                    say("캘린더: 접근 거부됨", error?.localizedDescription ?? "")
                    return
                }
                self.observer = NotificationCenter.default.addObserver(
                    forName: .EKEventStoreChanged, object: self.store, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.reload() }
                }
                self.reload()
                // 시험용: `--test-account-picker` 로 띄우면 계정 고르기를 바로 연다
                if CommandLine.arguments.contains("--test-account-picker") { self.startPicking() }
            }
        }
    }

    /// 오늘 남은 일정(지금 진행 중인 것 포함)을 다시 읽는다
    func reload() {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        if picking { loadAccounts() }  // 고르는 중 시스템 설정에서 계정을 넣으면 목록에 바로 나타나게
        let calendars = accountCalendars()
        if calendars.isEmpty {
            status = .noAccount
            for source in store.sources {
                say("캘린더: 계정 \(source.title)(\(source.sourceType.rawValue)):",
                    source.calendars(for: .event).map(\.title).sorted())
            }
            say("캘린더: 고른 계정이 없음 → 팝업에서 고르기")
            today = []
            next = nil
            offerPicking()
            return
        }
        let now = Date()
        let endOfDay = Foundation.Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: calendars)
        today = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { Item(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "(No title)",
                        start: $0.startDate, end: $0.endDate, allDay: $0.isAllDay) }
        // 다음 회의: 앞으로 60일 안에서 아직 시작 안 한 첫 일정
        let later = store.predicateForEvents(withStart: now, end: now.addingTimeInterval(60 * 24 * 60 * 60),
                                             calendars: calendars)
        next = store.events(matching: later)
            .filter { !$0.isAllDay && $0.startDate > now.addingTimeInterval(-Self.linger) }
            .min { $0.startDate < $1.startDate }
            .map { Item(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "(No title)",
                        start: $0.startDate, end: $0.endDate, allDay: false) }
        status = .ready
        say("캘린더: 다음 회의", next.map { "\($0.start) \($0.title)" } ?? "없음")
        say("캘린더: \(calendars.map(\.title)) 에서 오늘 남은 일정 \(today.count)개")
    }

    /// 고른 계정의 캘린더. 고른 적이 없으면 예전 규칙으로 찾아서(집·회사 맥) 그 계정을 고른 것으로 저장한다.
    /// 고른 계정이 사라졌거나 찾지 못하면 빈 배열 → 팝업에서 고르게 한다.
    private func accountCalendars() -> [EKCalendar] {
        if let id = selectedID {
            let calendars = store.sources.first { $0.sourceIdentifier == id }?.calendars(for: .event) ?? []
            return Array(calendars)
        }
        guard let source = guessSource() else { return [] }
        UserDefaults.standard.set(source.sourceIdentifier, forKey: Self.sourceKey)
        say("캘린더: 예전 규칙으로 \(source.title) 계정을 골라 둠")
        return Array(source.calendars(for: .event))
    }

    /// 예전 규칙: 기본 캘린더 이름이 이메일(회사 맥)인 계정, 아니면 캘린더가 있는 "Google" 계정이 하나뿐일 때 그것(집 맥).
    /// 캘린더 앱은 구글 계정 이름(EKSource.title)을 이메일이 아니라 "Google"로 둔다.
    private func guessSource() -> EKSource? {
        let name = Self.account.components(separatedBy: "@")[0]
        for source in store.sources {
            let calendars = source.calendars(for: .event)
            let isAccount = source.title == Self.account || source.title == name
                || calendars.contains(where: { $0.title == Self.account })
            if isAccount && !calendars.isEmpty { return source }
        }
        let google = store.sources.filter { $0.title == "Google" && !$0.calendars(for: .event).isEmpty }
        return google.count == 1 ? google[0] : nil
    }

    // MARK: 계정 고르기(팝업)

    /// 캘린더가 있는 계정 목록을 다시 읽는다. 캘린더가 없는 빈 계정은 뺀다.
    func loadAccounts() {
        accounts = store.sources.compactMap { source in
            let calendars = source.calendars(for: .event).map(\.title).sorted()
            guard !calendars.isEmpty else { return nil }
            return Account(id: source.sourceIdentifier, title: source.title, calendars: calendars)
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// 저절로 띄우는 경우(첫 실행, 고른 계정이 없어짐, 권한 거부)
    private func offerPicking() {
        guard !picking, !pickingDismissed else { return }
        startPicking()
    }

    /// 메뉴의 "캘린더 계정…", 또는 팝업의 안내 글을 눌렀을 때
    func startPicking() {
        if status != .denied { loadAccounts() }
        picking = true
    }

    /// 목록 끝 "Later": 고르지 않고 닫는다. 메뉴의 "캘린더 계정…"이나 안내 글을 누르면 다시 연다.
    func later() {
        picking = false
        pickingDismissed = true
    }

    func choose(_ account: Account) {
        UserDefaults.standard.set(account.id, forKey: Self.sourceKey)
        picking = false
        say("캘린더: \(account.title) 계정을 고름", account.calendars)
        reload()
    }

    /// 목록에 없는 계정은 시스템 설정 > 인터넷 계정에서 로그인해 넣는다(맥 기본 기능, 무료). 지금은 계정이 하나도 없을 때의 안내 글에서만 연다.
    /// 넣고 나면 EKEventStoreChanged로 목록이 저절로 바뀐다.
    func openInternetAccounts() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension")!)
    }

    /// 권한을 거부했을 때: 시스템 설정 > 개인정보 보호 및 보안 > 캘린더
    func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
    }

    /// 팝업에 임시로 띄울 글(영어). 화면 구성은 나중에 정한다.
    var summary: String {
        switch status {
        case .unknown: return "Connecting to calendar…"
        case .denied: return "Calendar access denied. Click to allow."
        case .noAccount: return "No calendar account. Click to choose."
        case .ready:
            // 임시: 다음 회의가 있으면 그 제목(날짜·시각은 오른쪽에 따로, nextWhen)
            if let next { return next.title }
            if today.isEmpty { return "No more events today" }
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return today.prefix(4).map { ($0.allDay ? "All day" : f.string(from: $0.start)) + "  " + $0.title }
                .joined(separator: "\n")
        }
    }
}

extension CalendarFeed {
    /// 다음 회의 날짜("Mon, Nov 2")와 시작 시각("13:30"). 팝업 오른쪽 두 줄.
    var nextWhen: (day: String, time: String)? {
        guard let next else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE, MMM d"
        let day = f.string(from: next.start)
        f.dateFormat = "HH:mm"
        return (day, f.string(from: next.start))
    }
}

/// 남은 시간: 1시간 미만 "MM:SS", 100시간 미만 "HH:MM:SS"(날로 나누지 않음), 그 이상 "4 days".
func countdownText(to date: Date, now: Date) -> String {
    let total = max(0, Int(date.timeIntervalSince(now)))
    if total < 3600 { return String(format: "%02d:%02d", total / 60, total % 60) }
    if total < 100 * 3600 { return String(format: "%02d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60) }
    return "\(total / 86400) days"
}

/// 퇴근 알림: 평일(월~금) 18:00:00부터 10초간 팝업을 열어 "18:00"을 깜빡인다.
enum GoHome {
    static let hour = 18
    static let seconds = 10

    /// 시험용: `--test-gohome` 인자로 띄우면 실행 3초 뒤에 한 번 보여 준다(open build/36NOCH.app --args --test-gohome)
    static let testStart: Date? = CommandLine.arguments.contains("--test-gohome") ? Date().addingTimeInterval(3) : nil

    /// 평일 18:00:00부터 seconds초 안인지
    static func isTime(_ date: Date, seconds: Int) -> Bool {
        if let t = testStart, date >= t, date < t.addingTimeInterval(Double(seconds)) { return true }
        let c = Foundation.Calendar.current.dateComponents([.weekday, .hour, .minute, .second], from: date)
        guard let weekday = c.weekday, (2...6).contains(weekday) else { return false }  // 1 = 일요일
        return c.hour == hour && c.minute == 0 && (c.second ?? 99) < seconds
    }

    /// 시계 자리 글: "18:00"
    static var clock: String { String(format: "%02d:00", hour) }

    /// 오른쪽 두 줄: 오늘 날짜와 18:00
    static func when(_ date: Date) -> (day: String, time: String) {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE, MMM d"
        return (f.string(from: date), String(format: "%02d:00", hour))
    }
}

/// 시계 글꼴. 숫자는 가장 넓은 숫자 폭의 칸에 하나씩 넣어(고정폭처럼) 초가 바뀌어도 폭이 흔들리지 않게 한다.
/// 글자 크기는 정해진 너비에 맞춰 글자 수로 정한다. 숫자마다 Distro 네 가지 중 하나를 무작위로 쓴다(DigitFonts).
/// 콜론과 위치 계산(높이·내림)은 DistroMix 기준.
enum ClockFont {
    static let name = "DistroMix"
    /// 숫자에 무작위로 쓰는 글꼴 네 가지. 맥에 없는 글꼴은 빠진다(집 맥에 없으면 시스템 글꼴로 나온다).
    static let digitNames = ["DistroLight", "DistroMix", "Distro-Bold", "DistroHeavy"]
        .filter { NSFont(name: $0, size: 1) != nil }
    private static let unit = NSFont(name: name, size: 1) ?? .systemFont(ofSize: 1)
    static var descent: CGFloat { -unit.descender }
    /// 프레임 위 ~ 숫자 위 끝(1pt 기준)
    static var capTop: CGFloat { unit.ascender - unit.capHeight }

    private static func width(_ s: String) -> CGFloat {
        (s as NSString).size(withAttributes: [.font: unit]).width
    }
    /// 글꼴마다 숫자 높이가 달라서(같은 크기에서 Light 69, Mix 72, Bold 77, Heavy 72) 대문자 높이를
    /// DistroMix에 맞추는 배율. 이대로 크기를 곱해야 숫자 위 끝이 흔들리지 않는다.
    static func scale(_ f: String) -> CGFloat {
        guard let font = NSFont(name: f, size: 1), font.capHeight > 0 else { return 1 }
        return unit.capHeight / font.capHeight
    }
    /// 배율 적용한 그 글꼴의 위 높이(프레임 위 ~ 바닥선, 1pt 기준). 글자 칸을 DistroMix 높이로 고정하고
    /// 이 차이만큼 내려서 바닥선을 맞춘다. 바닥선 맞춤(HStack)으로 두면 줄 위 끝이 가장 높은 글꼴을 따라가서,
    /// Light 숫자가 들어올 때마다 시계 전체가 약 1pt 오르내렸다.
    static func ascender(_ f: String) -> CGFloat {
        (NSFont(name: f, size: 1)?.ascender ?? unit.ascender) * scale(f)
    }
    static var lineHeight: CGFloat { unit.ascender - unit.descender }
    /// 네 글꼴 숫자(배율 적용) 중 가장 넓은 폭. 어느 글꼴이 걸려도 칸 너비가 같다.
    private static let digitCell: CGFloat = (digitNames.isEmpty ? [name] : digitNames).flatMap { f -> [CGFloat] in
        let font = NSFont(name: f, size: scale(f)) ?? unit
        return "0123456789".map { (String($0) as NSString).size(withAttributes: [.font: font]).width }
    }.max() ?? 0.6

    /// 1pt 기준 칸 너비
    static func cell(_ c: Character) -> CGFloat { c.isNumber ? digitCell : width(String(c)) }

    static func size(for text: String, width: CGFloat) -> CGFloat {
        let em = text.reduce(0) { $0 + cell($1) }
        return em > 0 ? width / em : 12
    }
}

/// 출력이 파일로 갈 때 버퍼에 묶이지 않게 표준 오류로 바로 쓴다
private func say(_ items: Any...) {
    let line = items.map { "\($0)" }.joined(separator: " ") + "\n"
    FileHandle.standardError.write(line.data(using: .utf8)!)
}

/// 자리마다 숫자 글꼴을 기억한다. 그 자리 숫자가 바뀔 때만 네 가지 중 하나를 새로 뽑는다(0.5초마다 다시 그려도 그대로).
final class DigitFonts {
    private var chars: [Character] = []
    private var fonts: [String] = []

    func fonts(for text: String) -> [String] {
        let new = Array(text)
        if new.count != chars.count { chars = []; fonts = [] }  // 형식이 바뀌면(MM:SS → N days 등) 모두 다시 뽑는다
        for (i, c) in new.enumerated() {
            if i < chars.count && chars[i] == c { continue }
            let pick = c.isNumber ? (ClockFont.digitNames.randomElement() ?? ClockFont.name) : ClockFont.name
            if i < fonts.count { fonts[i] = pick } else { fonts.append(pick) }
        }
        chars = new
        return fonts
    }
}

/// 시계 글자. 글자마다 칸을 나눠 그린다(숫자 칸은 모두 같은 폭, 높이는 DistroMix 줄 높이로 고정). 글꼴이 섞여도 바닥선을 맞춘다.
/// colonBlink면 초 왼쪽 콜론이 1초에 한 번 깜빡인다(앞 0.5초 보임, 뒤 0.5초 숨김).
struct ClockText: View {
    let text: String
    let size: CGFloat
    var colonBlink = false
    var now = Date()
    @State private var picker = DigitFonts()

    var body: some View {
        let fonts = picker.fonts(for: text)
        let colonOn = !colonBlink || now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) < 0.5
        // 깜빡이는 건 초 왼쪽 콜론 하나(MM:SS, HH:MM:SS 모두 마지막 콜론)
        let blinkAt = text.lastIndex(of: ":").map { text.distance(from: text.startIndex, to: $0) }
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { i, c in
                let f = i < fonts.count ? fonts[i] : ClockFont.name
                Text(String(c))
                    .font(.custom(f, size: size * ClockFont.scale(f)))
                    .fixedSize()
                    // 글꼴이 바뀌어도 칸 높이·바닥선이 DistroMix와 같게
                    .offset(y: (ClockFont.ascender(ClockFont.name) - ClockFont.ascender(f)) * size)
                    .frame(width: ClockFont.cell(c) * size, height: ClockFont.lineHeight * size, alignment: .top)
                    .opacity(i == blinkAt && !colonOn ? 0 : 1)
            }
        }
        .fixedSize()
    }
}
