import XCTest
@testable import WordPop

/// Fixtures are the raw strings Dictionary Services returns for the New
/// Oxford American Dictionary and the Oxford American Writer's Thesaurus,
/// captured on macOS 26. The assertions pin the shape the parsers extract
/// from them: block labels, sense counts, forms, and the leading synonyms.
final class ParserTests: XCTestCase {
    private func fixture(_ name: String) -> String? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func entry(_ word: String) -> WordEntry {
        let slug = word.replacingOccurrences(of: " ", with: "_")
        let thesaurus = fixture("\(slug).thesaurus").map { Thesaurus.parse($0, word: word) } ?? []
        return DictionaryLookup.entry(word: word, entryText: fixture("\(slug).noad"), thesaurus: thesaurus)
    }

    private func block(_ entry: WordEntry, _ partOfSpeech: String) -> PartOfSpeechBlock? {
        entry.blocks.first { $0.partOfSpeech == partOfSpeech }
    }

    // MARK: Headword normalization

    func testHeadwordStripsQuotesAndPunctuation() {
        XCTAssertEqual(DictionaryLookup.headword(in: "\"gregarious,\" she said."), "gregarious")
        XCTAssertEqual(DictionaryLookup.headword(in: "  (meticulous)\n"), "meticulous")
    }

    func testHeadwordKeepsKnownPhrases() {
        XCTAssertEqual(DictionaryLookup.headword(in: "ice cream"), "ice cream")
    }

    func testHeadwordTakesFirstTermOfASentence() {
        XCTAssertEqual(DictionaryLookup.headword(in: "quick brown foxes jumped"), "quick")
    }

    // MARK: Multi-block entries

    func testRunSplitsVerbAndNounBlocks() {
        let run = entry("run")
        XCTAssertEqual(run.blocks.prefix(2).map(\.partOfSpeech), ["verb", "noun"])

        let verb = block(run, "verb")!
        XCTAssertGreaterThanOrEqual(verb.items.filter { $0.number != nil }.count, 10)
        XCTAssertEqual(verb.items.first?.number, 1)
        XCTAssertTrue(verb.items.first!.text.hasPrefix("move at a speed faster than a walk"))
        XCTAssertEqual(verb.items.first?.example, "the dog ran across the road")

        let noun = block(run, "noun")!
        XCTAssertGreaterThanOrEqual(noun.items.filter { $0.number != nil }.count, 10)
        XCTAssertEqual(noun.items.first?.number, 1, "noun numbering restarts at 1 and must not collide with the verb block")
        XCTAssertTrue(noun.items.first!.text.hasPrefix("an act or spell of running"))
    }

    func testRunHeaderFormsAndPronunciation() {
        let run = entry("run")
        XCTAssertNil(run.syllables, "one-syllable words have no syllable dots")
        XCTAssertEqual(run.pronunciation, "rən")
        XCTAssertEqual(run.forms, ["runs", "running", "past ran", "past participle run"])
    }

    func testGoFormsWithLabelledSegments() {
        XCTAssertEqual(entry("go").forms, [
            "third singular present goes", "present participle going", "past went", "past participle gone",
        ])
    }

    func testGoodComparativeForms() {
        XCTAssertEqual(entry("good").forms, ["better", "best"])
    }

    func testChildPluralForm() {
        let child = entry("child")
        XCTAssertEqual(child.forms, ["plural children"])
        XCTAssertEqual(child.blocks.map(\.partOfSpeech), ["noun"])
        XCTAssertTrue(child.blocks[0].items.first!.text.hasPrefix("a young human being"))
    }

    // MARK: Single-sense and phrase entries

    func testMeticulousSyllablesAndSingleSense() {
        let meticulous = entry("meticulous")
        XCTAssertEqual(meticulous.syllables, "me·tic·u·lous")
        XCTAssertEqual(meticulous.forms, [])
        let adjective = block(meticulous, "adjective")!
        XCTAssertEqual(adjective.items.count, 1)
        XCTAssertNil(adjective.items[0].number)
        XCTAssertEqual(adjective.items[0].text, "showing great attention to detail; very careful and precise")
        XCTAssertEqual(adjective.items[0].example, "he had always been so meticulous about his appearance.")
        XCTAssertTrue(meticulous.origin!.hasPrefix("mid 16th century"))
    }

    func testIceCreamIsAPhraseEntry() {
        let iceCream = entry("ice cream")
        XCTAssertEqual(iceCream.blocks.map(\.partOfSpeech), ["noun"])
        XCTAssertTrue(iceCream.blocks[0].items.first!.text.hasPrefix("a soft frozen food"))
    }

    func testUnitedNationsSyllablesSpanBothWordsAndSkipAbbreviation() {
        let un = entry("United Nations")
        XCTAssertEqual(un.syllables, "U·nit·ed Na·tions")
        XCTAssertEqual(un.forms, [], "(abbreviation UN) is not an inflected form")
        XCTAssertEqual(un.blocks.count, 1)
        XCTAssertEqual(un.blocks[0].items.count, 1)
    }

    func testMissingEntryIsNotFound() {
        let entry = DictionaryLookup.entry(word: "zzzz", entryText: nil, thesaurus: [])
        XCTAssertFalse(entry.found)
        XCTAssertTrue(entry.blocks.isEmpty)
    }

    // MARK: Thesaurus

    func testRunThesaurusSensesFollowTheDictionaryBlocks() {
        let run = entry("run")
        let verb = block(run, "verb")!
        XCTAssertGreaterThanOrEqual(verb.senses.count, 15)
        XCTAssertEqual(verb.senses[0].example, "she jumped out of her car and ran across the road")
        XCTAssertEqual(Array(verb.senses[0].synonyms.prefix(4)), ["sprint", "race", "dart", "rush"])
        XCTAssertEqual(verb.senses[0].antonyms, ["dawdle"])
        XCTAssertEqual(verb.senses[1].antonyms, ["stay"])

        let noun = block(run, "noun")!
        XCTAssertGreaterThanOrEqual(noun.senses.count, 5)
        XCTAssertEqual(noun.senses[0].synonyms.first, "sprint")
    }

    func testRegisterLabelledGroupsSortAfterPlainOnes() {
        let verb = block(entry("run"), "verb")!
        let first = verb.senses[0].synonyms
        XCTAssertFalse(first.contains("informal"))
        XCTAssertTrue(first.firstIndex(of: "bolt")! < first.count, "plain group words precede the informal group")
    }

    func testParentheticalsAreRemovedFromTerms() {
        let flee = block(entry("run"), "verb")!.senses[1].synonyms
        XCTAssertTrue(flee.contains("beat a retreat"), "\"beat a (hasty) retreat\" loses the parenthetical and the double space")
    }

    func testQuietAdjectiveHasEightSensesAndNounIgnoresPhrasesTrailer() {
        let quiet = entry("quiet")
        XCTAssertEqual(block(quiet, "adjective")!.senses.count, 8)
        XCTAssertEqual(block(quiet, "adjective")!.senses[1].antonyms, ["loud"])
        let nounAntonyms = block(quiet, "noun")!.senses.flatMap(\.antonyms)
        XCTAssertFalse(nounAntonyms.contains("openly"), "antonym from the PHRASES idiom section must not leak into the noun")
    }

    func testCatDropsWordLinksTrailer() {
        let cat = block(entry("cat"), "noun")!
        XCTAssertEqual(cat.senses.count, 1)
        XCTAssertEqual(cat.senses[0].synonyms.first, "feline")
        XCTAssertFalse(cat.senses[0].synonyms.contains { $0.contains(":") }, "\"feline: relating to cats\" word links are not synonyms")
    }

    func testSingleSenseThesaurusWithoutNumbering() {
        let sense = block(entry("meticulous"), "adjective")!.senses
        XCTAssertEqual(sense.count, 1)
        XCTAssertEqual(sense[0].example, "meticulous attention to detail")
        XCTAssertEqual(sense[0].synonyms.first, "careful")
        XCTAssertEqual(sense[0].antonyms, ["careless", "sloppy", "slapdash"])
    }

    func testSerendipityExampleIsNotMistakenForASynonymList() {
        let sense = block(entry("serendipity"), "noun")!.senses[0]
        XCTAssertEqual(sense.example, "technical innovation may be the result of pure serendipity")
        XCTAssertEqual(Array(sense.synonyms.prefix(2)), ["chance", "happy chance"])
    }

    func testThesaurusBlockWithoutDictionaryBlockIsAppended() {
        // "cat" has a verb block in NOAD but the Thesaurus only covers the noun;
        // "good" has adverb/noun/exclamation blocks in NOAD. Either way every
        // Thesaurus part of speech must end up on some block.
        let good = entry("good")
        for thesaurusBlock in Thesaurus.parse(fixture("good.thesaurus")!, word: "good") {
            XCTAssertNotNil(block(good, thesaurusBlock.partOfSpeech!), "missing block for \(thesaurusBlock.partOfSpeech!)")
        }
    }
}
