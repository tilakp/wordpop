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
extension Font {
    static let headword = Font.system(size: 30, weight: .semibold, design: .serif)
    static let partOfSpeech = Font.system(size: 14, design: .serif).italic()
    static let pronunciation = Font.system(size: 13, design: .monospaced)
    static let forms = Font.system(size: 12, design: .serif).italic()
    static let definition = Font.system(size: 13.5)
    static let senseNumber = Font.system(size: 12, weight: .semibold, design: .serif)
    static let example = Font.system(size: 13, design: .serif).italic()
    static let sectionLabel = Font.system(size: 10.5, weight: .semibold)
    static let pill = Font.system(size: 12.5, design: .serif)
    static let origin = Font.system(size: 12.5, design: .serif)
    static let searchField = Font.system(size: 20, design: .serif)
    static let recentWord = Font.system(size: 14, design: .serif)
    static let recentMeta = Font.system(size: 11)
}
