import XCTest
@testable import WordPop

final class GuidesTests: XCTestCase {
    func testEveryNoteSectionHasAGuide() {
        let titles = [
            "Spelling", "Grammar", "Consistency", "Style rules", "Wordy phrases and clich\u{E9}s", "Sentence rhythm", "Hard sentences",
            "Possible passive voice", "Fiction", "Your crutch words", "Weak words", "Repeated words",
        ]
        for title in titles { XCTAssertNotNil(Guides.text(for: title), title) }
        XCTAssertNil(Guides.text(for: "Tools"))
    }
}
