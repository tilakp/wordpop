import XCTest
@testable import WordPop

final class TextReplacerTests: XCTestCase {
    func testKeepsPunctuationAndSpacingAroundTheWord() {
        XCTAssertEqual(TextReplacer.replacement(in: "quiet,", with: "hushed"), "hushed,")
        XCTAssertEqual(TextReplacer.replacement(in: "quiet ", with: "hushed"), "hushed ")
        XCTAssertEqual(TextReplacer.replacement(in: "\u{201C}quiet\u{201D}", with: "hushed"), "\u{201C}hushed\u{201D}")
    }

    func testMatchesCapitalization() {
        XCTAssertEqual(TextReplacer.replacement(in: "Quiet", with: "hushed"), "Hushed")
        XCTAssertEqual(TextReplacer.replacement(in: "QUIET", with: "hushed"), "HUSHED")
        XCTAssertEqual(TextReplacer.replacement(in: "I", with: "me"), "Me")
    }

    func testReplacesOnlyTheLookedUpWordOfAPhrase() {
        XCTAssertEqual(TextReplacer.replacement(in: "quiet street", with: "silent"), "silent street")
    }
}
