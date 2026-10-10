import Testing
@testable import Vigilia

struct DurationTextTests {
    @Test(arguments: [
        (10, "10 min"),
        (60, "1 h"),
        (90, "1 h 30 min"),
        (720, "12 h"),
    ])
    func label(minutes: Int, expected: String) {
        #expect(DurationText.label(minutes: minutes) == expected)
    }

    @Test func remainingRoundsUpToTheMinute() {
        #expect(DurationText.remaining(30) == "1 min")
        #expect(DurationText.remaining(61) == "2 min")
        #expect(DurationText.remaining(83 * 60) == "1 h 23 min")
    }
}
