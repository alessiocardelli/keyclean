import AppKit
import Combine
import SwiftUI

/// Icona nella barra dei menu e pannello con lo stesso materiale e gli stessi angoli di BatteryGuard.
@MainActor
final class MenuBarController: NSObject, NSWindowDelegate {
    private static let panelGap: CGFloat = 2
    private static let panelRadius: CGFloat = 6

    private let model: AppModel
    private let statusItem: NSStatusItem
    private var panel: FloatingPanel?
    private var hostingView: NSHostingView<PopoverView>?
    private var outsideClickMonitor: Any?
    private var lastClosed = Date.distantPast
    private var modelObserver: AnyCancellable?
    private lazy var overlay = LockOverlayController { [weak self] in self?.model.unlock() }

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePanel)
            button.setAccessibilityLabel("KeyClean")
        }
        updateIcon(locked: false)
        modelObserver = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.fitPanel() }
        }
        model.onLockChange = { [weak self] locked in
            guard let self else { return }
            self.updateIcon(locked: locked)
            locked ? self.overlay.show() : self.overlay.hide()
        }
    }

    private func updateIcon(locked: Bool) {
        let image = NSImage(systemSymbolName: locked ? "lock.fill" : "keyboard", accessibilityDescription: "KeyClean")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    @objc private func togglePanel() {
        if panel?.isVisible == true {
            closePanel()
        } else if Date().timeIntervalSince(lastClosed) > 0.3 {
            showPanel()
        }
    }

    func showPanel() {
        guard !model.isLocked else { return }
        model.watchTrust()
        let panel = panel ?? makePanel()
        let content = makeContent()
        if let hostingView {
            hostingView.rootView = content
        } else {
            let hostingView = NSHostingView(rootView: content)
            hostingView.sizingOptions = []
            hostingView.autoresizingMask = [.width, .height]
            panel.contentView?.addSubview(hostingView)
            self.hostingView = hostingView
        }
        let size = measuredSize()

        let itemFrame = statusItem.button?.window?.frame
        let screen = NSScreen.screens.first(where: { itemFrame.map($0.frame.intersects) ?? false })
            ?? NSScreen.main ?? NSScreen.screens[0]
        let top = itemFrame?.minY ?? (screen.frame.maxY - NSStatusBar.system.thickness)
        let preferredX = itemFrame?.minX ?? screen.frame.midX - size.width / 2
        let x = min(max(preferredX, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - size.width - 8)
        panel.setFrame(NSRect(x: x, y: top - Self.panelGap - size.height, width: size.width, height: size.height), display: true)
        hostingView?.frame = panel.contentView?.bounds ?? .zero

        panel.makeKeyAndOrderFront(nil)
        statusItem.button?.highlight(true)
        outsideClickMonitor = outsideClickMonitor ?? NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closePanel() }
        }
    }

    private func makeContent() -> PopoverView {
        PopoverView(model: model) { [weak self] in
            self?.closePanel()
            self?.model.lock()
        }
    }

    /// Misura su una vista a parte: quella nel pannello non impone dimensioni e darebbe 0 (come in BatteryGuard).
    private func measuredSize() -> NSSize {
        NSHostingView(rootView: makeContent()).fittingSize
    }

    /// Il pannello segue l'altezza del contenuto quando cambia (permesso concesso, errore), con il bordo alto fermo.
    private func fitPanel() {
        guard let panel, panel.isVisible else { return }
        let size = measuredSize()
        let current = panel.frame
        guard abs(current.height - size.height) > 0.5 else { return }
        panel.setFrame(NSRect(x: current.minX, y: current.maxY - size.height, width: size.width, height: size.height), display: true)
    }

    func closePanel() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        lastClosed = Date()
        statusItem.button?.highlight(false)
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        closePanel()
    }

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.onCancel = { [weak self] in self?.closePanel() }
        panel.delegate = self

        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.maskImage = Self.roundedMask(radius: Self.panelRadius)
        panel.contentView = background
        self.panel = panel
        return panel
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// Pannello senza bordi che prende la tastiera (Esc chiude) senza attivare l'app.
final class FloatingPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
