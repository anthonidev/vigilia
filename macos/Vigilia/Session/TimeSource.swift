import Foundation

/// Fuente de la hora actual, inyectable para poder controlar el tiempo en los tests.
protocol TimeSource {
    var now: Date { get }
}

struct SystemTimeSource: TimeSource {
    var now: Date { Date() }
}
