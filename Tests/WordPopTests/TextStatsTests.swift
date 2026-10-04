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
}
