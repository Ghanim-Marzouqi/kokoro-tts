import Foundation

enum AppPaths {
    static var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("KokoroBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static var backendLog: URL {
        appSupportDirectory.appendingPathComponent("backend.log")
    }
}

enum BackendPathResolver {
    static var defaultBackendPath: URL {
        let fileManager = FileManager.default

        if let resourceBackend = Bundle.main.resourceURL?.appendingPathComponent("backend"),
           fileManager.fileExists(atPath: resourceBackend.path) {
            return resourceBackend
        }

        let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let candidates = [
            currentDirectory.appendingPathComponent("backend"),
            currentDirectory.deletingLastPathComponent().appendingPathComponent("backend"),
            currentDirectory.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("backend")
        ]

        return candidates.first { fileManager.fileExists(atPath: $0.path) }
            ?? currentDirectory.appendingPathComponent("backend")
    }
}
