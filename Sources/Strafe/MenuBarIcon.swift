import AppKit

enum MenuBarIcon {
    static func makeImage(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let sourceWidth: CGFloat = 18
        let sourceHeight: CGFloat = 11
        let scale = (size * 0.9) / sourceWidth
        let drawWidth = sourceWidth * scale
        let drawHeight = sourceHeight * scale
        let originX = (size - drawWidth) / 2
        let originY = (size - drawHeight) / 2

        let lines: [(CGFloat, CGFloat, CGFloat)] = [
            (7.0498, 16.0498, 1.05005),
            (4.0498, 13.0498, 5.05005),
            (1.0498, 10.0498, 9.05005)
        ]

        let path = NSBezierPath()
        path.lineWidth = 2.1 * scale
        path.lineCapStyle = .round
        for (x1, x2, y) in lines {
            let yFlipped = sourceHeight - y
            path.move(to: NSPoint(x: originX + x1 * scale, y: originY + yFlipped * scale))
            path.line(to: NSPoint(x: originX + x2 * scale, y: originY + yFlipped * scale))
        }

        NSColor.black.setStroke()
        path.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
