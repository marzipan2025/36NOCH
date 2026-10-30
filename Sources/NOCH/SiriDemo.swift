import AppKit
import SwiftUI

// 실험: 노치가 넓어지고, 거기서 유리 방울이 떨어지듯 팝업이 생긴다.
//   1) 노치가 너비 +100, 높이 +12로 커진다(검정).
//   2) 커진 노치에서 Liquid Glass 방울이 맺혀 아래로 떨어지며 팝업이 된다. 팝업 너비 = 커진 노치 너비.
// 방울 느낌은 GlassEffectContainer에 맡긴다. 같은 컨테이너 안의 유리 모양들은 가까워지면
// 액체처럼 붙고(spacing 이내), 멀어지면 목이 늘어나다 끊어진다(RESEARCH §3.5).
// 팝업 안에는 위에서 내려오는 검정을 유리 "아래"에 깐다. 검정은 팝업 모양을 따라 휘며 사라지고,
// 유리가 그 위에서 굴절·반사해서 검정 부분도 액체 유리처럼 보인다.

/// 2026-10-30 사용자가 맞춘 방울 팝업 값(고정)
enum DropFixed {
    static let growWidth: CGFloat = 100
    static let growHeight: CGFloat = 12
    static let notchBottomRadius: CGFloat = 16
    static let popupHeight: CGFloat = 150
    static let popupRadius: CGFloat = 28
    static let gap: CGFloat = 18               // 커진 노치 아래 끝과 팝업 위 끝 사이
    static let spacing: CGFloat = 24           // GlassEffectContainer가 두 유리를 붙이는 거리
    static let growDuration: Double = 0.2
    static let dropDelay: Double = 0
    static let dropDuration: Double = 1.0
    static let dropBounce: Double = 0.5
    // 유리는 .clear, 패널은 key(비활성 매트 모양 방지)

    static let summary = "growWidth=100 growHeight=12 notchBottomRadius=16 popupHeight=150 popupRadius=28 gap=18 spacing=24 clearGlass=yes tint=0 keyPanel=yes growDuration=0.2 dropDelay=0 dropDuration=1.0 dropBounce=0.5"
}

final class DropTuning: ObservableObject {
    // 검정 덮개: 팝업 모양을 위로 끌어올려 흐리게 만든 검정. 흐린 경계가 모서리 곡선을 따라 휜다.
    @Published var lift: CGFloat = 50           // 검정 아래 끝을 팝업 아래 끝보다 얼마나 위로
    @Published var softness: CGFloat = 22       // 흐림 = 검정이 사라지는 구간 길이
    @Published var blackRadius: CGFloat = 28    // 검정 모양의 아래 모서리 반지름(휘어짐 정도)
    @Published var sideInset: CGFloat = 4       // 양옆에서 들임. 키우면 옆 가장자리에 유리가 더 드러남
    @Published var blackOpacity: CGFloat = 1
    // 유리 테두리 빛: 검정 위에도 유리 가장자리가 보이게
    @Published var rimOpacity: CGFloat = 0     // 유리 자체 테두리가 보이므로 기본은 끔
    @Published var clearGlass = true
    @Published var rimWidth: CGFloat = 1.5
    @Published var rimSoftness: CGFloat = 0.5
    // 바깥 그림자
    @Published var shadowOpacity: CGFloat = 0.35
    @Published var shadowRadius: CGFloat = 18
    @Published var shadowY: CGFloat = 8

    /// 버튼으로 바꾸는 값. 바뀔 때마다 패널이 열기/닫기 모션을 한다.
    @Published var isOpen = false

    var summary: String {
        String(format: "lift=%.1f softness=%.1f blackRadius=%.1f sideInset=%.1f blackOpacity=%.2f rimOpacity=%.2f rimWidth=%.1f rimSoftness=%.1f shadowOpacity=%.2f shadowRadius=%.1f shadowY=%.1f",
               lift, softness, blackRadius, sideInset, blackOpacity,
               rimOpacity, rimWidth, rimSoftness, shadowOpacity, shadowRadius, shadowY)
    }
}

@available(macOS 26.0, *)
struct DropPanelView: View {
    let metrics: NotchMetrics
    @ObservedObject var tuning: DropTuning

    // 모션 단계: 노치가 커졌는지, 방울이 떨어졌는지
    @State private var grown = false
    @State private var dropped = false
    @State private var sequence: Task<Void, Never>?

    private var notchWidth: CGFloat { metrics.width + (grown ? DropFixed.growWidth : 0) }
    private var notchHeight: CGFloat { metrics.height + (grown ? DropFixed.growHeight : 0) }

    private var notchShape: NotchShape {
        NotchShape(width: notchWidth, height: notchHeight,
                   bottomRadius: grown ? DropFixed.notchBottomRadius : NotchMetrics.bottomRadius,
                   topRadius: NotchMetrics.topRadius)
    }

    // 떨어지기 전 방울은 노치 아래 끝에 숨은 작은 알갱이
    private var popupSize: CGSize {
        dropped ? CGSize(width: notchWidth, height: DropFixed.popupHeight)
                : CGSize(width: notchWidth * 0.4, height: 24)
    }
    private var popupTop: CGFloat {
        dropped ? notchHeight + DropFixed.gap : notchHeight - popupSize.height
    }
    private var glass: Glass { tuning.clearGlass ? .clear : .regular }

    private var popupShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: min(DropFixed.popupRadius, popupSize.height / 2))
    }

    var body: some View {
        ZStack(alignment: .top) {
            shadowLayer

            // 검정은 유리 "아래"에 깐다. 유리가 그 위에서 굴절·반사하므로 검정도 액체 유리 속에 있는 것처럼 보이고,
            // 가장자리에서는 유리의 렌즈 효과로 검정이 모서리를 따라 휜다. (위에 덮으면 매트한 평면이 된다)
            blackCover
                .frame(width: popupSize.width, height: popupSize.height, alignment: .topLeading)
                .clipShape(popupShape)
                .offset(y: popupTop)

            GlassEffectContainer(spacing: DropFixed.spacing) {
                ZStack(alignment: .top) {
                    // 노치 쪽 유리: 검정 아래에 깔려서, 방울과 이어지는 목만 유리로 보인다.
                    Color.clear
                        .glassEffect(glass, in: notchShape)

                    Color.clear
                        .frame(width: popupSize.width, height: popupSize.height)
                        .glassEffect(glass, in: popupShape)
                        .offset(y: popupTop)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            // 유리 위에 얹는 것: 테두리 빛(기본 꺼짐), 글
            ZStack(alignment: .topLeading) {
                rim
                Text("11월에 있는 토요일 중에 오후 12시부터 3시 사이에 간식을 가져갈 수 있는 날들 정리해서 이메일 초안 작성해 줘.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .opacity(dropped ? 1 : 0)
            }
            .frame(width: popupSize.width, height: popupSize.height, alignment: .topLeading)
            .clipShape(popupShape)
            .offset(y: popupTop)

            // 커진 노치는 하드웨어 노치와 같은 검정
            notchShape.fill(.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: tuning.isOpen) { _, open in play(open: open) }
        .onAppear { tuning.isOpen = true }
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
            .opacity(tuning.blackOpacity)
    }

    /// 유리 가장자리 빛. 위는 밝게, 옆은 거의 없게, 아래는 다시 살짝 — 빛이 위에서 비치는 유리처럼.
    private var rim: some View {
        popupShape
            .strokeBorder(
                LinearGradient(stops: [
                    .init(color: .white.opacity(tuning.rimOpacity), location: 0),
                    .init(color: .white.opacity(tuning.rimOpacity * 0.15), location: 0.45),
                    .init(color: .white.opacity(tuning.rimOpacity * 0.6), location: 1),
                ], startPoint: .top, endPoint: .bottom),
                lineWidth: tuning.rimWidth)
            .blur(radius: tuning.rimSoftness)
    }

    /// 바깥 그림자만 남긴다. 그림자를 만드는 모양 자체는 오려 내서 투명한 유리 안이 어두워지지 않게 한다.
    private var shadowLayer: some View {
        let shapes = ZStack(alignment: .top) {
            notchShape.fill(.black)
            popupShape.fill(.black)
                .frame(width: popupSize.width, height: popupSize.height)
                .offset(y: popupTop)
        }
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
        sequence = Task { @MainActor in
            if open {
                withAnimation(.spring(duration: DropFixed.growDuration, bounce: 0.2)) { grown = true }
                try? await Task.sleep(for: .seconds(DropFixed.dropDelay))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: DropFixed.dropDuration, bounce: DropFixed.dropBounce)) { dropped = true }
            } else {
                withAnimation(.spring(duration: DropFixed.dropDuration * 0.7, bounce: 0.1)) { dropped = false }
                try? await Task.sleep(for: .seconds(DropFixed.dropDuration * 0.5))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: DropFixed.growDuration, bounce: 0.1)) { grown = false }
            }
        }
    }
}

struct DropControlView: View {
    @ObservedObject var tuning: DropTuning

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("열기") { tuning.isOpen = true }
                Button("닫기") { tuning.isOpen = false }
                Button("다시 재생") { replay() }
            }
            Text("방울 팝업 크기·모션은 고정값(DropFixed)")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("검정 덮개").font(.headline)
            sliderRow("끌어올림", $tuning.lift, -40...150)
            sliderRow("흐림(전이 길이)", $tuning.softness, 0...80)
            sliderRow("검정 모서리 반지름", $tuning.blackRadius, 0...80)
            sliderRow("양옆 들임", $tuning.sideInset, -30...60)
            sliderRow("불투명도", $tuning.blackOpacity, 0...1, step: 0.05)
            Divider()
            Text("유리").font(.headline)
            Toggle("clear 유리 (끄면 regular)", isOn: $tuning.clearGlass)
            Text("덧그린 테두리 빛").font(.subheadline)
            sliderRow("밝기", $tuning.rimOpacity, 0...1, step: 0.05)
            sliderRow("굵기", $tuning.rimWidth, 0...6)
            sliderRow("번짐", $tuning.rimSoftness, 0...6)
            Divider()
            Text("바깥 그림자").font(.headline)
            sliderRow("진하기", $tuning.shadowOpacity, 0...1, step: 0.05)
            sliderRow("번짐", $tuning.shadowRadius, 0...60)
            sliderRow("아래로", $tuning.shadowY, -10...40)
            HStack {
                Button("값 출력") { print(tuning.summary) }
                Button("종료") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    private func replay() {
        tuning.isOpen = false
        DispatchQueue.main.asyncAfter(deadline: .now() + DropFixed.dropDuration + DropFixed.growDuration) {
            tuning.isOpen = true
        }
    }
}

@available(macOS 26.0, *)
@MainActor
final class SiriDemo {
    private var panel: NotchPanel?
    private var controlWindow: NSWindow?
    private let tuning = DropTuning()

    func start(metrics: NotchMetrics) {
        // 그림자가 잘리지 않게 넉넉하게 잡는다.
        let size = CGSize(width: 900, height: 360)
        let panel = NotchPanel(frame: NotchPanel.topCenterFrame(on: metrics.screen, size: size))
        // 앱이 비활성이어도 SwiftUI가 활성 모양으로 그리게 한다.
        panel.contentView = NSHostingView(rootView: DropPanelView(metrics: metrics, tuning: tuning)
            .environment(\.appearsActive, true)
            .environment(\.controlActiveState, .key))
        panel.forceActive = true
        // 유리가 비활성(매트) 모양으로 그려지지 않게 패널을 key로
        panel.allowsKey = true
        panel.orderFrontRegardless()
        panel.makeKey()
        self.panel = panel

        // 조절 창은 패널을 가리지 않게 오른쪽 아래에 둔다.
        let control = makeControlWindow(title: "36NOCH 방울 팝업 조절", on: metrics.screen, below: 600,
                                        content: DropControlView(tuning: tuning))
        control.setFrameOrigin(CGPoint(x: metrics.screen.frame.maxX - control.frame.width - 20,
                                       y: metrics.screen.frame.minY + 20))
        control.orderFrontRegardless()
        controlWindow = control
    }

    func stop() {
        print(tuning.summary)
    }
}
