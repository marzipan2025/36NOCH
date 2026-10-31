import AppKit
import CoreGraphics

/// 트랙패드로 데스크탑(스페이스)을 좌우로 넘기는 스와이프를 지켜보다가, 옆 데스크탑이 threshold(30%)만큼 들어오거나
/// 그 전에 손가락을 떼어 넘어가기로 정해지면(관성으로 넘어감) 알린다.
/// 데스크탑 전환 공식 알림(activeSpaceDidChangeNotification)은 전환이 거의 끝난 뒤에 오므로, 넘어가기 전에 닫으려고 쓴다.
///
/// 공개 API가 없어서 Dock이 받는 스와이프 이벤트(비공개 종류 30)를 듣기 전용 이벤트 탭으로 읽는다.
/// 필드 번호는 Mac Mouse Fix 등이 역공학으로 찾은 값이라 macOS가 바뀌면 안 될 수 있다. 그때는 공식 알림(전환 끝)만 남는다.
/// 듣기 전용 탭은 "입력 모니터링" 권한이 필요하다(시스템 설정 > 개인정보 보호 및 보안 > 입력 모니터링).
@MainActor
final class SpaceSwipeWatcher {
    /// 옆 데스크탑이 이만큼(한 화면 = 1) 들어오면 알린다
    var threshold: Double = 0.3
    private let onSwipe: () -> Void
    private var tap: CFMachPort?
    private var retry: Timer?
    /// 한 번의 스와이프에서 한 번만 알린다
    private var fired = false

    private static let dockControlType: UInt32 = 30           // kCGSEventDockControl
    private static let hidTypeField = CGEventField(rawValue: 110)!   // kCGEventGestureHIDType
    private static let dockSwipeHIDType: Int64 = 23           // kIOHIDEventTypeDockSwipe
    private static let motionField = CGEventField(rawValue: 123)!    // 1 = 좌우, 2 = 위아래
    private static let progressField = CGEventField(rawValue: 124)!  // 진행(한 화면 = ±1)
    private static let phaseField = CGEventField(rawValue: 132)!     // 1 시작, 2 진행, 4 끝, 8 취소

    /// 시험용: `--log-swipe` 로 띄우면 받은 스와이프 값을 표준 오류로 찍는다
    private static let log = CommandLine.arguments.contains("--log-swipe")

    init(onSwipe: @escaping () -> Void) {
        self.onSwipe = onSwipe
    }

    /// 권한이 없으면 한 번 묻고(시스템 창), 허용될 때까지 5초마다 다시 시도한다.
    func start() {
        if !CGPreflightListenEventAccess() { CGRequestListenEventAccess() }
        if installTap() { return }
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.installTap() else { return }
                self.retry?.invalidate()
                self.retry = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        retry = timer
    }

    private func installTap() -> Bool {
        guard tap == nil else { return true }
        guard CGPreflightListenEventAccess() else { return false }
        let mask = CGEventMask(1) << CGEventMask(Self.dockControlType)
        let callback: CGEventTapCallBack = { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let watcher = Unmanaged<SpaceSwipeWatcher>.fromOpaque(info).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.handle(type: type, event: event) }
            return Unmanaged.passUnretained(event)
        }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                           eventsOfInterest: mask, callback: callback,
                                           userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            say("스와이프: 이벤트 탭을 만들지 못함")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        say("스와이프: 지켜보기 시작")
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // 시스템이 탭을 꺼 버리면(응답이 늦었을 때 등) 다시 켠다
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard type.rawValue == Self.dockControlType,
              event.getIntegerValueField(Self.hidTypeField) == Self.dockSwipeHIDType else { return }
        let motion = event.getIntegerValueField(Self.motionField)
        let progress = event.getDoubleValueField(Self.progressField)
        let phase = event.getIntegerValueField(Self.phaseField)
        if Self.log { say("스와이프: motion \(motion) phase \(phase) progress \(progress)") }
        if phase == 1 { fired = false }
        // 빠르게 휙 넘기면 손가락을 뗄 때까지 진행이 0.15~0.2에 그치고 나머지는 관성으로 넘어간다(2026-11-01 집 맥 기록).
        // 손가락을 뗄 때 넘어갈 스와이프는 단계 4(끝), 제자리로 돌아갈 스와이프는 8(취소)로 오므로 4에서도 닫는다.
        guard motion == 1, !fired, abs(progress) >= threshold || phase == 4 else { return }
        fired = true
        if Self.log { say("스와이프: \(progress)에서 닫기") }
        onSwipe()
    }
}

/// 출력이 파일로 갈 때 버퍼에 묶이지 않게 표준 오류로 바로 쓴다
private func say(_ items: Any...) {
    let line = items.map { "\($0)" }.joined(separator: " ") + "\n"
    FileHandle.standardError.write(line.data(using: .utf8)!)
}
