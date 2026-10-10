import Foundation

/// Textos de duración en español: "10 min", "1 h", "1 h 30 min".
nonisolated enum DurationText {
    static func label(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest) min"
        case (_, 0): return "\(hours) h"
        default: return "\(hours) h \(rest) min"
        }
    }

    /// Tiempo restante redondeado hacia arriba al minuto, para no mostrar "0 min" mientras quedan segundos.
    static func remaining(_ interval: TimeInterval) -> String {
        label(minutes: max(1, Int((interval / 60).rounded(.up))))
    }
}
