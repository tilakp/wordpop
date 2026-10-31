import XCTest
@testable import WordPop

final class NotesReportTests: XCTestCase {
    func testWritesOneLinePerKindOfNote() {
        let text = "I think the report was written in order to help. I really liked it. I read it twice."
        let stats = TextStats.analyze(text, flags: [PhraseFlag(phrase: "in order to", fix: "to", isCliche: false)])
        let report = NotesReport.markdown(
            stats: stats, typos: [("recieve", ["receive"])], style: StyleRules.parse("liked | enjoyed").check(text, sentences: stats.sentenceTexts)
        )
        let lines = report.components(separatedBy: "\n")
        XCTAssertTrue(lines[0].hasPrefix("**Notes on the passage:** 18 words, 3 sentences, grade "), lines[0])
        XCTAssertTrue(lines.contains("- **Spelling:** recieve \u{2192} receive"), report)
        XCTAssertTrue(lines.contains("- **Style rules:** liked \u{2192} enjoyed"), report)
        XCTAssertTrue(lines.contains("- **Wordy phrases:** in order to \u{2192} to"), report)
        XCTAssertTrue(lines.contains("- **Possible passive voice:** was written"), report)
        XCTAssertTrue(lines.contains("- **Hedges and filler:** I think; really"), report)
        XCTAssertTrue(lines.contains("- **Sentence starts:** \u{201C}I\u{201D} starts 3 of 3 sentences"), report)
    }

    func testLeavesOutHiddenSectionsAndSaysWhenThereAreNoNotes() {
        let stats = TextStats.analyze("The cat sat on the mat. The dog ran far away.")
        XCTAssertTrue(NotesReport.markdown(stats: stats).hasSuffix("No notes."))
        let hedged = TextStats.analyze("I think it works. It really does work well for us.")
        XCTAssertFalse(NotesReport.markdown(stats: hedged, shows: { $0 != .hedges }).contains("Hedges"))
    }
}
