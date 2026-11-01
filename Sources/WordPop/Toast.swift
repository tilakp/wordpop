import AppKit
import SwiftUI

/// A short message near the bottom of the screen that goes away by
/// itself: for news the user needs after the popup has closed, such as a
/// paste that could not reach its app.
enum Toast {
    private static var panel: NSPanel?
    private static var hideWork: DispatchWorkItem?

    @MainActor
    static func show(_ message: String, systemImage: String = "doc.on.clipboard") {
        hideWork?.cancel()
        let view = Label(message, systemImage: systemImage)
            .font(.link)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.82), in: Capsule())
            .fixedSize()
        let hosting = NSHostingView(rootView: view)
        hosting.frame.size = hosting.fittingSize

        let panel = Self.panel ?? NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.contentView = hosting
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrame(NSRect(x: frame.midX - hosting.frame.width / 2, y: frame.minY + 80,
                                  width: hosting.frame.width, height: hosting.frame.height), display: true)
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        Self.panel = panel
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let work = DispatchWorkItem {
            if reduceMotion {
                panel.orderOut(nil)
            } else {
                NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; panel.animator().alphaValue = 0 },
                                                     completionHandler: { panel.orderOut(nil) })
            }
        }
        hideWork = work
        // Long enough to read; longer still with VoiceOver speaking it.
        let seconds = NSWorkspace.shared.isVoiceOverEnabled ? 8.0 : max(3.0, Double(message.count) / 15)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}
