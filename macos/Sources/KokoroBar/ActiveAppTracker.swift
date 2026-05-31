import AppKit

final class ActiveAppTracker {
    static let shared = ActiveAppTracker()

    private var observer: NSObjectProtocol?
    private let selfPID = ProcessInfo.processInfo.processIdentifier
    private let selfBundleIdentifier = Bundle.main.bundleIdentifier

    private(set) var lastNonSelfPID: pid_t?

    private init() {}

    func start() {
        updateLastNonSelfApp(NSWorkspace.shared.frontmostApplication)

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.updateLastNonSelfApp(app)
        }
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    func selectedTextTargetPID() -> pid_t? {
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           isUsableTarget(frontmost) {
            updateLastNonSelfApp(frontmost)
            return frontmost.processIdentifier
        }

        return lastNonSelfPID
    }

    private func updateLastNonSelfApp(_ app: NSRunningApplication?) {
        guard let app, isUsableTarget(app) else {
            return
        }
        lastNonSelfPID = app.processIdentifier
    }

    private func isUsableTarget(_ app: NSRunningApplication) -> Bool {
        if app.processIdentifier == selfPID {
            return false
        }
        if let selfBundleIdentifier, app.bundleIdentifier == selfBundleIdentifier {
            return false
        }
        return true
    }
}
