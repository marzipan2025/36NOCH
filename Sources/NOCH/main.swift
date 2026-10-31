import AppKit

// 노치 패널(SiriDemo)을 띄우는 메뉴 막대 앱

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var siri: AnyObject?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let metrics = NotchMetrics.builtIn() else {
            print("노치가 있는 화면을 찾지 못했습니다.")
            NSApp.terminate(nil)
            return
        }
        print(String(format: "노치: %.1f × %.1f pt, 화면 %@", metrics.width, metrics.height,
                     NSStringFromRect(metrics.screen.frame)))

        guard #available(macOS 26.0, *) else {
            print("Liquid Glass는 macOS 26 이상에서만 됩니다.")
            NSApp.terminate(nil)
            return
        }
        let demo = SiriDemo()
        demo.start(metrics: metrics)
        siri = demo
        NSApp.activate(ignoringOtherApps: true)
    }

    // 설정창을 닫아도 노치는 계속 살아 있어야 한다
    // (노치 패널은 "마지막 창"으로 세지 않아서, 설정창을 닫으면 앱이 그대로 종료돼 버렸다). 종료는 메뉴의 종료로.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        if #available(macOS 26.0, *) { (siri as? SiriDemo)?.stop() }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// 독에 나타나지 않는 메뉴 막대 앱. .app 번들에서는 Info.plist의 LSUIElement도 같은 뜻.
app.setActivationPolicy(.accessory)
app.run()
