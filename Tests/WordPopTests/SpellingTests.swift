import XCTest
@testable import WordPop

/// Uses the system spell checker and dictionary, as the app does.
final class SpellingTests: XCTestCase {
    func testSuggestsCloseWordsForAMisspelling() {
        XCTAssertEqual(Spelling.suggestions(for: "seperate").first, "separate")
        XCTAssertTrue(Spelling.suggestions(for: "recieve").contains("receive"))
    }

    func testNoSuggestionsForACorrectWord() {
        XCTAssertEqual(Spelling.suggestions(for: "quiet"), [])
    }

    func testMergesCaseVariants() {
        XCTAssertEqual(Spelling.suggestions(for: "pharoah"), ["pharaoh"])
    }

    func testGlossIsPartOfSpeechAndFirstDefinition() {
        XCTAssertEqual(DictionaryLookup.gloss(of: "weird")?.hasPrefix("adjective \u{B7} "), true)
    }
}

final class CollocationFilterTests: XCTestCase {
    func testKeepsPhrasesWithTheWordAndARealPartner() {
        XCTAssertEqual(
            WritingModel.usefulCollocations(["Light rain", "rainstorm", "rain in the morning", "evidence of", "heavy rain", "light rain"], word: "rain"),
            ["light rain", "rain in the morning", "heavy rain"]
        )
        XCTAssertEqual(WritingModel.usefulCollocations(["evidence of", "evidence for", "strong evidence"], word: "evidence"), ["strong evidence"])
    }
}
