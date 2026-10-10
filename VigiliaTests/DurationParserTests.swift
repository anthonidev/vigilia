import Testing
@testable import Vigilia

struct DurationParserTests {
    @Test(arguments: [
        ("30m", 30), ("30min", 30), ("90", 90), ("2h", 120), ("1h30m", 90), ("1h30", 90),
        ("1.5h", 90), ("1,5h", 90), ("2 h", 120), ("24h", 1440), ("1H", 60),
    ])
    func validFormats(text: String, minutes: Int) {
        #expect(DurationParser.minutes(from: text) == minutes)
    }

    @Test(arguments: ["", "0", "0m", "-5", "25h", "1441", "abc", "1d", "h", "m30"])
    func invalidFormats(text: String) {
        #expect(DurationParser.minutes(from: text) == nil)
    }
}
