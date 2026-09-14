import SwiftUI
import AppKit

/// A solid "page" background — warm off-white in light mode, warm near-black
/// in dark mode — used by both the lookup popup and the quick-search bar,
/// instead of a frosted/vibrancy material.
extension Color {
    static let popupPage = Color(NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark
            ? NSColor(red: 0.110, green: 0.108, blue: 0.102, alpha: 1)
            : NSColor(red: 0.992, green: 0.988, blue: 0.976, alpha: 1)
    }))

    static let synonymTint = Color.teal
    static let antonymTint = Color.pink
    static let rhymeTint = Color.indigo
}

/// Editorial type scale: the headword and quoted examples set in the system
/// serif (New York), everything else in SF for legibility at small sizes.
/// Sizes follow the Text Size preference; they are read on each access so
/// the next popup picks up a change.
extension Font {
    private static func scaled(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: size * Settings.textScale, weight: weight, design: design)
    }

    static var headword: Font { scaled(30, weight: .semibold, design: .serif) }
    static var partOfSpeech: Font { scaled(14, design: .serif).italic() }
    static var pronunciation: Font { scaled(13, design: .monospaced) }
    static var forms: Font { scaled(12, design: .serif).italic() }
    static var definition: Font { scaled(13.5) }
    static var senseNumber: Font { scaled(12, weight: .semibold, design: .serif) }
    static var example: Font { scaled(13, design: .serif).italic() }
    static var sectionLabel: Font { scaled(10.5, weight: .semibold) }
    static var pill: Font { scaled(12.5, design: .serif) }
    static var origin: Font { scaled(12.5, design: .serif) }
    static var phrase: Font { scaled(13.5, weight: .semibold, design: .serif) }
    static var searchField: Font { scaled(20, design: .serif) }
    static var recentWord: Font { scaled(14, design: .serif) }
    static var recentMeta: Font { scaled(11) }
}
