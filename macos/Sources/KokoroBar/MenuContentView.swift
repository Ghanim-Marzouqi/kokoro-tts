import SwiftUI

struct MenuContentView: View {
    @ObservedObject var controller: AppController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Read Clipboard") {
            Task { await controller.readClipboard() }
        }
        .keyboardShortcut("r", modifiers: [.command, .shift])

        Button("Save Clipboard Audio...") {
            Task { await controller.saveClipboardAudio() }
        }

        Button("Read Selected Text") {
            Task { await controller.readSelectedText(explicit: true) }
        }

        Button("Stop Speaking") {
            controller.stopSpeaking()
        }

        Divider()

        Button(controller.isBackendProcessRunning ? "Stop Backend" : "Start Backend") {
            if controller.isBackendProcessRunning {
                controller.stopStartedBackend()
            } else {
                controller.startBackendIfPossible()
            }
        }

        Button("Check Backend") {
            Task { await controller.checkHealth() }
        }

        Divider()

        Button("Settings") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }

        if !controller.statusMessage.isEmpty {
            Divider()
            Text(controller.statusMessage)
                .font(.caption)
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}
