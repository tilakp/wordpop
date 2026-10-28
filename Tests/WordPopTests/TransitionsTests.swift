import XCTest
@testable import WordPop

final class TransitionsTests: XCTestCase {
    func testPutsATransitionAtTheStart() {
        XCTAssertEqual(Transitions.applying("However", to: "The plan failed."), "However, the plan failed.")
        XCTAssertEqual(Transitions.applying("So", to: "We left early."), "So we left early.")
        XCTAssertEqual(Transitions.applying("In fact", to: "I was there."), "In fact, I was there.")
        XCTAssertEqual(Transitions.applying("Also", to: "NASA agreed."), "Also, NASA agreed.")
        XCTAssertEqual(Transitions.applying("Still", to: "London was cold."), "Still, London was cold.")
    }

    func testReplacesTheTransitionASentenceStartsWith() {
        XCTAssertEqual(Transitions.leading(in: "However, the plan failed."), "However")
        XCTAssertEqual(Transitions.leading(in: "On the other hand, it rained."), "On the other hand")
        XCTAssertNil(Transitions.leading(in: "Still water runs deep."))
        XCTAssertNil(Transitions.leading(in: "Sometimes it rains."))
        XCTAssertEqual(Transitions.applying("As a result", to: "However, the plan failed."), "As a result, the plan failed.")
        XCTAssertEqual(Transitions.applying("However", to: "So we left early."), "However, we left early.")
    }
}
