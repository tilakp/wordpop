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

    /// Four tints, each with one meaning, dark enough on the paper
    /// background (4.5:1 or more) for small labels and light enough on
    /// the dark one. Words to use are blue-teal, what fits is green, what
    /// to review is amber, and opposites and removals are red. Actions use
    /// the system accent color.
    static let wordTint = dynamic(light: 0x1F6F8B, dark: 0x7CC4D9)
    static let fitTint = dynamic(light: 0x1E7F34, dark: 0x6FD38A)
    static let reviewTint = dynamic(light: 0xA05500, dark: 0xF2B04C)
    static let oppositeTint = dynamic(light: 0xB3261E, dark: 0xFF8A80)

    // The names the sections were built with, each mapped to its meaning.
    static let synonymTint = wordTint
    static let rhymeTint = wordTint
    static let compareTint = wordTint
    static let collocationTint = wordTint
    static let inclusiveTint = wordTint
    static let strongerTint = wordTint
    static let toneTint = wordTint
    static let antonymTint = oppositeTint
    static let confusedTint = reviewTint
    static let spellingTint = reviewTint

    private static func dynamic(light: Int, dark: Int) -> Color {
        func color(_ hex: Int) -> NSColor {
            NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        return Color(NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? color(dark) : color(light)
        }))
    }
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
    static var pillLabel: Font { scaled(10, design: .serif).italic() }
    static var origin: Font { scaled(12.5, design: .serif) }
    static var phrase: Font { scaled(13.5, weight: .semibold, design: .serif) }
    static var searchField: Font { scaled(20, design: .serif) }
    static var recentWord: Font { scaled(14, design: .serif) }
    static var recentMeta: Font { scaled(11) }
    /// Links and action chips.
    static var link: Font { scaled(12, weight: .medium) }
    /// A symbol in a button, at `size` points before the Text Size scale.
    static func icon(_ size: CGFloat, weight: Font.Weight = .regular) -> Font { scaled(size, weight: weight) }
}

// MARK: Components shared by the popup, the notes and Quick Search

/// A section's title: small gray capitals. Color goes on the chips, not
/// on the labels.
struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.sectionLabel)
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A word to use, in the serif: a synonym, a rhyme, a fix. Selected or
/// focused chips get a stronger fill and a border; a chosen fix also gets
/// a checkmark, so the choice does not rest on color alone.
struct WordChip: View {
    let text: String
    var tint: Color = .wordTint
    /// A register or "rare" tag after the word, in small italics.
    var label: String? = nil
    var selected = false
    var checked = false
    var italic = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if checked {
                Image(systemName: "checkmark")
                    .font(.icon(9, weight: .bold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(.pill)
                .italic(italic)
                .foregroundStyle(.primary)
            if let label {
                Text(label)
                    .font(.pillLabel)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tint.opacity(selected ? 0.22 : 0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(selected ? tint : Color.clear, lineWidth: 1))
        .contentShape(Capsule())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A command, in the system font: a tool, a tone, a text change. One
/// neutral style, filled more when it is open.
struct ActionChip: View {
    let title: String
    var isOn = false

    var body: some View {
        Text(title)
            .font(.link)
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(isOn ? 0.13 : 0.06), in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 1))
            .contentShape(Capsule())
            .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A plain action in the accent color: "More examples", "Replace".
struct TextLink: View {
    let title: String
    let action: () -> Void
    var muted = false

    init(_ title: String, muted: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.muted = muted
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.link)
                .foregroundStyle(muted ? Color.secondary : Color.accentColor)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A row that opens and closes a part below it: "Origin ›".
struct DisclosureRow: View {
    let title: String
    let expanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.link)
                    .foregroundStyle(.primary)
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.icon(9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(expanded ? "expanded" : "collapsed")
    }
}

/// A note section's title with its short guide behind an info button,
/// which shows while the pointer is over the title or the guide is open.
struct NoteSectionHeader: View {
    let title: String
    let guide: String?
    let isOpen: Bool
    let toggle: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 5) {
            SectionLabel(title: title)
            if guide != nil {
                Button(action: toggle) {
                    Image(systemName: isOpen ? "info.circle.fill" : "info.circle")
                        .font(.icon(11))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 20, minHeight: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(hovering || isOpen ? 1 : 0)
                .help("What this note means")
                .accessibilityLabel("About \(title)")
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}
