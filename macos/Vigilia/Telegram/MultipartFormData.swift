import Foundation

/// Cuerpo `multipart/form-data` para subir archivos a la Bot API.
nonisolated struct MultipartFormData: Sendable {
    let boundary: String
    private var body = Data()

    init(boundary: String = "Vigilia-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    mutating func append(field name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func append(file name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        append("\r\n")
    }

    /// El cuerpo completo, con el separador de cierre.
    var data: Data {
        body + Data("--\(boundary)--\r\n".utf8)
    }

    private mutating func append(_ string: String) {
        body.append(Data(string.utf8))
    }
}

/// Un archivo para subir: foto (comprimida por Telegram) o documento (se envía tal cual).
nonisolated struct TelegramUpload: Equatable, Sendable {
    nonisolated enum Kind: String, Sendable {
        case photo
        case document
    }

    let kind: Kind
    let data: Data
    let filename: String
    let caption: String?

    var mimeType: String {
        filename.hasSuffix(".png") ? "image/png" : "image/jpeg"
    }
}
