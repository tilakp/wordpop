import XCTest
@testable import WordPop

final class ConsistencyTests: XCTestCase {
    func testFindsHyphenatedAndJoinedSpellings() {
        let result = Consistency.check("Send an email today. The e-mail went out, and every email after it. We co-operate.")
        XCTAssertEqual(result.variants, [["email", "e-mail"]])
        XCTAssertTrue(Consistency.check("We meet every day. It is an everyday task. A well-known author is well known.").variants.isEmpty)
    }

    func testFindsBritishAndAmericanSpellingTogether() {
        let result = Consistency.check("The colour of the center was organised well.")
        XCTAssertEqual(result.british, ["colour", "organised"])
        XCTAssertEqual(result.american, ["center"])
        XCTAssertEqual(result.toAmerican["colour"], "color")
        XCTAssertEqual(result.toAmerican["organised"], "organized")
        XCTAssertEqual(result.toBritish["center"], "centre")
        XCTAssertTrue(Consistency.check("The colour of the centre was organised well.").british.isEmpty, "one system is fine")
    }

    func testFindsMixedQuotesAndSpacing() {
        XCTAssertTrue(Consistency.check("She said \"yes\" and he said \u{201C}no\u{201D}.").mixedQuotes)
        XCTAssertTrue(Consistency.check("It's here and it\u{2019}s there.").mixedQuotes)
        XCTAssertTrue(Consistency.check("It\u{2019}s \"here\".").mixedQuotes)
        XCTAssertFalse(Consistency.check("It\u{2019}s here and \u{201C}there\u{201D}.").mixedQuotes)
        XCTAssertTrue(Consistency.check("One.  Two. Three.").mixedSpacing)
        XCTAssertFalse(Consistency.check("One.  Two.  Three.").mixedSpacing)
    }

    func testFindsAcronymsNotSpelledOut() {
        XCTAssertEqual(Consistency.undefinedAcronyms(in: "Write in STE. It is Simplified Technical English (STE). Do NOT use the API."), ["STE"])
        XCTAssertEqual(Consistency.undefinedAcronyms(in: "Simplified Technical English (STE) is strict. Use STE and ATA codes."), ["ATA"])
        XCTAssertEqual(Consistency.undefinedAcronyms(in: "WARNING: the KPIs are late."), ["KPI"])
    }

    func testEditDistance() {
        XCTAssertEqual(Consistency.editDistance("center", "centre"), 2)
        XCTAssertEqual(Consistency.editDistance("color", "colour"), 1)
        XCTAssertEqual(Consistency.editDistance("", "abc"), 3)
    }
}
