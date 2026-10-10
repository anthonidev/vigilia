import AppKit

/// Estilo del ícono de la barra de menú, elegible en Ajustes.
nonisolated enum IconStyle: String, CaseIterable, Identifiable, Sendable {
    case mug
    case flame
    case lightbulb

    var id: Self { self }

    var title: String {
        switch self {
        case .mug: "Taza"
        case .flame: "Llama"
        case .lightbulb: "Foco"
        }
    }

    /// Símbolo de SF Symbols: contorno si está inactiva, relleno si está activa.
    func symbol(active: Bool) -> String {
        switch self {
        case .mug: active ? "mug.fill" : "mug"
        case .flame: active ? "flame.fill" : "flame"
        case .lightbulb: active ? "lightbulb.fill" : "lightbulb"
        }
    }
}

/// Un fotograma de la animación de activación.
nonisolated struct IconAnimationFrame: Equatable, Sendable {
    /// Posición dentro del ciclo, de 0 a 1 (se repite).
    var phase: Double
    /// Opacidad general, de 0 a 1, para que el efecto aparezca y se vaya suavemente.
    var intensity: Double
}

/// Dibuja el ícono de la barra de menú y su animación:
/// - Taza: vapor que sube.
/// - Llama: la llama titila y suelta chispas.
/// - Foco: rayos de luz que laten alrededor.
///
/// Las imágenes son plantillas (template), así que el sistema las tiñe en modo claro y oscuro.
nonisolated enum MenuBarIconRenderer {
    /// Más alto que ancho: el símbolo ocupa casi toda la altura de la barra y el efecto sale por encima.
    static let size = NSSize(width: 18, height: 22)

    static func image(style: IconStyle, active: Bool, frame: IconAnimationFrame?) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            switch style {
            case .mug:
                let cup = drawSymbol(style.symbol(active: active), in: NSRect(x: 0, y: 2, width: 18, height: 14.5))
                if let frame { drawSteam(frame, above: cup) }
            case .flame:
                drawFlame(active: active, frame: frame)
            case .lightbulb:
                let bulb = drawSymbol(style.symbol(active: active), in: NSRect(x: 2, y: 1, width: 14, height: 14))
                if let frame { drawRays(frame, around: bulb) }
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Vigilia"
        return image
    }

    // MARK: - Símbolos

    private static func symbolImage(_ name: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
    }

    /// Rectángulo del símbolo ajustado a `area`, conservando la proporción y centrado abajo.
    private static func fittedRect(for name: String, in area: NSRect) -> NSRect {
        guard let symbol = symbolImage(name) else { return area }
        let scale = min(area.width / symbol.size.width, area.height / symbol.size.height)
        let size = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
        return NSRect(origin: NSPoint(x: area.midX - size.width / 2, y: area.minY), size: size)
    }

    /// Dibuja un símbolo ajustado a `area` y devuelve dónde quedó.
    @discardableResult
    private static func drawSymbol(_ name: String, in area: NSRect) -> NSRect {
        let rect = fittedRect(for: name, in: area)
        symbolImage(name)?.draw(in: rect)
        return rect
    }

    private static func stroke(_ path: NSBezierPath, alpha: Double, width: CGFloat) {
        path.lineWidth = width
        path.lineCapStyle = .round
        NSColor.black.withAlphaComponent(alpha).setStroke()
        path.stroke()
    }

    /// Cada elemento va desfasado para que no se muevan todos a la vez. Devuelve su avance (0…1)
    /// y una opacidad que sube y baja a lo largo del ciclo.
    private static func staggered(_ frame: IconAnimationFrame, index: Int, of count: Int) -> (progress: Double, alpha: Double) {
        let progress = (frame.phase + Double(index) / Double(count)).truncatingRemainder(dividingBy: 1)
        return (progress, sin(progress * .pi) * frame.intensity)
    }

    // MARK: - Taza: vapor

    private static func drawSteam(_ frame: IconAnimationFrame, above cup: NSRect) {
        // El cuerpo de la taza ocupa el ~70 % izquierdo; el asa, el resto.
        let bodyCenter = cup.minX + cup.width * 0.38
        let xs: [CGFloat] = [bodyCenter - 3, bodyCenter, bodyCenter + 3]
        let height: CGFloat = 3.5
        let sway: CGFloat = 1

        for (index, x) in xs.enumerated() {
            let (progress, alpha) = staggered(frame, index: index, of: xs.count)
            guard alpha > 0.01 else { continue }

            let y = cup.maxY + 0.5 + CGFloat(progress) * 1.5
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: y))
            path.curve(
                to: NSPoint(x: x, y: y + height),
                controlPoint1: NSPoint(x: x - sway, y: y + height * 0.35),
                controlPoint2: NSPoint(x: x + sway, y: y + height * 0.65)
            )
            stroke(path, alpha: alpha, width: 1.3)
        }
    }

    // MARK: - Llama: titileo y chispas

    private static func drawFlame(active: Bool, frame: IconAnimationFrame?) {
        let area = NSRect(x: 1, y: 1, width: 16, height: 16)
        guard let frame else {
            drawSymbol(IconStyle.flame.symbol(active: active), in: area)
            return
        }

        // Titileo: la llama se estira y encoge desde la base, con dos ritmos mezclados, y se mece
        // un poco. Se dibuja directamente en el rectángulo deformado (sin transformaciones) para
        // que el símbolo siga siendo vectorial y nítido.
        let t = frame.phase * 2 * .pi
        let flicker = CGFloat((0.07 * sin(t * 2) + 0.04 * sin(t * 5 + 1)) * frame.intensity)
        let sway = CGFloat(0.6 * sin(t * 3) * frame.intensity)

        let base = fittedRect(for: IconStyle.flame.symbol(active: active), in: area)
        let width = base.width * (1 - flicker * 0.5)
        let height = base.height * (1 + flicker)
        let flame = NSRect(x: base.midX - width / 2 + sway, y: base.minY, width: width, height: height)
        symbolImage(IconStyle.flame.symbol(active: active))?.draw(in: flame)

        // Chispas que suben desde la punta.
        let top = flame.maxY
        let xs: [CGFloat] = [area.midX - 2.5, area.midX + 0.5, area.midX + 3]
        for (index, x) in xs.enumerated() {
            let (progress, alpha) = staggered(frame, index: index, of: xs.count)
            guard alpha > 0.01 else { continue }

            let radius: CGFloat = 0.9 * (1 - CGFloat(progress) * 0.4)
            let center = NSPoint(
                x: x + sin(progress * .pi * 2 + Double(index)) * 0.8,
                y: top - 1 + CGFloat(progress) * 5
            )
            NSColor.black.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
        }
    }

    // MARK: - Foco: rayos de luz

    private static func drawRays(_ frame: IconAnimationFrame, around bulb: NSRect) {
        // Centro del cristal: la parte alta del foco (abajo está la rosca).
        let center = NSPoint(x: bulb.midX, y: bulb.minY + bulb.height * 0.62)
        let glassRadius = bulb.width * 0.5
        let angles: [Double] = [-70, -35, 0, 35, 70]

        for (index, degrees) in angles.enumerated() {
            // Los rayos laten en ondas desde el centro hacia los lados.
            let distance = abs(Double(index) - 2) / Double(angles.count)
            let pulse = (sin((frame.phase - distance) * 2 * .pi) + 1) / 2
            let alpha = (0.35 + 0.65 * pulse) * frame.intensity
            guard alpha > 0.01 else { continue }

            let radians = (90 - degrees) * .pi / 180
            let direction = CGVector(dx: cos(radians), dy: sin(radians))
            let start = glassRadius + 1.2
            let length = 1.6 + 1.2 * CGFloat(pulse)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: center.x + direction.dx * start, y: center.y + direction.dy * start))
            path.line(to: NSPoint(
                x: center.x + direction.dx * (start + length),
                y: center.y + direction.dy * (start + length)
            ))
            stroke(path, alpha: alpha, width: 1.2)
        }
    }
}
