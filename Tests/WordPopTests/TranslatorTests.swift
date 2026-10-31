import XCTest
@testable import WordPop

final class TranslatorTests: XCTestCase {
    func testTellsTheLanguageOfTheText() {
        XCTAssertEqual(Translator.language(of: "The report is due on Friday, so please send it soon."), "en")
        XCTAssertEqual(Translator.language(of: "El informe vence el viernes, así que envíalo pronto."), "es")
    }

    func testDoesNotTranslateIntoTheSameLanguage() async {
        let outcome = await Translator.translate("The report is due on Friday, so please send it soon.", to: "en")
        XCTAssertEqual(outcome, .failed("The text is already in \(Translator.name(of: "en"))."))
    }
}
