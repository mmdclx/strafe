@preconcurrency import ApplicationServices

@MainActor
final class AccessibilityPermissionService: PermissionChecking {
    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func promptIfNeeded() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: CFDictionary = [promptKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            Log.info(Log.permissions, "Accessibility permission not granted")
        }
    }
}
