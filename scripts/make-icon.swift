// Draws the KeyCrib icon (a keycap with "{ }" and an Option legend) and writes
// assets/logo.png (1024 px) and assets/AppIcon.icns.  Run: swift scripts/make-icon.swift
import AppKit

let size: CGFloat = 1024
func draw() -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let c = { (h: UInt32) in NSColor(srgbRed: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: 1) }

    // Background tile (macOS icon grid: 824 px body, centred, with a soft shadow).
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 24; shadow.shadowOffset = NSSize(width: 0, height: -10); shadow.set()
    c(0x0B5F78).setFill(); bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: c(0x1A9DBF), ending: c(0x0A5269))!.draw(in: bodyPath, angle: -90)

    // Keycap: darker base, lighter top face.
    let base = NSRect(x: 232, y: 214, width: 560, height: 560)
    c(0x9FB3C2).setFill(); NSBezierPath(roundedRect: base, xRadius: 96, yRadius: 96).fill()
    let face = NSRect(x: 232, y: 262, width: 560, height: 512)
    NSGradient(starting: c(0xFFFFFF), ending: c(0xE3EAF0))!.draw(in: NSBezierPath(roundedRect: face, xRadius: 96, yRadius: 96), angle: -90)

    func text(_ s: String, _ font: NSFont, _ color: NSColor, center: NSPoint) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let sz = (s as NSString).size(withAttributes: attrs)
        (s as NSString).draw(at: NSPoint(x: center.x - sz.width / 2, y: center.y - sz.height / 2), withAttributes: attrs)
    }
    text("{}", NSFont.monospacedSystemFont(ofSize: 280, weight: .bold), c(0x17202A), center: NSPoint(x: 512, y: 490))
    text("⌥", NSFont.systemFont(ofSize: 110, weight: .semibold), c(0x0B6E8A), center: NSPoint(x: 330, y: 680))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let png = draw().representation(using: .png, properties: [:])!
let logo = root.appendingPathComponent("assets/logo.png")
try! png.write(to: logo)

// Iconset -> icns
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("KeyCrib.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for s in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = s * scale
        let name = scale == 1 ? "icon_\(s)x\(s).png" : "icon_\(s)x\(s)@2x.png"
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        p.arguments = ["-z", "\(px)", "\(px)", logo.path, "--out", iconset.appendingPathComponent(name).path]
        p.standardOutput = FileHandle.nullDevice; try! p.run(); p.waitUntilExit()
    }
}
let ic = Process(); ic.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
ic.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("assets/AppIcon.icns").path]
try! ic.run(); ic.waitUntilExit()
print("wrote assets/logo.png and assets/AppIcon.icns")
