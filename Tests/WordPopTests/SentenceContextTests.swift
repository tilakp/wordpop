import XCTest
@testable import WordPop

final class SentenceContextTests: XCTestCase {
    func testPicksTheSentenceThatContainsTheSelection() {
        let text = "The jury came back. The room fell quiet after the verdict. Then the judge spoke."
        let range = (text as NSString).range(of: "quiet")
        XCTAssertEqual(TextCapture.sentence(in: text, containing: range), "The room fell quiet after the verdict.")
    }
}
