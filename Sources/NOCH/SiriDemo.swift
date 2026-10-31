import AppKit
import SwiftUI

// 실험: 노치가 넓어지고, 거기서 유리 방울이 떨어지듯 팝업이 생긴다.
//   1) 노치가 너비·높이·모서리 반지름이 함께 커진다(검정).
//   2) 커진 노치에서 Liquid Glass 방울이 맺혀 아래로 떨어지며 팝업이 된다. 팝업 너비 = 커진 노치 너비.
// 방울 느낌은 GlassEffectContainer에 맡긴다. 같은 컨테이너 안의 유리 모양들은 가까워지면
// 액체처럼 붙고(spacing 이내), 멀어지면 목이 늘어나다 끊어진다(RESEARCH §3.5).
// 팝업 안에는 위에서 내려오는 검정을 유리 "아래"에 깐다. 검정은 팝업 모양을 따라 휘며 사라지고,
// 유리가 그 위에서 굴절·반사해서 검정 부분도 액체 유리처럼 보인다.

import Combine

/// 모든 조절 값. 기본값은 2026-10-31 사용자가 맞춘 11차 설정.
/// 바꾼 값은 UserDefaults에 저장해서 앱을 다시 켜도 이어진다.
final class DropTuning: ObservableObject {
    // 노치 확장
    @Published var growWidth: CGFloat = 80
    @Published var growHeight: CGFloat = 12
    @Published var restWide = true                  // 닫혀 있을 때도 노치 검정을 좌우로 늘여 둔다
    @Published var restWidth: CGFloat = 44           // 그때 늘이는 너비(양쪽 합, 한쪽 22)
    @Published var grownBottomRadius: CGFloat = 16   // 커진 노치 아래 모서리(볼록). 원래 노치 10
    @Published var grownTopRadius: CGFloat = 21.5      // 커진 노치 위 모서리(오목). 원래 노치 6
    // 팝업 방울
    @Published var popupHeight: CGFloat = 232
    @Published var popupRadius: CGFloat = 26
    @Published var gap: CGFloat = 14                 // 커진 노치 아래 끝과 팝업 위 끝 사이
    @Published var spacing: CGFloat = 12             // GlassEffectContainer가 두 유리를 붙이는 거리
    @Published var grainHeight: CGFloat = 34         // 떨어지기 전 팝업 높이(실제 노치 밑에 숨어 있음)
    @Published var waitInset: CGFloat = 4            // 대기 중 팝업을 실제 노치보다 좁힐 너비(양쪽 합). 하드웨어 노치에 완전히 가려지게
    @Published var inkDelay: CGFloat = 0             // 떨어지기 시작하고 검정이 빠지기 시작할 때까지(초)
    @Published var inkDuration: CGFloat = 0.65       // 검정 → 유리로 바뀌는 시간(초)
    @Published var inkNeck = true                    // 노치와 방울 사이 목도 유리 틴트로 검게
    // 유리
    @Published var clearGlass = true
    @Published var tintOpacity: CGFloat = 0.05
    // 검정 덮개: 팝업 모양을 위로 끌어올려 흐리게 만든 검정. 흐린 경계가 모서리 곡선을 따라 휜다.
    @Published var lift: CGFloat = 65.5              // 검정 아래 끝을 팝업 아래 끝보다 얼마나 위로
    @Published var softness: CGFloat = 37          // 흐림 = 검정이 사라지는 구간 길이
    @Published var blackRadius: CGFloat = 44         // 검정 모양의 아래 모서리 반지름(휘어짐 정도)
    @Published var sideInset: CGFloat = -1          // 양옆에서 들임. 키우면 옆 가장자리에 유리가 더 드러남
    @Published var blackOpacity: CGFloat = 1
    @Published var overBlack: CGFloat = 0.65          // 같은 검정 모양을 유리 "위"에도 이만큼 덧칠. 유리가 검정을 밝혀 보이게 하는 만큼 다시 어둡게
    // 하단 영역: 팝업 아래쪽 안에 둔 흰 반투명 면. 이 안에는 검정이 들어오지 않는다.
    @Published var trayHeight: CGFloat = 48
    @Published var trayMargin: CGFloat = 36          // 좌우·아래 여백
    @Published var trayOpacity: CGFloat = 0.1        // 흰색 불투명도
    @Published var trayConcentric = true             // 켜면 모서리 = 팝업 모서리 − 여백(같은 중심의 곡선), 끄면 팝업과 같은 반지름
    @Published var trayRadiusPlus: CGFloat = 4       // 위 규칙으로 정한 모서리에 더하는 값
    @Published var trayCapsule = true                // 켜면 좌우가 완전한 반원(위 두 규칙 무시)
    @Published var popupBottomConcentric = true      // 켜면 팝업 아래 두 모서리 = 하단 영역 모서리 + 여백(같은 중심의 곡선)
    @Published var trayDelay: CGFloat = -0.2         // 팝업 등장이 끝나고 이만큼 뒤에 나타난다(초). 음수면 끝나기 전
    @Published var trayFade: CGFloat = 0.3           // 나타나고 사라지는 시간(초). 닫을 때는 닫힘 시작과 함께 사라진다
    // 덧그린 테두리 빛
    @Published var rimOpacity: CGFloat = 0.05        // 유리 자체 테두리 위에 아주 살짝
    @Published var rimWidth: CGFloat = 1
    @Published var rimSoftness: CGFloat = 1
    // 바깥 그림자
    @Published var shadowOpacity: CGFloat = 0.3
    @Published var shadowRadius: CGFloat = 28
    @Published var shadowY: CGFloat = 14.5
    // 글: 확정한 값이라 설정창·저장에서 뺐다(2026-10-30)
    let textSize: CGFloat = 11
    let textPadding: CGFloat = 22
    let textTop: CGFloat = 30                // 팝업 위 끝 ~ 시계·글 위 끝(2026-10-31 18 → 38(팝업 높이도 20 늘림) → 30)
    let popupSideExtra: CGFloat = 33         // 커진 노치를 좌우로 더 넓힌 양(한쪽). 12 → 27(전체 30) → 57(전체 60 더) → 41(전체 32 줄임) → 37 → 33(8씩 두 번 더 줄임)
    /// 글·아이콘 좌우 끝을 하단 캡슐 좌우 끝(노치 끝에서 trayMargin)보다 uiInsideCapsule만큼 안쪽에 두려고 textPadding에 더하는 여백(한쪽)
    let uiInsideCapsule: CGFloat = 3
    var uiSideInset: CGFloat { trayMargin - textPadding + uiInsideCapsule }
    let clockGap: CGFloat = 10               // 실제 노치 아래 끝 ~ 시계 숫자 위 끝(4에서 6 내림)
    // 팝업이 커진 노치보다 넓은 양(양쪽 합). 커진 노치를 줄일 때(너비 + 100 → 92 → 80) 팝업 너비는 그대로 두려고
    // 줄인 만큼(8, 12) 24에 더함
    var popupExtraWidth: CGFloat { 44 + popupSideExtra * 2 }
    // 다음 회의까지 남은 시간(Distro Mix, 금색). 너비를 고정하고, 글자 수가 줄면 그만큼 글자가 커져 아래로 늘어난다.
    let countdownWidth: CGFloat = 204     // 시계 너비. 204면 8자리(70:02:31)가 약 49pt
    let countdownGap: CGFloat = 12        // 숫자 아래 끝 ~ 제목 글자 위 끝
    let countdownX: CGFloat = -7          // 남은 시간만 좌우로 옮기는 양(음수 = 왼쪽). −4 → −8 → −9 → −7
    let countdownLift: CGFloat = 0        // 더 끌어올리는 양. 0이면 숫자 위 끝 = 날짜 글자 위 끝
    // 모션(초)
    @Published var growDuration: CGFloat = 0.6
    @Published var growBounce: CGFloat = 0.2
    @Published var dropDelay: CGFloat = -0.7
    @Published var dropDuration: CGFloat = 0.55
    @Published var dropBounce: CGFloat = 0.2
    @Published var closeSpeed: CGFloat = 0.5         // 닫힘은 열림의 정확한 역재생. 이 값은 시간 배율(1 = 열 때와 같은 속도, 작을수록 빠름)

    // 마우스
    @Published var hoverMargin: CGFloat = 40         // 실제 노치 좌우·위 이만큼 안에 마우스가 오면 연다
    @Published var hoverDown: CGFloat = 16           // 실제 노치 아래로는 이만큼까지
    @Published var keepMargin: CGFloat = 8           // 커진 노치+팝업 둘레 이만큼 밖으로 나가면 닫는다
    @Published var holdWhileSettings = true          // 설정창이 떠 있는 동안은 마우스와 상관없이 펼친 채 유지

    /// 바뀔 때마다 패널이 열기/닫기 모션을 한다. 마우스 위치(SiriDemo)나 설정창 버튼이 바꾼다.
    @Published var isOpen = false

    /// 11차 설정(= 기본값): 2026-10-31 집 맥. 10차에서 하단 캡슐 좌우·아래 여백 31.5 → 36.
    /// 조절하다가 이 값으로 되돌릴 때 쓴다.
    func applyEleventhPreset() {
        growWidth = 80; growHeight = 12; restWide = true; restWidth = 44; grownBottomRadius = 16; grownTopRadius = 21.5; popupHeight = 232
        popupRadius = 26; gap = 14; spacing = 12; grainHeight = 34; waitInset = 4
        inkDelay = 0; inkDuration = 0.65; inkNeck = true; clearGlass = true; tintOpacity = 0.05
        lift = 65.5; softness = 37; blackRadius = 44; sideInset = -1; blackOpacity = 1; overBlack = 0.65
        trayHeight = 48; trayMargin = 36; trayOpacity = 0.1; trayConcentric = true
        trayRadiusPlus = 4; trayDelay = -0.2; trayFade = 0.3; trayCapsule = true; popupBottomConcentric = true
        rimOpacity = 0.05; rimWidth = 1; rimSoftness = 1; shadowOpacity = 0.3; shadowRadius = 28
        shadowY = 14.5; growDuration = 0.6
        growBounce = 0.2; dropDelay = -0.7; dropDuration = 0.55; dropBounce = 0.2; closeSpeed = 0.5
    }

    // MARK: 저장

    /// 저장·출력하는 값 목록. 새 조절 값을 만들면 여기에도 넣는다(isOpen 같은 상태는 빼고).
    private static let numbers: [(String, ReferenceWritableKeyPath<DropTuning, CGFloat>)] = [
        ("growWidth", \.growWidth), ("growHeight", \.growHeight),
        ("grownBottomRadius", \.grownBottomRadius), ("grownTopRadius", \.grownTopRadius),
        ("popupHeight", \.popupHeight), ("popupRadius", \.popupRadius), ("gap", \.gap), ("spacing", \.spacing),
        ("grainHeight", \.grainHeight), ("waitInset", \.waitInset),
        ("inkDelay", \.inkDelay), ("inkDuration", \.inkDuration), ("tintOpacity", \.tintOpacity),
        ("lift", \.lift), ("softness", \.softness), ("blackRadius", \.blackRadius),
        ("sideInset", \.sideInset), ("blackOpacity", \.blackOpacity), ("overBlack", \.overBlack),
        ("trayHeight", \.trayHeight), ("trayMargin", \.trayMargin), ("trayOpacity", \.trayOpacity),
        ("trayRadiusPlus", \.trayRadiusPlus), ("trayDelay", \.trayDelay), ("trayFade", \.trayFade),
        ("rimOpacity", \.rimOpacity), ("rimWidth", \.rimWidth), ("rimSoftness", \.rimSoftness),
        ("shadowOpacity", \.shadowOpacity), ("shadowRadius", \.shadowRadius), ("shadowY", \.shadowY),
        ("growDuration", \.growDuration), ("growBounce", \.growBounce), ("dropDelay", \.dropDelay),
        ("dropDuration", \.dropDuration), ("dropBounce", \.dropBounce), ("closeSpeed", \.closeSpeed),
        ("restWidth", \.restWidth), ("hoverMargin", \.hoverMargin), ("hoverDown", \.hoverDown), ("keepMargin", \.keepMargin),
    ]
    private static let flags: [(String, ReferenceWritableKeyPath<DropTuning, Bool>)] = [
        ("inkNeck", \.inkNeck), ("restWide", \.restWide), ("clearGlass", \.clearGlass), ("holdWhileSettings", \.holdWhileSettings),
        ("trayConcentric", \.trayConcentric), ("trayCapsule", \.trayCapsule),
        ("popupBottomConcentric", \.popupBottomConcentric),
    ]
    private static let defaultsKey = "dropTuning"
    private var saving: AnyCancellable?

    init() {
        if let saved = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) {
            for (key, path) in Self.numbers {
                if let value = saved[key] as? Double { self[keyPath: path] = CGFloat(value) }
            }
            for (key, path) in Self.flags {
                if let value = saved[key] as? Bool { self[keyPath: path] = value }
            }
        }
        // 슬라이더를 끄는 동안 매번 쓰지 않도록, 손을 멈추고 0.3초 뒤에 저장
        saving = objectWillChange
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.save() }
    }

    func save() {
        var dict: [String: Any] = [:]
        for (key, path) in Self.numbers { dict[key] = Double(self[keyPath: path]) }
        for (key, path) in Self.flags { dict[key] = self[keyPath: path] }
        UserDefaults.standard.set(dict, forKey: Self.defaultsKey)
    }

    /// 열림 시간표(초). 스프링 길이는 눈에 보이게 움직이는 데까지(visibleDuration)로 잡는다.
    /// 닫힘은 이 시간표를 거꾸로 돌린다.
    var openTimeline: (grow: Spring, drop: Spring, dropStart: Double, inkStart: Double, total: Double) {
        let grow = Spring(duration: Double(growDuration), bounce: Double(growBounce))
        let drop = Spring(duration: Double(dropDuration), bounce: Double(dropBounce))
        let dropStart = 0.0  // 팝업이 노치와 하나가 되어 떨어짐은 없다
        let inkStart = Double(inkDelay)
        // 팝업이 노치와 하나가 되어(2026-10-31) 따로 떨어지지 않는다. drop 값은 남겨 두지만 전체 길이에 넣지 않는다.
        let total = max(grow.visibleDuration, inkStart + Double(inkDuration))
        return (grow, drop, dropStart, inkStart, total)
    }

    var summary: String {
        let numbers = Self.numbers.map { String(format: "%@=%g", $0.0, Double(self[keyPath: $0.1])) }
        let flags = Self.flags.map { "\($0.0)=\(self[keyPath: $0.1] ? 1 : 0)" }
        return (numbers + flags).joined(separator: " ")
    }
}

@available(macOS 26.0, *)
struct DropPanelView: View {
    let metrics: NotchMetrics
    let onSettings: () -> Void
    @ObservedObject var tuning: DropTuning
    @ObservedObject var calendar: CalendarFeed
    @ObservedObject var updates: UpdateFeed

    // 모션 단계. 팝업은 따로 없고(2026-10-31) 노치가 팝업 크기까지 커지며, 아래쪽이 예전 팝업 모양(유리)이 된다.
    // dropped는 늘 grown과 같이 바뀐다(글·그림자를 보일지).
    @State private var grown = false
    @State private var dropped = false
    @State private var inked = true       // 커진 노치가 온통 검정인지. 열릴 때 검정으로 커졌다가 아래쪽이 유리로 걷힌다
    @State private var trayShown = false  // 하단 영역. 팝업 등장이 끝난 뒤에 나타난다
    /// 시험용: `--test-red` 면 늘 붉게(`--test-settings --test-open`과 같이 써서 본다)
    private static let testRed = CommandLine.arguments.contains("--test-red")
    @State private var finalRed = false   // 회의 10초 전부터 00:00 깜빡임이 끝나 닫힐 때까지 아래 유리를 붉게
    @State private var sequence: Task<Void, Never>?

    // 닫혀 있을 때도 너비를 restWidth만큼 늘여 둘 수 있다(restWide).
    private var notchWidth: CGFloat {
        metrics.width + (grown ? tuning.growWidth : tuning.restWide ? tuning.restWidth : 0)
    }


    /// 노치 모양을 그리는 틀 너비. 위 두 모서리는 화면 위 끝에서 바깥으로 오목하게 퍼지므로(위 반지름만큼)
    /// 틀이 모양 너비와 같으면 그 곡선이 잘린다. 양쪽으로 위 반지름만큼 넓힌다.
    private var shapeFrameWidth: CGFloat {
        popupSize.width + 2 * max(tuning.grownTopRadius, NotchMetrics.topRadius) + 2
    }

    /// 노치 전체(닫힘 = 실제 노치 + 좌우로 늘여 둔 만큼, 열림 = 예전 팝업 너비 × 화면 위 끝~예전 팝업 아래 끝).
    /// 이름은 예전 그대로 popupSize·popupShape를 쓴다. popupTop은 늘 0(화면 위 끝).
    private var popupSize: CGSize {
        grown ? CGSize(width: metrics.width + tuning.growWidth + tuning.popupExtraWidth,
                       height: tuning.notchBodyHeight(calendar: calendar, metrics: metrics))
              : CGSize(width: notchWidth, height: metrics.height)
    }
    private var popupTop: CGFloat { 0 }

    private var glass: Glass {
        let base: Glass = tuning.clearGlass ? .clear : .regular
        // 온통 검정일 때는 유리 자체도 검게 물들인다
        if inked && tuning.inkNeck { return base.tint(.black) }
        return tuning.tintOpacity > 0 ? base.tint(.black.opacity(tuning.tintOpacity)) : base
    }

    /// 노치 전체 모양. 위 두 모서리는 화면 위 끝과 이어지는 오목한 곡선(노치), 아래 두 모서리는
    /// 켜 두면 하단 영역 곡선과 같은 중심(하단 영역 반지름 + 여백), 끄면 팝업 반지름. 닫히면 실제 노치 모양.
    private var popupShape: NotchShape {
        let size = popupSize
        if !grown {
            // 닫힌 노치(좌우로 늘여 둔 검정)의 아래 모서리는 실제 노치(10)보다 4 크게(14) — 같으면 더 작아 보였다
            return NotchShape(width: size.width, height: size.height,
                              bottomRadius: NotchMetrics.bottomRadius + 4, topRadius: NotchMetrics.topRadius)
        }
        let limit = min(size.height / 2, size.width / 2)
        let bottom = tuning.popupBottomConcentric ? min(trayRadius + tuning.trayMargin, limit) : min(tuning.popupRadius, limit)
        return NotchShape(width: size.width, height: size.height, bottomRadius: bottom, topRadius: tuning.grownTopRadius)
    }

    /// 하단 영역 모서리 반지름. 팝업의 위 모서리 기준으로 정해서, 팝업 아래 모서리와 서로 물고 돌지 않게 한다.
    private var trayRadius: CGFloat {
        if tuning.trayCapsule { return tuning.trayHeight / 2 }
        let outer = min(tuning.popupRadius, popupSize.height / 2, popupSize.width / 2)
        let base = tuning.trayConcentric ? max(0, outer - tuning.trayMargin) : outer
        return max(0, min(base + tuning.trayRadiusPlus, tuning.trayHeight / 2))
    }

    var body: some View {
        ZStack(alignment: .top) {
            shadowLayer

            // 검정은 유리 "아래"에 깐다. 유리가 그 위에서 굴절·반사하므로 검정도 액체 유리 속에 있는 것처럼 보이고,
            // 가장자리에서는 유리의 렌즈 효과로 검정이 모서리를 따라 휜다. (위에 덮으면 매트한 평면이 된다)
            popupLayers

            notchButtons
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onReceive(Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()) { now in
            let red = Self.testRed || calendar.next.map {
                let left = $0.start.timeIntervalSince(now)
                return left <= 10 && left > -CalendarFeed.blink
            } ?? false
            if red != finalRed { withAnimation(.easeInOut(duration: 0.3)) { finalRed = red } }
        }
        .onChange(of: tuning.isOpen) { _, open in
            if open { calendar.reload() }
            play(open: open)
        }
    }

    /// 노치 좌우의 14pt 아이콘 버튼 두 개(IconShape.left / right, 다운로드한 SVG). 닫혀 있을 때는 실제(하드웨어) 노치 좌우 끝에 바짝 붙어 #181818,
    /// 열리면 #24252F가 되고 노치가 넓어지는 만큼 바깥으로 함께 움직인다. 높이는 늘 노치 높이 가운데.
    /// 오른쪽 원이 설정창을 연다. 왼쪽 원은 새 버전이 있을 때만 금색(#ffd700)이 되고, 누르면 업데이트한다.
    /// 업데이트가 끝나고 다시 뜨면 왼쪽 원이 1초간 파랗게(#0A84FF) 빛났다가 원래 색으로 돌아간다.
    @State private var hoverLeft = false
    @State private var hoverRight = false
    @State private var hoverTitle = false

    private var notchButtons: some View {
        let d: CGFloat = 14
        // 닫혀 있으면 실제 노치 좌우 끝 바로 바깥, 열리면 아이콘 바깥 끝을 글 좌우 끝(노치 끝에서 textPadding)에 맞춘다.
        // 높이는 실제 노치 가운데, 열리면 2 아래.
        let x = grown ? popupSize.width / 2 - tuning.textPadding - tuning.uiSideInset - d / 2
                      : metrics.width / 2 + d / 2
        let y = metrics.height / 2 - d / 2 + (grown ? 2 : 0)
        let color = grown ? Color(red: 0x24 / 255, green: 0x25 / 255, blue: 0x2F / 255)
                          : Color(red: 0x18 / 255, green: 0x18 / 255, blue: 0x18 / 255)
        // 열려 있을 때 마우스를 올리면 #303243
        let hover = Color(red: 0x30 / 255, green: 0x32 / 255, blue: 0x43 / 255)
        let update = updates.available != nil
        let gold = Color(red: 1, green: 0xd7 / 255, blue: 0)
        // 업데이트 뒤 첫 실행에서 1초간 파랗게 빛난다(UpdateFeed.flash)
        let blue = Color(red: 0x0a / 255, green: 0x84 / 255, blue: 1)  // #0A84FF
        let leftColor = updates.flash ? blue
                      : update ? (grown && hoverLeft ? gold.mix(with: .white, by: 0.3) : gold)
                               : (grown && hoverLeft ? hover : color)
        return ZStack {
            Button(action: { updates.install() }) {
                IconShape.left.fill(leftColor).frame(width: d, height: d)
                    .shadow(color: blue.opacity(updates.flash ? 0.9 : 0), radius: 4)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .onHover { hoverLeft = $0 }
            .buttonStyle(.plain)
            .focusable(false)
            .focusEffectDisabled()
            .help(updates.available.map { "\($0.version)(으)로 업데이트" } ?? "")
            .offset(x: -x)
            .allowsHitTesting(grown)   // 새 버전이 없을 때 눌러도 install()이 아무것도 안 한다(롤오버 색만)
            Button(action: onSettings) {
                IconShape.right.fill(grown && hoverRight ? hover : color).frame(width: d, height: d)
                    .frame(width: 24, height: 24)   // 누르기 쉽게 누르는 영역만 넓힘
                    .contentShape(Rectangle())
            }
            .onHover { hoverRight = $0 }
            .buttonStyle(.plain)
            .focusable(false)   // 키 창이 되면 첫 버튼에 파란 포커스 테두리가 잡히므로 끈다
            .focusEffectDisabled()
            .offset(x: x)
            .allowsHitTesting(grown)
        }
        .frame(height: 24)
        .offset(y: y - (24 - d) / 2)
    }

    /// 팝업과 그 유리 컨테이너. 검정 덮개 → 유리 → 글 순으로 쌓는다.
    private var popupLayers: some View {
        ZStack(alignment: .top) {
            popupBlack(opacity: tuning.blackOpacity)

            // 유리는 노치 전체 모양 하나. 위쪽은 검정에 덮이고 아래쪽만 유리로 보인다.
            Color.clear
                .frame(width: shapeFrameWidth, height: popupSize.height)
                .glassEffect(glass, in: popupShape)
                // 유리는 모양이 바뀔 때 자기 방식(둥근 사각형)으로 따로 움직여서, 열고 닫기를 빠르게 되풀이하면
                // 검정 노치보다 넓고 위 모서리가 볼록하게 둥근 유리가 드러나 노치가 화면 위에서 떨어져 보였다.
                // SwiftUI가 매 프레임 그리는 같은 모양으로 잘라 늘 검정 노치 안에만 보이게 한다.
                .mask { popupShape.fill(.black).frame(width: shapeFrameWidth, height: popupSize.height) }

            // 덧칠: 유리 아래 검정만으로는 유리가 빛을 더해 덜 검게 보인다. 같은 모양을 유리 위에 반투명으로 한 번 더.
            // 위에 덮는 만큼 유리 질감도 가려지므로 불투명도로 맞춘다(1이면 처음의 매트한 평면과 같아짐).
            popupBlack(opacity: tuning.overBlack)

            // 회의 10초 전 ~ 시작 뒤 00:00 깜빡임이 끝날 때까지: 아래 투명한 유리를 붉게(#ff3b30, 알림 시계 색) 채운다.
            // 검정 덮개와 같은 흐린 경계 아래로만 보이게 덮개 모양을 오려 낸다. 하단 캡슐·글은 이 위에 그대로.
            popupShape.fill(Color(red: 1, green: 0x3b / 255, blue: 0x30 / 255).opacity(0.85))
                .frame(width: shapeFrameWidth, height: popupSize.height)
                .mask {
                    Rectangle()
                        .overlay { blackCover.frame(width: popupSize.width, height: popupSize.height, alignment: .topLeading)
                            .blendMode(.destinationOut) }
                        .compositingGroup()
                }
                .opacity(finalRed && dropped ? 1 : 0)

            // 온통 검정: 노치와 같은 검정으로 커졌다가 걷혀 아래쪽 유리가 드러난다.
            popupShape.fill(.black)
                .frame(width: shapeFrameWidth, height: popupSize.height)
                .offset(y: popupTop)
                .opacity(inked ? 1 : 0)

            // 위쪽 띠(실제 노치 높이)는 하드웨어 노치와 같은 검정. 그 아래 60에 걸쳐 옅어져
            // 검정 덮개(흐린 경계)로 이어진다. 닫히면 모양 전체가 이 띠 안이라 온통 검정.
            popupShape.fill(.black)
                .frame(width: shapeFrameWidth, height: popupSize.height)
                .mask {
                    LinearGradient(stops: [.init(color: .black, location: 0),
                                           .init(color: .black, location: metrics.height / max(popupSize.height, 1)),
                                           .init(color: .clear, location: min(1, (metrics.height + 60) / max(popupSize.height, 1)))],
                                   startPoint: .top, endPoint: .bottom)
                }
            // (글보다 아래에 깐다. 위에 덮으면 시계·글 윗부분이 검정에 가려 어두워진다)

            // 유리 위에 얹는 것: 하단 영역, 테두리 빛, 글
            ZStack(alignment: .topLeading) {
                // 계정을 고르는 동안은 하단 캡슐(흰 곳)을 없앤다.
                tray(Color.white.opacity(tuning.trayOpacity))
                    .opacity(trayShown && !calendar.picking ? 1 : 0)
                rim
                // 왼쪽: 남은 시간(금색) 아래에 회의 제목(어두운 금색). 오른쪽: 날짜·시각 두 줄.
                // 0.5초마다 다시 그린다(남은 시간, 퇴근 알림, 00:00 깜빡임, 콜론 깜빡임).
                // 초 경계에서 시작해 숫자와 콜론이 같은 순간에 바뀌게 한다.
                // 계정을 고르는 중이면 시계 자리에 계정 목록(AccountPicker)
                Group { if calendar.picking {
                    // 스크롤 영역은 노치 위 끝 ~ 아래 끝 전체(아래 .padding(.top)을 되돌린다). 첫 화면은 글 줄 자리에서 시작하고
                    // 마지막 줄 아래 여백은 18. 계정마다 검정 상자에 담기므로 아래 투명한 유리까지 내려가도 읽힌다.
                    AccountPicker(calendar: calendar, textSize: tuning.textSize,
                                  onLater: { calendar.later(); tuning.isOpen = false },
                                  topInset: tuning.contentTop(metrics: metrics), bottomInset: 18, fadeTop: metrics.height)
                        .frame(height: popupSize.height)
                        .padding(.top, -tuning.contentTop(metrics: metrics))
                } else {
                TimelineView(.periodic(from: Date(timeIntervalSinceReferenceDate: Date().timeIntervalSinceReferenceDate.rounded(.down)), by: 0.5)) { context in
                    let now = context.date
                    // 퇴근 알림은 닫힘 모션이 끝날 때까지(10초 + 2초) 그대로 보여 준다
                    let home = GoHome.isTime(now, seconds: GoHome.seconds + 2)
                    HStack(alignment: .top) {
                        if home {
                            // 평일 18시: "18:00"을 하늘색으로, 열려 있는 10초 동안 회의 시작 00:00처럼 깜빡인다
                            let blinking = GoHome.isTime(now, seconds: GoHome.seconds)
                            clockColumn(text: GoHome.clock, title: "Go home Now!", color: (0x87 / 255, 0xce / 255, 0xeb / 255),  // skyblue #87ceeb
                                        clockVisible: !blinking || Int(now.timeIntervalSinceReferenceDate * 2) % 2 == 0)
                        } else if let next = calendar.next {
                            // 임시: 다음 회의까지 남은 시간. 알림으로 열려 있는 동안만 붉게:
                            // 10분 전 10초간, 5분 전부터 시작 뒤 00:00을 깜빡이는 10초까지
                            // 시험용: `--test-long-countdown` 이면 회의를 12시간 뒤로 밀어 HH:MM:SS를 보여 준다
                            let start = next.start.addingTimeInterval(CommandLine.arguments.contains("--test-long-countdown") ? 12 * 3600 : 0)
                            let left = start.timeIntervalSince(now)
                            let alert = left <= 5 * 60 || (left > 10 * 60 - 10 && left <= 10 * 60)
                            let blinking = left <= 0 && left > -CalendarFeed.blink
                            let text = countdownText(to: start, now: now)
                            clockColumn(text: text, title: calendar.summary,
                                        color: clockColor(alert: alert, left: left),
                                        clockVisible: !blinking || Int(now.timeIntervalSinceReferenceDate * 2) % 2 == 0,
                                        colonBlink: left > 0 && left < 100 * 3600, now: now,
                                        width: clockWidth(for: text),
                                        onTitle: openCalendarApp)
                        } else {
                            Text(calendar.summary)
                                .foregroundStyle(Color(red: 0xcc / 255, green: 0xcc / 255, blue: 0xdd / 255))
                                .onTapGesture {
                                    if calendar.status == .noAccount || calendar.status == .denied { calendar.startPicking() }
                                }
                        }
                        Spacer(minLength: 0)  // HH:MM:SS는 너비가 정해져 있어 최소 간격은 clockWidth가 정한다
                        if let when = home ? GoHome.when(now) : calendar.nextWhen {
                            Text(when.day + "\n" + when.time).multilineTextAlignment(.trailing).fixedSize()
                                .foregroundStyle(Color(red: 0xcc / 255, green: 0xcc / 255, blue: 0xdd / 255))  // #ccccdd
                        }
                    }
                }
                } }
                    .font(.system(size: tuning.textSize, weight: .light))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, tuning.textPadding + tuning.uiSideInset)  // 노치 좌우 끝에서 trayMargin + 3(하단 캡슐 좌우 끝보다 3 안쪽)
                    .padding(.top, tuning.contentTop(metrics: metrics))
                    .opacity(dropped ? 1 : 0)
            }
            .frame(width: popupSize.width, height: popupSize.height, alignment: .topLeading)
            .clipShape(popupShape)
            .offset(y: popupTop)
        }
        // 계정 고르기로 팝업 높이가 바뀔 때 부드럽게
        .animation(.spring(duration: 0.45, bounce: 0.15), value: calendar.picking)
        .animation(.spring(duration: 0.45, bounce: 0.15), value: calendar.accounts.count)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// 왼쪽 시계와 그 아래 제목. 너비를 고정한 시계는 글자 수가 줄면 커져 아래로 늘어나고 제목은 그만큼 밀린다.
    /// 제목은 늘 시계 색을 70%로 어둡게 한 색.
    private func clockColumn(text: String, title: String, color: (r: Double, g: Double, b: Double),
                             clockVisible: Bool = true, colonBlink: Bool = false, now: Date = Date(),
                             width: CGFloat? = nil, onTitle: (() -> Void)? = nil) -> some View {
        let size = ClockFont.size(for: text, width: width ?? tuning.countdownWidth)
        let small = NSFont.systemFont(ofSize: tuning.textSize, weight: .light)
        let smallCapTop = small.ascender - small.capHeight  // 작은 글 프레임 위 ~ 글자 위 끝
        // 제목은 오른쪽 날짜 글보다 2 크게. 시계와의 간격은 제목 글자 위 끝 기준이라 제목 글꼴로 잰다.
        let titleSize = tuning.textSize + 2
        let titleFont = NSFont.systemFont(ofSize: titleSize, weight: .light)
        let titleCapTop = titleFont.ascender - titleFont.capHeight
        return VStack(alignment: .leading, spacing: tuning.countdownGap - titleCapTop - size * ClockFont.descent) {
            ClockText(text: text, size: size, colonBlink: colonBlink, now: now)
                .foregroundStyle(Color(red: color.r, green: color.g, blue: color.b))
                .offset(x: tuning.countdownX)
                .opacity(clockVisible ? 1 : 0)
            Text(title)
                .font(.system(size: titleSize, weight: .light))
                .foregroundStyle(titleColor(color, hover: onTitle != nil && hoverTitle))
                .offset(x: 3, y: 2)  // 글 줄에서 오른쪽으로 3(−1 → 1 → 3), 아래로 2
                .onHover { hoverTitle = $0 }
                .onTapGesture { onTitle?() }
        }
        // 숫자 위 끝이 오른쪽 날짜 글자 위 끝과 같은 높이에 오도록 끌어올린다
        .padding(.top, smallCapTop - size * ClockFont.capTop - tuning.countdownLift)
    }

    /// 시계 너비. HH:MM:SS(콜론 둘)는 날짜와 상관없이 고정: 글 줄 너비에서 68을 뺀 너비.
    /// 68 = "Sat, Oct 31" 너비(57) + 간격 12 + countdownX(−9, 왼쪽으로 밀려 그려지는 만큼) + 8.
    /// 2026-10-31에 날짜 글 12 앞까지 채우던 271에서 8 줄인 263(노치 409 기준). 그 뒤 countdownX를 −7로 옮겨 오른쪽 간격은 2 줄었다.
    /// 칸 끝 기준 오른쪽 글과의 간격은 가장 넓은 날짜(Wed, May 30) 9.5 ~ 가장 좁은 날짜(Fri, Jul 7) 33.
    /// 그 밖(MM:SS 등)은 countdownWidth.
    private func clockWidth(for text: String) -> CGFloat {
        guard text.filter({ $0 == ":" }).count == 2 else { return tuning.countdownWidth }
        let content = popupSize.width - 2 * (tuning.textPadding + tuning.uiSideInset)
        return content - 68
    }

    /// 시계 색: 알림 중 #ff3b30, 1시간 이상 남음(HH:MM:SS) #686B88, 그 밖에 금색 #ffd700
    private func clockColor(alert: Bool, left: TimeInterval) -> (r: Double, g: Double, b: Double) {
        if alert { return (1, 0x3b / 255, 0x30 / 255) }
        if left >= 3600 { return (0x68 / 255, 0x6b / 255, 0x88 / 255) }
        return (1, 0xd7 / 255, 0)
    }

    /// 제목 색: 시계 색의 70%. 누를 수 있는 제목에 마우스를 올리면 흰색을 30% 섞는다.
    private func titleColor(_ c: (r: Double, g: Double, b: Double), hover: Bool) -> Color {
        let mix = hover ? 0.3 : 0
        func ch(_ v: Double) -> Double { v * 0.7 * (1 - mix) + mix }
        return Color(red: ch(c.r), green: ch(c.g), blue: ch(c.b))
    }

    /// 회의 제목을 누르면 캘린더 앱을 띄운다
    private func openCalendarApp() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
    }

    /// 팝업 자리에 놓인 검정 덮개. 하단 영역 모양만큼은 오려 내서 그 안에 검정이 들어오지 않게 한다.
    private func popupBlack(opacity: CGFloat) -> some View {
        blackCover
            .opacity(opacity)
            .frame(width: popupSize.width, height: popupSize.height, alignment: .topLeading)
            .mask {
                Rectangle()
                    .overlay { tray(Color.black).opacity(trayShown && !calendar.picking ? 1 : 0).blendMode(.destinationOut) }
                    .compositingGroup()
            }
            .clipShape(popupShape)
            .offset(y: popupTop)
    }

    /// 하단 영역: 팝업 아래쪽에 좌우·아래 여백을 두고 놓은 둥근 사각형. 팝업 크기만 한 틀 안에 그린다.
    private func tray(_ style: some ShapeStyle) -> some View {
        let margin = tuning.trayMargin
        return RoundedRectangle(cornerRadius: trayRadius)
            .fill(style)
            // 노치 너비에 맞춰 좌우 여백만 두고 넓힌다
            .frame(width: max(0, popupSize.width - margin * 2), height: tuning.trayHeight)
            .padding(.bottom, margin)
            .frame(width: popupSize.width, height: popupSize.height, alignment: .bottom)
    }

    /// 팝업 모양을 위로 길게 늘여 그린 뒤 흐리게 한다.
    /// 흐린 경계가 모양의 아래 모서리 곡선을 따라가므로, 모서리 쪽에서는 검정이 위로 휘어 올라간다.
    private var blackCover: some View {
        let extraTop: CGFloat = 120
        let height = max(0, popupSize.height - tuning.lift + extraTop)
        return RoundedRectangle(cornerRadius: tuning.blackRadius)
            .fill(.black)
            .frame(width: max(0, popupSize.width - tuning.sideInset * 2), height: height)
            .offset(x: tuning.sideInset, y: -extraTop)
            .blur(radius: tuning.softness)
    }

    /// 유리 가장자리 빛. 위는 밝게, 옆은 거의 없게, 아래는 다시 살짝 — 빛이 위에서 비치는 유리처럼.
    private var rim: some View {
        popupShape
            .stroke(
                LinearGradient(stops: [
                    .init(color: .white.opacity(tuning.rimOpacity), location: 0),
                    .init(color: .white.opacity(tuning.rimOpacity * 0.15), location: 0.45),
                    .init(color: .white.opacity(tuning.rimOpacity * 0.6), location: 1),
                ], startPoint: .top, endPoint: .bottom),
                lineWidth: tuning.rimWidth * 2)  // 모양 밖으로 나간 절반은 아래 clipShape로 잘린다
            .clipShape(popupShape)
            .blur(radius: tuning.rimSoftness)
    }

    /// 바깥 그림자만 남긴다. 그림자를 만드는 모양 자체는 오려 내서 투명한 유리 안이 어두워지지 않게 한다.
    private var shadowLayer: some View {
        let shapes = popupShape.fill(.black)
            .frame(width: shapeFrameWidth, height: popupSize.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

        return shapes
            .shadow(color: .black.opacity(tuning.shadowOpacity), radius: tuning.shadowRadius, y: tuning.shadowY)
            .mask {
                Rectangle()
                    .overlay { shapes.blendMode(.destinationOut) }
                    .compositingGroup()
            }
            .opacity(dropped ? 1 : 0)
    }

    private func play(open: Bool) {
        sequence?.cancel()
        let t = tuning
        let line = t.openTimeline
        let ink = Double(t.inkDuration)

        // (시작 시각, 할 일). 닫힘은 열림을 정확히 거꾸로: 열림에서 [s, s+d]에 있던 움직임은
        // 닫힘에서 [T−s−d, T−s]에 놓이고, 곡선도 시간을 뒤집은 것(ReversedSpring, easeInOut은 대칭)을 쓴다.
        var steps: [(at: Double, run: () -> Void)]
        if open {
            steps = [
                (0, { withAnimation(.spring(line.grow)) { grown = true; dropped = true } }),
                (line.inkStart, { withAnimation(.easeInOut(duration: ink)) { inked = false } }),
                (line.total + Double(t.trayDelay), {
                    withAnimation(.easeInOut(duration: Double(t.trayFade))) { trayShown = true } }),
            ]
        } else {
            let k = Double(t.closeSpeed)
            let T = line.total
            // 하단 영역은 역재생에 넣지 않는다(넣으면 그만큼 늦게 닫힌다). 닫힘 시작과 함께 사라진다.
            steps = [
                (0, { withAnimation(.easeInOut(duration: Double(t.trayFade) * k)) { trayShown = false } }),
                (k * (T - line.inkStart - ink), {
                    withAnimation(.easeInOut(duration: ink * k)) { inked = true } }),
                (k * (T - line.grow.visibleDuration), {
                    withAnimation(Animation(ReversedSpring(spring: line.grow, scale: k))) { grown = false; dropped = false } }),
            ]
        }
        steps.sort { $0.at < $1.at }

        sequence = Task { @MainActor in
            var now = 0.0
            for step in steps {
                if step.at > now {
                    try? await Task.sleep(for: .seconds(step.at - now))
                    now = step.at
                }
                guard !Task.isCancelled else { return }
                step.run()
            }
        }
    }
}

/// 스프링을 시간 거꾸로 재생하는 애니메이션. 열림 스프링의 끝(튕김)부터 시작해서 출발점의 느린 가속으로 끝난다.
/// 값은 0 → value로 가야 하므로, 정방향 스프링 s(t)에 대해 value − s(D − t)를 돌려준다(D = visibleDuration).
extension Spring {
    /// 목표와의 차이가 이동 거리의 0.5% 안으로 들어온 뒤로는 눈에 안 보이는 잔떨림이다.
    /// settlingDuration은 이 꼬리까지 포함해서 길고(튕김 0.4, 0.75초 스프링이면 1.73초),
    /// 그대로 역재생하면 닫기 시작할 때 아무것도 안 움직이는 공백이 생긴다.
    var visibleDuration: Double {
        var t = settlingDuration
        while t > 0 {
            if abs(value(target: 1.0, time: t) - 1) > 0.005 { return t }
            t -= 1.0 / 240
        }
        return 0
    }
}

struct ReversedSpring: CustomAnimation {
    let spring: Spring
    let scale: Double   // 시간 배율

    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        let duration = spring.visibleDuration
        let local = time / scale
        guard local < duration else { return nil }
        var result = value
        result -= spring.value(target: value, time: duration - local)
        return result
    }
}

struct DropControlView: View {
    let metrics: NotchMetrics
    @ObservedObject var tuning: DropTuning

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button("열기") { tuning.isOpen = true }
                Button("닫기") { tuning.isOpen = false }
                Button("다시 재생") { replay() }
                Spacer()
                Button("11차설정") { tuning.applyEleventhPreset(); replay() }
                Button("종료") { NSApp.terminate(nil) }
            }
            .padding(16)
            Divider()
            column {
                section("노치 크기")
                sliderRow("열린 너비 +", $tuning.growWidth, 0...300, step: 2)
                sliderRow("열린 높이(글 아래)", $tuning.popupHeight, 120...400, step: 2)
                sliderRow("위 모서리(오목)", $tuning.grownTopRadius, 0...30)
                Toggle("닫혀 있을 때도 너비를 늘여 둠", isOn: $tuning.restWide)
                sliderRow("닫혔을 때 너비 +", $tuning.restWidth, 0...200)

                section("유리와 검정")
                Toggle("clear 유리 (끄면 regular)", isOn: $tuning.clearGlass)
                sliderRow("유리 검정 틴트", $tuning.tintOpacity, 0...1, step: 0.05)
                sliderRow("검정 끌어올림", $tuning.lift, -40...300)
                sliderRow("흐림(전이 길이)", $tuning.softness, 0...80)
                sliderRow("검정 모서리 반지름", $tuning.blackRadius, 0...80)
                sliderRow("양옆 들임", $tuning.sideInset, -30...60)
                sliderRow("검정 불투명도", $tuning.blackOpacity, 0...1, step: 0.05)
                sliderRow("유리 위 덧칠", $tuning.overBlack, 0...1, step: 0.05)

                section("하단 캡슐")
                sliderRow("높이", $tuning.trayHeight, 0...200)
                sliderRow("좌우·아래 여백", $tuning.trayMargin, 0...40)
                sliderRow("흰색 불투명도", $tuning.trayOpacity, 0...1, step: 0.05)
                sliderRow("나타나는 때(열림 끝 기준)", $tuning.trayDelay, -1...3, step: 0.05)
                sliderRow("나타나는 시간", $tuning.trayFade, 0.05...2, step: 0.05)

                section("테두리와 그림자")
                sliderRow("테두리 빛 밝기", $tuning.rimOpacity, 0...1, step: 0.05)
                sliderRow("테두리 빛 굵기", $tuning.rimWidth, 0...6)
                sliderRow("테두리 빛 번짐", $tuning.rimSoftness, 0...6)
                sliderRow("그림자 진하기", $tuning.shadowOpacity, 0...1, step: 0.05)
                sliderRow("그림자 번짐", $tuning.shadowRadius, 0...60)
                sliderRow("그림자 아래로", $tuning.shadowY, -10...40)

                section("모션 (초)")
                sliderRow("커지는 시간", $tuning.growDuration, 0.05...2, step: 0.05)
                sliderRow("튕김", $tuning.growBounce, 0...0.8, step: 0.05)
                sliderRow("검정 걷히기 시작", $tuning.inkDelay, 0...3, step: 0.05)
                sliderRow("검정 → 유리 시간", $tuning.inkDuration, 0.05...3, step: 0.05)
                Toggle("커지는 동안 유리도 검게 (틴트)", isOn: $tuning.inkNeck)
                sliderRow("닫힘 속도 배율 (1 = 열 때 그대로 역재생)", $tuning.closeSpeed, 0.2...1.5, step: 0.05)
                timeline

                section("마우스")
                sliderRow("여는 거리(노치 좌우)", $tuning.hoverMargin, 0...200)
                sliderRow("여는 거리(노치 아래)", $tuning.hoverDown, 0...200)
                sliderRow("닫는 거리(노치 둘레)", $tuning.keepMargin, 0...80)
                Toggle("설정창이 떠 있으면 펼친 채 유지", isOn: $tuning.holdWhileSettings)
            }
        }
        // 검정 바탕에 맞춰 컨트롤·글자를 어두운 모양(흰 글자)으로
        .environment(\.colorScheme, .dark)
        .foregroundStyle(.white)
        .background(Color.black)
        .frame(width: 500, height: 760)
    }

    /// 한 단. 항목 사이 간격은 예전 8에서 20% 늘린 9.6
    private func column<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9.6) { content() }
                .padding(16)
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity)
    }

    /// 중간 제목. 예전 .headline(13pt)의 두 배
    private func section(_ title: String) -> some View {
        Text(title).font(.system(size: 26, weight: .semibold)).padding(.top, 9.6)
    }

    /// 열 때 시간표: 노치가 커지는 동안(흰색)과 검정이 걷혀 유리가 드러나는 동안(회색)
    private var timeline: some View {
        let line = tuning.openTimeline
        let grow = line.grow.visibleDuration
        let inkStart = line.inkStart
        let inkEnd = inkStart + Double(tuning.inkDuration)
        let total = max(line.total, 0.01)
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let scale = geo.size.width / total
                VStack(alignment: .leading, spacing: 3) {
                    Capsule().fill(.white)
                        .frame(width: max(2, grow * scale), height: 6)
                    Capsule().fill(.gray)
                        .frame(width: max(2, Double(tuning.inkDuration) * scale), height: 6)
                        .offset(x: inkStart * scale)
                }
            }
            .frame(height: 16)
            Text(String(format: "노치(흰색) 0 → %.2f초 · 검정→유리(회색) %.2f → %.2f초 · 전체 %.2f초",
                        grow, inkStart, inkEnd, total))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func replay() {
        tuning.isOpen = false
        let wait = tuning.openTimeline.total * Double(tuning.closeSpeed) + 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
            tuning.isOpen = true
        }
    }
}

@available(macOS 26.0, *)
@MainActor
final class SiriDemo: NSObject {
    private var panel: NotchPanel?
    private var statusItem: NSStatusItem?
    private var controlWindow: NSWindow?
    private var metrics: NotchMetrics?
    private var mouseTimer: Timer?
    private let tuning = DropTuning()
    private let calendar = CalendarFeed()
    private let updates = UpdateFeed()
    private var updateItem: NSMenuItem?

    func start(metrics: NotchMetrics) {
        self.metrics = metrics
        // 슬라이더 최대값과 그림자가 잘리지 않게 넉넉하게 잡는다.
        let size = CGSize(width: 1000, height: 620)
        let panel = NotchPanel(frame: NotchPanel.topCenterFrame(on: metrics.screen, size: size))
        // 앱이 비활성이어도 활성 모양(유리)으로 그린다. 실제로 효과가 있는 건 NotchPanel의 비공개 메서드 덮어쓰기.
        let root = DropPanelView(metrics: metrics, onSettings: { [weak self] in self?.toggleSettings() },
                                tuning: tuning, calendar: calendar, updates: updates)
            .environment(\.appearsActive, true)
            .environment(\.controlActiveState, .key)
        panel.contentView = FirstClickHostingView(rootView: root)
        panel.forceActive = true
        panel.allowsKey = true
        panel.orderFrontRegardless()
        panel.makeKey()
        self.panel = panel
        calendar.start()
        updates.start()

        // 설정창은 처음엔 숨겨 두고, 노치의 설정 아이콘으로 연다. 패널을 가리지 않게 오른쪽 아래에 둔다.
        let control = makeControlWindow(title: "Developer Test Setting", on: metrics.screen, below: 600,
                                        content: DropControlView(metrics: metrics, tuning: tuning))
        // 검정 바탕: 제목 막대까지 검정으로 이어지게
        control.appearance = NSAppearance(named: .darkAqua)
        control.backgroundColor = .black
        control.titlebarAppearsTransparent = true
        control.setFrameOrigin(CGPoint(x: metrics.screen.frame.maxX - control.frame.width - 20,
                                       y: metrics.screen.frame.minY + 20))
        controlWindow = control
        // 시험용: `--test-settings` 로 띄우면 설정창을 바로 연다
        if CommandLine.arguments.contains("--test-settings") { control.orderFrontRegardless() }
        // 시험용: `--test-settings --test-open` 이면 2초 뒤 노치를 열고, 설정창이 떠 있는 동안 펼친 채 둔다
        // 시험용: `--test-settings --test-flicker` 면 2초 뒤부터 6초 동안 0.1~0.35초 간격으로 열고 닫기를 반복한다(마우스를 넣었다 뺐다 하는 흉내)
        if CommandLine.arguments.contains("--test-flicker") {
            var at = 2.0
            while at < 8 {
                DispatchQueue.main.asyncAfter(deadline: .now() + at) { [weak self] in self?.tuning.isOpen.toggle() }
                at += Double.random(in: 0.1...0.35)
            }
        }
        if CommandLine.arguments.contains("--test-open") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.tuning.isOpen = true }
        }

        // 마우스 위치를 짧은 간격으로 확인한다. 전역 이벤트 감시와 달리 손쉬운 사용 권한이 필요 없다.
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.trackMouse() }
        }
        RunLoop.main.add(timer, forMode: .common)
        mouseTimer = timer

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeForSpaceChange() }
        }
        // 트랙패드 스와이프로 옆 데스크탑이 30% 들어오면 넘어가기 전에 닫는다(입력 모니터링 권한 필요).
        // 위 공식 알림은 키보드·Mission Control로 바꿀 때와, 이 방법이 안 될 때를 맡는다.
        let swipe = SpaceSwipeWatcher { [weak self] in self?.closeForSpaceChange() }
        swipe.start()
        spaceSwipe = swipe

        setUpStatusItem()
    }

    /// 메뉴 막대 아이콘과 메뉴(설정, 종료)
    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = Self.menuBarIcon() {
            image.isTemplate = true   // 회색 단색 그림이라 메뉴 막대 밝기에 맞춰 칠하게
            image.size = NSSize(width: 16, height: 16)
            item.button?.image = image
        } else {
            item.button?.title = "36"
        }
        let menu = NSMenu()
        menu.delegate = self
        let version = NSMenuItem(title: "36NOCH \(UpdateFeed.currentVersion)", action: nil, keyEquivalent: "")
        version.isEnabled = false
        menu.addItem(version)
        let update = NSMenuItem(title: "업데이트 확인…", action: #selector(menuUpdate), keyEquivalent: "")
        update.target = self
        menu.addItem(update)
        updateItem = update
        menu.addItem(.separator())
        let account = NSMenuItem(title: "캘린더 계정…", action: #selector(menuCalendarAccount), keyEquivalent: "")
        account.target = self
        menu.addItem(account)
        let settings = NSMenuItem(title: "설정…", action: #selector(menuSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "36NOCH 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    @objc private func menuSettings() { toggleSettings() }
    @objc private func menuCalendarAccount() { calendar.startPicking() }

    /// 새 버전이 있으면 바로 업데이트, 없으면 확인하고 결과를 알린다
    @objc private func menuUpdate() {
        if updates.available != nil { updates.install(); return }
        Task {
            let found = await updates.check()
            if found == true { updates.install(); return }
            let alert = NSAlert()
            alert.messageText = found == false ? "최신 버전입니다" : "확인하지 못했습니다"
            alert.informativeText = found == false ? "36NOCH \(UpdateFeed.currentVersion)"
                                                   : "인터넷 연결을 확인한 뒤 다시 시도하세요."
            NSApp.activate()
            alert.runModal()
        }
    }

    /// .app 번들 안(Contents/Resources)에서 찾고, `swift build`로 띄운 경우엔 저장소의 Resources에서 찾는다.
    private static func menuBarIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "menubarIcon", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return NSImage(contentsOf: repo.appendingPathComponent("Resources/menubarIcon.png"))
    }

    private func toggleSettings() {
        guard let control = controlWindow else { return }
        if control.isVisible {
            control.orderOut(nil)
        } else {
            control.orderFrontRegardless()
        }
    }

    /// 닫혀 있을 때: 마우스가 실제 노치 근처에 오면 연다.
    /// 열려 있을 때: 커진 노치 + 팝업 영역 안이면 유지, 벗어나면 닫는다.
    private func trackMouse() {
        guard let metrics, let panel else { return }
        let mouse = NSEvent.mouseLocation
        let sf = metrics.screen.frame
        let t = tuning

        // 설정창이 떠 있으면 펼친 채 유지. 설정창을 닫으면 다음 확인(1/60초 뒤)에 바로 아래 규칙으로 돌아가서,
        // 마우스가 노치+팝업 위에 없으면 곧장 닫힌다.
        // 회의 알림도 마찬가지로 마우스와 상관없이 펼친 채 유지한다.
        // 팝업에서 캘린더 계정을 고르는 동안도 열어 둔다(고를 계정이 있을 때만. 권한 거부·계정 없음은 안내 글만이라 붙들지 않는다).
        let choosing = calendar.picking && calendar.status != .denied && !calendar.accounts.isEmpty
        var alerting = meetingAlert() || GoHome.isTime(Date(), seconds: GoHome.seconds) || choosing
        // 데스크탑을 바꿔 닫은 알림은 그 알림이 끝날 때까지 다시 열지 않는다
        if !alerting { alertMuted = false }
        if alertMuted { alerting = false }
        if alerting && !t.isOpen { t.isOpen = true }
        let holding = alerting || (t.holdWhileSettings && (controlWindow?.isVisible ?? false))
        if !holding {
            if t.isOpen {
                if !keepRect(screen: sf, metrics: metrics, margin: t.keepMargin).contains(mouse) { t.isOpen = false }
            } else {
                let notch = CGRect(x: sf.midX - metrics.width / 2, y: sf.maxY - metrics.height,
                                   width: metrics.width, height: metrics.height)
                // 위쪽은 화면 끝이라 여백이 필요 없지만, 끝에 붙은 마우스도 잡히게 위로도 넓힌다.
                // 화면 좌표는 y가 위로 커진다. 아래쪽만 hoverDown으로 따로 둔다.
                let hover = CGRect(x: notch.minX - t.hoverMargin, y: notch.minY - t.hoverDown,
                                   width: notch.width + t.hoverMargin * 2,
                                   height: notch.height + t.hoverDown + t.hoverMargin)
                // 데스크탑을 바꿔 닫은 뒤에는 마우스가 한 번 노치 밖으로 나갔다 와야 다시 연다
                if !hover.contains(mouse) { reopenBlocked = false }
                if hover.contains(mouse) && !reopenBlocked { t.isOpen = true }
            }
        }
        // 열려 있고 마우스가 노치+팝업 위에 있을 때만 클릭을 받는다(설정 아이콘).
        // 패널 창은 1000×620으로 커서, 창 전체가 클릭을 받으면 겹친 설정창의 제목 막대·버튼 클릭까지 가로챈다.
        let overContent = keepRect(screen: sf, metrics: metrics, margin: 0).contains(mouse)
        panel.ignoresMouseEvents = !(t.isOpen && overContent)
    }

    private var alertUntil = Date.distantPast
    /// 데스크탑을 바꿔 닫았을 때: 진행 중인 알림(계정 고르기)은 끝날 때까지 붙들지 않고(alertMuted),
    /// 마우스가 노치 위에 있었으면 한 번 벗어날 때까지 다시 열지 않는다(reopenBlocked)
    private var alertMuted = false
    private var spaceSwipe: SpaceSwipeWatcher?
    private var reopenBlocked = false

    /// 데스크탑(스페이스)이 바뀌면 설정창을 닫고 노치도 닫힘 모션으로 닫는다. 계정 고르기 중이면 "Choose later"와 같게 처리.
    /// macOS 공식 알림이라 권한이 필요 없지만, 전환이 거의 끝난 뒤에 온다(스와이프 30% 같은 중간 시점은 알 수 없음).
    /// 다만 회의 알림(10분 전 10초, 5분 전부터 시작 뒤 00:00 깜빡임까지)과 퇴근 알림으로 열려 있는 동안은
    /// 시간을 계속 보여 주는 게 우선이라 노치는 닫지 않는다(설정창만 닫는다).
    private func closeForSpaceChange() {
        controlWindow?.orderOut(nil)
        if meetingAlert() || GoHome.isTime(Date(), seconds: GoHome.seconds) { return }
        if calendar.picking { calendar.later() }
        alertMuted = true
        reopenBlocked = true
        tuning.isOpen = false
    }
    private var alertedTen: String?
    private var reloadedAfter: String?

    /// 회의 알림: 10분 전이 되면 10초간, 5분 전부터 시작 뒤 10초(00:00 깜빡임)까지 팝업을 열어 둔다.
    private func meetingAlert() -> Bool {
        guard let next = calendar.next else { return false }
        let now = Date()
        let left = next.start.timeIntervalSince(now)
        if left <= 0 {
            // 시작하면 10초간 00:00을 깜빡이며 열어 두고, 닫힘 모션이 끝난 뒤에 다음 회의로 넘어간다
            if left > -CalendarFeed.blink { return true }
            if left <= -CalendarFeed.linger && reloadedAfter != next.id {
                reloadedAfter = next.id
                calendar.reload()
            }
            return false
        }
        if left <= 10 * 60 && left > 10 * 60 - 10 && alertedTen != next.id {
            alertedTen = next.id
            alertUntil = now.addingTimeInterval(10)
        }
        return now < alertUntil || left <= 5 * 60
    }

    /// 커진 노치와 팝업(간격 포함)을 감싸는 사각형에 여백을 더한 것, 화면 좌표
    private func keepRect(screen sf: CGRect, metrics: NotchMetrics, margin: CGFloat) -> CGRect {
        let t = tuning
        let width = metrics.width + t.growWidth + t.popupExtraWidth  // 팝업이 커진 노치보다 넓다
        let height = t.notchBodyHeight(calendar: calendar, metrics: metrics)
        return CGRect(x: sf.midX - width / 2, y: sf.maxY - height, width: width, height: height)
            .insetBy(dx: -margin, dy: -margin)
    }

    func stop() {
        mouseTimer?.invalidate()
        tuning.save()
        print(tuning.summary)
    }
}

/// 비활성 패널에서도 첫 클릭이 바로 버튼에 가게 한다.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@available(macOS 26.0, *)
extension SiriDemo: NSMenuDelegate {
    /// 메뉴를 열 때 업데이트 항목 글을 지금 상태로
    func menuNeedsUpdate(_ menu: NSMenu) {
        switch updates.state {
        case .installing: updateItem?.title = "업데이트 중…"
        case .checking: updateItem?.title = "확인 중…"
        default:
            updateItem?.title = updates.available.map { "\($0.version)(으)로 업데이트" } ?? "업데이트 확인…"
        }
        updateItem?.isEnabled = updates.state != .installing && updates.state != .checking
    }
}

extension DropTuning {
    /// 커진 노치 안에서 글 틀의 위 끝(화면 위 끝에서). 시계 숫자 위 끝 = 날짜 글자 위 끝 = 실제 노치 아래 + clockGap.
    func contentTop(metrics: NotchMetrics) -> CGFloat {
        let small = NSFont.systemFont(ofSize: textSize, weight: .light)
        return metrics.height + clockGap - (small.ascender - small.capHeight)
    }

    /// 커진 노치 전체 높이(화면 위 끝 ~ 아래 끝). 예전 팝업 내용(popupHeight, 위 여백 textTop 포함)을
    /// 글 틀 위 끝(contentTop)에 맞춰 올려 놓은 높이.
    @MainActor
    func notchBodyHeight(calendar: CalendarFeed, metrics: NotchMetrics) -> CGFloat {
        contentTop(metrics: metrics) + popupHeight(calendar: calendar, metrics: metrics) - textTop
    }

    /// 지금 팝업 높이. 캘린더 계정을 고르는 동안은 목록이 다 들어가게 늘린다(아래 여백 18).
    /// 다만 화면 높이의 절반, 그리고 노치 패널(620) 안에 그림자까지 들어가는 높이를 넘지 않는다. 넘치면 목록이 스크롤된다.
    @MainActor
    func popupHeight(calendar: CalendarFeed, metrics: NotchMetrics) -> CGFloat {
        guard calendar.picking, calendar.status != .denied, !calendar.accounts.isEmpty else { return popupHeight }
        let top = contentTop(metrics: metrics) - textTop  // 화면 위 끝 ~ 예전 팝업 위 끝에 해당하는 곳
        let n = CGFloat(calendar.accounts.count)
        let list = 16 + AccountPicker.titleGap + n * AccountPicker.rowHeight + n * AccountPicker.rowGap
            + AccountPicker.laterHeight  // 맨 끝 "Later"
        // 목록이 다 들어가는 높이에서 100 낮춘다. 넘치는 만큼은 안에서 스크롤된다.
        let needed = textTop + list + 18 - 100
        let limit = min(metrics.screen.frame.height / 2, 620 - 40) - top
        return max(popupHeight, min(needed, limit))
    }
}
