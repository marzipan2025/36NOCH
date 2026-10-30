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

    @Published private(set) var status: Status = .unknown
    @Published private(set) var today: [Item] = []
    /// 지금 이후 처음 시작하는 회의(종일 일정 제외). 며칠 뒤여도 된다. 남은 시간 표시에 쓴다.
    @Published private(set) var next: Item?

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
                    say("캘린더: 접근 거부됨", error?.localizedDescription ?? "")
                    return
                }
                self.observer = NotificationCenter.default.addObserver(
                    forName: .EKEventStoreChanged, object: self.store, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.reload() }
                }
                self.reload()
            }
        }
    }

    /// 오늘 남은 일정(지금 진행 중인 것 포함)을 다시 읽는다
    func reload() {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        let calendars = accountCalendars()
        if calendars.isEmpty {
            status = .noAccount
            for source in store.sources {
                say("캘린더: 계정 \(source.title)(\(source.sourceType.rawValue)):",
                    source.calendars(for: .event).map(\.title).sorted())
            }
            say("캘린더: \(Self.account) 계정을 찾지 못함")
            today = []
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

    /// 캘린더 앱은 구글 계정 이름을 이메일이 아니라 "Google"로 둔다. 구글 계정의 기본 캘린더 이름이
    /// 이메일 주소이므로, 그 캘린더를 가진 계정을 찾아 그 계정의 캘린더를 모두 쓴다.
    private func accountCalendars() -> [EKCalendar] {
        for source in store.sources {
            let calendars = source.calendars(for: .event)
            let name = Self.account.components(separatedBy: "@")[0]
            let isAccount = source.title == Self.account || source.title == name
                || calendars.contains(where: { $0.title == Self.account })
            if isAccount && !calendars.isEmpty {
                return Array(calendars)
            }
        }
        return []
    }

    /// 팝업에 임시로 띄울 글(영어). 화면 구성은 나중에 정한다.
    var summary: String {
        switch status {
        case .unknown: return "Connecting to calendar…"
        case .denied: return "Calendar access denied. Allow 36NOCH in System Settings > Privacy & Security > Calendars."
        case .noAccount: return "No calendars found for \(Self.account)"
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

/// 남은 시간. 1시간 미만 "MM:SS", 100시간 미만 "H:MM:SS"·"HH:MM:SS"(날로 나누지 않음), 그 이상 "4 days".
func countdownText(to date: Date, now: Date) -> String {
    let total = max(0, Int(date.timeIntervalSince(now)))
    if total < 3600 { return String(format: "%02d:%02d", total / 60, total % 60) }
    if total < 100 * 3600 { return String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60) }
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
/// 글자 크기는 정해진 너비에 맞춰 글자 수로 정한다.
enum ClockFont {
    static let name = "DistroMix"
    private static let unit = NSFont(name: name, size: 1) ?? .systemFont(ofSize: 1)
    static var descent: CGFloat { -unit.descender }
    /// 프레임 위 ~ 숫자 위 끝(1pt 기준)
    static var capTop: CGFloat { unit.ascender - unit.capHeight }

    private static func width(_ s: String) -> CGFloat {
        (s as NSString).size(withAttributes: [.font: unit]).width
    }
    private static let digitCell: CGFloat = "0123456789".map { width(String($0)) }.max() ?? 0.6

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

/// 시계 글자. 글자마다 칸을 나눠 그린다(숫자 칸은 모두 같은 폭).
struct ClockText: View {
    let text: String
    let size: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, c in
                Text(String(c)).frame(width: ClockFont.cell(c) * size)
            }
        }
        .font(.custom(ClockFont.name, size: size))
        .fixedSize()
    }
}
