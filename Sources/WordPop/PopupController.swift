import AppKit
import Combine
import SwiftUI

/// Owns the single reusable popup panel: centers it on the screen the
/// cursor is on, animates it in/out, and decides when it should close
/// (Escape always, click-away only when not pinned).
final class PopupController: NSObject, NSWindowDelegate {
    private let viewModel = PopupViewModel()
    private var panel: PopupPanel?
    private var hostingController: NSHostingController<PopupContentView>?
    private var blockSelection: AnyCancellable?
    /// The selection the popup was opened for, which a chosen synonym can
    /// replace; nil for Quick Search lookups.
    private var replaceTarget: TextCapture.Selection?
    /// The entry the selection was looked up as, whose word and forms tell
    /// which form the selection is in ("ran" is the past of "run").
    private var replaceEntry: WordEntry?

    func show(entry: WordEntry, near point: NSPoint, replacing selection: TextCapture.Selection? = nil) {
        remember(entry)
        replaceTarget = selection
        replaceEntry = entry
        viewModel.reset(with: entry)
        viewModel.canReplace = selection != nil
        rankSynonyms(of: entry, for: selection)
        wireViewModelActions()

        let panel = ensurePanel()
        layOut(panel: panel, near: point)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    /// Shows readability notes for a selected passage.
    func show(passage: String, near point: NSPoint) {
        replaceTarget = nil
        viewModel.reset(with: .empty)
        viewModel.canReplace = false
        viewModel.textStats = TextStats.analyze(passage, syllables: { Database.syllables(of: $0) })
        wireViewModelActions()

        let panel = ensurePanel()
        layOut(panel: panel, near: point)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            // Guards against a hide-then-show-again within the fade-out
            // window: if the panel has since been shown again, its alpha
            // will no longer be 0, so this stale completion should not
            // order it back out.
            guard let panel, panel.alphaValue == 0 else { return }
            panel.orderOut(nil)
        })
    }

    /// Asks the on-device model which synonyms fit the sentence the word
    /// was selected in, and shows them when it answers (about a second),
    /// provided the popup still shows the same entry.
    private func rankSynonyms(of entry: WordEntry, for selection: TextCapture.Selection?) {
        guard let selection, let sentence = selection.sentence, WritingModel.isAvailable else { return }
        // Only the part of speech the word has in the sentence: "will" in
        // "I will go" must not get the noun's synonyms (determination).
        let partOfSpeech = TextCapture.partOfSpeech(of: selection.trimmed, in: sentence)
        let matching = entry.blocks.filter { $0.partOfSpeech == partOfSpeech }
        var candidates: [String] = []
        for block in matching.isEmpty ? entry.blocks : matching {
            for word in block.senses.flatMap(\.synonyms) + block.synonyms where !candidates.contains(word) {
                candidates.append(word)
            }
        }
        guard candidates.count > 1 else { return }
        Task { @MainActor in
            let fits = await WritingModel.bestFits(
                for: selection.trimmed, in: sentence, candidates: Array(candidates.prefix(40))
            )
            guard viewModel.entry.word == entry.word, viewModel.bestFits.isEmpty else { return }
            // The new section comes first, so a focused pill's index would
            // now point at another word.
            viewModel.focusedPill = nil
            viewModel.bestFits = Array(fits.prefix(8))
        }
    }

    private func remember(_ entry: WordEntry) {
        guard entry.found else { return }
        LookupHistory.shared.record(entry.word)
    }

    private func wireViewModelActions() {
        viewModel.onClose = { [weak self] in self?.hide() }
        viewModel.onTogglePin = { [weak self] in self?.viewModel.isPinned.toggle() }
        viewModel.onSpeak = { [weak self] in
            guard let word = self?.viewModel.entry.word else { return }
            SpeechHelper.speak(word)
        }
        viewModel.onSelectWord = { [weak self] word in
            let newEntry = DictionaryLookup.lookup(word)
            self?.remember(newEntry)
            self?.viewModel.push(newEntry)
            if let panel = self?.panel {
                self?.relayout(panel: panel)
            }
        }
        viewModel.onReplace = { [weak self] word in
            guard let self, let target = self.replaceTarget else { return }
            self.replaceTarget = nil
            self.hide()
            Task { @MainActor in
                // Let the panel give up key status so the paste lands in
                // the app the selection came from.
                try? await Task.sleep(nanoseconds: 150_000_000)
                let text = TextReplacer.replacement(
                    in: target.text, with: word, lemma: self.replaceEntry?.word, lemmaForms: self.replaceEntry?.forms ?? [],
                    formsOf: { DictionaryLookup.lookup($0).forms }
                )
                await TextReplacer.paste(text, into: target.app)
            }
        }
        viewModel.onCompare = { [weak self] other in
            guard let self else { return }
            let entry = self.viewModel.entry
            let partOfSpeech = self.viewModel.block?.partOfSpeech
            let comparison = Comparison(
                word: entry.word, definition: self.viewModel.block?.items.first?.text,
                other: other, otherDefinition: DictionaryLookup.firstDefinition(of: other, partOfSpeech: partOfSpeech)?.text
            )
            self.viewModel.comparison = comparison
            Task { @MainActor in
                let difference = await WritingModel.difference(
                    between: comparison.word, comparison.definition, and: other, comparison.otherDefinition
                )
                guard self.viewModel.comparison?.other == other, self.viewModel.entry.word == entry.word else { return }
                self.viewModel.comparison?.difference = difference
            }
        }
        viewModel.onLoadCollocations = { [weak self] in
            guard let self, !self.viewModel.isLoadingCollocations else { return }
            let entry = self.viewModel.entry
            self.viewModel.isLoadingCollocations = true
            Task { @MainActor in
                let phrases = await WritingModel.collocations(for: entry.word, partOfSpeech: self.viewModel.block?.partOfSpeech)
                guard self.viewModel.entry.word == entry.word else { return }
                self.viewModel.isLoadingCollocations = false
                self.viewModel.collocations = phrases
            }
        }
        viewModel.onGoBack = { [weak self] in
            self?.viewModel.goBack()
            if let panel = self?.panel {
                self?.relayout(panel: panel)
            }
        }
    }

    /// Keyboard map: Space speaks, ←/→/Tab move through the pills, Return
    /// follows the focused pill, ⌥Return puts it in place of the
    /// selection, ⇧Return compares it with the word, 1-9 switch part of speech, ⌘[ goes back, ⌘D stars the
    /// word, ⌘C copies the word and ⌘⇧C the first definition.
    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "[": viewModel.onGoBack()
            case "d": viewModel.toggleStar()
            case "c": viewModel.copyWord()
            case "C": viewModel.copyDefinition()
            default: return false
            }
            return true
        }
        switch event.keyCode {
        case 49: viewModel.onSpeak() // Space
        case 124: viewModel.moveFocus(by: 1) // →
        case 123: viewModel.moveFocus(by: -1) // ←
        case 48: viewModel.moveFocus(by: flags.contains(.shift) ? -1 : 1) // Tab
        case 36, 76: // Return, Enter; with ⌥, replace the selection; with ⇧, compare
            if flags.contains(.option) {
                viewModel.replaceWithFocusedPill()
            } else if flags.contains(.shift) {
                viewModel.compareWithFocusedPill()
            } else {
                viewModel.followFocusedPill()
            }
        default:
            guard let digit = event.charactersIgnoringModifiers.flatMap(Int.init), (1...9).contains(digit) else { return false }
            viewModel.selectBlock(digit - 1)
        }
        return true
    }

    private func ensurePanel() -> PopupPanel {
        if let panel { return panel }

        let hostingController = NSHostingController(rootView: PopupContentView(viewModel: viewModel))
        let newPanel = PopupPanel(contentViewController: hostingController)
        newPanel.styleMask = [.nonactivatingPanel, .borderless]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.level = .floating
        newPanel.hidesOnDeactivate = false
        newPanel.isMovableByWindowBackground = true
        newPanel.isReleasedWhenClosed = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.delegate = self
        newPanel.onEscape = { [weak self] in self?.hide() }
        newPanel.onKey = { [weak self] event in self?.handleKey(event) ?? false }

        // Every published value that changes the popup's height; each emits
        // its current value on subscription, hence the dropFirst.
        let heightChanges: [AnyPublisher<Void, Never>] = [
            viewModel.$selectedBlock.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$showAllSenses.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$showPhrases.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$showOrigin.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$showUsage.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$bestFits.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$comparison.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$collocations.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$isLoadingCollocations.map { _ in () }.eraseToAnyPublisher(),
        ]
        blockSelection = Publishers.MergeMany(heightChanges)
            .dropFirst(heightChanges.count)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, let panel = self.panel, panel.isVisible else { return }
                self.relayout(panel: panel)
            }

        self.hostingController = hostingController
        panel = newPanel
        return newPanel
    }

    /// Places the panel on the screen containing `point` (the cursor, at
    /// the time the hotkey was pressed): centered, or just below and to the
    /// right of the pointer, per the Popup Position preference. Only used
    /// for the initial appearance — see `relayout` for why later resizes
    /// don't re-place it.
    private func layOut(panel: PopupPanel, near point: NSPoint) {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = contentSize()
        let topLeft: NSPoint
        switch Settings.popupPlacement {
        case .center:
            topLeft = NSPoint(x: visible.midX - size.width / 2, y: visible.midY + size.height / 2)
        case .cursor:
            topLeft = NSPoint(x: point.x + 12, y: point.y - 16)
        }
        applyFrame(panel: panel, topLeft: topLeft, size: size, visible: visible)
    }

    /// Re-sizes the panel to fit its (changed) content, keeping its current
    /// top-left corner fixed rather than re-centering. The panel is
    /// user-movable (`isMovableByWindowBackground`), so re-centering here
    /// would yank it back to the middle of the screen if the user had
    /// dragged it elsewhere.
    private func relayout(panel: PopupPanel) {
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        let size = contentSize()
        let screen = NSScreen.screens.first { $0.frame.contains(topLeft) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        applyFrame(panel: panel, topLeft: topLeft, size: size, visible: visible)
    }

    private func contentSize() -> NSSize {
        let width = PopupContentView.popupWidth
        // View-model changes are applied on the next layout pass; without
        // this flush, sizeThatFits measures the previous word's content.
        hostingController?.view.layoutSubtreeIfNeeded()
        return hostingController?.sizeThatFits(in: NSSize(width: width, height: .greatestFiniteMagnitude))
            ?? NSSize(width: width, height: 160)
    }

    private func applyFrame(panel: PopupPanel, topLeft: NSPoint, size: NSSize, visible: NSRect) {
        let size = NSSize(width: size.width, height: min(size.height, visible.height))
        var origin = NSPoint(x: topLeft.x, y: topLeft.y - size.height)
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !viewModel.isPinned else { return }
        hide()
    }
}
