import AppKit
import SwiftUI

// MARK: - 노치 측정

/// 노치의 사각 영역(너비·높이)은 NSScreen API로 정확히 알 수 있지만, 모서리 곡선은 API가 없다.
/// 곡선 값은 노치 둘레 형광선 실험(OutlineDemo)으로 맞춘 값이다(RESEARCH §3.2).
struct NotchMetrics {
    let screen: NSScreen
    let width: CGFloat
    let height: CGFloat

    static let bottomRadius: CGFloat = 10
    static let topRadius: CGFloat = 6

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

// MARK: - 노치 모양

/// 화면 위 테두리에 붙은 노치 모양. 위쪽 끝은 화면 테두리로 오목하게 퍼지고, 아래쪽 모서리는 볼록하게 둥글다.
/// 노치 자체뿐 아니라 노치에서 펼쳐지는 패널에도 쓴다. 가운데 기준으로 rect 위쪽에 붙는다.
/// 위쪽 변은 열린 채로 두므로 stroke하면 둘레선, fill하면 위쪽 변이 직선으로 닫힌 면이 된다.
struct NotchShape: Shape {
    var width: CGFloat
    var height: CGFloat
    var bottomRadius: CGFloat
    var topRadius: CGFloat
    var outset: CGFloat = 0

    // 펼침 애니메이션에서 크기와 두 모서리가 부드럽게 바뀌도록
    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(width, height), AnimatablePair(bottomRadius, topRadius)) }
        set {
            width = newValue.first.first
            height = newValue.first.second
            bottomRadius = newValue.second.first
            topRadius = newValue.second.second
        }
    }

    /// 아래 모서리 반지름의 기하학적 최대. 옆면 직선이 0이 되는 지점(높이 − 위 반지름)이고, 너비 절반도 넘을 수 없다.
    static func maxBottomRadius(width: CGFloat, height: CGFloat, topRadius: CGFloat) -> CGFloat {
        max(0, min(height - topRadius, width / 2))
    }

    func path(in rect: CGRect) -> Path {
        // 원을 베지어 곡선으로 근사할 때 쓰는 상수
        let k: CGFloat = 0.5523
        let left = rect.midX - width / 2 - outset
        let right = rect.midX + width / 2 + outset
        let bottom = height + outset
        let tr = max(0, topRadius - outset)
        let br = max(0, min(bottomRadius + outset, (right - left) / 2, bottom - tr))

        var p = Path()
        // 왼쪽 위: 화면 테두리에서 옆면으로 오목하게 꺾임
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

// MARK: - 창

/// 노치 위에 겹치는 투명 패널. 클릭은 아래로 통과시킨다.
final class NotchPanel: NSPanel {
    /// Liquid Glass는 창(앱)이 비활성이면 비활성 모양(매트)으로 그려진다.
    /// 다른 앱을 만지는 순간 매트로 바뀌므로, 창이 늘 key인 척해서 활성 모양을 유지한다.
    var allowsKey = false
    var forceActive = false
    override var canBecomeKey: Bool { allowsKey }
    override var isKeyWindow: Bool { forceActive || super.isKeyWindow }
    override var isMainWindow: Bool { forceActive || super.isMainWindow }

    // 위 공개 속성만으로는 부족했다. 유리(NSGlassEffectView의 _windowChangedKeyState)는
    // 창의 "활성 모양" 판단을 따르는데, 그건 AppKit 비공개 메서드라 같은 이름으로 덮어쓴다.
    // macOS 27.0.1에서 런타임으로 확인한 이름. OS가 바뀌면 이름이 달라질 수 있다.
    @objc func _hasActiveAppearance() -> Bool { forceActive }
    @objc func _hasActiveAppearanceIgnoringKeyFocus() -> Bool { forceActive }
    @objc func _hasKeyAppearance() -> Bool { forceActive }
    @objc func _hasMainAppearance() -> Bool { forceActive }
    @objc func hasKeyAppearance() -> Bool { forceActive }
    @objc func hasMainAppearance() -> Bool { forceActive }

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

    /// 화면 위 가운데에 붙는 패널 프레임
    static func topCenterFrame(on screen: NSScreen, size: CGSize) -> CGRect {
        let sf = screen.frame
        return CGRect(x: sf.midX - size.width / 2, y: sf.maxY - size.height,
                      width: size.width, height: size.height)
    }
}

/// 실험용 조절 창. 노치 바로 아래 가운데에 띄운다.
/// 슬라이더를 만져도 key를 가져가지 않는 패널이라, 노치 쪽 패널이 key를 유지할 수 있다.
func makeControlWindow<V: View>(title: String, on screen: NSScreen, below: CGFloat, content: V) -> NSWindow {
    let window = NSPanel(contentRect: .zero, styleMask: [.titled, .closable, .nonactivatingPanel],
                         backing: .buffered, defer: false)
    window.becomesKeyOnlyIfNeeded = true
    window.hidesOnDeactivate = false
    window.title = title
    window.contentView = NSHostingView(rootView: content)
    window.setContentSize(window.contentView!.fittingSize)
    let sf = screen.frame
    window.setFrameTopLeftPoint(CGPoint(x: sf.midX - window.frame.width / 2, y: sf.maxY - below))
    window.isReleasedWhenClosed = false
    return window
}

/// 조절 창의 슬라이더 한 줄. 오른쪽 수치를 누르면 입력칸으로 바뀌어 숫자로도 넣을 수 있다.
func sliderRow(_ label: String, _ value: Binding<CGFloat>, _ range: ClosedRange<CGFloat>,
               step: CGFloat = 0.5) -> some View {
    HStack {
        Text(label).frame(width: 120, alignment: .leading)
        Slider(value: value, in: range, step: step)
        NumberField(value: value, range: range, format: step < 0.1 ? "%.2f" : "%.1f")
    }
}

/// 수치 표시. 누르면 입력칸이 되고, 리턴이나 다른 곳을 누르면 반영(범위 밖이면 범위 끝으로), esc면 취소.
struct NumberField: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let format: String
    @State private var editing = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if editing {
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused($focused)
                    .onSubmit(commit)
                    .onExitCommand { editing = false }
                    .onChange(of: focused) { _, now in if !now { commit() } }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor, lineWidth: 1))
            } else {
                Text(String(format: format, value)).monospacedDigit()
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
                    .onTapGesture { begin() }
                    .help("눌러서 숫자 입력")
            }
        }
        .frame(width: 56)
    }

    private func begin() {
        text = String(format: format, value)
        editing = true
        // 입력칸이 생긴 뒤에 포커스를 주고, 기존 숫자를 모두 선택해 바로 덮어 쓸 수 있게 한다
        DispatchQueue.main.async {
            focused = true
            DispatchQueue.main.async { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
        }
    }

    private func commit() {
        guard editing else { return }
        editing = false
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if let v = Double(cleaned) {
            value = min(max(CGFloat(v), range.lowerBound), range.upperBound)
        }
    }
}
