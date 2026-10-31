import Foundation

enum TextSize: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var scale: CGFloat {
        switch self {
        case .small: 0.9
        case .medium: 1.0
        case .large: 1.15
        }
    }
}

enum PopupPlacement: String, CaseIterable, Identifiable {
    case center, cursor

    var id: String { rawValue }
    var label: String {
        switch self {
        case .center: "Center of screen"
        case .cursor: "Near the mouse pointer"
        }
    }
}

/// A part of the popup the user can hide in Preferences.
enum PopupSection: String, CaseIterable, Identifiable {
    case fits, synonyms, antonyms, specific, family, stronger, inclusive, confused, rhymes, tone, collocations, examples, usage, phrases, origin

    var id: String { rawValue }
    var label: String {
        switch self {
        case .fits: "Fits your sentence"
        case .synonyms: "Synonyms"
        case .antonyms: "Antonyms"
        case .specific: "More specific words"
        case .family: "Word family"
        case .stronger: "Stronger words"
        case .inclusive: "Inclusive alternatives"
        case .confused: "Often confused"
        case .rhymes: "Rhymes"
        case .tone: "Tone buttons"
        case .collocations: "What goes with"
        case .examples: "More examples"
        case .usage: "Usage notes"
        case .phrases: "Phrases"
        case .origin: "Origin"
        }
    }

    /// The section a pill row belongs to; "Did you mean" has none and
    /// always shows.
    init?(pillSectionID id: String) {
        switch id {
        case "lineRhymes": self = .rhymes
        default: self.init(rawValue: id)
        }
    }
}

/// A part of the notes on a selected passage the user can hide in
/// Preferences. Spelling and grammar always show.
enum PassageSection: String, CaseIterable, Identifiable {
    case tools, consistency, wordy, rhythm, longSentences, passive, crutches, adverbs, hedges, repeated

    /// Kept in the same hidden list as the popup's sections, apart by name.
    var id: String { "passage." + rawValue }
    var label: String {
        switch self {
        case .tools: "Tools"
        case .consistency: "Consistency"
        case .wordy: "Wordy phrases"
        case .rhythm: "Sentence rhythm"
        case .longSentences: "Long sentences"
        case .passive: "Passive voice"
        case .crutches: "Crutch words"
        case .adverbs: "Adverbs"
        case .hedges: "Hedges and filler"
        case .repeated: "Repeated words"
        }
    }
}

enum Settings {
    static let textSizeKey = "WordPop.textSize"
    static let popupPlacementKey = "WordPop.popupPlacement"
    static let hiddenSectionsKey = "WordPop.hiddenSections"
    /// The reading grade passages should not go above; 0 for none.
    static let targetGradeKey = "WordPop.targetGrade"

    static var targetGrade: Int? {
        let grade = UserDefaults.standard.integer(forKey: targetGradeKey)
        return grade > 0 ? grade : nil
    }

    static var hiddenSections: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: hiddenSectionsKey) ?? []) }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: hiddenSectionsKey) }
    }

    static func shows(_ section: PopupSection) -> Bool {
        !hiddenSections.contains(section.rawValue)
    }

    static func shows(_ section: PassageSection) -> Bool {
        !hiddenSections.contains(section.id)
    }

    static var textSize: TextSize {
        UserDefaults.standard.string(forKey: textSizeKey).flatMap(TextSize.init) ?? .medium
    }

    static var popupPlacement: PopupPlacement {
        UserDefaults.standard.string(forKey: popupPlacementKey).flatMap(PopupPlacement.init) ?? .center
    }

    static var textScale: CGFloat { textSize.scale }
}
