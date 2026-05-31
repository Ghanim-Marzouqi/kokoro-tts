import SwiftUI

@main
struct KokoroBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = AppController()

    var body: some Scene {
        MenuBarExtra("Kokoro TTS", systemImage: "waveform") {
            MenuContentView(controller: controller)
        }
        .menuBarExtraStyle(.menu)

        Window("Kokoro Settings", id: "settings") {
            SettingsView(controller: controller)
                .frame(width: 460, height: 340)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotKeyManager = HotKeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ActiveAppTracker.shared.start()
        hotKeyManager.registerCommandShiftR {
            let targetPID = ActiveAppTracker.shared.selectedTextTargetPID()
            let userInfo: [String: Any]? = targetPID.map { ["targetPID": $0] }
            NotificationCenter.default.post(
                name: .kokoroReadRequested,
                object: nil,
                userInfo: userInfo
            )
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
        ActiveAppTracker.shared.stop()
    }
}

extension Notification.Name {
    static let kokoroReadRequested = Notification.Name("kokoroReadRequested")
}
