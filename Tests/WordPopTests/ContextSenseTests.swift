import XCTest
@testable import WordPop

final class ContextSenseTests: XCTestCase {
    private func item(_ number: Int?, _ text: String) -> DefinitionItem {
        DefinitionItem(number: number, text: text, example: nil, isSubItem: number == nil)
    }

    func testTheSenseUsedInTheSentenceMovesToTheTopWithItsSubSenses() {
        let items = [item(1, "move fast"), item(nil, "run as a sport"), item(2, "flow"), item(3, "manage"), item(nil, "operate"), item(4, "smuggle")]
        let entry = WordEntry(
            word: "run", syllables: nil, pronunciation: nil, forms: [],
            blocks: [PartOfSpeechBlock(partOfSpeech: "verb", items: items, senses: [], synonyms: [], antonyms: [])],
            rhymes: [], nearRhymes: [], origin: nil, phrases: [], source: nil, found: true
        )
        let model = PopupViewModel()
        model.reset(with: entry)
        XCTAssertEqual(model.displayItems.map(\.text), items.map(\.text))

        model.contextSense = (block: 0, number: 3)
        XCTAssertEqual(model.displayItems.map(\.text), ["manage", "operate", "move fast", "run as a sport", "flow", "smuggle"])
        XCTAssertTrue(model.isContextSense(model.displayItems[0]))
        XCTAssertFalse(model.isContextSense(model.displayItems[2]))
    }
}
