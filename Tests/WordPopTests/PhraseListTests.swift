import XCTest
@testable import WordPop

/// The hand-written lists as the app loads them from the bundled
/// database (scripts/wordy.txt, plain.txt and cliches.txt).
final class PhraseListTests: XCTestCase {
    func testLoadsTheWordyAndClicheLists() {
        let flags = Database.phraseFlags
        XCTAssertGreaterThan(flags.filter { !$0.isCliche }.count, 100)
        XCTAssertGreaterThan(flags.filter(\.isCliche).count, 50)
    }

    func testEveryPhraseIsLowercaseAndHasNoStraySpace() {
        for flag in Database.phraseFlags {
            XCTAssertEqual(flag.phrase, flag.phrase.lowercased(), flag.phrase)
            XCTAssertEqual(flag.phrase, flag.phrase.trimmingCharacters(in: .whitespaces), flag.phrase)
            XCTAssertEqual(flag.fix, flag.fix.trimmingCharacters(in: .whitespaces), flag.phrase)
            XCTAssertNotEqual(flag.phrase, flag.fix.lowercased(), "\(flag.phrase) fixes to itself")
        }
    }

    func testFindsAndTightensWithTheRealLists() {
        let text = "Due to the fact that we were late, we took the low-hanging fruit in order to finish. Needless to say, it worked."
        let found = TextStats.flagged(Database.phraseFlags, in: text)
        XCTAssertEqual(found.map(\.phrase), ["Due to the fact that", "low-hanging fruit", "in order to", "Needless to say"])
        let fixes = Dictionary(found.filter { !$0.isCliche }.map { ($0.phrase, $0.fix) }, uniquingKeysWith: { first, _ in first })
        XCTAssertEqual(TextStats.tightened(text, fixes: fixes), "Because we were late, we took the low-hanging fruit to finish. It worked.")
    }

    func testPlainWordsAreFixedLikeWordyPhrases() {
        let text = "Utilize the remainder. We commenced work and utilized numerous tools."
        let found = TextStats.flagged(Database.phraseFlags, in: text)
        XCTAssertEqual(found.map(\.phrase), ["Utilize", "remainder", "commenced", "utilized", "numerous"])
        XCTAssertFalse(found.contains(where: \.isCliche))
        let fixes = Dictionary(found.map { ($0.phrase, $0.fix) }, uniquingKeysWith: { first, _ in first })
        XCTAssertEqual(TextStats.tightened(text, fixes: fixes), "Use the rest. We started work and used many tools.")
    }

    func testMoreSpecificWordsBySense() {
        let walk = Database.specific(for: "walk", partOfSpeech: "verb")
        XCTAssertTrue(walk.first?.words.contains("stroll") == true, "\(walk)")
        XCTAssertFalse(walk.flatMap(\.words).contains("mouse"), "not a main sense of mouse")
        XCTAssertTrue(Database.specific(for: "laugh", partOfSpeech: "noun").first?.words.contains("giggle") == true)
        XCTAssertTrue(Database.specific(for: "happy", partOfSpeech: "noun").isEmpty)
    }
}
