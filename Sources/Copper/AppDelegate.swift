import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let store = CopperStore()

    private var panelController: CopperPanelController!
    private var captureService: CaptureService!
    private var notesKeyMonitor: NotesKeyMonitor!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panelController = CopperPanelController(store: Self.store)
        captureService = CaptureService(store: Self.store) { [weak self] in
            self?.panelController.show(animated: false)
        }
        captureService.start()
        notesKeyMonitor = NotesKeyMonitor(targetWindow: panelController.window)
        notesKeyMonitor.start()
        configureStatusItem()
        panelController.show()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "square.stack.3d.up.fill", accessibilityDescription: "Copper")
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Copper", action: #selector(showCopper), keyEquivalent: " ")
        menu.addItem(withTitle: "Capture Selected Text", action: #selector(captureSelectedText), keyEquivalent: "")
        menu.addItem(withTitle: "New Longform Note…", action: #selector(newLongform), keyEquivalent: "")
        menu.addItem(withTitle: "New Section…", action: #selector(newSection), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Reveal Notes File", action: #selector(revealNotes), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Copper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func showCopper() { panelController.show() }

    @objc private func captureSelectedText() { captureService.captureSelection() }

    @objc private func newLongform() {
        panelController.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            NotificationCenter.default.post(name: .copperNewLongform, object: nil)
        }
    }

    @objc private func newSection() {
        panelController.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            NotificationCenter.default.post(name: .copperNewSection, object: nil)
        }
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func revealNotes() {
        NSWorkspace.shared.activateFileViewerSelecting([Self.store.fileURL])
    }
}

@MainActor
final class CopperPanelController: NSWindowController, NSWindowDelegate {
    init(store: CopperStore) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 700),
            styleMask: [.titled, .fullSizeContentView, .resizable, .closable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 360, height: 480)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: ContentView().environmentObject(store))
        super.init(window: panel)
        panel.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(animated: Bool = true) {
        guard let panel = window else { return }
        guard !panel.isVisible else {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: frame.maxX - panel.frame.width - 18,
                y: frame.midY - panel.frame.height / 2
            ))
        }

        guard animated else {
            panel.alphaValue = 1
            NSApp.unhide(nil)
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .copperFocusComposer, object: nil)
            return
        }

        let restingFrame = panel.frame
        let startFrame = restingFrame.offsetBy(dx: 0, dy: -8)
        panel.alphaValue = 0
        panel.setFrame(startFrame, display: false)

        NSApp.unhide(nil)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(restingFrame, display: true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: .copperFocusComposer, object: nil)
        }
    }

    func hide(completion: (() -> Void)? = nil) {
        guard let panel = window, panel.isVisible else {
            completion?()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
            completion?()
        }
    }

    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }
}
