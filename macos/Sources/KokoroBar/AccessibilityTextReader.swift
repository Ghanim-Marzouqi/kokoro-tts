import AppKit
import ApplicationServices

enum AccessibilityTextReader {
    enum ReaderError: LocalizedError {
        case permissionMissing
        case focusedElementUnavailable
        case selectedTextUnavailable

        var errorDescription: String? {
            switch self {
            case .permissionMissing:
                return "Accessibility permission is missing."
            case .focusedElementUnavailable:
                return "Could not find the focused UI element."
            case .selectedTextUnavailable:
                return "The focused app did not expose selected text."
            }
        }
    }

    static func selectedText() throws -> String? {
        guard isTrusted(prompt: true) else {
            throw ReaderError.permissionMissing
        }

        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard focusedResult == .success, let focusedElement = focusedValue else {
            throw ReaderError.focusedElementUnavailable
        }

        var selectedValue: CFTypeRef?
        let selectedResult = AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        )

        guard selectedResult == .success else {
            throw ReaderError.selectedTextUnavailable
        }

        return selectedValue as? String
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private static func isTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
