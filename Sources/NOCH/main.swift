import AppKit

// 실험 모드
//   NOCH          노치 둘레 형광선 (OutlineDemo)
//   NOCH siri     Siri 팝업식 유리 패널 (SiriDemo)

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let mode = CommandLine.arguments.dropFirst().first ?? "outline"
    private var outline: OutlineDemo?
    private var siri: AnyObject?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let metrics = NotchMetrics.builtIn() else {
            print("노치가 있는 화면을 찾지 못했습니다.")
            NSApp.terminate(nil)
            return
        }
        print(String(format: "노치: %.1f × %.1f pt, 화면 %@", metrics.width, metrics.height,
                     NSStringFromRect(metrics.screen.frame)))

        switch mode {
        case "siri":
            guard #available(macOS 26.0, *) else {
                print("Liquid Glass는 macOS 26 이상에서만 됩니다.")
                NSApp.terminate(nil)
                return
            }
            let demo = SiriDemo()
            demo.start(metrics: metrics)
            siri = demo
        default:
            let demo = OutlineDemo()
            demo.start(metrics: metrics)
            outline = demo
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        outline?.stop()
        if #available(macOS 26.0, *) { (siri as? SiriDemo)?.stop() }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
