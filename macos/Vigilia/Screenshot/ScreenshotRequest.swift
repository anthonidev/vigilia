import CoreGraphics

/// Qué capturar y con qué calidad.
nonisolated struct ScreenshotRequest: Equatable, Sendable {
    nonisolated enum Target: Equatable, Sendable {
        case display(CGDirectDisplayID)
        case all
    }

    /// `nil`: si hay una sola pantalla se captura esa; si hay varias, se pregunta.
    var target: Target?
    /// HD: PNG a resolución completa, enviado como documento.
    var hd: Bool

    init(target: Target? = nil, hd: Bool = false) {
        self.target = target
        self.hd = hd
    }

    /// `callback_data` del botón: "shot:<id>:n", "shot:all:hd"…
    var callbackData: String {
        let target = switch target {
        case .display(let id): String(id)
        case .all, nil: "all"
        }
        return "shot:\(target):\(hd ? "hd" : "n")"
    }

    init?(callbackData: String) {
        if callbackData == "shot" {
            self.init()
            return
        }
        guard let match = callbackData.wholeMatch(of: /shot:(all|\d+):(n|hd)/) else { return nil }
        let target: Target
        if match.1 == "all" {
            target = .all
        } else if let id = CGDirectDisplayID(match.1) {
            target = .display(id)
        } else {
            return nil
        }
        self.init(target: target, hd: match.2 == "hd")
    }
}
