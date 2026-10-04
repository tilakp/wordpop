import AppKit
import NaturalLanguage

/// Captures the currently selected text in whatever app is frontmost.
///
/// First choice is the Accessibility API: the focused element's
/// AXSelectedText, which native apps (Safari, Mail, Notes, Xcode, most
/// Chromium browsers) expose and which touches nothing. Apps that don't
/// (many Electron apps, terminals, remote desktops) fall back to simulating
/// Cmd+C and reading the clipboard, then restoring it. Both need
/// Accessibility permission.
///
/// The clipboard route is the same technique PopClip and Alfred use, and
/// has an inherent, hard-to-close race: if the frontmost app is slow to
/// write its own copy, our restore can land before that copy does and
/// overwrite the user's clipboard with stale content. The brief extra wait
/// below narrows that window but can't eliminate it.
enum TextCapture {
    /// The selection as the app holds it (untrimmed, so a replacement can
    /// keep its spacing) and the app it came from.
    struct Selection {
        let text: String
        let app: NSRunningApplication?
        /// The sentence the selection sits in, when the app exposes the
        /// surrounding text through Accessibility.
        var sentence: String? = nil
        /// The line (up to the line breaks) the selection sits in, for
        /// poems and lyrics, whose lines often have no punctuation.
        var line: String? = nil

        /// Whether the selection is the last word of its line, the word a
        /// songwriter rhymes.
        var endsLine: Bool {
            guard let line else { return false }
            let words = line.split(whereSeparator: \.isWhitespace)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }
            return words.last?.caseInsensitiveCompare(trimmed.trimmingCharacters(in: .punctuationCharacters)) == .orderedSame
        }

        var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    static func captureSelection() async -> Selection? {
        let app = NSWorkspace.shared.frontmostApplication
        if let (selected, element) = accessibilitySelection(), !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let context = context(around: element)
            return Selection(text: selected, app: app, sentence: context?.sentence, line: context?.line)
        }
        guard let copied = await clipboardSelectedText() else { return nil }
        // Code editors (VS Code, JetBrains) copy the whole current line,
        // with its line break, when nothing is selected. A selected word
        // never ends in a line break, so such a copy is not a lookup.
        if copied.hasSuffix("\n") || copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        return Selection(text: copied, app: app)
    }

    private static func accessibilitySelection() -> (String, AXUIElement)? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success else {
            return nil
        }
        return (value as? String).map { ($0, element) }
    }

    /// Reads up to 300 characters on each side of the selection and keeps
    /// the sentence and the line that contain it.
    private static func context(around element: AXUIElement) -> (sentence: String?, line: String?)? {
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        var selected = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &selected) else { return nil }
        var countValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXNumberOfCharactersAttribute as CFString, &countValue)
        let total = (countValue as? Int) ?? selected.location + selected.length
        let start = max(0, selected.location - 300)
        var window = CFRange(location: start, length: min(total, selected.location + selected.length + 300) - start)
        guard let parameter = AXValueCreate(.cfRange, &window) else { return nil }
        var text: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXStringForRangeParameterizedAttribute as CFString, parameter, &text
        ) == .success, let text = text as? String else { return nil }
        let range = NSRange(location: selected.location - start, length: selected.length)
        return (sentence(in: text, containing: range), line(in: text, containing: range))
    }

    /// The line of `text` (between line breaks) that contains `range`.
    static func line(in text: String, containing range: NSRange) -> String? {
        let ns = text as NSString
        guard range.location <= ns.length else { return nil }
        let lineRange = ns.lineRange(for: NSRange(location: range.location, length: 0))
        let line = ns.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
        return line.isEmpty ? nil : line
    }

    /// The part of speech `word` has in `sentence`, as the dictionary
    /// names it ("verb" for "ran" in "She ran across the road").
    static func partOfSpeech(of word: String, in sentence: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = sentence
        var found: String?
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            guard sentence[range].caseInsensitiveCompare(word) == .orderedSame else { return true }
            found = [NLTag.noun: "noun", .verb: "verb", .adjective: "adjective", .adverb: "adverb"][tag ?? .otherWord]
            return false
        }
        return found
    }

    /// The sentence of `text` that contains `range` (UTF-16 offsets).
    static func sentence(in text: String, containing range: NSRange) -> String? {
        guard let target = Range(range, in: text) else { return nil }
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        let sentence = tokenizer.tokens(for: text.startIndex..<text.endIndex)
            .first { $0.contains(target.lowerBound) || $0.upperBound == target.lowerBound && target.isEmpty }
        return sentence.map { text[$0].trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func clipboardSelectedText() async -> String? {
        let pasteboard = NSPasteboard.general
        let saved = Clipboard.snapshot()
        let priorChangeCount = pasteboard.changeCount

        simulateKey(0x08) // 'C'

        guard await waitForPasteboardChange(from: priorChangeCount, timeout: 0.3) else { return nil }
        let result = pasteboard.string(forType: .string)
        let changeCountAfterRead = pasteboard.changeCount

        // Give a slow app's own copy a brief extra moment to land before
        // restoring, so we don't clobber it (see doc comment above).
        try? await Task.sleep(nanoseconds: 60_000_000)
        if pasteboard.changeCount == changeCountAfterRead {
            Clipboard.restore(saved)
        }

        return result
    }

    /// Posts Command plus the given key: 0x08 is C, 0x09 is V.
    ///
    /// The key is wrapped in its own Command down and up, posted from a
    /// private event source. Posting only the flagged key from the HID
    /// system source left Command held in the system's modifier state, so
    /// the user's next keystrokes arrived as Command shortcuts and the
    /// lookup shortcut stopped matching.
    static func simulateKey(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .privateState)
        let command: CGKeyCode = 0x37
        let events: [(CGKeyCode, Bool, CGEventFlags)] = [
            (command, true, .maskCommand), (keyCode, true, .maskCommand),
            (keyCode, false, .maskCommand), (command, false, []),
        ]
        for (key, isDown, flags) in events {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }

    private static func waitForPasteboardChange(from priorChangeCount: Int, timeout: TimeInterval) async -> Bool {
        let pasteboard = NSPasteboard.general
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if pasteboard.changeCount != priorChangeCount {
                return true
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return false
    }
}

/// Saves and restores every item and type on the general pasteboard, so an
/// image, a file or rich text comes back intact, not only plain text.
enum Clipboard {
    typealias Snapshot = [[(NSPasteboard.PasteboardType, Data)]]

    static func snapshot() -> Snapshot {
        NSPasteboard.general.pasteboardItems?.map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        } ?? []
    }

    static func restore(_ snapshot: Snapshot) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(snapshot.map { types in
            let item = NSPasteboardItem()
            for (type, data) in types { item.setData(data, forType: type) }
            return item
        })
    }
}
