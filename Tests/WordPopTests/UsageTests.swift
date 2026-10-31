import XCTest
@testable import WordPop

final class UsageTests: XCTestCase {
    func testCountsAndFindsAPhrase() {
        let from = Database.usage(of: "different from", limit: 3)
        let than = Database.usage(of: "different than", limit: 3)
        XCTAssertGreaterThan(from.count, than.count)
        XCTAssertEqual(from.sentences.count, 3)
        XCTAssertTrue(from.sentences.allSatisfy { $0.lowercased().contains("different from") })
        XCTAssertEqual(Database.usage(of: "zzqx glorp", limit: 3).count, 0)
        XCTAssertEqual(Database.usage(of: "say \"hi\"", limit: 1).count, Database.usage(of: "say hi", limit: 1).count, "quotes are escaped")
    }
}
