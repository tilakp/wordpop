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

    func show(entry: WordEntry, near point: NSPoint) {
        remember(entry)
        viewModel.reset(with: entry)
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
        viewModel.onGoBack = { [weak self] in
            self?.viewModel.goBack()
            if let panel = self?.panel {
                self?.relayout(panel: panel)
            }
        }
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
        newPanel.onSpace = { [weak self] in self?.viewModel.onSpeak() }

        blockSelection = viewModel.$selectedBlock
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, let panel = self.panel, panel.isVisible else { return }
                self.relayout(panel: panel)
            }

        self.hostingController = hostingController
        panel = newPanel
        return newPanel
    }

    /// Centers the panel on the screen containing `point` (the cursor, at
    /// the time the hotkey was pressed). Only used for the initial
    /// appearance — see `relayout` for why later resizes don't re-center.
    private func layOut(panel: PopupPanel, near point: NSPoint) {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = contentSize()
        let topLeft = NSPoint(x: visible.midX - size.width / 2, y: visible.midY + size.height / 2)
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
