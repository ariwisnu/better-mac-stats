import AppKit
import SwiftUI
import Combine

/// Creates one NSStatusItem per enabled module, drives the refresh timer, and
/// shows the detail popover (left-click) or the control menu (right-click).
final class MenuBarController: NSObject {
    private let settings: AppSettings
    private let engine: StatsEngine

    private var order: [(kind: ModuleKind, item: NSStatusItem)] = []
    private var controlItem: NSStatusItem?
    private let popover = NSPopover()
    private var activeKind: ModuleKind?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: SettingsWindowController?

    private var lastVisible: [ModuleKind] = []
    private var lastInterval: Double = 0

    init(settings: AppSettings, engine: StatsEngine) {
        self.settings = settings
        self.engine = engine
        super.init()
    }

    func start() {
        popover.behavior = .transient
        popover.animates = true
        lastVisible = settings.visibleModules
        lastInterval = settings.refreshInterval

        rebuildItems()
        engine.tick()
        refreshAll()
        startTimer()

        settings.objectWillChange
            .sink { [weak self] in DispatchQueue.main.async { self?.settingsChanged() } }
            .store(in: &cancellables)
    }

    // MARK: Status items

    private func rebuildItems() {
        if popover.isShown { popover.performClose(nil) }
        for entry in order { NSStatusBar.system.removeStatusItem(entry.item) }
        order.removeAll()

        for kind in settings.visibleModules {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.target = self
                button.action = #selector(handleClick(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                button.setAccessibilityLabel(kind.title)
            }
            order.append((kind, item))
        }
        updateControlItem()
        refreshAll()
    }

    /// When no modules are enabled, keep a single gear item so the app stays reachable.
    private func updateControlItem() {
        if order.isEmpty {
            guard controlItem == nil else { return }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Better Mac Stats")
                button.target = self
                button.action = #selector(handleControlClick(_:))
            }
            controlItem = item
        } else if let item = controlItem {
            NSStatusBar.system.removeStatusItem(item)
            controlItem = nil
        }
    }

    private func refreshAll() {
        for entry in order {
            apply(MenuBarRenderer.content(for: entry.kind, engine: engine, settings: settings),
                  to: entry.item, kind: entry.kind)
        }
    }

    private func apply(_ content: MenuBarContent, to item: NSStatusItem, kind: ModuleKind) {
        guard let button = item.button else { return }

        if let symbol = content.symbol,
           let image = NSImage(systemSymbolName: symbol, accessibilityDescription: kind.title) {
            image.isTemplate = true
            button.image = image
            button.imagePosition = content.title.isEmpty ? .imageOnly : .imageLeading
        } else {
            button.image = nil
        }

        if content.title.isEmpty {
            button.attributedTitle = NSAttributedString(string: "")
        } else {
            var attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            ]
            if let color = content.color { attrs[.foregroundColor] = color }
            let prefix = button.image != nil ? " " : ""
            button.attributedTitle = NSAttributedString(string: prefix + content.title, attributes: attrs)
        }
    }

    // MARK: Timer

    private func startTimer() {
        timer?.invalidate()
        let interval = max(0.2, settings.refreshInterval)
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        engine.tick()
        refreshAll()
    }

    // MARK: Settings reactions

    private func settingsChanged() {
        if settings.visibleModules != lastVisible {
            lastVisible = settings.visibleModules
            rebuildItems()
        }
        if settings.refreshInterval != lastInterval {
            lastInterval = settings.refreshInterval
            startTimer()
        }
        refreshAll()
    }

    // MARK: Interaction

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let entry = order.first(where: { $0.item.button === sender }) else { return }
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) ?? false)
        if isRight {
            showMenu(at: sender)
        } else {
            togglePopover(for: entry.kind, item: entry.item)
        }
    }

    @objc private func handleControlClick(_ sender: NSStatusBarButton) {
        showMenu(at: sender)
    }

    private func togglePopover(for kind: ModuleKind, item: NSStatusItem) {
        if popover.isShown && activeKind == kind {
            popover.performClose(nil)
            return
        }
        if popover.isShown { popover.performClose(nil) }

        let root = ModulePopover(kind: kind, engine: engine, settings: settings,
                                 onOpenSettings: { [weak self] in self?.openSettings() })
        popover.contentViewController = NSHostingController(rootView: root)
        activeKind = kind
        if let button = item.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showMenu(at button: NSStatusBarButton) {
        let menu = NSMenu()
        let header = menu.addItem(withTitle: "Better Mac Stats", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettingsAction), keyEquivalent: ",").target = self
        let login = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = settings.launchAtLogin ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Better Mac Stats", action: #selector(quitAction), keyEquivalent: "q").target = self
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }

    @objc private func openSettingsAction() { openSettings() }
    @objc private func quitAction() { NSApp.terminate(nil) }
    @objc private func toggleLogin() { settings.launchAtLogin.toggle() }

    private func openSettings() {
        if popover.isShown { popover.performClose(nil) }
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(settings: settings)
        }
        settingsWindow?.show()
    }
}
