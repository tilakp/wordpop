import XCTest
@testable import WordPop

final class InflectionTests: XCTestCase {
    private let runForms = ["runs", "running", "past ran", "past participle run"]
    private let forms: [String: [String]] = [
        "tear": ["past tore", "past participle torn"],
        "make": ["past and past participle made"],
        "flee": ["flees", "fleeing", "past and past participle fled"],
        "kid": ["kids", "kidding", "kidded"],
        "big": ["bigger", "biggest"],
    ]

    private func replace(_ selection: String, lemma: String, lemmaForms: [String] = [], with word: String) -> String {
        TextReplacer.replacement(in: selection, with: word, lemma: lemma, lemmaForms: lemmaForms) { self.forms[$0] ?? [] }
    }

    func testFindsTheFormOfTheSelection() {
        XCTAssertEqual(Inflection.form(of: "ran", lemma: "run", forms: runForms), .past)
        XCTAssertEqual(Inflection.form(of: "running", lemma: "run", forms: runForms), .ing)
        XCTAssertEqual(Inflection.form(of: "runs", lemma: "run", forms: runForms), .s)
        XCTAssertEqual(Inflection.form(of: "walked", lemma: "walk", forms: []), .past)
        XCTAssertEqual(Inflection.form(of: "hurries", lemma: "hurry", forms: []), .s)
        XCTAssertEqual(Inflection.form(of: "children", lemma: "child", forms: ["plural children"]), .s)
        XCTAssertEqual(Inflection.form(of: "quieter", lemma: "quiet", forms: ["quieter", "quietest"]), .comparative)
        XCTAssertEqual(Inflection.form(of: "run", lemma: "run", forms: runForms), .plain)
    }

    func testRegularSpelling() {
        XCTAssertEqual(Inflection.regular("sprint", .past), "sprinted")
        XCTAssertEqual(Inflection.regular("race", .ing), "racing")
        XCTAssertEqual(Inflection.regular("stop", .ing), "stopping")
        XCTAssertEqual(Inflection.regular("dash", .s), "dashes")
        XCTAssertEqual(Inflection.regular("hurry", .past), "hurried")
        XCTAssertEqual(Inflection.regular("calm", .comparative), "calmer")
        XCTAssertEqual(Inflection.regular("careful", .comparative), "more careful")
        XCTAssertEqual(Inflection.regular("tie", .ing), "tying")
    }

    func testReplacementTakesTheSelectionsForm() {
        XCTAssertEqual(replace("ran", lemma: "run", lemmaForms: runForms, with: "sprint"), "sprinted")
        XCTAssertEqual(replace("Running,", lemma: "run", lemmaForms: runForms, with: "race"), "Racing,")
        XCTAssertEqual(replace("ran", lemma: "run", lemmaForms: runForms, with: "flee"), "fled")
        XCTAssertEqual(replace("ran", lemma: "run", lemmaForms: runForms, with: "make off"), "made off")
        XCTAssertEqual(replace("children", lemma: "child", lemmaForms: ["plural children"], with: "kid"), "kids")
        XCTAssertEqual(replace("quieter", lemma: "quiet", lemmaForms: ["quieter", "quietest"], with: "calm"), "calmer")
        XCTAssertEqual(replace("quiet", lemma: "quiet", with: "hushed"), "hushed")
    }
}
