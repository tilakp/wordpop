import XCTest
@testable import WordPop

final class StyleRulesTests: XCTestCase {
    func testParsesRulesAndSettings() {
        let rules = StyleRules.parse("""
            # A note.
            Leverage | use
            very
            \u{2014}
            max sentence words: 12
            max paragraph sentences: 2
            flag -ing words
            """)
        XCTAssertEqual(rules.avoid, [
            PhraseFlag(phrase: "leverage", fix: "use", isCliche: false),
            PhraseFlag(phrase: "very", fix: "", isCliche: false),
            PhraseFlag(phrase: "\u{2014}", fix: "", isCliche: false),
        ])
        XCTAssertEqual(rules.maxSentenceWords, 12)
        XCTAssertEqual(rules.maxParagraphSentences, 2)
        XCTAssertTrue(rules.flagsIngWords)
        XCTAssertTrue(StyleRules.parse("# only notes\n\n").isEmpty)
    }

    func testOwnRulesWinOverThePreset() {
        let preset = StyleRules.parse("max sentence words: 20\nutilize | use")
        let merged = preset.merged(with: StyleRules.parse("max sentence words: 15\nutilize | apply"))
        XCTAssertEqual(merged.maxSentenceWords, 15)
        XCTAssertEqual(merged.avoid.map(\.fix), ["apply"])
    }

    func testChecksAPassage() {
        let rules = StyleRules.parse("leverage | use\nvery\n\u{2014}\nmax sentence words: 6\nmax paragraph sentences: 2\nflag -ing words")
        let text = "We leverage the tool\u{2014}it is very fast. Checking the valve is easy. Bring the box.\nShort one."
        let report = rules.check(text, sentences: TextStats.analyze(text).sentenceTexts)
        XCTAssertEqual(report.words.map(\.phrase), ["leverage", "\u{2014}", "very"])
        XCTAssertEqual(report.longSentences, ["We leverage the tool\u{2014}it is very fast."])
        XCTAssertEqual(report.longParagraphs.map(\.number), [1])
        XCTAssertEqual(report.longParagraphs.first?.sentences, 3)
        XCTAssertEqual(report.ingWords, ["checking"])
    }

    func testTheSTEPresetLoads() {
        let rules = StyleRules.parse(Database.preset(named: "ste") ?? "")
        XCTAssertEqual(rules.maxSentenceWords, 20)
        XCTAssertTrue(rules.flagsIngWords)
        XCTAssertTrue(rules.avoid.contains(PhraseFlag(phrase: "prior to", fix: "before", isCliche: false)))
        let fixes = Dictionary(TextStats.flagged(rules.avoid, in: "Verify the seal prior to use.").map { ($0.phrase, $0.fix) }, uniquingKeysWith: { a, _ in a })
        XCTAssertEqual(TextStats.tightened("Verify the seal prior to use.", fixes: fixes), "Make sure the seal before use.")
    }
}
