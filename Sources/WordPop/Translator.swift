import AppKit
import NaturalLanguage
#if canImport(Translation)
import Translation
#endif

/// Translation with Apple's on-device Translation framework (macOS 26 or
/// later). Each language is downloaded once by macOS, in System Settings >
/// General > Language & Region > Translation Languages; after that it
/// works offline. WordPop itself makes no network call.
enum Translator {
    enum Outcome: Equatable {
        case translated(String)
        /// The language pair is supported but not downloaded; the
        /// associated value names the missing language.
        case notInstalled(String)
        case failed(String)
    }

    static var isAvailable: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    static let targetKey = "WordPop.translateTarget"

    /// The language to translate into, as an identifier ("es").
    static var target: String {
        get { UserDefaults.standard.string(forKey: targetKey) ?? "es" }
        set { UserDefaults.standard.set(newValue, forKey: targetKey) }
    }

    static func name(of identifier: String) -> String {
        Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }

    /// The language `text` is most likely in, as an identifier ("en").
    static func language(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    /// The languages the framework can translate into, by name.
    static func targets() async -> [(id: String, name: String)] {
        #if canImport(Translation)
        if #available(macOS 26, *) {
            let languages = await LanguageAvailability().supportedLanguages
            return languages.map { ($0.minimalIdentifier, name(of: $0.minimalIdentifier)) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        #endif
        return []
    }

    static func translate(_ text: String, to target: String) async -> Outcome {
        guard let source = language(of: text) else { return .failed("Could not tell what language the text is in.") }
        guard Locale.Language(identifier: source).minimalIdentifier != Locale.Language(identifier: target).minimalIdentifier else {
            return .failed("The text is already in \(name(of: target)).")
        }
        #if canImport(Translation)
        if #available(macOS 26, *) {
            let from = Locale.Language(identifier: source), to = Locale.Language(identifier: target)
            switch await LanguageAvailability().status(from: from, to: to) {
            case .unsupported: return .failed("Translation from \(name(of: source)) to \(name(of: target)) is not supported.")
            case .supported: return .notInstalled([name(of: source), name(of: target)].joined(separator: " and "))
            case .installed: break
            @unknown default: break
            }
            do {
                return .translated(try await TranslationSession(installedSource: from, target: to).translate(text).targetText)
            } catch {
                return .failed("The translation did not work: \(error.localizedDescription)")
            }
        }
        #endif
        return .failed("Translation needs macOS 26 or later.")
    }

    /// Opens Language & Region in System Settings, where translation
    /// languages are downloaded.
    static func openLanguageSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
