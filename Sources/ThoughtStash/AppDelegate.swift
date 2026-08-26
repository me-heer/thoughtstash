import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let store = StashStore()

    private var panelController: StashPanelController!
    private var captureService: CaptureService!
    private var notesKeyMonitor: NotesKeyMonitor!
    private var statusItem: NSStatusItem?
    private var zenLabController: ZenLabController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        // Design storybook for the focus-mode iterations. Replaces the panel for this run
        // so the variants can be compared without capture, hotkeys, or the notes file.
        if ProcessInfo.processInfo.arguments.contains("--zen-lab")
            || ProcessInfo.processInfo.environment["THOUGHTSTASH_ZEN_LAB"] == "1" {
            zenLabController = ZenLabController()
            zenLabController?.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        panelController = StashPanelController(store: Self.store)
        captureService = CaptureService(
            store: Self.store,
            shouldFocusComposer: { [weak self] in
                self?.panelController.window?.isKeyWindow == true
            },
            showPanel: { [weak self] in
                self?.panelController.show(animated: false)
            }
        )
        captureService.start()
        notesKeyMonitor = NotesKeyMonitor(targetWindow: panelController.window)
        notesKeyMonitor.start()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusItemVisibility),
            name: .stashMenuBarVisibilityChanged,
            object: nil
        )
        updateStatusItemVisibility()
        panelController.show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panelController.show()
        return true
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = StatusItemGlyph.image()
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Thought Stash", action: #selector(showThoughtStash), keyEquivalent: " ")
        menu.addItem(withTitle: "Capture Selected Text", action: #selector(captureSelectedText), keyEquivalent: "")
        menu.addItem(withTitle: "New Note…", action: #selector(newNote), keyEquivalent: "")
        menu.addItem(withTitle: "New Section…", action: #selector(newSection), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Reveal Notes File", action: #selector(revealNotes), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Thought Stash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func updateStatusItemVisibility() {
        if Self.store.showsMenuBarItem {
            if statusItem == nil { configureStatusItem() }
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    @objc private func showThoughtStash() { panelController.show() }

    @objc private func captureSelectedText() { captureService.captureSelection() }

    @objc private func newNote() {
        panelController.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            NotificationCenter.default.post(name: .stashNewNote, object: nil)
        }
    }

    @objc private func newSection() {
        panelController.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            NotificationCenter.default.post(name: .stashNewSection, object: nil)
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
final class StashPanelController: NSWindowController, NSWindowDelegate {
    init(store: StashStore) {
        let panel = NSWindow(
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
        panel.level = .normal
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.managed, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 360, height: 480)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        let host = NSHostingView(rootView: ContentView().environmentObject(store))
        // `.fullSizeContentView` lets content draw under the title bar, but the hosting
        // view still insets for it, which leaves a title-bar-sized gap above the header.
        // There are no window controls to avoid — they're all hidden — so drop the inset.
        host.safeAreaRegions = []
        panel.contentView = host
        super.init(window: panel)
        panel.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(animated: Bool = true) {
        guard let panel = window else { return }
        guard !panel.isVisible else {
            reveal(panel)
            focusComposer()
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
            reveal(panel)
            focusComposer()
            return
        }

        let restingFrame = panel.frame
        let startFrame = restingFrame.offsetBy(dx: 0, dy: -8)
        panel.alphaValue = 0
        panel.setFrame(startFrame, display: false)

        reveal(panel)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(restingFrame, display: true)
        }

        focusComposer()
    }

    private func reveal(_ panel: NSWindow) {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        // Status-menu actions run while AppKit is dismissing the menu. Reasserting the
        // window on the next run loop prevents that teardown from swallowing the show.
        DispatchQueue.main.async { [weak panel] in
            guard let panel else { return }
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    private func focusComposer() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .stashFocusComposer, object: nil)
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
