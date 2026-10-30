import AppKit
import SwiftUI

// 1단계 실험: 노치 둘레를 형광선으로 따라 그려서 노치 모양을 얼마나 정확히 아는지 확인한다.
// 곡선 반지름은 조절 창의 슬라이더로 맞춰 보고 맞는 값을 기록한다.

final class OutlineTuning: ObservableObject {
    @Published var bottomRadius: CGFloat = NotchMetrics.bottomRadius   // 노치 아래쪽 두 모서리(볼록)
    @Published var topRadius: CGFloat = NotchMetrics.topRadius         // 노치가 화면 위 테두리와 만나는 곳(오목)
    @Published var lineWidth: CGFloat = 2
    @Published var gap: CGFloat = 0             // 노치 가장자리에서 선까지 바깥쪽 거리
    @Published var widthAdjust: CGFloat = 0     // 측정 너비에 더할 값(양쪽 합)
    @Published var heightAdjust: CGFloat = 0    // 측정 높이에 더할 값

    var summary: String {
        String(format: "bottomRadius=%.1f topRadius=%.1f lineWidth=%.1f gap=%.1f widthAdjust=%.1f heightAdjust=%.1f",
               bottomRadius, topRadius, lineWidth, gap, widthAdjust, heightAdjust)
    }
}

/// 선은 노치 가장자리 바로 바깥에 그린다(가장자리 위에 그리면 절반이 노치 밑에 가려진다).
struct OutlineOverlayView: View {
    let metrics: NotchMetrics
    @ObservedObject var tuning: OutlineTuning

    var body: some View {
        NotchShape(width: metrics.width + tuning.widthAdjust,
                   height: metrics.height + tuning.heightAdjust,
                   bottomRadius: tuning.bottomRadius,
                   topRadius: tuning.topRadius,
                   outset: tuning.gap + tuning.lineWidth / 2)
            .stroke(Color(red: 0.2, green: 1.0, blue: 0.1),
                    style: StrokeStyle(lineWidth: tuning.lineWidth, lineCap: .round, lineJoin: .round))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct OutlineControlView: View {
    let metrics: NotchMetrics
    @ObservedObject var tuning: OutlineTuning

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(format: "측정값: 너비 %.1fpt, 높이 %.1fpt (%@, 배율 %.2f)",
                        metrics.width, metrics.height,
                        metrics.screen.localizedName, metrics.screen.backingScaleFactor))
                .font(.caption).foregroundStyle(.secondary)
            sliderRow("아래 모서리 반지름", $tuning.bottomRadius, 0...20)
            sliderRow("위 모서리 반지름", $tuning.topRadius, 0...20)
            sliderRow("선 굵기", $tuning.lineWidth, 0.5...6)
            sliderRow("가장자리와 거리", $tuning.gap, -3...6)
            sliderRow("너비 보정", $tuning.widthAdjust, -10...10)
            sliderRow("높이 보정", $tuning.heightAdjust, -6...6)
            HStack {
                Button("값 출력") { print(tuning.summary) }
                Button("종료") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 380)
    }
}

@MainActor
final class OutlineDemo {
    private var panel: NotchPanel?
    private var controlWindow: NSWindow?
    private let tuning = OutlineTuning()

    func start(metrics: NotchMetrics) {
        // 노치보다 넉넉하게 잡아서 바깥쪽 선과 위 모서리 곡선이 잘리지 않게 한다.
        let margin: CGFloat = 40
        let size = CGSize(width: metrics.width + margin * 2, height: metrics.height + margin)
        let panel = NotchPanel(frame: NotchPanel.topCenterFrame(on: metrics.screen, size: size))
        panel.contentView = NSHostingView(rootView: OutlineOverlayView(metrics: metrics, tuning: tuning))
        panel.orderFrontRegardless()
        self.panel = panel

        let control = makeControlWindow(title: "36NOCH 노치 선 조절", on: metrics.screen, below: 160,
                                        content: OutlineControlView(metrics: metrics, tuning: tuning))
        control.makeKeyAndOrderFront(nil)
        controlWindow = control
    }

    func stop() {
        print(tuning.summary)
    }
}
