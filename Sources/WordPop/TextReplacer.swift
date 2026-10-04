import AppKit

/// Puts a chosen synonym in place of the word the user looked up, in the
/// app the selection came from. The text goes in through the clipboard and
/// Cmd-V, which works in any editable field; the clipboard is restored
/// afterwards and the temporary item is marked transient so clipboard
/// managers skip it.
enum TextReplacer {
    /// The selection with its looked-up word swapped for `word`, in the
    /// same capitalization and word form: "Quiet," -> "Hushed,", "ran" ->
    /// "sprinted" (when `lemma` is "run"). Text around the word
    /// (punctuation, spacing, the rest of a selected phrase) is kept.
    /// `lemmaForms` is the looked-up entry's form list and `formsOf` gives
    /// any word's, for irregular synonyms ("tear" -> "tore").
    static func replacement(
        in selection: String, with word: String, lemma: String? = nil, lemmaForms: [String] = [],
        formsOf: (String) -> [String] = { _ in [] }
    ) -> String {
        let original = DictionaryLookup.headword(in: selection)
        guard !original.isEmpty, let range = selection.range(of: original, options: .caseInsensitive) else { return word }
        let token = String(selection[range])
        let form = lemma.map { Inflection.form(of: token, lemma: $0, forms: lemmaForms) } ?? .plain
        let inflected = Inflection.inflect(word, as: form, formsOf: formsOf)
        return selection.replacingCharacters(in: range, with: matchingCase(of: token, inflected))
    }

    private static func matchingCase(of original: String, _ word: String) -> String {
        let letters = original.filter(\.isLetter)
        if letters.count > 1, letters == letters.uppercased() { return word.uppercased() }
        if letters.first?.isUppercase == true { return word.prefix(1).uppercased() + word.dropFirst() }
        return word
    }

    /// Pastes `text` into `app` if it is still frontmost; does nothing if
    /// the user has moved to another app since the lookup.
    @MainActor
    static func paste(_ text: String, into app: NSRunningApplication?) async {
        guard let app, NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { return }
        let pasteboard = NSPasteboard.general
        let saved = Clipboard.snapshot()
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        pasteboard.writeObjects([item])
        let changeCount = pasteboard.changeCount

        TextCapture.simulateKey(0x09) // 'V'

        // The target app reads the clipboard when it handles the paste,
        // which can take a moment; restoring sooner would paste the old
        // contents instead.
        try? await Task.sleep(nanoseconds: 500_000_000)
        if pasteboard.changeCount == changeCount {
            Clipboard.restore(saved)
        }
    }
}
