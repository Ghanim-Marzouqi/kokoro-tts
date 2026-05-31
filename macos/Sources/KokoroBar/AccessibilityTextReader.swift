import AppKit
import ApplicationServices
import Carbon.HIToolbox

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

        if let selectedText = directAccessibilitySelectedText(), !selectedText.trimmed.isEmpty {
            return selectedText
        }

        if let copiedText = copySelectedTextPreservingClipboard(), !copiedText.trimmed.isEmpty {
            return copiedText
        }

        throw ReaderError.selectedTextUnavailable
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private static func directAccessibilitySelectedText() -> String? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard focusedResult == .success, let focusedElement = focusedValue else {
            return nil
        }

        var selectedValue: CFTypeRef?
        let selectedResult = AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        )

        guard selectedResult == .success else {
            return nil
        }

        return selectedValue as? String
    }

    private static func copySelectedTextPreservingClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        let originalChangeCount = pasteboard.changeCount
        let originalItems = pasteboard.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }

        pasteboard.clearContents()
        postCommandC()

        var copiedText: String?
        for _ in 0..<10 {
            usleep(50_000)
            if pasteboard.changeCount != originalChangeCount,
               let text = pasteboard.string(forType: .string),
               !text.trimmed.isEmpty {
                copiedText = text
                break
            }
        }

        pasteboard.clearContents()
        if let originalItems, !originalItems.isEmpty {
            pasteboard.writeObjects(originalItems)
        }

        return copiedText
    }

    private static func postCommandC() {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false) else {
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private static func isTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
