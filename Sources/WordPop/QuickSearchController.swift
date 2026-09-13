import AppKit
import SwiftUI

/// Owns the Spotlight-style search bar: invoked without needing a prior
/// text selection, for looking up any word directly. Positioned near the
/// top third of the screen (like Spotlight/Alfred), distinct from the
/// lookup popup's screen-centered position, so the two don't visually
/// collide when the search bar hands off to the result popup.
final class QuickSearchController: NSObject, NSWindowDelegate {
    private var panel: QuickSearchPanel?
    private var hostingController: NSHostingController<QuickSearchView>?
    private let onSubmit: (String) -> Void

    init(onSubmit: @escaping (String) -> Void) {
        self.onSubmit = onSubmit
    }

    func show() {
        let panel = ensurePanel()
        layOut(panel: panel)

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
            guard let panel, panel.alphaValue == 0 else { return }
            panel.orderOut(nil)
        })
    }

    private func ensurePanel() -> QuickSearchPanel {
        if let panel { return panel }

        let hostingController = NSHostingController(rootView: QuickSearchView(onSubmit: { [weak self] word in
            self?.onSubmit(word)
            self?.hide()
        }))
        let newPanel = QuickSearchPanel(contentViewController: hostingController)
        newPanel.styleMask = [.nonactivatingPanel, .borderless]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.level = .floating
        newPanel.hidesOnDeactivate = false
        newPanel.isReleasedWhenClosed = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.delegate = self
        newPanel.onEscape = { [weak self] in self?.hide() }

        self.hostingController = hostingController
        panel = newPanel
        return newPanel
    }

    private func layOut(panel: QuickSearchPanel) {
        let point = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let size = hostingController?.sizeThatFits(in: NSSize(width: QuickSearchView.width, height: .greatestFiniteMagnitude))
            ?? NSSize(width: QuickSearchView.width, height: 60)

        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + visible.height * 0.68 - size.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
