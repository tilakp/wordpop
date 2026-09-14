import Foundation

struct Phrase: Equatable {
    let phrase: String
    let definition: String
    let example: String?
}

enum PhraseParser {
    static func phrases(in markup: String) -> [Phrase] {
        EntryMarkupParser.parse(markup)?.phrases ?? []
    }
}
