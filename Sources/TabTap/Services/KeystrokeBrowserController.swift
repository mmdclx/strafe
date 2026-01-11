import CoreGraphics
import Carbon

final class KeystrokeBrowserController: BrowserNavigating {
    func navigateLeft() {
        postTabKey(shift: true)
        Log.debug(Log.navigation, "Navigate left")
    }

    func navigateRight() {
        postTabKey(shift: false)
        Log.debug(Log.navigation, "Navigate right")
    }

    private func postTabKey(shift: Bool) {
        let flags: CGEventFlags = shift ? [.maskControl, .maskShift] : [.maskControl]
        let keyCode = CGKeyCode(kVK_Tab)

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
