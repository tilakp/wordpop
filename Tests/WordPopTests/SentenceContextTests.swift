import XCTest
@testable import WordPop

final class SentenceContextTests: XCTestCase {
    func testPicksTheSentenceThatContainsTheSelection() {
        let text = "The jury came back. The room fell quiet after the verdict. Then the judge spoke."
        let range = (text as NSString).range(of: "quiet")
        XCTAssertEqual(TextCapture.sentence(in: text, containing: range), "The room fell quiet after the verdict.")
    }

    func testFindsTheSentencesAroundASentence() {
        let paragraph = "The data came in late. I think we could send it sooner. The review starts Monday."
        let around = WritingModel.neighbors(of: "I think we could send it sooner. ", in: paragraph)
        XCTAssertEqual(around.before, "The data came in late.")
        XCTAssertEqual(around.after, "The review starts Monday.")
        XCTAssertNil(WritingModel.neighbors(of: "The data came in late.", in: paragraph).before)
    }

    func testPicksTheParagraphThatContainsTheSelection() {
        let text = "First paragraph here.\n\nThe room fell quiet. Then the judge spoke.\nLast paragraph."
        let range = (text as NSString).range(of: "quiet")
        XCTAssertEqual(TextCapture.paragraph(in: text, containing: range), "The room fell quiet. Then the judge spoke.")
        let whole = (text as NSString).range(of: "Last paragraph.")
        XCTAssertNil(TextCapture.paragraph(in: text, containing: whole))
    }
}

final class PartOfSpeechInContextTests: XCTestCase {
    func testTagsTheWordInItsSentence() {
        XCTAssertEqual(TextCapture.partOfSpeech(of: "ran", in: "She ran across the road."), "verb")
        XCTAssertEqual(TextCapture.partOfSpeech(of: "run", in: "We went for a run before work."), "noun")
        XCTAssertEqual(TextCapture.partOfSpeech(of: "quiet", in: "The room fell quiet after the verdict."), "adjective")
    }
}

final class LineContextTests: XCTestCase {
    func testFindsTheLineAndWhetherTheSelectionEndsIt() {
        let poem = "I walked alone beneath the fading light\nAnd wondered where the day had gone"
        let range = (poem as NSString).range(of: "light")
        XCTAssertEqual(TextCapture.line(in: poem, containing: range), "I walked alone beneath the fading light")
        let selection = TextCapture.Selection(text: "light", app: nil, line: "I walked alone beneath the fading light,")
        XCTAssertTrue(selection.endsLine)
        XCTAssertFalse(TextCapture.Selection(text: "fading", app: nil, line: "I walked alone beneath the fading light").endsLine)
    }
}
