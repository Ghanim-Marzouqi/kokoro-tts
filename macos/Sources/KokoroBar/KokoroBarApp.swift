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
        hotKeyManager.registerCommandShiftR {
            NotificationCenter.default.post(name: .kokoroReadRequested, object: nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
    }
}

extension Notification.Name {
    static let kokoroReadRequested = Notification.Name("kokoroReadRequested")
}
