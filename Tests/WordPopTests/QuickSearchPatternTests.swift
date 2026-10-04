import XCTest
@testable import WordPop

final class QuickSearchPatternTests: XCTestCase {
    private func pattern(_ query: String) -> (glob: String, meaning: String?)? {
        let model = QuickSearchModel()
        model.query = query
        return model.pattern
    }

    func testRecognizesPatternsAndMeanings() {
        XCTAssertEqual(pattern("con*")?.glob, "con*")
        XCTAssertNil(pattern("con*")?.meaning)
        XCTAssertEqual(pattern("b??t")?.glob, "b??t")
        XCTAssertEqual(pattern("_ough")?.glob, "?ough")
        XCTAssertEqual(pattern("Con* : agree")?.glob, "con*")
        XCTAssertEqual(pattern("Con* : agree")?.meaning, "agree")
    }

    func testPlainWordsAndDescriptionsAreNotPatterns() {
        XCTAssertNil(pattern("quiet"))
        XCTAssertNil(pattern("?a strong desire to travel"))
        XCTAssertNil(pattern("***"))
    }
}
