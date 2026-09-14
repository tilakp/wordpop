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

enum Settings {
    static let textSizeKey = "WordPop.textSize"
    static let popupPlacementKey = "WordPop.popupPlacement"

    static var textSize: TextSize {
        UserDefaults.standard.string(forKey: textSizeKey).flatMap(TextSize.init) ?? .medium
    }

    static var popupPlacement: PopupPlacement {
        UserDefaults.standard.string(forKey: popupPlacementKey).flatMap(PopupPlacement.init) ?? .center
    }

    static var textScale: CGFloat { textSize.scale }
}
