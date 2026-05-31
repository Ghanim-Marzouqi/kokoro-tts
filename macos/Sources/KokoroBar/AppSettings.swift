import Foundation

struct AppSettings {
    var backendURL: String {
        didSet { UserDefaults.standard.set(backendURL, forKey: Keys.backendURL) }
    }

    var backendPath: String {
        didSet { UserDefaults.standard.set(backendPath, forKey: Keys.backendPath) }
    }

    var voice: String {
        didSet { UserDefaults.standard.set(voice, forKey: Keys.voice) }
    }

    var speed: Double {
        didSet { UserDefaults.standard.set(speed, forKey: Keys.speed) }
    }

    var autoStartBackend: Bool {
        didSet { UserDefaults.standard.set(autoStartBackend, forKey: Keys.autoStartBackend) }
    }

    init() {
        backendURL = UserDefaults.standard.string(forKey: Keys.backendURL) ?? "http://127.0.0.1:8880"
        backendPath = UserDefaults.standard.string(forKey: Keys.backendPath) ?? BackendPathResolver.defaultBackendPath.path
        voice = UserDefaults.standard.string(forKey: Keys.voice) ?? "af_sarah"

        let storedSpeed = UserDefaults.standard.double(forKey: Keys.speed)
        speed = storedSpeed == 0 ? 1.0 : storedSpeed
        autoStartBackend = UserDefaults.standard.bool(forKey: Keys.autoStartBackend)
    }

    private enum Keys {
        static let backendURL = "backendURL"
        static let backendPath = "backendPath"
        static let voice = "voice"
        static let speed = "speed"
        static let autoStartBackend = "autoStartBackend"
    }
}
