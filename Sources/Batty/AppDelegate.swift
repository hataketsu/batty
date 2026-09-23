import AppKit
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    /// Read back with:
    ///   log show --predicate 'subsystem == "dev.hataketsu.batty"' --last 1d
    private let log = Logger(subsystem: "dev.hataketsu.batty", category: "statusitem")

    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private let menu = NSMenu()
    private var menuIsOpen = false

    /// Idle polling is deliberately lazy; we speed up only while the menu is
    /// on screen, where stale numbers would be visible.
    private let idleInterval: TimeInterval = 5
    private let activeInterval: TimeInterval = 1

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.delegate = self
        // Rows carry no action, and AppKit greys out actionless items unless we
        // take over enabling ourselves.
        menu.autoenablesItems = false
        createStatusItem()
        log.notice("launched, status item created")
        refresh()
        schedule(every: idleInterval)
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        item.behavior = []
        item.isVisible = true
        item.menu = menu
        statusItem = item
    }

    /// The menu bar can drop a status item out from under a long-lived agent —
    /// when the menu bar agent restarts, for instance — leaving the process
    /// running with nothing on screen. Detect the orphaned item and rebuild it.
    private func ensureStatusItemIsOnScreen() {
        guard let item = statusItem else {
            createStatusItem()
            return
        }
        if item.button?.window == nil || !item.isVisible {
            log.error("status item left the menu bar (window: \(item.button?.window != nil), visible: \(item.isVisible)); rebuilding")
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
            createStatusItem()
        }
    }

    private func schedule(every interval: TimeInterval) {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        // Keep firing while a menu is tracking the mouse.
        timer.tolerance = interval / 4
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuIsOpen = true
        refresh()
        schedule(every: activeInterval)
    }

    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
        schedule(every: idleInterval)
    }

    private func refresh() {
        ensureStatusItemIsOnScreen()
        guard let button = statusItem?.button else { return }
        guard let snapshot = BatteryReader.read() else {
            button.title = " —"
            return
        }
        button.image = BattyIcon.menuBar(level: snapshot.percent,
                                         charging: snapshot.isCharging)
        button.imagePosition = .imageLeading
        button.title = " " + MenuFormatter.statusTitle(snapshot)
        if menuIsOpen {
            MenuFormatter.populate(menu, with: snapshot, target: self,
                                   quitAction: #selector(quit))
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
