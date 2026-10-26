import CoreGraphics
import Carbon

final class KeystrokeBrowserController: BrowserNavigating {
    private let postEvent: (CGEvent) -> Void

    init(postEvent: @escaping (CGEvent) -> Void = { $0.post(tap: .cghidEventTap) }) {
        self.postEvent = postEvent
    }

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

        postEvent(keyDown)
        postEvent(keyUp)
    }
}
