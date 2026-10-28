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

final class GrammarTests: XCTestCase {
    // Only the checker's rule-based mistakes: its agreement model ("They
    // was") never loads in the test process.
    func testFindsGrammarMistakesWithCorrections() {
        let text = "We left at noon. I saw a apple on the table. They left, and we should of known."
        let issues = Spelling.grammarIssues(in: text)
        XCTAssertEqual(issues.map(\.flagged), ["a", "of"])
        XCTAssertEqual(issues.map { $0.corrections.first }, ["an", "have"])
        XCTAssertTrue(Spelling.grammarIssues(in: "The committee approved the report after a long debate.").isEmpty)
    }

    func testAppliesGrammarFixesInTheirSentence() {
        let text = "  I saw a apple. They left, and a owl said we should of known."
        let issues = Spelling.grammarIssues(in: text)
        let fixed = Spelling.applying(issues.map { ($0, $0.corrections[0]) }, to: text.trimmingCharacters(in: .whitespaces))
        XCTAssertEqual(fixed, "I saw an apple. They left, and an owl said we should have known.")
    }
}
