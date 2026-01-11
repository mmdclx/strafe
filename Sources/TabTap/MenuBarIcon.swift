import AppKit

enum MenuBarIcon {
    static func makeImage(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let path = NSBezierPath()
        path.lineWidth = 1.8
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let leftTop = NSPoint(x: size * 0.58, y: size * 0.80)
        let leftMid = NSPoint(x: size * 0.38, y: size * 0.50)
        let leftBottom = NSPoint(x: size * 0.58, y: size * 0.20)

        let rightTop = NSPoint(x: size * 0.42, y: size * 0.80)
        let rightMid = NSPoint(x: size * 0.62, y: size * 0.50)
        let rightBottom = NSPoint(x: size * 0.42, y: size * 0.20)

        path.move(to: leftTop)
        path.line(to: leftMid)
        path.line(to: leftBottom)

        path.move(to: rightTop)
        path.line(to: rightMid)
        path.line(to: rightBottom)

        NSColor.black.setStroke()
        path.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
