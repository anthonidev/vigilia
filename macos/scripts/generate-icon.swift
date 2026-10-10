// Genera el ícono de la app: una taza con vapor sobre un cielo nocturno.
//
// Desde la carpeta macos/:
//
//     swift scripts/generate-icon.swift Vigilia/Assets.xcassets/AppIcon.appiconset
import AppKit

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
let canvas: CGFloat = 1024

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let cream = color(0xF7E9D7)

func drawIcon() {
    // Forma estándar de los íconos de macOS: 824 pt centrados, esquinas de 185 pt.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    // Sombra suave bajo el ícono.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    color(0x1B2350).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Cielo nocturno: de azul profundo a violeta.
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [color(0x3A2F78), color(0x1B2350), color(0x101633)])!
        .draw(in: body, angle: -90)

    // Unas pocas estrellas.
    let stars: [(CGFloat, CGFloat, CGFloat)] = [
        (230, 800, 7), (330, 720, 4), (760, 820, 6), (820, 690, 4), (690, 760, 3), (190, 640, 3),
    ]
    for (x, y, r) in stars {
        cream.withAlphaComponent(0.8).setFill()
        NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2)).fill()
    }
    NSGraphicsContext.restoreGraphicsState()

    // Taza (símbolo del sistema, teñido de crema).
    let config = NSImage.SymbolConfiguration(pointSize: 400, weight: .semibold)
    let symbol = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(config)!
    let scale = 560 / symbol.size.width
    let cupSize = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
    let cupRect = NSRect(x: (canvas - cupSize.width) / 2, y: 190, width: cupSize.width, height: cupSize.height)
    let tinted = NSImage(size: cupSize, flipped: false) { rect in
        symbol.draw(in: rect)
        cream.set()
        rect.fill(using: .sourceAtop)
        return true
    }
    tinted.draw(in: cupRect)

    // Vapor: tres volutas sobre el cuerpo de la taza (el asa queda a la derecha).
    let steamBase = cupRect.maxY + 30
    for (index, x) in [CGFloat(400), 480, 560].enumerated() {
        let height: CGFloat = index == 1 ? 190 : 150
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x, y: steamBase))
        path.curve(
            to: NSPoint(x: x, y: steamBase + height),
            controlPoint1: NSPoint(x: x - 45, y: steamBase + height * 0.35),
            controlPoint2: NSPoint(x: x + 45, y: steamBase + height * 0.65)
        )
        path.lineWidth = 26
        path.lineCapStyle = .round
        cream.withAlphaComponent(index == 1 ? 0.95 : 0.7).setStroke()
        path.stroke()
    }
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: canvas, height: canvas)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Tamaños que pide macOS: 16, 32, 128, 256 y 512 pt, en @1x y @2x.
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try! render(pixels: points * scale).write(to: outputDirectory.appending(path: filename))
        images.append([
            "filename": filename,
            "idiom": "mac",
            "scale": "\(scale)x",
            "size": "\(points)x\(points)",
        ])
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: outputDirectory.appending(path: "Contents.json"))
print("Ícono generado en \(outputDirectory.path)")
