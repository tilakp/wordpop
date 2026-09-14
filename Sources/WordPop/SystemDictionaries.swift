import CoreServices
import Foundation

// Dictionary Services only documents DCSCopyTextDefinition against the
// default dictionary. These enumerate the installed and user-enabled
// dictionaries (the same list Dictionary.app shows in its preferences) so
// the Thesaurus and bilingual dictionaries can be queried directly. They
// have been stable since 10.6 and are widely used outside the App Store.
@_silgen_name("DCSCopyAvailableDictionaries") private func DCSCopyAvailableDictionaries() -> Unmanaged<CFSet>
@_silgen_name("DCSGetActiveDictionaries") private func DCSGetActiveDictionaries() -> Unmanaged<CFArray>
@_silgen_name("DCSDictionaryGetName") private func DCSDictionaryGetName(_ dictionary: DCSDictionary) -> Unmanaged<CFString>
@_silgen_name("DCSDictionaryGetIdentifier") private func DCSDictionaryGetIdentifier(_ dictionary: DCSDictionary) -> Unmanaged<CFString>
@_silgen_name("DCSCopyRecordsForSearchString") private func DCSCopyRecordsForSearchString(
    _ dictionary: DCSDictionary, _ string: CFString, _ method: Int, _ maxResults: Int
) -> Unmanaged<CFArray>?
@_silgen_name("DCSRecordCopyData") private func DCSRecordCopyData(_ record: AnyObject, _ format: Int) -> Unmanaged<CFString>?
@_silgen_name("DCSRecordGetHeadword") private func DCSRecordGetHeadword(_ record: AnyObject) -> Unmanaged<CFString>?

enum SystemDictionaries {
    static let thesaurusIdentifiers = ["com.apple.dictionary.OAWT", "com.apple.dictionary.OTE"]
    private static let englishIdentifiers: Set<String> = [
        "com.apple.dictionary.NOAD", "com.apple.dictionary.ODE", "com.apple.dictionary.OAWT",
        "com.apple.dictionary.OTE", "com.apple.dictionary.AppleDictionary", "com.apple.dictionary.Wikipedia",
    ]

    static let thesaurus: DCSDictionary? = {
        let available = DCSCopyAvailableDictionaries().takeRetainedValue() as? Set<DCSDictionary> ?? []
        for identifier in thesaurusIdentifiers {
            if let match = available.first(where: { Self.identifier(of: $0) == identifier }) {
                return match
            }
        }
        return nil
    }()

    /// Dictionaries the user has enabled in Dictionary.app, minus the
    /// English ones WordPop already covers — in practice the bilingual
    /// dictionaries, tried in the user's preferred order.
    static let fallbacks: [DCSDictionary] = {
        let active = DCSGetActiveDictionaries().takeUnretainedValue() as? [DCSDictionary] ?? []
        return active.filter { !englishIdentifiers.contains(identifier(of: $0)) }
    }()

    /// The default English dictionary (NOAD, or ODE on British systems),
    /// needed because record lookups require an explicit dictionary.
    static let english: DCSDictionary? = {
        let active = DCSGetActiveDictionaries().takeUnretainedValue() as? [DCSDictionary] ?? []
        return active.first { ["com.apple.dictionary.NOAD", "com.apple.dictionary.ODE"].contains(identifier(of: $0)) }
    }()

    /// The entries for `word` as the dictionary's own XHTML markup, which
    /// keeps the structure (phrase sub-entries, definitions, examples) that
    /// the flat text from DCSCopyTextDefinition throws away. An exact-match
    /// search also returns entries like "Child, Julia" for "child" and the
    /// homographs "lead" (verb) and "lead" (metal); only records whose
    /// headword is exactly `word` are kept, and all of them are returned.
    static func entryMarkups(of word: String, in dictionary: DCSDictionary) -> [String] {
        guard let records = DCSCopyRecordsForSearchString(dictionary, word as CFString, 0, 8)?.takeRetainedValue() as? [AnyObject] else {
            return []
        }
        return records.compactMap { record in
            guard let headword = DCSRecordGetHeadword(record)?.takeUnretainedValue() as String?, headword == word else { return nil }
            return DCSRecordCopyData(record, 0)?.takeRetainedValue() as String?
        }
    }

    static func name(of dictionary: DCSDictionary) -> String {
        DCSDictionaryGetName(dictionary).takeUnretainedValue() as String
    }

    static func identifier(of dictionary: DCSDictionary) -> String {
        DCSDictionaryGetIdentifier(dictionary).takeUnretainedValue() as String
    }

    static func definition(of word: String, in dictionary: DCSDictionary?) -> String? {
        let cfWord = word as CFString
        let range = CFRange(location: 0, length: CFStringGetLength(cfWord))
        return DCSCopyTextDefinition(dictionary, cfWord, range)?.takeRetainedValue() as String?
    }
}
