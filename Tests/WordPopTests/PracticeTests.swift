import XCTest
@testable import WordPop

final class PracticeTests: XCTestCase {
    func testQuestionHasTheAnswerAndThreeOtherChoices() {
        let question = PracticeQuiz.question(.definition, prompt: "very careful", answer: "meticulous",
                                             distractors: ["meticulous", "lazy", "brisk", "ornate", "plain"])
        XCTAssertEqual(question.choices.count, 4)
        XCTAssertTrue(question.choices.contains("meticulous"))
        XCTAssertEqual(Set(question.choices).count, 4)
    }

    func testBlanksTheWordOrAFormOfIt() {
        XCTAssertEqual(PracticeQuiz.blanked("She was meticulous about it.", word: "meticulous"), "She was _____ about it.")
        XCTAssertEqual(PracticeQuiz.blanked("They planned it for weeks.", word: "plan"), "They _____ it for weeks.")
        XCTAssertNil(PracticeQuiz.blanked("She was careful.", word: "meticulous"))
    }
}
