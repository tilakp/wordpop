import XCTest
@testable import WordPop

final class PhraseMatchTests: XCTestCase {
    private let kickPhrases = [
        Phrase(phrase: "kick oneself", definition: "be annoyed with oneself", example: nil),
        Phrase(phrase: "kick the bucket", definition: "die", example: nil),
        Phrase(phrase: "kick up a fuss", definition: "object loudly", example: nil),
    ]

    func testMatchesAnIdiomInAnyTense() {
        XCTAssertEqual(PhraseMatch.best(for: "kicked the bucket", among: kickPhrases)?.definition, "die")
        XCTAssertEqual(PhraseMatch.best(for: "Kick the bucket.", among: kickPhrases)?.definition, "die")
    }

    func testIgnoresPhrasesThatDoNotCoverTheSelection() {
        XCTAssertNil(PhraseMatch.best(for: "kick the ball", among: kickPhrases))
        XCTAssertNil(PhraseMatch.best(for: "the bucket was full of water", among: kickPhrases))
    }

    func testPlaceholdersStandForAnyWord() {
        let phrases = [Phrase(phrase: "bite one's tongue", definition: "make an effort not to say something", example: nil)]
        XCTAssertEqual(PhraseMatch.best(for: "bit her tongue", among: phrases)?.definition, "make an effort not to say something")
    }

    func testOnlyMultiWordSelectionsReducedToOneWordAreCandidates() {
        XCTAssertTrue(PhraseMatch.isPhrase("spill the beans", lookedUpAs: "spill"))
        XCTAssertFalse(PhraseMatch.isPhrase("ice cream", lookedUpAs: "ice cream"))
        XCTAssertFalse(PhraseMatch.isPhrase("quiet", lookedUpAs: "quiet"))
    }
}

/// Uses the dictionary installed with macOS, as the app does.
final class PhraseLookupTests: XCTestCase {
    private func find(_ selection: String) -> (phrase: Phrase, source: String)? {
        let entry = DictionaryLookup.lookup(selection)
        return PhraseMatch.find(selection, in: entry) { DictionaryLookup.lookup($0) }
    }

    func testFindsIdiomsUnderAnyOfTheirWords() {
        XCTAssertEqual(find("spill the beans")?.phrase.phrase, "spill the beans")
        XCTAssertEqual(find("moved the goalposts")?.phrase.phrase, "move the goalposts")
        XCTAssertEqual(find("kicked the bucket")?.phrase.phrase, "kick the bucket")
        XCTAssertEqual(find("touch base")?.source, "base")
        XCTAssertNil(find("paint the ceiling blue"))
    }
}
