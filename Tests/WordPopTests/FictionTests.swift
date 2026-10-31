import XCTest
@testable import WordPop

final class FictionTests: XCTestCase {
    func testFindsTagsFilterWordsAndEmotionsTold() {
        let text = """
            "Leave now," she said angrily. He felt nervous and saw the door open. \u{201C}I know,\u{201D} he hissed. \
            "Fine," she hissed. A wave of panic rose as she realized the truth. "Why?" he asked.
            """
        let notes = FictionNotes.check(text)
        XCTAssertEqual(notes.tagAdverbs, ["said angrily"])
        XCTAssertEqual(notes.showyTags, [FictionNotes.Count(word: "hissed", count: 2)])
        XCTAssertEqual(Set(notes.filterWords.map(\.word)), ["saw", "felt", "realized"])
        XCTAssertEqual(notes.emotionTells, ["felt nervous", "a wave of panic"])
        XCTAssertNotNil(notes.dialogueShare)
        XCTAssertLessThan(notes.dialogueShare ?? 1, 0.5)
    }

    func testPlainProseHasNoDialogue() {
        let notes = FictionNotes.check("The report is due on Friday. Please send it early.")
        XCTAssertTrue(notes.isEmpty)
    }
}
