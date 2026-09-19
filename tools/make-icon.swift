import AppKit

/// Renders Batty's app icon at every size macOS asks for, into an .iconset
/// directory that build.sh hands to iconutil.
@main
struct MakeIcon {
    static func main() {
        let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Batty.iconset"
        try? FileManager.default.createDirectory(
            atPath: output, withIntermediateDirectories: true)

        // (point size, scale) pairs required by the .iconset format.
        let variants: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1),
                                      (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
        for (points, scale) in variants {
            let pixels = points * scale
            let name = scale == 1 ? "icon_\(points)x\(points).png"
                                  : "icon_\(points)x\(points)@2x.png"
            write(render(size: pixels), to: "\(output)/\(name)")
        }
        print("wrote \(output)")
    }

    static func render(size: Int) -> NSBitmapImageRep {
        let side = CGFloat(size)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        // Squircle-ish rounded background with a warm dusk gradient.
        let margin = side * 0.08
        let plate = NSRect(x: margin, y: margin, width: side - margin * 2, height: side - margin * 2)
        let shape = NSBezierPath(roundedRect: plate,
                                 xRadius: plate.width * 0.23, yRadius: plate.width * 0.23)
        NSGradient(colors: [NSColor(srgbRed: 0.36, green: 0.29, blue: 0.78, alpha: 1),
                            NSColor(srgbRed: 0.16, green: 0.13, blue: 0.36, alpha: 1)])?
            .draw(in: shape, angle: -90)

        // The bat-battery glyph, rendered separately in white and composited on
        // top so its knocked-out eyes do not cut into the background.
        let glyph = NSSize(width: plate.width * 0.74, height: plate.width * 0.74 * 16 / 22)
        BattyIcon.image(level: 72, charging: true, size: glyph, color: .white)
            .draw(in: NSRect(x: plate.midX - glyph.width / 2,
                             y: plate.midY - glyph.height / 2,
                             width: glyph.width, height: glyph.height))

        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    static func write(_ rep: NSBitmapImageRep, to path: String) {
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }
}
