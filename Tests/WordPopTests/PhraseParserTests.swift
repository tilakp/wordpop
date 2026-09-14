import XCTest
@testable import WordPop

final class PhraseParserTests: XCTestCase {
    private func markup(_ name: String) -> String {
        let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures")!
        return try! String(contentsOf: url, encoding: .utf8)
    }

    func testQuietPhrases() {
        let phrases = PhraseParser.phrases(in: markup("quiet.xml"))
        XCTAssertEqual(phrases.map(\.phrase), [
            "keep quiet", "keep someone quiet", "keep something quiet", "on the quiet", "as quiet as a mouse",
        ])
        XCTAssertEqual(phrases[0].definition, "refrain from speaking or from disclosing something secret")
        XCTAssertNil(phrases[0].example)
        XCTAssertEqual(phrases[3].example, "the deal was done on the quiet six months ago")
    }

    func testVariantFormIsNotPartOfThePhrase() {
        // "keep something quiet (also keep quiet about something)": the
        // "also" variant sits in a separate span and must not leak in.
        let phrase = PhraseParser.phrases(in: markup("quiet.xml"))[2]
        XCTAssertEqual(phrase.phrase, "keep something quiet")
        XCTAssertEqual(phrase.definition, "refrain from disclosing information about something; keep something secret")
    }

    func testRegisterLabelIsNotPartOfTheDefinition() {
        // "on the quiet informal without anyone knowing": "informal" is a
        // register label in its own span.
        let phrase = PhraseParser.phrases(in: markup("quiet.xml"))[3]
        XCTAssertEqual(phrase.definition, "without anyone knowing or noticing; secretly or unobtrusively")
    }

    func testEntryWithoutPhraseSections() {
        XCTAssertEqual(PhraseParser.phrases(in: "<span class=\"df\">nothing</span>"), [])
    }
}
