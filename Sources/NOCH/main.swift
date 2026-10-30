import AppKit
import SwiftUI

// 1단계 실험: 노치 둘레를 형광선으로 따라 그려서 노치 모양을 얼마나 정확히 아는지 확인한다.
// 노치의 사각 영역(너비·높이)은 NSScreen API로 정확히 알 수 있지만, 모서리 곡선은 API가 없다.
// 그래서 곡선 반지름은 조절 창의 슬라이더로 맞춰 보고 맞는 값을 기록한다.

// MARK: - 노치 측정

struct NotchMetrics {
    let screen: NSScreen
    let width: CGFloat
    let height: CGFloat

    static func builtIn() -> NotchMetrics? {
        for screen in NSScreen.screens where screen.safeAreaInsets.top > 0 {
            guard let left = screen.auxiliaryTopLeftArea,
                  let right = screen.auxiliaryTopRightArea else { continue }
            let width = screen.frame.width - left.width - right.width
            return NotchMetrics(screen: screen, width: width, height: screen.safeAreaInsets.top)
        }
        return nil
    }
}

// MARK: - 조절 값

final class Tuning: ObservableObject {
    @Published var bottomRadius: CGFloat = 10   // 노치 아래쪽 두 모서리(볼록)
    @Published var topRadius: CGFloat = 6       // 노치가 화면 위 테두리와 만나는 곳(오목)
    @Published var lineWidth: CGFloat = 2
    @Published var gap: CGFloat = 0             // 노치 가장자리에서 선까지 바깥쪽 거리
    @Published var widthAdjust: CGFloat = 0     // 측정 너비에 더할 값(양쪽 합)
    @Published var heightAdjust: CGFloat = 0    // 측정 높이에 더할 값

    var summary: String {
        String(format: "bottomRadius=%.1f topRadius=%.1f lineWidth=%.1f gap=%.1f widthAdjust=%.1f heightAdjust=%.1f",
               bottomRadius, topRadius, lineWidth, gap, widthAdjust, heightAdjust)
    }
}

// MARK: - 노치 모양

/// 노치 둘레 선. 위쪽 끝은 화면 테두리로 오목하게 퍼지고, 아래쪽 모서리는 볼록하게 둥글다.
/// 선은 노치 가장자리 바로 바깥에 그린다(가장자리 위에 그리면 절반이 노치 밑에 가려진다).
struct NotchOutline: Shape {
    var notchWidth: CGFloat
    var notchHeight: CGFloat
    var bottomRadius: CGFloat
    var topRadius: CGFloat
    var outset: CGFloat

    func path(in rect: CGRect) -> Path {
        // 원을 베지어 곡선으로 근사할 때 쓰는 상수
        let k: CGFloat = 0.5523
        let left = rect.midX - notchWidth / 2 - outset
        let right = rect.midX + notchWidth / 2 + outset
        let bottom = notchHeight + outset
        let br = max(0, min(bottomRadius + outset, (right - left) / 2, bottom))
        let tr = max(0, topRadius - outset)

        var p = Path()
        // 왼쪽 위: 화면 테두리에서 노치 옆면으로 오목하게 꺾임
        p.move(to: CGPoint(x: left - tr, y: 0))
        p.addCurve(to: CGPoint(x: left, y: tr),
                   control1: CGPoint(x: left - tr + tr * k, y: 0),
                   control2: CGPoint(x: left, y: tr - tr * k))
        p.addLine(to: CGPoint(x: left, y: bottom - br))
        // 왼쪽 아래
        p.addCurve(to: CGPoint(x: left + br, y: bottom),
                   control1: CGPoint(x: left, y: bottom - br + br * k),
                   control2: CGPoint(x: left + br - br * k, y: bottom))
        p.addLine(to: CGPoint(x: right - br, y: bottom))
        // 오른쪽 아래
        p.addCurve(to: CGPoint(x: right, y: bottom - br),
                   control1: CGPoint(x: right - br + br * k, y: bottom),
                   control2: CGPoint(x: right, y: bottom - br + br * k))
        p.addLine(to: CGPoint(x: right, y: tr))
        // 오른쪽 위
        p.addCurve(to: CGPoint(x: right + tr, y: 0),
                   control1: CGPoint(x: right, y: tr - tr * k),
                   control2: CGPoint(x: right + tr - tr * k, y: 0))
        return p
    }
}

struct OverlayView: View {
    let metrics: NotchMetrics
    @ObservedObject var tuning: Tuning

    var body: some View {
        NotchOutline(notchWidth: metrics.width + tuning.widthAdjust,
                     notchHeight: metrics.height + tuning.heightAdjust,
                     bottomRadius: tuning.bottomRadius,
                     topRadius: tuning.topRadius,
                     outset: tuning.gap + tuning.lineWidth / 2)
            .stroke(Color(red: 0.2, green: 1.0, blue: 0.1),
                    style: StrokeStyle(lineWidth: tuning.lineWidth, lineCap: .round, lineJoin: .round))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - 조절 창

struct ControlView: View {
    let metrics: NotchMetrics
    @ObservedObject var tuning: Tuning

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(format: "측정값: 너비 %.1fpt, 높이 %.1fpt (%@, 배율 %.2f)",
                        metrics.width, metrics.height,
                        metrics.screen.localizedName, metrics.screen.backingScaleFactor))
                .font(.caption).foregroundStyle(.secondary)
            row("아래 모서리 반지름", $tuning.bottomRadius, 0...20)
            row("위 모서리 반지름", $tuning.topRadius, 0...20)
            row("선 굵기", $tuning.lineWidth, 0.5...6)
            row("가장자리와 거리", $tuning.gap, -3...6)
            row("너비 보정", $tuning.widthAdjust, -10...10)
            row("높이 보정", $tuning.heightAdjust, -6...6)
            HStack {
                Button("값 출력") { print(tuning.summary) }
                Button("종료") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 380)
    }

    private func row(_ label: String, _ value: Binding<CGFloat>, _ range: ClosedRange<CGFloat>) -> some View {
        HStack {
            Text(label).frame(width: 110, alignment: .leading)
            Slider(value: value, in: range, step: 0.5)
            Text(String(format: "%.1f", value.wrappedValue)).monospacedDigit().frame(width: 36)
        }
    }
}

// MARK: - 창

/// 노치 위에 겹치는 투명 패널. 클릭은 아래로 통과시킨다.
final class NotchPanel: NSPanel {
    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private var controlWindow: NSWindow?
    private let tuning = Tuning()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let metrics = NotchMetrics.builtIn() else {
            print("노치가 있는 화면을 찾지 못했습니다.")
            NSApp.terminate(nil)
            return
        }
        print(String(format: "노치: %.1f × %.1f pt, 화면 %@", metrics.width, metrics.height,
                     NSStringFromRect(metrics.screen.frame)))

        // 노치보다 넉넉하게 잡아서 바깥쪽 선과 위 모서리 곡선이 잘리지 않게 한다.
        let margin: CGFloat = 40
        let size = CGSize(width: metrics.width + margin * 2, height: metrics.height + margin)
        let sf = metrics.screen.frame
        let frame = CGRect(x: sf.midX - size.width / 2, y: sf.maxY - size.height,
                           width: size.width, height: size.height)
        let panel = NotchPanel(frame: frame)
        panel.contentView = NSHostingView(rootView: OverlayView(metrics: metrics, tuning: tuning))
        panel.orderFrontRegardless()
        self.panel = panel

        let control = NSWindow(contentRect: .zero, styleMask: [.titled, .closable],
                               backing: .buffered, defer: false)
        control.title = "36NOCH 노치 선 조절"
        control.contentView = NSHostingView(rootView: ControlView(metrics: metrics, tuning: tuning))
        control.setContentSize(control.contentView!.fittingSize)
        control.setFrameTopLeftPoint(CGPoint(x: sf.midX - control.frame.width / 2, y: sf.maxY - 160))
        control.isReleasedWhenClosed = false
        control.makeKeyAndOrderFront(nil)
        controlWindow = control
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        print(tuning.summary)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
