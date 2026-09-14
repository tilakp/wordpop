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
