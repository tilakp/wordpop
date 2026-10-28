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

final class ModelAnswerParsingTests: XCTestCase {
    func testListItemsDropNumberingBulletsAndQuotes() {
        XCTAssertEqual(WritingModel.listItems("1. *tirade*\n2. rant.\n- \u{201C}harangue\u{201D}"), ["tirade", "rant", "harangue"])
        XCTAssertEqual(WritingModel.listItems("silent, hushed, still."), ["silent", "hushed", "still"])
    }

    func testNumbers() {
        XCTAssertEqual(WritingModel.numbers("4, 5"), [4, 5])
        XCTAssertEqual(WritingModel.numbers("The answer is 2."), [2])
    }
}

final class ExampleSentenceTests: XCTestCase {
    func testKeepsSentencesThatUseTheWordOrAForm() {
        XCTAssertTrue(WritingModel.usesWord("meticulous", in: "She did a meticulous job."))
        XCTAssertTrue(WritingModel.usesWord("plan", in: "They planned the trip for weeks."))
        XCTAssertFalse(WritingModel.usesWord("meticulous", in: "She was very careful."))
    }

    func testLinesDropNumberingAndQuotes() {
        XCTAssertEqual(WritingModel.lines("1. \u{201C}She ran, then stopped.\u{201D}\n2. He ran home."), ["She ran, then stopped.", "He ran home."])
    }

    func testFindsEachTypoOnceWithSuggestions() {
        let typos = Spelling.typos(in: "We have recieved your letter. It was recieved late, seperate from the rest.")
        XCTAssertEqual(typos.map(\.word), ["recieved", "seperate"])
        XCTAssertEqual(typos.first?.suggestions.first, "received")
    }

    func testAppliesFixesToWholeWordsInTheSameCase() {
        let text = "Recieved today. We recieved it, not unrecieved."
        XCTAssertEqual(Spelling.applying(["recieved": "received"], to: text), "Received today. We received it, not unrecieved.")
    }
}
