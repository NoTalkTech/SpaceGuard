import Foundation
import AppKit

class IconGenerator {

    static func generateDiskIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size, height: size)

        // Draw background - blue gradient
        let backgroundColor = NSColor.systemBlue
        backgroundColor.setFill()
        rect.fill()

        // Draw disk shape - white circle
        let diskRect = NSRect(
            x: size * 0.15,
            y: size * 0.15,
            width: size * 0.7,
            height: size * 0.7
        )
        let diskPath = NSBezierPath(ovalIn: diskRect)
        NSColor.white.setFill()
        diskPath.fill()

        // Draw shield overlay - smaller blue shield
        let shieldRect = NSRect(
            x: size * 0.3,
            y: size * 0.3,
            width: size * 0.4,
            height: size * 0.4
        )
        let shieldPath = createShieldPath(in: shieldRect)
        NSColor.systemBlue.setFill()
        shieldPath.fill()

        // Draw inner disk detail
        let innerDiskRect = NSRect(
            x: size * 0.25,
            y: size * 0.25,
            width: size * 0.5,
            height: size * 0.5
        )
        let innerDiskPath = NSBezierPath(ovalIn: innerDiskRect)
        NSColor.systemBlue.setFill()
        innerDiskPath.fill()

        image.unlockFocus()
        return image
    }

    static func createShieldPath(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()

        // Simple shield shape (upside-down teardrop)
        let topCenter = NSPoint(x: rect.midX, y: rect.maxY - rect.height * 0.1)
        let leftTop = NSPoint(x: rect.minX + rect.width * 0.2, y: rect.maxY - rect.height * 0.3)
        let rightTop = NSPoint(x: rect.maxX - rect.width * 0.2, y: rect.maxY - rect.height * 0.3)
        let leftBottom = NSPoint(x: rect.minX + rect.width * 0.1, y: rect.minY + rect.height * 0.2)
        let rightBottom = NSPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY + rect.height * 0.2)
        let bottomCenter = NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.1)

        path.move(to: topCenter)
        path.curve(to: leftTop, controlPoint1: NSPoint(x: topCenter.x - rect.width * 0.1, y: topCenter.y),
                  controlPoint2: NSPoint(x: leftTop.x, y: leftTop.y + rect.height * 0.1))
        path.line(to: leftBottom)
        path.curve(to: bottomCenter, controlPoint1: NSPoint(x: leftBottom.x, y: bottomCenter.y),
                  controlPoint2: NSPoint(x: bottomCenter.x - rect.width * 0.05, y: bottomCenter.y))
        path.curve(to: rightBottom, controlPoint1: NSPoint(x: bottomCenter.x + rect.width * 0.05, y: bottomCenter.y),
                  controlPoint2: NSPoint(x: rightBottom.x, y: rightBottom.y))
        path.line(to: rightTop)
        path.curve(to: topCenter, controlPoint1: NSPoint(x: rightTop.x, y: rightTop.y + rect.height * 0.1),
                  controlPoint2: NSPoint(x: topCenter.x + rect.width * 0.1, y: topCenter.y))
        path.close()

        return path
    }

    static func saveIcon(image: NSImage, to path: String) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to PNG"])
        }

        try pngData.write(to: URL(fileURLWithPath: path))
    }

    static func generateAllIcons() throws {
        let sizes: [CGFloat] = [16, 32, 64, 128, 256, 512]

        // Create Resources directory if it doesn't exist
        let resourcesURL = URL(fileURLWithPath: "Sources/Resources")
        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true, attributes: nil)

        for size in sizes {
            let image = generateDiskIcon(size: size)
            let filename = "appicon_\(Int(size)).png"
            let fileURL = resourcesURL.appendingPathComponent(filename)

            try saveIcon(image: image, to: fileURL.path)
            print("Generated \(filename)")
        }

        // Create ICNS file
        print("Note: To create .icns file, run:")
        print("iconutil -c icns -o Sources/Resources/AppIcon.icns Sources/Resources/appicon_*.iconset")
        print("First create .iconset directory with all PNG files named correctly")
    }
}

// Run if called directly
if CommandLine.arguments.contains("--generate") {
    do {
        try IconGenerator.generateAllIcons()
        print("Icons generated successfully!")
    } catch {
        print("Error generating icons: \(error)")
        exit(1)
    }
} else {
    print("IconGenerator - Usage: swift IconGenerator.swift --generate")
}