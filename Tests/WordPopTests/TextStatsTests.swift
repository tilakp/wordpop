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
        XCTAssertEqual(String(format: "%.1f", TextStats.analyze(
            "The storm came in fast. We closed the shutters quickly. The dog hid under the bed. The lights went out at nine.",
            syllables: { Database.syllables(of: $0) }
        ).grade), "0.0", "a small negative grade shows as 0.0, not -0.0")
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

    func testCountsShortAndCommonWordsToo() {
        XCTAssertEqual(TextStats.occurrences(of: "very", in: "It was very, very cold. Very."), 3)
        XCTAssertEqual(TextStats.occurrences(of: "plan", in: "We planned the plans."), 2)
        let index = TextStats.wordIndex(of: "It was Very cold, and we planned more.")
        XCTAssertTrue(TextStats.contains("very", in: index))
        XCTAssertTrue(TextStats.contains("plan", in: index))
        XCTAssertFalse(TextStats.contains("really", in: index))
    }

    func testFindsARunOfSentencesOfTheSameLength() {
        let even = TextStats.analyze("I went home. I made some tea. I sat down there. Then, after a long and tiring day at work, I finally fell asleep on the sofa.")
        XCTAssertEqual(even.sentenceLengths, [3, 4, 4, 16])
        XCTAssertEqual(even.evenRun, 0...2)
        XCTAssertNil(TextStats.analyze("I went home. Then I made a pot of strong tea for us. I sat.").evenRun)
    }

    private let flags = [
        PhraseFlag(phrase: "the fact that", fix: "that", isCliche: false),
        PhraseFlag(phrase: "due to the fact that", fix: "because", isCliche: false),
        PhraseFlag(phrase: "in order to", fix: "to", isCliche: false),
        PhraseFlag(phrase: "needless to say", fix: "", isCliche: false),
        PhraseFlag(phrase: "low-hanging fruit", fix: "easy wins", isCliche: true),
    ]

    func testFlagsWordyPhrasesAndClichesLongestFirst() {
        let text = "Due to the fact that we were late, we took the low-hanging fruit in order to finish. In order to win, we ran."
        let found = TextStats.flagged(flags, in: text)
        XCTAssertEqual(found.map(\.phrase), ["Due to the fact that", "low-hanging fruit", "in order to"])
        XCTAssertEqual(found.map(\.isCliche), [false, true, false])
        XCTAssertTrue(TextStats.flagged(flags, in: "Inorder to tonight").isEmpty)
    }

    func testTightensPhrasesKeepingCase() {
        XCTAssertEqual(
            TextStats.tightened("Due to the fact that it rained, we left in order to rest.", fixes: ["due to the fact that": "because", "in order to": "to"]),
            "Because it rained, we left to rest."
        )
        // Overlapping keys: without longest-first, about half of all runs
        // (the dictionary's order changes per process) gave "Due to that".
        XCTAssertEqual(
            TextStats.tightened("Due to the fact that it rained, we stayed. The fact that she left hurt.",
                                fixes: ["The fact that": "that", "Due to the fact that": "because"]),
            "Because it rained, we stayed. That she left hurt."
        )
        XCTAssertEqual(TextStats.tightened("Needless to say, it failed.", fixes: ["needless to say": ""]), "It failed.")
        XCTAssertEqual(TextStats.tightened("It failed, needless to say.", fixes: ["needless to say": ""]), "It failed.")
        XCTAssertEqual(TextStats.tightened("We were, needless to say, late.", fixes: ["needless to say": ""]), "We were late.")
        XCTAssertEqual(TextStats.tightened("Needless to say, \u{1F600} it worked.", fixes: ["needless to say": ""]), "\u{1F600} it worked.")
        XCTAssertEqual(TextStats.tightened("First para.\n\nNeedless to say, it failed.", fixes: ["needless to say": ""]), "First para.\n\nIt failed.")
        XCTAssertEqual(TextStats.tightened("We were, needless to say, \"late\".", fixes: ["needless to say": ""]), "We were \"late\".")
        XCTAssertEqual(TextStats.tightened("It failed, needless to say (again).", fixes: ["needless to say": ""]), "It failed (again).")
        XCTAssertEqual(TextStats.tightened("He said \"needless to say\".", fixes: ["needless to say": ""]), "He said \"\".")
        XCTAssertEqual(TextStats.tightened("We are in the process of moving.", fixes: ["in the process of": ""]), "We are moving.")
    }

    func testFindsHedgesInOrderWithCounts() {
        let hedges = TextStats.hedges(in: "I think it is just a little bit late. Just go. It was kind of fun, I think.")
        XCTAssertEqual(hedges.map(\.word), ["I think", "just", "a little bit", "kind of"])
        XCTAssertEqual(hedges.map(\.count), [2, 2, 1, 1])
        XCTAssertTrue(TextStats.hedges(in: "The judge was justly praised.").isEmpty)
    }

    func testFindsRepeatedSentenceStarts() {
        let stats = TextStats.analyze("I woke early. I made tea. Then I read. \u{201C}I am late,\u{201D} I said. The bus came.")
        XCTAssertEqual(stats.repeatedStarts.map(\.word), ["I"])
        XCTAssertEqual(stats.repeatedStarts.first?.count, 3)
        let varied = TextStats.analyze("The sun rose. The birds sang. A dog barked. We ate. The day was warm. Rain fell. It stopped. "
            + "We left. Cars passed. Night came. A moon rose. Stars shone. Owls called.")
        XCTAssertTrue(varied.repeatedStarts.isEmpty, "3 of 13 is under a quarter \(varied.repeatedStarts)")
    }
}
