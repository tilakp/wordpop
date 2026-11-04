import AppKit

/// Underlines wordy phrases, cliches and style-rule words in TextEdit and
/// Notes while the user types (beta). macOS underlines spelling and
/// grammar there already; these are the notes it does not give. Pointing
/// at an underline shows the fix.
///
/// It works through Accessibility: the visible text of the focused text
/// area, and the screen bounds of each match, read again every 0.3 s.
/// The underlines are drawn in a click-through window over the text area.
final class LiveCheck {
    static let shared = LiveCheck()
    static let apps: Set<String> = ["com.apple.TextEdit", "com.apple.Notes"]
    private static let key = "WordPop.liveCheck"

    var isOn: Bool {
        get { UserDefaults.standard.bool(forKey: Self.key) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.key)
            apply()
        }
    }

    private var timer: Timer?
    private let overlay = UnderlineWindow()
    private let hint = HintWindow()
    private var pattern: NSRegularExpression?
    private var flags: [String: PhraseFlag] = [:]
    private var lastText = ""
    private var lastLocation = -1
    private var matches: [(range: NSRange, flag: PhraseFlag)] = []
    private var marks: [(rect: NSRect, flag: PhraseFlag)] = []

    /// Starts or stops the timer for the current setting; called at launch.
    func apply() {
        timer?.invalidate()
        timer = nil
        clear()
        guard isOn else { return }
        buildPattern()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in self?.tick() }
    }

    /// One pattern for every phrase, longest first, so a single pass finds
    /// "due to the fact that" and not "the fact that" inside it.
    private func buildPattern() {
        flags = [:]
        for flag in Database.phraseFlags + StyleRules.current.avoid { flags[flag.phrase.lowercased()] = flag }
        pattern = Self.pattern(for: Array(flags.keys))
        lastText = ""
    }

    static func pattern(for phrases: [String]) -> NSRegularExpression? {
        let alternatives = phrases.sorted { $0.count > $1.count }.map(TextStats.wholePhrase)
        return try? NSRegularExpression(pattern: alternatives.joined(separator: "|"), options: .caseInsensitive)
    }

    private func tick() {
        guard let app = NSWorkspace.shared.frontmostApplication, let id = app.bundleIdentifier, Self.apps.contains(id),
              let element = focusedTextArea(of: app), let frame = frame(of: element),
              let visible = visibleRange(of: element), let text = string(of: element, in: visible) else { return clear() }
        if text != lastText || visible.location != lastLocation {
            lastText = text
            lastLocation = visible.location
            matches = pattern?.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).compactMap { match in
                let phrase = (text as NSString).substring(with: match.range).lowercased()
                return flags[phrase].map { (match.range, $0) }
            } ?? []
        }
        // Bounds every time: scrolling and typing above move the words.
        marks = matches.flatMap { match in
            lineRects(of: NSRange(location: visible.location + match.range.location, length: match.range.length), in: element)
                .filter { frame.contains(NSPoint(x: $0.midX, y: $0.midY)) }
                .map { ($0, match.flag) }
        }
        overlay.show(marks.map(\.rect), over: frame)
        let mouse = NSEvent.mouseLocation
        if let mark = marks.first(where: { $0.rect.insetBy(dx: 0, dy: -3).contains(mouse) }) {
            hint.show(Self.hintText(for: mark.flag), above: mark.rect)
        } else {
            hint.orderOut(nil)
        }
    }

    private func clear() {
        lastText = ""
        lastLocation = -1
        matches = []
        marks = []
        overlay.orderOut(nil)
        hint.orderOut(nil)
    }

    static func hintText(for flag: PhraseFlag) -> String {
        let kind = flag.isCliche ? "Clich\u{E9}" : flag.isHiddenVerb ? "Hidden verb" : "Wordy"
        if flag.fix.isEmpty { return flag.isCliche ? "\(kind): say it plainly" : "\(kind): remove \u{201C}\(flag.phrase)\u{201D}" }
        return "\(kind): \(flag.phrase) \u{2192} \(flag.fix)"
    }

    // MARK: Accessibility

    private func focusedTextArea(of app: NSRunningApplication) -> AXUIElement? {
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        return role as? String == kAXTextAreaRole ? element : nil
    }

    private func visibleRange(of element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXVisibleCharacterRangeAttribute as CFString, &value) == .success, let value else { return nil }
        var range = CFRange()
        return AXValueGetValue(value as! AXValue, .cfRange, &range) ? range : nil
    }

    private func string(of element: AXUIElement, in range: CFRange) -> String? {
        var range = range
        guard let rangeValue = AXValueCreate(.cfRange, &range) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString, rangeValue, &value) == .success else { return nil }
        return value as? String
    }

    /// The element's frame in screen coordinates (origin bottom left).
    private func frame(of element: AXUIElement) -> NSRect? {
        var position: CFTypeRef?, size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size else { return nil }
        var point = CGPoint.zero, extent = CGSize.zero
        AXValueGetValue(position as! AXValue, .cgPoint, &point)
        AXValueGetValue(size as! AXValue, .cgSize, &extent)
        return Self.screenRect(CGRect(origin: point, size: extent))
    }

    private func bounds(of range: NSRange, in element: AXUIElement) -> NSRect? {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, rangeValue, &value) == .success,
              let value else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &rect), rect.width > 0 else { return nil }
        return Self.screenRect(rect)
    }

    /// One rectangle per line the range covers. The bounds of a phrase
    /// that wraps cover both lines whole, so then each word is measured
    /// and the words on one line are joined.
    private func lineRects(of range: NSRange, in element: AXUIElement) -> [NSRect] {
        guard let whole = bounds(of: range, in: element),
              let first = bounds(of: NSRange(location: range.location, length: 1), in: element) else { return [] }
        if whole.height < first.height * 1.5 { return [whole] }
        let local = NSRange(location: range.location - lastLocation, length: range.length)
        guard NSMaxRange(local) <= (lastText as NSString).length else { return [] }
        var rects: [NSRect] = []
        (lastText as NSString).enumerateSubstrings(in: local, options: .byWords) { _, wordRange, _, _ in
            guard let rect = self.bounds(of: NSRange(location: wordRange.location + self.lastLocation, length: wordRange.length), in: element) else { return }
            if let last = rects.last, abs(last.minY - rect.minY) < 2 {
                rects[rects.count - 1] = last.union(rect)
            } else {
                rects.append(rect)
            }
        }
        return rects
    }

    /// Accessibility measures from the top left of the main screen; AppKit
    /// from the bottom left.
    private static func screenRect(_ rect: CGRect) -> NSRect {
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        return NSRect(x: rect.minX, y: top - rect.maxY, width: rect.width, height: rect.height)
    }
}

/// A transparent window that lets clicks through and draws a line under
/// each rectangle.
private final class UnderlineWindow: NSPanel {
    private let canvas = UnderlineView()

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        contentView = canvas
    }

    func show(_ rects: [NSRect], over frame: NSRect) {
        guard !rects.isEmpty else { return orderOut(nil) }
        setFrame(frame, display: false)
        canvas.lines = rects.map { NSRect(x: $0.minX - frame.minX, y: $0.minY - frame.minY, width: $0.width, height: $0.height) }
        orderFrontRegardless()
    }
}

private final class UnderlineView: NSView {
    var lines: [NSRect] = [] { didSet { if lines != oldValue { needsDisplay = true } } }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemPurple.withAlphaComponent(0.85).setStroke()
        for rect in lines {
            let path = NSBezierPath()
            path.lineWidth = 2
            path.setLineDash([3, 2], count: 2, phase: 0)
            path.move(to: NSPoint(x: rect.minX, y: rect.minY + 1))
            path.line(to: NSPoint(x: rect.maxX, y: rect.minY + 1))
            path.stroke()
        }
    }
}

/// The fix for the underline under the pointer, in a small label above it.
private final class HintWindow: NSPanel {
    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        level = .floating
        let box = NSVisualEffectView()
        box.material = .toolTip
        box.state = .active
        box.wantsLayer = true
        box.layer?.cornerRadius = 6
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -4),
        ])
        contentView = box
    }

    func show(_ text: String, above rect: NSRect) {
        if label.stringValue != text { label.stringValue = text }
        let size = contentView?.fittingSize ?? .zero
        setFrame(NSRect(x: rect.minX, y: rect.maxY + 4, width: size.width, height: size.height), display: true)
        orderFrontRegardless()
    }
}
