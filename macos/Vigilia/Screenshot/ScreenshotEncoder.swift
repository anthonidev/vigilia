import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Convierte capturas en JPEG (calidad normal) o PNG (HD), fuera del hilo principal.
nonisolated enum ScreenshotEncoder {
    /// Lado mayor de la captura normal: legible en el celular y muy por debajo de los límites de Telegram
    /// (10 MB, y ancho + alto ≤ 10 000).
    static let normalMaxSide = 2560
    static let jpegQuality = 0.75

    @concurrent
    static func normal(_ image: CGImage) async throws -> Data {
        let scaled = try scale(image, maxSide: normalMaxSide)
        return try encode(scaled, type: .jpeg, properties: [
            kCGImageDestinationLossyCompressionQuality: jpegQuality,
        ])
    }

    @concurrent
    static func hd(_ image: CGImage) async throws -> Data {
        try encode(image, type: .png, properties: [:])
    }

    /// Reduce la imagen para que su lado mayor no pase de `maxSide`. Si ya es pequeña, la deja igual.
    static func scale(_ image: CGImage, maxSide: Int) throws -> CGImage {
        let longest = max(image.width, image.height)
        guard longest > maxSide else { return image }

        let factor = Double(maxSide) / Double(longest)
        let width = Int((Double(image.width) * factor).rounded())
        let height = Int((Double(image.height) * factor).rounded())

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ScreenshotError.encodingFailed }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let scaled = context.makeImage() else { throw ScreenshotError.encodingFailed }
        return scaled
    }

    private static func encode(_ image: CGImage, type: UTType, properties: [CFString: Any]) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
            throw ScreenshotError.encodingFailed
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ScreenshotError.encodingFailed }
        return data as Data
    }
}
