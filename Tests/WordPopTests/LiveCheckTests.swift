import XCTest
@testable import WordPop

final class LiveCheckTests: XCTestCase {
    func testOnePatternFindsTheLongestPhrases() throws {
        let phrases = Database.phraseFlags.map { $0.phrase.lowercased() }
        let start = Date()
        let pattern = try XCTUnwrap(LiveCheck.pattern(for: phrases))
        let text = "In order to finish the report, we need to make a decision at this point in time. At the end of the day, the team will utilize the new tool. "
        let found = pattern.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
            .map { (text as NSString).substring(with: $0.range).lowercased() }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(found.contains("in order to"))
        XCTAssertTrue(found.contains("at this point in time"), "the longest phrase, not a part of it: \(found)")
        XCTAssertTrue(found.contains("at the end of the day"))
        XCTAssertTrue(found.contains("make a decision"))
        XCTAssertTrue(found.contains("utilize"))
        XCTAssertLessThan(elapsed, 0.5, "built and run in \(elapsed) s for \(phrases.count) phrases")
    }

    func testHintText() {
        XCTAssertEqual(LiveCheck.hintText(for: PhraseFlag(phrase: "in order to", fix: "to", isCliche: false)), "Wordy: in order to \u{2192} to")
        XCTAssertEqual(LiveCheck.hintText(for: PhraseFlag(phrase: "make a decision", fix: "decide", isCliche: false, isHiddenVerb: true)),
                       "Hidden verb: make a decision \u{2192} decide")
    }
}
