import XCTest
@testable import WordPop

final class TextStatsTests: XCTestCase {
    private let passage = """
        The report was written by the committee. It was quickly approved. The committee really wanted the report \
        to succeed, and the committee members worked on the report for many weeks, rewriting each section again and \
        again until every member of the committee agreed that it said exactly what they meant.
        """

    func testCountsAndSentences() {
        let stats = TextStats.analyze(passage)
        XCTAssertEqual(stats.sentences, 3)
        XCTAssertEqual(stats.words, 50)
        XCTAssertGreaterThan(stats.grade, 0)
    }

    func testFlagsLongSentencesPassivesAdverbsAndRepeats() {
        let stats = TextStats.analyze(passage)
        XCTAssertEqual(stats.longSentences.count, 1)
        XCTAssertEqual(stats.passives, ["was written", "was quickly approved"])
        XCTAssertTrue(stats.adverbs.contains("quickly"))
        XCTAssertEqual(stats.repeated.first?.word, "committee")
        XCTAssertEqual(stats.repeated.first?.count, 4)
    }

    func testFindsTheSentenceANoteRefersTo() {
        let stats = TextStats.analyze(passage)
        XCTAssertEqual(stats.sentence(containing: "was quickly approved"), "It was quickly approved.")
    }

    func testPassageThreshold() {
        XCTAssertFalse(TextStats.isPassage("quiet"))
        XCTAssertFalse(TextStats.isPassage("ice cream"))
        XCTAssertTrue(TextStats.isPassage("The room fell quiet after the long verdict."))
    }

    func testSimpleTextReadsAtALowGrade() {
        XCTAssertLessThan(TextStats.analyze("The cat sat on the mat. The dog ran to the park.").grade, 3)
    }

    func testAShortSentenceIsAPassageButAnIdiomIsNot() {
        XCTAssertTrue(TextStats.isPassage("We have recieved your letter."))
        XCTAssertTrue(TextStats.isPassage("Did you read the \u{201C}whole report?\u{201D}"))
        XCTAssertFalse(TextStats.isPassage("a piece of cake"))
        XCTAssertFalse(TextStats.isPassage("once in a blue moon"))
        XCTAssertFalse(TextStats.isPassage("It went well."))
    }

    func testCountsAWordAndItsFormsInAParagraph() {
        let paragraph = "The plan matters. Planning is hard, and our plans change. Still, we plan."
        XCTAssertEqual(TextStats.uses(of: "plan", forms: [], in: paragraph), 4)
        XCTAssertEqual(TextStats.uses(of: "run", forms: [], in: "We run, you run, they run."), 0, "short words are skipped")
        let report = "The report was late. Reports take time, and I reported it. Reporting is dull."
        XCTAssertEqual(TextStats.uses(of: "report", forms: ["reports", "reporting", "reported"], in: report), 4)
        XCTAssertEqual(TextStats.uses(of: "write", forms: ["past wrote", "past participle written"], in: "I wrote it, he writes, she has written."), 3)
        XCTAssertEqual(TextStats.uses(of: "about", forms: [], in: "about about about"), 0, "common words are skipped")
    }
}
