import AppKit
import Foundation
import OSLog
import UniformTypeIdentifiers

@MainActor
final class AppController: ObservableObject {
    @Published var settings = AppSettings()
    @Published var voices: [String] = [AppSettings().voice]
    @Published var statusMessage = ""
    @Published var isErrorStatus = false
    @Published var isBackendProcessRunning = false
    @Published var cacheSummary = "Cache not checked."

    private let logger = Logger(subsystem: "KokoroBar", category: "AppController")
    private let apiClient = KokoroAPIClient()
    private let audioPlayer = AudioPlaybackService()
    private var hotKeyObserver: NSObjectProtocol?
    private var backendProcess: Process?
    private var backendLogHandle: FileHandle?

    init() {
        hotKeyObserver = NotificationCenter.default.addObserver(
            forName: .kokoroReadRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.readSelectedText(explicit: false) }
        }

        if settings.autoStartBackend {
            startBackendIfPossible()
        }
    }

    deinit {
        if let hotKeyObserver {
            NotificationCenter.default.removeObserver(hotKeyObserver)
        }
        backendProcess?.terminate()
        try? backendLogHandle?.close()
    }

    func readClipboard() async {
        let text = NSPasteboard.general.string(forType: .string)?.trimmed ?? ""
        guard !text.isEmpty else {
            setError("Clipboard is empty.")
            return
        }

        await speak(text)
    }

    func readSelectedText(explicit: Bool) async {
        do {
            if let selectedText = try AccessibilityTextReader.selectedText(), !selectedText.trimmed.isEmpty {
                await speak(selectedText)
                return
            }

            if explicit {
                setError("No selected text found. Try copying text first, or grant Accessibility permission.")
                return
            }

            await readClipboard()
        } catch AccessibilityTextReader.ReaderError.permissionMissing {
            if explicit {
                setError("Accessibility permission is required. Open System Settings > Privacy & Security > Accessibility and enable this app.")
            } else {
                logger.info("Accessibility permission missing; falling back to clipboard")
                await readClipboard()
            }
        } catch {
            if explicit {
                setError("Could not read selected text: \(error.localizedDescription)")
            } else {
                logger.info("Selected text unavailable; falling back to clipboard")
                await readClipboard()
            }
        }
    }

    func stopSpeaking() {
        audioPlayer.stop()
        setStatus("Stopped.")
    }

    func checkHealth() async {
        do {
            let health = try await apiClient.health(baseURL: settings.backendURL)
            if health.ok {
                cacheSummary = "\(health.cacheFiles) files, \(Self.formatBytes(health.cacheBytes))"
                setStatus(health.modelLoaded ? "Backend healthy. Model loaded." : "Backend healthy. Model not loaded yet.")
            } else {
                setError(health.error ?? "Backend is not ready.")
            }
        } catch {
            setError("Backend not running at \(settings.backendURL).")
        }
    }

    func loadVoices() async {
        do {
            let loadedVoices = try await apiClient.voices(baseURL: settings.backendURL)
            voices = loadedVoices.isEmpty ? voices : loadedVoices
            if !voices.contains(settings.voice), let firstVoice = voices.first {
                settings.voice = firstVoice
            }
            setStatus("Loaded \(voices.count) voices.")
        } catch {
            setError("Could not load voices. Check that the backend is running.")
        }
    }

    func refreshCacheInfo() async {
        do {
            let cache = try await apiClient.cache(baseURL: settings.backendURL)
            cacheSummary = "\(cache.files) files, \(Self.formatBytes(cache.bytes))"
            setStatus("Cache: \(cacheSummary).")
        } catch {
            setError("Could not read backend cache info.")
        }
    }

    func clearCache() async {
        do {
            let cache = try await apiClient.clearCache(baseURL: settings.backendURL)
            cacheSummary = "\(cache.files) files, \(Self.formatBytes(cache.bytes))"
            setStatus("Cleared generated audio cache.")
        } catch {
            setError("Could not clear backend cache.")
        }
    }

    func saveClipboardAudio() async {
        let text = NSPasteboard.general.string(forType: .string)?.trimmed ?? ""
        guard !text.isEmpty else {
            setError("Clipboard is empty.")
            return
        }

        do {
            setStatus("Generating speech for export...")
            let audioURL = try await generateSpeech(for: text)
            guard let destination = chooseSaveDestination() else {
                setStatus("Export cancelled.")
                return
            }
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: audioURL, to: destination)
            setStatus("Saved \(destination.lastPathComponent).")
        } catch {
            setError("Could not save audio: \(error.localizedDescription)")
        }
    }

    func chooseBackendFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: settings.backendPath)
        panel.message = "Choose the backend folder that contains app/main.py and scripts/run.sh."

        if panel.runModal() == .OK, let url = panel.url {
            settings.backendPath = url.path
            setStatus("Backend folder updated.")
        }
    }

    func revealBackendFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: settings.backendPath)])
    }

    func openBackendLog() {
        let logURL = AppPaths.backendLog
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        NSWorkspace.shared.open(logURL)
    }

    private func speak(_ text: String) async {
        do {
            setStatus("Generating speech...")
            let audioURL = try await generateSpeech(for: text)
            try audioPlayer.play(fileURL: audioURL)
            setStatus("Speaking.")
        } catch {
            logger.error("Speech failed: \(error.localizedDescription)")
            setError(error.localizedDescription)
        }
    }

    private func generateSpeech(for text: String) async throws -> URL {
        try await apiClient.tts(
            baseURL: settings.backendURL,
            text: text,
            voice: settings.voice,
            speed: settings.speed
        )
    }

    func startBackendIfPossible() {
        guard backendProcess?.isRunning != true else {
            setStatus("Backend is already starting or running.")
            return
        }

        let backendDirectory = URL(fileURLWithPath: settings.backendPath, isDirectory: true)

        guard FileManager.default.fileExists(atPath: backendDirectory.path) else {
            setError("Auto-start backend is enabled, but the backend folder was not found.")
            return
        }

        let appFile = backendDirectory.appendingPathComponent("app/main.py")
        guard FileManager.default.fileExists(atPath: appFile.path) else {
            setError("Backend folder is invalid. Expected app/main.py inside \(backendDirectory.path).")
            return
        }

        let hostAndPort = parsedBackendHostAndPort()
        let process = Process()
        process.currentDirectoryURL = backendDirectory
        process.environment = backendEnvironment(host: hostAndPort.host, port: hostAndPort.port)

        let runScript = backendDirectory.appendingPathComponent("scripts/run.sh")
        if FileManager.default.isExecutableFile(atPath: runScript.path) {
            process.executableURL = runScript
            process.arguments = []
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [
                "uv", "run", "uvicorn", "app.main:app",
                "--host", hostAndPort.host,
                "--port", String(hostAndPort.port)
            ]
        }

        do {
            try? backendLogHandle?.close()
            backendLogHandle = try logHandle()
            process.standardOutput = backendLogHandle
            process.standardError = backendLogHandle
        } catch {
            logger.error("Could not open backend log: \(error.localizedDescription)")
        }

        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard let self else { return }
                self.isBackendProcessRunning = false
                self.backendProcess = nil
                try? self.backendLogHandle?.close()
                self.backendLogHandle = nil
                self.setStatus("Backend stopped with exit code \(process.terminationStatus).")
            }
        }

        do {
            try process.run()
            backendProcess = process
            isBackendProcessRunning = true
            setStatus("Backend starting on \(hostAndPort.host):\(hostAndPort.port).")
        } catch {
            setError("Could not auto-start backend. Run it manually from the backend folder.")
        }
    }

    func stopStartedBackend() {
        guard let backendProcess, backendProcess.isRunning else {
            return
        }
        backendProcess.terminate()
        self.backendProcess = nil
        isBackendProcessRunning = false
        setStatus("Stopped app-started backend.")
    }

    private func parsedBackendHostAndPort() -> (host: String, port: Int) {
        guard let url = URL(string: settings.backendURL) else {
            return ("127.0.0.1", 8880)
        }
        return (url.host ?? "127.0.0.1", url.port ?? 8880)
    }

    private func backendEnvironment(host: String, port: Int) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            environment["PATH"] ?? ""
        ].joined(separator: ":")
        environment["KOKORO_HOST"] = host
        environment["KOKORO_PORT"] = String(port)
        return environment
    }

    private func logHandle() throws -> FileHandle {
        let logURL = AppPaths.backendLog
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: logURL)
        try handle.seekToEnd()
        return handle
    }

    private func chooseSaveDestination() -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "kokoro-speech.wav"
        panel.canCreateDirectories = true
        if let wavType = UTType(filenameExtension: "wav") {
            panel.allowedContentTypes = [wavType]
        }
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static func formatBytes(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func setStatus(_ message: String) {
        statusMessage = message
        isErrorStatus = false
        logger.info("\(message)")
    }

    private func setError(_ message: String) {
        statusMessage = message
        isErrorStatus = true
        logger.error("\(message)")
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
