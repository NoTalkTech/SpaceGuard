import AppKit

enum MenuBarIcon {
    static func defaultImage(pointSize: CGFloat = 22) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: image.size)
        drawBadge(in: rect, pointSize: pointSize)
        drawMobius(in: rect, pointSize: pointSize)

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func drawBadge(in rect: NSRect, pointSize: CGFloat) {
        let badgeRect = NSRect(
            x: rect.midX - pointSize * 0.245,
            y: rect.midY - pointSize * 0.245,
            width: pointSize * 0.49,
            height: pointSize * 0.49
        )

        let badge = NSBezierPath(ovalIn: badgeRect)
        badge.lineWidth = max(1.9, pointSize * 0.115)
        NSColor.labelColor.setStroke()
        badge.stroke()
    }

    private static func drawMobius(in rect: NSRect, pointSize: CGFloat) {
        let center = NSPoint(x: rect.midX, y: rect.midY + pointSize * 0.02)
        let outerRect = NSRect(
            x: center.x - pointSize * 0.188,
            y: center.y - pointSize * 0.088,
            width: pointSize * 0.376,
            height: pointSize * 0.176
        )
        let innerRect = outerRect.insetBy(dx: pointSize * 0.061, dy: pointSize * 0.033)

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.rotate(byDegrees: -18)
        transform.translateX(by: -center.x, yBy: -center.y)
        transform.concat()

        let ring = NSBezierPath()
        ring.appendOval(in: outerRect)
        ring.appendOval(in: innerRect)
        ring.windingRule = .evenOdd
        NSColor.labelColor.setFill()
        ring.fill()

        let cutout = NSBezierPath(
            roundedRect: NSRect(
                x: center.x - pointSize * 0.04,
                y: center.y - pointSize * 0.108,
                width: pointSize * 0.08,
                height: pointSize * 0.216
            ),
            xRadius: pointSize * 0.022,
            yRadius: pointSize * 0.022
        )
        NSGraphicsContext.current?.compositingOperation = .clear
        cutout.fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver

        let bridge = NSBezierPath()
        bridge.move(to: NSPoint(x: center.x - pointSize * 0.148, y: center.y + pointSize * 0.026))
        bridge.curve(
            to: NSPoint(x: center.x + pointSize * 0.128, y: center.y - pointSize * 0.008),
            controlPoint1: NSPoint(x: center.x - pointSize * 0.07, y: center.y - pointSize * 0.012),
            controlPoint2: NSPoint(x: center.x + pointSize * 0.036, y: center.y - pointSize * 0.032)
        )
        bridge.line(to: NSPoint(x: center.x + pointSize * 0.148, y: center.y + pointSize * 0.037))
        bridge.curve(
            to: NSPoint(x: center.x - pointSize * 0.122, y: center.y + pointSize * 0.066),
            controlPoint1: NSPoint(x: center.x + pointSize * 0.06, y: center.y + pointSize * 0.062),
            controlPoint2: NSPoint(x: center.x - pointSize * 0.036, y: center.y + pointSize * 0.084)
        )
        bridge.close()
        NSColor.labelColor.setFill()
        bridge.fill()

        NSGraphicsContext.restoreGraphicsState()
    }
}
