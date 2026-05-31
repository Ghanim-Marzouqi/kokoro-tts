import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        Form {
            Section("Backend") {
                TextField("Backend URL", text: $controller.settings.backendURL)
                    .textFieldStyle(.roundedBorder)

                TextField("Backend Folder", text: $controller.settings.backendPath)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Choose Folder") {
                        controller.chooseBackendFolder()
                    }

                    Button("Reveal Folder") {
                        controller.revealBackendFolder()
                    }
                }

                Toggle("Auto-start backend", isOn: $controller.settings.autoStartBackend)
                    .onChange(of: controller.settings.autoStartBackend) { enabled in
                        if enabled {
                            controller.startBackendIfPossible()
                        } else {
                            controller.stopStartedBackend()
                        }
                    }

                HStack {
                    Button(controller.isBackendProcessRunning ? "Stop Backend" : "Start Backend") {
                        if controller.isBackendProcessRunning {
                            controller.stopStartedBackend()
                        } else {
                            controller.startBackendIfPossible()
                        }
                    }

                    Button("Check Health") {
                        Task { await controller.checkHealth() }
                    }

                    Button("Load Voices") {
                        Task { await controller.loadVoices() }
                    }
                }

                HStack {
                    Button("Open Backend Log") {
                        controller.openBackendLog()
                    }

                    Button("Refresh Cache") {
                        Task { await controller.refreshCacheInfo() }
                    }

                    Button("Clear Cache") {
                        Task { await controller.clearCache() }
                    }
                }
            }

            Section("Speech") {
                Picker("Voice", selection: $controller.settings.voice) {
                    ForEach(controller.voices, id: \.self) { voice in
                        Text(voice).tag(voice)
                    }
                }

                HStack {
                    Slider(value: $controller.settings.speed, in: 0.5...2.0, step: 0.05)
                    Text(controller.settings.speed.formatted(.number.precision(.fractionLength(2))))
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }

            Section("Status") {
                Text(controller.statusMessage.isEmpty ? "Idle" : controller.statusMessage)
                    .foregroundStyle(controller.isErrorStatus ? .red : .secondary)

                Text("Generated audio cache: \(controller.cacheSummary)")
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                Button("Open Accessibility Settings") {
                    AccessibilityTextReader.openAccessibilitySettings()
                }
            }
        }
        .padding(20)
        .onAppear {
            Task { await controller.loadVoices() }
        }
    }
}
