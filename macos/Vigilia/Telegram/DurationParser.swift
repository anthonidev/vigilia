import Foundation

/// Convierte "30m", "2h", "1h30m", "1.5h" o "90" (minutos) en minutos.
nonisolated enum DurationParser {
    static let maxMinutes = 24 * 60

    static func minutes(from text: String) -> Int? {
        let input = text.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")

        let minutes: Int?
        if let match = input.wholeMatch(of: /(\d+(?:\.\d+)?)h(?:(\d+)(?:m|min)?)?/) {
            let hours = Double(match.1) ?? 0
            let extra = match.2.flatMap { Int($0) } ?? 0
            minutes = Int((hours * 60).rounded()) + extra
        } else if let match = input.wholeMatch(of: /(\d+)(?:m|min)?/) {
            minutes = Int(match.1)
        } else {
            minutes = nil
        }

        guard let minutes, (1...maxMinutes).contains(minutes) else { return nil }
        return minutes
    }
}
