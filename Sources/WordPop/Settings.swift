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
    case fits, synonyms, antonyms, stronger, inclusive, confused, rhymes, tone, collocations, examples, usage, phrases, origin

    var id: String { rawValue }
    var label: String {
        switch self {
        case .fits: "Fits your sentence"
        case .synonyms: "Synonyms"
        case .antonyms: "Antonyms"
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

enum Settings {
    static let textSizeKey = "WordPop.textSize"
    static let popupPlacementKey = "WordPop.popupPlacement"
    static let hiddenSectionsKey = "WordPop.hiddenSections"

    static var hiddenSections: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: hiddenSectionsKey) ?? []) }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: hiddenSectionsKey) }
    }

    static func shows(_ section: PopupSection) -> Bool {
        !hiddenSections.contains(section.rawValue)
    }

    static var textSize: TextSize {
        UserDefaults.standard.string(forKey: textSizeKey).flatMap(TextSize.init) ?? .medium
    }

    static var popupPlacement: PopupPlacement {
        UserDefaults.standard.string(forKey: popupPlacementKey).flatMap(PopupPlacement.init) ?? .center
    }

    static var textScale: CGFloat { textSize.scale }
}
