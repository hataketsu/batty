import AppKit

/// The Batty glyph: a battery capsule wearing bat ears and wings. Laid out on a
/// fixed 22x16 grid and scaled to whatever the caller needs, so the menu bar
/// version and the app icon are the same drawing.
enum BattyIcon {
    static func menuBar(level: Int, charging: Bool) -> NSImage {
        let image = image(level: level, charging: charging,
                          size: NSSize(width: 20, height: 15), color: .black)
        image.isTemplate = true
        return image
    }

    /// Renders the glyph into its own transparent image. Drawing goes through
    /// here rather than straight onto the destination because the eyes and bolt
    /// are knocked out, which would also punch through anything underneath.
    static func image(level: Int, charging: Bool, size: NSSize,
                      color: NSColor, face: Bool = true) -> NSImage {
        NSImage(size: size, flipped: false) { _ in
            draw(level: level, charging: charging, in: size, color: color, face: face)
            return true
        }
    }

    private static let body = NSRect(x: 5.2, y: 3.6, width: 11.6, height: 7.6)

    static func draw(level: Int, charging: Bool, in size: NSSize,
                     color: NSColor, face: Bool = true) {
        let unit = min(size.width / 22, size.height / 16)
        NSGraphicsContext.current?.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: (size.width - 22 * unit) / 2,
                             yBy: (size.height - 16 * unit) / 2)
        transform.scale(by: unit)
        transform.concat()
        color.set()

        // Ears go down first; the battery outline then covers their base.
        ear(apex: 7.9, from: 6.6, to: 9.6).fill()
        ear(apex: 14.1, from: 12.4, to: 15.4).fill()

        // Clear the ear bases that reach inside the shell, then draw the shell.
        let outline = NSBezierPath(roundedRect: body, xRadius: 2.2, yRadius: 2.2)
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        NSBezierPath(roundedRect: body.insetBy(dx: 0.5, dy: 0.5),
                     xRadius: 1.8, yRadius: 1.8).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        outline.lineWidth = 1.0
        outline.stroke()

        // Charge level: a bar in the lower half, leaving room for the eyes.
        let inner = body.insetBy(dx: 1.9, dy: 1.9)
        let barHeight = face ? inner.height * 0.46 : inner.height
        let fraction = Double(max(0, min(100, level))) / 100
        let bar = NSRect(x: inner.minX, y: inner.minY,
                         width: inner.width * fraction, height: barHeight)
        if fraction > 0.03 {
            NSBezierPath(roundedRect: bar, xRadius: 0.7, yRadius: 0.7).fill()
        }

        // Eyes sit above the bar, so they can simply be drawn.
        if face {
            for x in [body.midX - 2.1, body.midX + 2.1] {
                NSBezierPath(ovalIn: NSRect(x: x - 0.8, y: inner.maxY - 1.7,
                                            width: 1.6, height: 1.6)).fill()
            }
        }

        // Charging shows as a bolt cut out of the bar (or drawn on the empty
        // track when the level has not reached the middle yet).
        if charging {
            let slot = NSRect(x: inner.midX - 1.0, y: inner.minY + 0.1,
                              width: 2.0, height: max(barHeight - 0.2, 1.6))
            let bolt = boltPath(in: slot)
            if bar.maxX >= slot.maxX {
                knockout(bolt)
            } else {
                bolt.fill()
            }
        }

        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private static func ear(apex: Double, from: Double, to: Double) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: from, y: body.maxY - 1.8))
        path.line(to: NSPoint(x: apex, y: 14.2))
        path.line(to: NSPoint(x: to, y: body.maxY - 1.8))
        path.close()
        return path
    }

    /// Removes a shape from what has been drawn so far, so it reads as a hole.
    private static func knockout(_ path: NSBezierPath) {
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        path.fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
    }

    /// A lightning bolt inscribed in the given rectangle.
    private static func boltPath(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        func point(_ x: Double, _ y: Double) -> NSPoint {
            NSPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        path.move(to: point(0.72, 1.0))
        path.line(to: point(0.06, 0.46))
        path.line(to: point(0.44, 0.46))
        path.line(to: point(0.28, 0.0))
        path.line(to: point(0.94, 0.54))
        path.line(to: point(0.56, 0.54))
        path.close()
        return path
    }
}
