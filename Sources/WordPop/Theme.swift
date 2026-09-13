import SwiftUI
import AppKit

/// A solid "page" background — plain white in light mode, near-black in
/// dark mode — used by both the lookup popup and the quick-search bar,
/// instead of a frosted/vibrancy material.
extension Color {
    static let popupPage = Color(NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? NSColor(white: 0.11, alpha: 1) : NSColor.white
    }))
}
