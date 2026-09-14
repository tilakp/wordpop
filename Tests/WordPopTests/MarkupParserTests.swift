import XCTest
@testable import WordPop

/// Structured parsing from the entry markup (`DCSRecordCopyData`), the
/// primary path; the flat-text parsers in ParserTests are the fallback.
final class MarkupParserTests: XCTestCase {
    private func markup(_ name: String) -> String {
        let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures")!
        return try! String(contentsOf: url, encoding: .utf8)
    }

    private func parsed(_ name: String) -> EntryMarkupParser.Parsed {
        EntryMarkupParser.parse(markup("\(name).xml"))!
    }

    // MARK: Dictionary entries

    func testQuietBlocksAndSenses() {
        let quiet = parsed("quiet")
        XCTAssertEqual(quiet.title, "quiet")
        XCTAssertEqual(quiet.syllables, "qui·et")
        XCTAssertEqual(quiet.pronunciation, "ˈkwīət")
        XCTAssertEqual(quiet.forms, ["quieter", "quietest"])
        XCTAssertEqual(quiet.blocks.map(\.partOfSpeech), ["adjective", "noun", "verb"])

        let adjective = quiet.blocks[0].items
        XCTAssertEqual(adjective.first?.number, 1)
        XCTAssertEqual(adjective.first?.text, "making little or no noise")
        XCTAssertEqual(adjective.first?.example, "the car has a quiet, economical engine")
        XCTAssertEqual(adjective.filter { $0.number != nil }.count, 2)
        XCTAssertTrue(adjective[1].isSubItem)
        XCTAssertTrue(quiet.origin!.hasPrefix("Middle English"))
    }

    func testRegisterLabelIsSeparateFromDefinition() {
        let child = parsed("child")
        let archaic = child.blocks[0].items.first { $0.label == "archaic" }
        XCTAssertNotNil(archaic)
        XCTAssertEqual(archaic?.text, "(children) the descendants of a family or people")
        XCTAssertFalse(child.blocks[0].items.contains { $0.text.hasPrefix("archaic") })
    }

    func testChildHeaderAndSingleUnnumberedSense() {
        let child = parsed("child")
        XCTAssertNil(child.syllables)
        XCTAssertEqual(child.forms, ["plural children"])
        XCTAssertEqual(child.blocks.count, 1)
        XCTAssertNil(child.blocks[0].items[0].number)
        XCTAssertTrue(child.blocks[0].items[0].text.hasPrefix("a young human being"))
        XCTAssertEqual(child.blocks[0].items[0].example, "she'd been playing tennis since she was a child")
    }

    func testMeticulousSyllablesFromMarkup() {
        let meticulous = parsed("meticulous")
        XCTAssertEqual(meticulous.syllables, "me·tic·u·lous")
        XCTAssertEqual(meticulous.blocks.map(\.partOfSpeech), ["adjective"])
        XCTAssertEqual(meticulous.blocks[0].items.count, 1)
    }

    func testUnitedNationsHasNoInflectionsAndKeepsPhraseTitle() {
        let un = parsed("United_Nations")
        XCTAssertEqual(un.title, "United Nations")
        XCTAssertEqual(un.syllables, "U·nit·ed Na·tions")
        XCTAssertEqual(un.forms, [])
    }

    func testPhrasesComeFromTheSameParse() {
        XCTAssertEqual(parsed("quiet").phrases.map(\.phrase), [
            "keep quiet", "keep someone quiet", "keep something quiet", "on the quiet", "as quiet as a mouse",
        ])
    }

    func testEntryAssemblyUsesTheCanonicalTitle() {
        let entry = DictionaryLookup.entry(from: parsed("child"), thesaurus: [])
        XCTAssertEqual(entry.word, "child")
        XCTAssertEqual(entry.blocks.map(\.partOfSpeech), ["noun"])
        XCTAssertTrue(entry.found)
    }

    // MARK: Thesaurus entries

    func testQuietThesaurusSenses() {
        let blocks = Thesaurus.parseMarkup(markup("quiet.thesaurus.xml"))!
        XCTAssertEqual(blocks.map(\.partOfSpeech), ["adjective", "noun"])
        let adjective = blocks[0].senses
        XCTAssertEqual(adjective.count, 8)
        XCTAssertEqual(adjective[0].example, "the whole bar went quiet")
        XCTAssertEqual(Array(adjective[0].synonyms.prefix(5)), ["silent", "still", "hushed", "noiseless", "soundless"])
        XCTAssertEqual(adjective[1].antonyms, ["loud"])
        let nounAntonyms = blocks[1].senses.flatMap(\.antonyms)
        XCTAssertFalse(nounAntonyms.contains("openly"), "the PHRASES sub-entry is outside the noun's senses")
    }

    func testLabelledGroupsSortAfterPlainOnes() {
        let calm = Thesaurus.parseMarkup(markup("quiet.thesaurus.xml"))![0].senses[4].synonyms
        XCTAssertEqual(calm.first, "calm")
        XCTAssertFalse(calm.contains("informal"))
    }

    func testCatThesaurusIgnoresWordLinks() {
        let blocks = Thesaurus.parseMarkup(markup("cat.thesaurus.xml"))!
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].senses.count, 1)
        XCTAssertEqual(blocks[0].senses[0].synonyms.first, "feline")
        XCTAssertFalse(blocks[0].senses[0].synonyms.contains("ailurophile"))
    }

    func testSingleSenseThesaurusEntry() {
        let sense = Thesaurus.parseMarkup(markup("meticulous.thesaurus.xml"))![0].senses[0]
        XCTAssertEqual(sense.example, "meticulous attention to detail")
        XCTAssertEqual(sense.synonyms.first, "careful")
        XCTAssertEqual(sense.antonyms, ["careless", "sloppy", "slapdash"])
    }

    // MARK: Canonical headword from flat text

    func testCanonicalHeadword() {
        XCTAssertEqual(DictionaryLookup.canonicalHeadword(in: "meticulous me·tic·u·lous | məˈtikyələs | adjective ..."), "meticulous")
        XCTAssertEqual(DictionaryLookup.canonicalHeadword(in: "go 1 | ɡō | verb ..."), "go")
        XCTAssertEqual(DictionaryLookup.canonicalHeadword(in: "United Nations U·nit·ed Na·tions | yo͞o | ..."), "United Nations")
    }
}
