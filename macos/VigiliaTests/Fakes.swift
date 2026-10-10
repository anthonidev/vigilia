import Foundation
@testable import Vigilia

final class FakeTimeSource: TimeSource {
    var now: Date

    init(now: Date = Date(timeIntervalSinceReferenceDate: 0)) {
        self.now = now
    }

    func advance(minutes: Double) {
        now = now.addingTimeInterval(minutes * 60)
    }
}

final class FakePowerAssertion: PowerAsserting {
    private(set) var isHeld = false
    private(set) var acquireCount = 0

    func acquire() {
        if !isHeld { acquireCount += 1 }
        isHeld = true
    }

    func release() {
        isHeld = false
    }
}

/// Minutos como `TimeInterval`. Dentro de `#expect`, un literal como `15 * 60` se infiere como `Int`.
func minutes(_ value: TimeInterval) -> TimeInterval {
    value * 60
}
