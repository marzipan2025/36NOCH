import AppKit
import SwiftUI

// 실험: 노치가 넓어지고, 거기서 유리 방울이 떨어지듯 팝업이 생긴다.
//   1) 노치가 너비·높이·모서리 반지름이 함께 커진다(검정).
//   2) 커진 노치에서 Liquid Glass 방울이 맺혀 아래로 떨어지며 팝업이 된다. 팝업 너비 = 커진 노치 너비.
// 방울 느낌은 GlassEffectContainer에 맡긴다. 같은 컨테이너 안의 유리 모양들은 가까워지면
// 액체처럼 붙고(spacing 이내), 멀어지면 목이 늘어나다 끊어진다(RESEARCH §3.5).
// 팝업 안에는 위에서 내려오는 검정을 유리 "아래"에 깐다. 검정은 팝업 모양을 따라 휘며 사라지고,
// 유리가 그 위에서 굴절·반사해서 검정 부분도 액체 유리처럼 보인다.

/// 모든 조절 값. 기본값은 2026-10-30 사용자가 맞춘 2차 설정.
final class DropTuning: ObservableObject {
    // 노치 확장
    @Published var growWidth: CGFloat = 100
    @Published var growHeight: CGFloat = 8
    @Published var grownBottomRadius: CGFloat = 26   // 커진 노치 아래 모서리(볼록). 원래 노치 10
    @Published var grownTopRadius: CGFloat = 12      // 커진 노치 위 모서리(오목). 원래 노치 6
    // 팝업 방울
    @Published var popupHeight: CGFloat = 204
    @Published var popupRadius: CGFloat = 26
    @Published var gap: CGFloat = 11                 // 커진 노치 아래 끝과 팝업 위 끝 사이
    @Published var spacing: CGFloat = 16             // GlassEffectContainer가 두 유리를 붙이는 거리
    @Published var grainHeight: CGFloat = 34         // 떨어지기 전 팝업 높이(실제 노치 밑에 숨어 있음)
    @Published var waitInset: CGFloat = 4            // 대기 중 팝업을 실제 노치보다 좁힐 너비(양쪽 합). 하드웨어 노치에 완전히 가려지게
    @Published var inkDelay: CGFloat = 0             // 떨어지기 시작하고 검정이 빠지기 시작할 때까지(초)
    @Published var inkDuration: CGFloat = 0.65       // 검정 → 유리로 바뀌는 시간(초)
    @Published var inkNeck = true                    // 노치와 방울 사이 목도 유리 틴트로 검게
    // 유리
    @Published var clearGlass = true
    @Published var tintOpacity: CGFloat = 0
    // 검정 덮개: 팝업 모양을 위로 끌어올려 흐리게 만든 검정. 흐린 경계가 모서리 곡선을 따라 휜다.
    @Published var lift: CGFloat = 35.5              // 검정 아래 끝을 팝업 아래 끝보다 얼마나 위로
    @Published var softness: CGFloat = 22.5          // 흐림 = 검정이 사라지는 구간 길이
    @Published var blackRadius: CGFloat = 74.5       // 검정 모양의 아래 모서리 반지름(휘어짐 정도)
    @Published var sideInset: CGFloat = -30          // 양옆에서 들임. 키우면 옆 가장자리에 유리가 더 드러남
    @Published var blackOpacity: CGFloat = 1
    // 덧그린 테두리 빛
    @Published var rimOpacity: CGFloat = 0.05        // 유리 자체 테두리 위에 아주 살짝
    @Published var rimWidth: CGFloat = 1
    @Published var rimSoftness: CGFloat = 1.5
    // 바깥 그림자
    @Published var shadowOpacity: CGFloat = 0.3
    @Published var shadowRadius: CGFloat = 28
    @Published var shadowY: CGFloat = 14.5
    // 글
    @Published var textSize: CGFloat = 15
    @Published var textPadding: CGFloat = 22
    @Published var textTop: CGFloat = 18
    // 모션(초)
    @Published var growDuration: CGFloat = 0.6
    @Published var growBounce: CGFloat = 0.2
    @Published var dropDelay: CGFloat = -0.7
    @Published var dropDuration: CGFloat = 0.75
    @Published var dropBounce: CGFloat = 0.4
    @Published var closeSpeed: CGFloat = 0.5         // 닫힘은 열림의 정확한 역재생. 이 값은 시간 배율(1 = 열 때와 같은 속도, 작을수록 빠름)

    /// 버튼으로 바꾸는 값. 바뀔 때마다 패널이 열기/닫기 모션을 한다.
    @Published var isOpen = false

    /// 2차 설정(= 기본값): 2026-10-30 회사 맥에서 사용자가 맞춘 값. 조절하다가 이 값으로 되돌릴 때 쓴다.
    func applySecondPreset() {
        growWidth = 100; growHeight = 8; grownBottomRadius = 26; grownTopRadius = 12; popupHeight = 204
        popupRadius = 26; gap = 11; spacing = 16; grainHeight = 34; waitInset = 4
        inkDelay = 0; inkDuration = 0.65; inkNeck = true; clearGlass = true; tintOpacity = 0
        lift = 35.5; softness = 22.5; blackRadius = 74.5; sideInset = -30; blackOpacity = 1
        rimOpacity = 0.05; rimWidth = 1; rimSoftness = 1.5; shadowOpacity = 0.3; shadowRadius = 28
        shadowY = 14.5; textSize = 15; textPadding = 22; textTop = 18; growDuration = 0.6
        growBounce = 0.2; dropDelay = -0.7; dropDuration = 0.75; dropBounce = 0.4; closeSpeed = 0.5
    }

    /// 열림 시간표(초). 스프링은 눈에 보이는 시간(duration)이 아니라 다 멈추는 시간(settlingDuration)으로 잡는다.
    /// 닫힘은 이 시간표를 거꾸로 돌린다.
    var openTimeline: (grow: Spring, drop: Spring, dropStart: Double, inkStart: Double, total: Double) {
        let grow = Spring(duration: Double(growDuration), bounce: Double(growBounce))
        let drop = Spring(duration: Double(dropDuration), bounce: Double(dropBounce))
        let dropStart = max(0, Double(growDuration + dropDelay))
        let inkStart = dropStart + Double(inkDelay)
        let total = max(grow.settlingDuration, dropStart + drop.settlingDuration, inkStart + Double(inkDuration))
        return (grow, drop, dropStart, inkStart, total)
    }

    var summary: String {
        let pairs: [(String, CGFloat)] = [
            ("growWidth", growWidth), ("growHeight", growHeight),
            ("grownBottomRadius", grownBottomRadius), ("grownTopRadius", grownTopRadius),
            ("popupHeight", popupHeight), ("popupRadius", popupRadius), ("gap", gap), ("spacing", spacing),
            ("grainHeight", grainHeight), ("waitInset", waitInset), ("inkDelay", inkDelay), ("inkDuration", inkDuration),
            ("inkNeck", inkNeck ? 1 : 0),
            ("clearGlass", clearGlass ? 1 : 0), ("tintOpacity", tintOpacity),
            ("lift", lift), ("softness", softness), ("blackRadius", blackRadius),
            ("sideInset", sideInset), ("blackOpacity", blackOpacity),
            ("rimOpacity", rimOpacity), ("rimWidth", rimWidth), ("rimSoftness", rimSoftness),
            ("shadowOpacity", shadowOpacity), ("shadowRadius", shadowRadius), ("shadowY", shadowY),
            ("textSize", textSize), ("textPadding", textPadding), ("textTop", textTop),
            ("growDuration", growDuration), ("growBounce", growBounce), ("dropDelay", dropDelay),
            ("dropDuration", dropDuration), ("dropBounce", dropBounce), ("closeSpeed", closeSpeed),
        ]
        return pairs.map { String(format: "%@=%g", $0.0, Double($0.1)) }.joined(separator: " ")
    }
}

@available(macOS 26.0, *)
struct DropPanelView: View {
    let metrics: NotchMetrics
    @ObservedObject var tuning: DropTuning

    // 모션 단계: 노치가 커졌는지, 방울이 떨어졌는지
    @State private var grown = false
    @State private var dropped = false
    @State private var inked = true       // 팝업이 온통 검정인지. 노치 밑에서 기다릴 때와 떨어지기 시작할 때는 검정 방울
    @State private var sequence: Task<Void, Never>?

    private var notchWidth: CGFloat { metrics.width + (grown ? tuning.growWidth : 0) }
    private var notchHeight: CGFloat { metrics.height + (grown ? tuning.growHeight : 0) }

    // 노치가 커질 때 모서리도 함께 커진다(NotchShape가 반지름까지 애니메이션).
    private var notchShape: NotchShape {
        NotchShape(width: notchWidth, height: notchHeight,
                   bottomRadius: grown ? tuning.grownBottomRadius : NotchMetrics.bottomRadius,
                   topRadius: grown ? tuning.grownTopRadius : NotchMetrics.topRadius)
    }

    // 떨어지기 전에는 실제(하드웨어) 노치보다 조금 좁고 낮게 숨어 있다가,
    // 떨어지면서 커진 노치 너비까지 넓어지며 드러난다. 하드웨어 노치는 불투명해서 그 밑은 화면에 안 보인다.
    private var popupSize: CGSize {
        dropped ? CGSize(width: metrics.width + tuning.growWidth, height: tuning.popupHeight)
                : CGSize(width: max(1, metrics.width - tuning.waitInset), height: tuning.grainHeight)
    }
    private var popupTop: CGFloat {
        dropped ? notchHeight + tuning.gap : max(0, metrics.height - tuning.waitInset / 2 - tuning.grainHeight)
    }

    private var glass: Glass {
        let base: Glass = tuning.clearGlass ? .clear : .regular
        // 검정 방울일 때는 유리 자체도 검게 물들여서, 노치와 방울 사이 목까지 검정으로 이어지게 한다.
        if inked && tuning.inkNeck { return base.tint(.black) }
        return tuning.tintOpacity > 0 ? base.tint(.black.opacity(tuning.tintOpacity)) : base
    }

    private var popupShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: min(tuning.popupRadius, popupSize.height / 2, popupSize.width / 2))
    }

    var body: some View {
        ZStack(alignment: .top) {
            shadowLayer

            // 검정은 유리 "아래"에 깐다. 유리가 그 위에서 굴절·반사하므로 검정도 액체 유리 속에 있는 것처럼 보이고,
            // 가장자리에서는 유리의 렌즈 효과로 검정이 모서리를 따라 휜다. (위에 덮으면 매트한 평면이 된다)
            popupLayers

            // 커진 노치는 하드웨어 노치와 같은 검정
            notchShape.fill(.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: tuning.isOpen) { _, open in play(open: open) }
        .onAppear { tuning.isOpen = true }
    }

    /// 팝업과 그 유리 컨테이너. 검정 덮개 → 유리 → 글 순으로 쌓는다.
    private var popupLayers: some View {
        ZStack(alignment: .top) {
            blackCover
                .frame(width: popupSize.width, height: popupSize.height, alignment: .topLeading)
                .clipShape(popupShape)
                .offset(y: popupTop)

            GlassEffectContainer(spacing: tuning.spacing) {
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

            // 검정 방울: 노치와 같은 검정으로 덮었다가 떨어지면서 걷혀 유리가 드러난다.
            popupShape.fill(.black)
                .frame(width: popupSize.width, height: popupSize.height)
                .offset(y: popupTop)
                .opacity(inked ? 1 : 0)

            // 유리 위에 얹는 것: 테두리 빛, 글
            ZStack(alignment: .topLeading) {
                rim
                Text("11월에 있는 토요일 중에 오후 12시부터 3시 사이에 간식을 가져갈 수 있는 날들 정리해서 이메일 초안 작성해 줘.")
                    .font(.system(size: tuning.textSize, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, tuning.textPadding)
                    .padding(.top, tuning.textTop)
                    .opacity(dropped ? 1 : 0)
            }
            .frame(width: popupSize.width, height: popupSize.height, alignment: .topLeading)
            .clipShape(popupShape)
            .offset(y: popupTop)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        let t = tuning
        let line = t.openTimeline
        let ink = Double(t.inkDuration)

        // (시작 시각, 할 일). 닫힘은 열림을 정확히 거꾸로: 열림에서 [s, s+d]에 있던 움직임은
        // 닫힘에서 [T−s−d, T−s]에 놓이고, 곡선도 시간을 뒤집은 것(ReversedSpring, easeInOut은 대칭)을 쓴다.
        var steps: [(at: Double, run: () -> Void)]
        if open {
            steps = [
                (0, { withAnimation(.spring(line.grow)) { grown = true } }),
                (line.dropStart, { withAnimation(.spring(line.drop)) { dropped = true } }),
                (line.inkStart, { withAnimation(.easeInOut(duration: ink)) { inked = false } }),
            ]
        } else {
            let k = Double(t.closeSpeed)
            let T = line.total
            steps = [
                (k * (T - line.inkStart - ink), {
                    withAnimation(.easeInOut(duration: ink * k)) { inked = true } }),
                (k * (T - line.dropStart - line.drop.settlingDuration), {
                    withAnimation(Animation(ReversedSpring(spring: line.drop, scale: k))) { dropped = false } }),
                (k * (T - line.grow.settlingDuration), {
                    withAnimation(Animation(ReversedSpring(spring: line.grow, scale: k))) { grown = false } }),
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
/// 값은 0 → value로 가야 하므로, 정방향 스프링 s(t)에 대해 value − s(D − t)를 돌려준다(D = 멈추는 시간).
struct ReversedSpring: CustomAnimation {
    let spring: Spring
    let scale: Double   // 시간 배율

    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        let duration = spring.settlingDuration
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
                Button("2차설정") { tuning.applySecondPreset(); replay() }
                Button("종료") { NSApp.terminate(nil) }
            }
            .padding(16)
            Divider()
            HStack(alignment: .top, spacing: 0) {
                column {
                    section("노치 확장")
                    sliderRow("너비 +", $tuning.growWidth, 0...300, step: 2)
                    sliderRow("높이 +", $tuning.growHeight, 0...60)
                    sliderRow("아래 모서리(볼록)", $tuning.grownBottomRadius, 0...60)
                    sliderRow("위 모서리(오목)", $tuning.grownTopRadius, 0...30)
                    radiusNote

                    section("팝업 방울")
                    sliderRow("높이", $tuning.popupHeight, 40...400, step: 2)
                    sliderRow("모서리 반지름", $tuning.popupRadius, 0...80)
                    sliderRow("노치와 간격", $tuning.gap, 0...60)
                    sliderRow("붙는 거리(spacing)", $tuning.spacing, 0...80)
                    sliderRow("대기 높이(실제 노치 밑)", $tuning.grainHeight, 4...36)
                    sliderRow("대기 너비 줄임(실제 노치 대비)", $tuning.waitInset, 0...40)

                    section("유리")
                    Toggle("clear 유리 (끄면 regular)", isOn: $tuning.clearGlass)
                    sliderRow("검정 틴트", $tuning.tintOpacity, 0...1, step: 0.05)

                    section("글")
                    sliderRow("글자 크기", $tuning.textSize, 10...30)
                    sliderRow("좌우 여백", $tuning.textPadding, 0...60)
                    sliderRow("위 여백", $tuning.textTop, 0...80)
                }
                Divider()
                column {
                    section("모션 (초)")
                    Text("열 때").font(.subheadline)
                    sliderRow("노치 커지는 시간", $tuning.growDuration, 0.05...2, step: 0.05)
                    sliderRow("노치 튕김", $tuning.growBounce, 0...0.8, step: 0.05)
                    sliderRow("팝업 시작(노치 끝 기준)", $tuning.dropDelay, -2...1.5, step: 0.05)
                    sliderRow("팝업 떨어지는 시간", $tuning.dropDuration, 0.1...3, step: 0.05)
                    sliderRow("떨어짐 튕김", $tuning.dropBounce, 0...0.8, step: 0.05)
                    sliderRow("검정 빠지기 시작(떨어짐 후)", $tuning.inkDelay, 0...3, step: 0.05)
                    sliderRow("검정 → 유리 시간", $tuning.inkDuration, 0.05...3, step: 0.05)
                    Toggle("노치와 방울 사이 목도 검정 (유리 틴트)", isOn: $tuning.inkNeck)
                    timeline
                    Text("닫을 때").font(.subheadline)
                    sliderRow("닫힘 속도 배율 (1 = 열 때 그대로 역재생)", $tuning.closeSpeed, 0.2...1.5, step: 0.05)

                    section("검정 덮개 (유리 아래)")
                    sliderRow("끌어올림", $tuning.lift, -40...300)
                    sliderRow("흐림(전이 길이)", $tuning.softness, 0...80)
                    sliderRow("검정 모서리 반지름", $tuning.blackRadius, 0...80)
                    sliderRow("양옆 들임", $tuning.sideInset, -30...60)
                    sliderRow("불투명도", $tuning.blackOpacity, 0...1, step: 0.05)

                    section("바깥 그림자")
                    sliderRow("진하기", $tuning.shadowOpacity, 0...1, step: 0.05)
                    sliderRow("번짐", $tuning.shadowRadius, 0...60)
                    sliderRow("아래로", $tuning.shadowY, -10...40)

                    section("덧그린 테두리 빛")
                    sliderRow("밝기", $tuning.rimOpacity, 0...1, step: 0.05)
                    sliderRow("굵기", $tuning.rimWidth, 0...6)
                    sliderRow("번짐", $tuning.rimSoftness, 0...6)
                }
            }
        }
        .frame(width: 1000, height: 760)
    }

    private func column<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) { content() }
                .padding(16)
        }
        .frame(maxWidth: .infinity)
    }

    private func section(_ title: String) -> some View {
        Text(title).font(.headline).padding(.top, 8)
    }

    /// 열 때 시간표: 노치 0초 시작 → 팝업 시작 → 팝업 끝. 막대로 겹침을 보여 준다.
    private var timeline: some View {
        let grow = Double(tuning.growDuration)
        let dropStart = max(0, grow + Double(tuning.dropDelay))
        let dropEnd = dropStart + Double(tuning.dropDuration)
        let inkStart = dropStart + Double(tuning.inkDelay)
        let inkEnd = inkStart + Double(tuning.inkDuration)
        let total = max(grow, dropEnd, inkEnd)
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let scale = geo.size.width / total
                VStack(alignment: .leading, spacing: 3) {
                    Capsule().fill(.black)
                        .frame(width: max(2, grow * scale), height: 6)
                    Capsule().fill(.blue)
                        .frame(width: max(2, Double(tuning.dropDuration) * scale), height: 6)
                        .offset(x: dropStart * scale)
                    Capsule().fill(.gray)
                        .frame(width: max(2, Double(tuning.inkDuration) * scale), height: 6)
                        .offset(x: inkStart * scale)
                }
            }
            .frame(height: 24)
            Text(String(format: "노치(검정) 0 → %.2f초 · 팝업(파랑) %.2f → %.2f초 · 검정→유리(회색) %.2f → %.2f초 · 전체 %.2f초",
                        grow, dropStart, dropEnd, inkStart, inkEnd, total))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// 커진 노치에서 아래 모서리가 가질 수 있는 최대값 안내
    private var radiusNote: some View {
        let h = metrics.height + tuning.growHeight
        let w = metrics.width + tuning.growWidth
        let geometric = NotchShape.maxBottomRadius(width: w, height: h, topRadius: tuning.grownTopRadius)
        let hardware = NotchMetrics.bottomRadius / metrics.height * h
        return Text(String(format: "커진 노치 %.0f×%.0f — 하드웨어 비율 %.1f · 권장 상한(높이 절반) %.1f · 기하 최대 %.1f",
                           w, h, hardware, h / 2, geometric))
            .font(.caption).foregroundStyle(.secondary)
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
final class SiriDemo {
    private var panel: NotchPanel?
    private var controlWindow: NSWindow?
    private let tuning = DropTuning()

    func start(metrics: NotchMetrics) {
        // 슬라이더 최대값과 그림자가 잘리지 않게 넉넉하게 잡는다.
        let size = CGSize(width: 1000, height: 620)
        let panel = NotchPanel(frame: NotchPanel.topCenterFrame(on: metrics.screen, size: size))
        // 앱이 비활성이어도 활성 모양(유리)으로 그린다. 실제로 효과가 있는 건 NotchPanel의 비공개 메서드 덮어쓰기.
        panel.contentView = NSHostingView(rootView: DropPanelView(metrics: metrics, tuning: tuning)
            .environment(\.appearsActive, true)
            .environment(\.controlActiveState, .key))
        panel.forceActive = true
        panel.allowsKey = true
        panel.orderFrontRegardless()
        panel.makeKey()
        self.panel = panel

        // 조절 창은 패널을 가리지 않게 오른쪽 아래에 둔다.
        let control = makeControlWindow(title: "36NOCH 방울 팝업 조절", on: metrics.screen, below: 600,
                                        content: DropControlView(metrics: metrics, tuning: tuning))
        control.setFrameOrigin(CGPoint(x: metrics.screen.frame.maxX - control.frame.width - 20,
                                       y: metrics.screen.frame.minY + 20))
        control.orderFrontRegardless()
        controlWindow = control
    }

    func stop() {
        print(tuning.summary)
    }
}
