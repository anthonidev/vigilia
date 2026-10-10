import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Vigilia

struct ScreenshotRequestTests {
    @Test(arguments: [
        ScreenshotRequest(target: .all, hd: false),
        ScreenshotRequest(target: .all, hd: true),
        ScreenshotRequest(target: .display(4_294_967_295), hd: true),
    ])
    func callbackDataRoundTrips(request: ScreenshotRequest) {
        #expect(ScreenshotRequest(callbackData: request.callbackData) == request)
        #expect(request.callbackData.utf8.count <= 64, "Telegram limita callback_data a 64 bytes")
    }
}

struct ScreenshotEncoderTests {
    @Test func normalIsScaledAndCompressed() async throws {
        // Un monitor 6K: 6016 × 3384.
        let data = try await ScreenshotEncoder.normal(TestImages.solid(width: 6016, height: 3384))
        let size = try #require(pixelSize(of: data))

        #expect(max(size.width, size.height) == 2560)
        #expect(size.width + size.height <= 10_000)
        #expect(data.count < 10_000_000)
        #expect(data.starts(with: [0xFF, 0xD8]), "JPEG")
    }

    @Test func smallImagesAreNotUpscaled() throws {
        let image = TestImages.solid(width: 800, height: 600)
        #expect(try ScreenshotEncoder.scale(image, maxSide: 2560).width == 800)
    }

    @Test func hdKeepsFullResolutionAsPNG() async throws {
        let data = try await ScreenshotEncoder.hd(TestImages.solid(width: 3024, height: 1964))
        let size = try #require(pixelSize(of: data))

        #expect(size.width == 3024 && size.height == 1964)
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]), "PNG")
    }

    private func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return (image.width, image.height)
    }
}

struct MultipartFormDataTests {
    @Test func buildsFieldsAndFiles() {
        var form = MultipartFormData(boundary: "XYZ")
        form.append(field: "chat_id", value: "42")
        form.append(file: "photo", filename: "a.jpg", mimeType: "image/jpeg", data: Data("JPEG".utf8))

        let expected = """
            --XYZ\r
            Content-Disposition: form-data; name="chat_id"\r
            \r
            42\r
            --XYZ\r
            Content-Disposition: form-data; name="photo"; filename="a.jpg"\r
            Content-Type: image/jpeg\r
            \r
            JPEG\r
            --XYZ--\r

            """
        #expect(String(decoding: form.data, as: UTF8.self) == expected)
        #expect(form.contentType == "multipart/form-data; boundary=XYZ")
    }
}

@MainActor
struct ScreenshotSenderTests {
    let capturer = FakeCapturer()
    let client = FakeTelegramClient()
    var sender: ScreenshotSender { ScreenshotSender(capturer: capturer) }

    @Test func withoutPermissionAsksForItAndExplains() async {
        capturer.hasPermission = false
        await sender.handle(ScreenshotRequest(), chatID: 42, client: client)

        #expect(capturer.permissionRequested)
        #expect(await client.sent.first?.text == ScreenshotText.noPermission)
        #expect(await client.uploads.isEmpty)
    }

    @Test func singleDisplaySendsPhotoDirectly() async {
        await sender.handle(ScreenshotRequest(), chatID: 42, client: client)

        let upload = await client.uploads.first
        #expect(upload?.kind == .photo)
        #expect(upload?.caption?.hasPrefix("Pantalla integrada · ") == true)
        #expect(await client.chatActions == ["upload_photo"])
    }

    @Test func hdSendsPNGDocument() async {
        await sender.handle(ScreenshotRequest(hd: true), chatID: 42, client: client)

        let upload = await client.uploads.first
        #expect(upload?.kind == .document)
        #expect(upload?.filename.wholeMatch(of: /vigilia-\d{4}-\d{2}-\d{2}-\d{4}\.png/) != nil)
        #expect(upload?.mimeType == "image/png")
    }

    @Test func multipleDisplaysAskWhichOne() async {
        capturer.screens = [DisplayInfo(id: 1, name: "Pantalla integrada"), DisplayInfo(id: 7, name: "DELL U2723QE")]
        await sender.handle(ScreenshotRequest(), chatID: 42, client: client)

        let message = await client.sent.first
        #expect(message?.text == "¿Qué pantalla?")
        let buttons = message?.keyboard?.inlineKeyboard.flatMap { $0 }.map(\.text)
        #expect(buttons == ["Pantalla integrada", "DELL U2723QE", "Todas"])
        #expect(capturer.captured.isEmpty)
    }

    @Test func chosenDisplayAndAll() async {
        capturer.screens = [DisplayInfo(id: 1, name: "Pantalla integrada"), DisplayInfo(id: 7, name: "DELL U2723QE")]

        await sender.handle(ScreenshotRequest(target: .display(7)), chatID: 42, client: client)
        #expect(capturer.captured == [7])
        #expect(await client.uploads.first?.caption?.hasPrefix("DELL U2723QE") == true)

        await sender.handle(ScreenshotRequest(target: .all, hd: true), chatID: 42, client: client)
        let album = await client.albums.first
        #expect(album?.count == 2)
        #expect(album?.allSatisfy { $0.kind == .document } == true)
        #expect(Set(album?.map(\.filename) ?? []).count == 2, "Cada archivo con su nombre")
    }

    @Test func disconnectedDisplay() async {
        await sender.handle(ScreenshotRequest(target: .display(99)), chatID: 42, client: client)
        #expect(await client.sent.first?.text == ScreenshotText.displayGone)
    }

    @Test func filenameUsesLocalTime() {
        var components = DateComponents(year: 2026, month: 10, day: 9, hour: 14, minute: 32)
        components.calendar = .current
        #expect(ScreenshotSender.filenameStem(for: components.date!) == "vigilia-2026-10-09-1432")
    }
}
