import XCTest
@testable import WordPop

final class SentenceContextTests: XCTestCase {
    func testPicksTheSentenceThatContainsTheSelection() {
        let text = "The jury came back. The room fell quiet after the verdict. Then the judge spoke."
        let range = (text as NSString).range(of: "quiet")
        XCTAssertEqual(TextCapture.sentence(in: text, containing: range), "The room fell quiet after the verdict.")
    }
}

final class PartOfSpeechInContextTests: XCTestCase {
    func testTagsTheWordInItsSentence() {
        XCTAssertEqual(TextCapture.partOfSpeech(of: "ran", in: "She ran across the road."), "verb")
        XCTAssertEqual(TextCapture.partOfSpeech(of: "run", in: "We went for a run before work."), "noun")
        XCTAssertEqual(TextCapture.partOfSpeech(of: "quiet", in: "The room fell quiet after the verdict."), "adjective")
    }
}
