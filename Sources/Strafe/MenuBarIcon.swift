import AppKit

enum MenuBarIcon {
    static func makeImage(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let barWidth = size * 0.78
        let barHeight = max(2, size * 0.16)
        let barRadius = barHeight / 2
        let gap = barHeight * 0.9
        let totalHeight = barHeight * 3 + gap * 2
        let startY = (size - totalHeight) / 2
        let startX = (size - barWidth) / 2

        let composite = NSBezierPath()
        for index in 0..<3 {
            let rect = NSRect(
                x: startX,
                y: startY + CGFloat(index) * (barHeight + gap),
                width: barWidth,
                height: barHeight
            )
            let bar = NSBezierPath(roundedRect: rect, xRadius: barRadius, yRadius: barRadius)
            composite.append(bar)
        }

        NSColor.black.setFill()
        composite.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
