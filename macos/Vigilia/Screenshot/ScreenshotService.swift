import AppKit
import CoreGraphics
import Observation
import ScreenCaptureKit

nonisolated struct DisplayInfo: Equatable, Sendable {
    let id: CGDirectDisplayID
    /// Nombre del monitor, por ejemplo "DELL U2723QE" o "Pantalla integrada".
    let name: String
}

nonisolated enum ScreenshotError: Error, Equatable {
    case displayNotFound
    case encodingFailed
}

/// Lo que el bot necesita para hacer capturas. Permite usar uno falso en los tests.
protocol ScreenCapturing: AnyObject {
    var hasPermission: Bool { get }
    func requestPermission()
    func displays() async throws -> [DisplayInfo]
    func capture(_ displayID: CGDirectDisplayID) async throws -> CGImage
}

/// Capturas de pantalla con ScreenCaptureKit. Requiere el permiso de Grabación de pantalla.
@Observable
final class ScreenshotService: ScreenCapturing {
    private(set) var hasPermission = CGPreflightScreenCaptureAccess()

    /// Vuelve a consultar el permiso (por ejemplo, al abrir Ajustes).
    func refreshPermission() {
        hasPermission = CGPreflightScreenCaptureAccess()
    }

    /// Muestra la solicitud del sistema la primera vez; después no hace nada.
    func requestPermission() {
        hasPermission = CGRequestScreenCaptureAccess()
    }

    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    /// Pantallas conectadas, con la principal primero.
    func displays() async throws -> [DisplayInfo] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let available = Set(content.displays.map(\.displayID))

        return NSScreen.screens.compactMap { screen in
            guard let id = screen.displayID, available.contains(id) else { return nil }
            return DisplayInfo(id: id, name: screen.localizedName)
        }
    }

    /// Captura una pantalla a su resolución nativa (Retina incluida), con el cursor.
    func capture(_ displayID: CGDirectDisplayID) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenshotError.displayNotFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        configuration.width = Int(filter.contentRect.width * scale)
        configuration.height = Int(filter.contentRect.height * scale)
        configuration.showsCursor = true

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
