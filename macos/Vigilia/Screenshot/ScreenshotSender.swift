import CoreGraphics
import Foundation
import os

/// Responde a `/captura`: comprueba el permiso, elige la pantalla, captura y envía.
final class ScreenshotSender {
    private let capturer: any ScreenCapturing
    private let timeSource: TimeSource

    private static let logger = Logger(subsystem: "com.tonis.vigilia", category: "screenshot")
    /// Telegram admite como mucho 10 elementos por álbum.
    private static let maxAlbumSize = 10

    init(capturer: any ScreenCapturing, timeSource: TimeSource = SystemTimeSource()) {
        self.capturer = capturer
        self.timeSource = timeSource
    }

    func handle(_ request: ScreenshotRequest, chatID: Int64, client: any TelegramClient) async {
        guard capturer.hasPermission else {
            // Muestra la solicitud del sistema en la Mac (solo la primera vez).
            capturer.requestPermission()
            _ = try? await client.sendMessage(chatID: chatID, text: ScreenshotText.noPermission, keyboard: nil)
            return
        }

        do {
            let displays = try await capturer.displays()
            let selected: [DisplayInfo]

            switch request.target {
            case nil where displays.count > 1:
                try await client.sendMessage(
                    chatID: chatID,
                    text: request.hd ? "¿Qué pantalla? (HD)" : "¿Qué pantalla?",
                    keyboard: Self.chooser(for: displays, hd: request.hd)
                )
                return
            case nil, .all:
                selected = displays
            case .display(let id):
                guard let display = displays.first(where: { $0.id == id }) else {
                    try await client.sendMessage(chatID: chatID, text: ScreenshotText.displayGone, keyboard: nil)
                    return
                }
                selected = [display]
            }

            guard !selected.isEmpty else { throw ScreenshotError.displayNotFound }
            try? await client.sendChatAction(request.hd ? "upload_document" : "upload_photo", chatID: chatID)

            let uploads = try await capture(Array(selected.prefix(Self.maxAlbumSize)), hd: request.hd)
            if uploads.count == 1 {
                try await client.send(uploads[0], chatID: chatID)
            } else {
                try await client.sendMediaGroup(uploads, chatID: chatID)
            }
        } catch {
            Self.logger.error("No se pudo enviar la captura: \(String(describing: error), privacy: .public)")
            _ = try? await client.sendMessage(chatID: chatID, text: ScreenshotText.failed, keyboard: nil)
        }
    }

    private func capture(_ displays: [DisplayInfo], hd: Bool) async throws -> [TelegramUpload] {
        let now = timeSource.now
        let time = now.formatted(date: .omitted, time: .shortened)
        var uploads: [TelegramUpload] = []

        for (index, display) in displays.enumerated() {
            let image = try await capturer.capture(display.id)
            let caption = "\(display.name) · \(time)"
            if hd {
                let suffix = displays.count > 1 ? "-\(index + 1)" : ""
                uploads.append(TelegramUpload(
                    kind: .document,
                    data: try await ScreenshotEncoder.hd(image),
                    filename: "\(Self.filenameStem(for: now))\(suffix).png",
                    caption: caption
                ))
            } else {
                uploads.append(TelegramUpload(
                    kind: .photo,
                    data: try await ScreenshotEncoder.normal(image),
                    filename: "captura-\(index + 1).jpg",
                    caption: caption
                ))
            }
        }
        return uploads
    }

    /// "vigilia-2026-10-09-1432", en la hora local.
    nonisolated static func filenameStem(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(
            format: "vigilia-%04d-%02d-%02d-%02d%02d",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0
        )
    }

    /// Un botón por pantalla, con su nombre, y "Todas" al final.
    nonisolated static func chooser(for displays: [DisplayInfo], hd: Bool) -> InlineKeyboardMarkup {
        let rows = displays.map { display in
            [InlineKeyboardButton(
                text: display.name,
                callbackData: ScreenshotRequest(target: .display(display.id), hd: hd).callbackData
            )]
        }
        let all = [InlineKeyboardButton(
            text: "Todas",
            callbackData: ScreenshotRequest(target: .all, hd: hd).callbackData
        )]
        return InlineKeyboardMarkup(inlineKeyboard: rows + [all])
    }
}

nonisolated enum ScreenshotText {
    static let noPermission = """
        🔒 Falta el permiso de Grabación de pantalla.
        Dalo en la Mac: Ajustes del Sistema → Privacidad y seguridad → Grabación de pantalla y audio del sistema → Vigilia.
        """
    static let displayGone = "Esa pantalla ya no está conectada. Vuelve a pedir la /captura."
    static let failed = "No se pudo hacer la captura. Inténtalo de nuevo."
}
