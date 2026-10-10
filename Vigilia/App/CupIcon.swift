import AppKit

/// Dibuja el ícono de la barra de menú: una taza y, durante la animación, vapor que sube.
/// Las imágenes son plantillas (template), así que el sistema las tiñe en modo claro y oscuro.
nonisolated enum CupIcon {
    static let size = NSSize(width: 18, height: 18)

    /// - Parameters:
    ///   - active: taza rellena (sesión activa) o solo contorno.
    ///   - steam: fotograma del vapor, o `nil` para no dibujarlo.
    static func image(active: Bool, steam: SteamFrame?) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            drawCup(active: active)
            if let steam {
                drawSteam(steam)
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Vigilia"
        return image
    }

    // MARK: - Taza

    /// Zona de la taza: la parte baja del ícono, dejando arriba sitio para el vapor.
    private static let cupRect = NSRect(x: 0, y: 0, width: 18, height: 11.5)

    private static func drawCup(active: Bool) {
        let name = active ? "cup.and.saucer.fill" : "cup.and.saucer"
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        else { return }

        // Ajusta el símbolo a la zona de la taza conservando su proporción, centrado abajo.
        let scale = min(cupRect.width / symbol.size.width, cupRect.height / symbol.size.height)
        let drawSize = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
        let origin = NSPoint(x: cupRect.midX - drawSize.width / 2, y: cupRect.minY)
        symbol.draw(in: NSRect(origin: origin, size: drawSize))
    }

    // MARK: - Vapor

    /// Posición horizontal de cada voluta, sobre el cuerpo de la taza (el asa queda a la derecha).
    private static let wispXs: [CGFloat] = [5.5, 8.5, 11.5]
    private static let wispBaseY: CGFloat = 10
    private static let wispHeight: CGFloat = 5
    private static let wispRise: CGFloat = 3

    private static func drawSteam(_ frame: SteamFrame) {
        for (index, x) in wispXs.enumerated() {
            // Cada voluta va desfasada para que no suban todas a la vez.
            let progress = (frame.phase + Double(index) / Double(wispXs.count))
                .truncatingRemainder(dividingBy: 1)
            // Aparece y se desvanece a lo largo de su subida.
            let alpha = sin(progress * .pi) * frame.intensity
            guard alpha > 0.01 else { continue }

            let y = wispBaseY + CGFloat(progress) * wispRise
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: y))
            path.curve(
                to: NSPoint(x: x, y: y + wispHeight),
                controlPoint1: NSPoint(x: x - 1.6, y: y + wispHeight * 0.35),
                controlPoint2: NSPoint(x: x + 1.6, y: y + wispHeight * 0.65)
            )
            path.lineWidth = 1.3
            path.lineCapStyle = .round
            NSColor.black.withAlphaComponent(alpha).setStroke()
            path.stroke()
        }
    }
}

/// Un fotograma de la animación del vapor.
nonisolated struct SteamFrame: Equatable, Sendable {
    /// Posición dentro del ciclo de subida, de 0 a 1 (se repite).
    var phase: Double
    /// Opacidad general, de 0 a 1, para que el vapor aparezca y se vaya suavemente.
    var intensity: Double
}
