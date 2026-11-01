import XCTest
@testable import WordPop

final class TextToolsTests: XCTestCase {
    func testTitleCase() {
        XCTAssertEqual(TextTool.titleCase.apply(to: "a guide to writing for the web"), "A Guide to Writing for the Web")
        XCTAssertEqual(TextTool.titleCase.apply(to: "why NASA bought an iPhone: a look in"), "Why NASA Bought an iPhone: A Look In")
        XCTAssertEqual(TextTool.titleCase.apply(to: "a step-by-step plan"), "A Step-By-Step Plan")
        XCTAssertEqual(TextTool.titleCase.apply(to: "THE END OF THE ROAD"), "The End of the Road")
    }

    func testSentenceCase() {
        XCTAssertEqual(TextTool.sentenceCase.apply(to: "The Quick Guide To Writing In STE"), "The quick guide to writing in STE")
        XCTAssertEqual(TextTool.sentenceCase.apply(to: "WHAT I LEARNED. IT WORKED!"), "What I learned. It worked!")
        XCTAssertEqual(TextTool.sentenceCase.apply(to: "Why I Moved My iPhone App"), "Why I moved my iPhone app")
    }

    func testQuotes() {
        XCTAssertEqual(TextTool.curlyQuotes.apply(to: "She said \"don't go\" ('maybe')."),
                       "She said \u{201C}don\u{2019}t go\u{201D} (\u{2018}maybe\u{2019}).")
        XCTAssertEqual(TextTool.straightQuotes.apply(to: "\u{201C}It\u{2019}s fine,\u{201D} she said."), "\"It's fine,\" she said.")
    }

    func testJoinLines() {
        XCTAssertEqual(TextTool.joinLines.apply(to: "one line\nbroken here \n and here.\n\nNext paragraph\nends."),
                       "one line broken here and here.\n\nNext paragraph ends.")
    }

    func testOffersOnlyToolsThatChangeTheText() {
        XCTAssertEqual(TextTool.useful(for: "A Guide to Writing"), [.sentenceCase])
        XCTAssertFalse(TextTool.useful(for: String(repeating: "word ", count: 20) + "end.").contains(.titleCase))
    }

    func testSentenceCaseIsForTitledTextAndKeepsDays() {
        XCTAssertFalse(TextTool.useful(for: "Hi Sam, please send it before Friday. Thanks.").contains(.sentenceCase))
        XCTAssertEqual(TextTool.sentenceCase.apply(to: "Plans For Friday And June"), "Plans for Friday and June")
    }

    func testASentenceIsNotAHeadline() {
        XCTAssertTrue(TextTool.useful(for: "Remote work makes teams more productive.").isEmpty)
        XCTAssertEqual(TextTool.useful(for: "remote work makes teams more productive"), [.titleCase])
    }
}
