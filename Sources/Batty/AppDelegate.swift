import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let menu = NSMenu()
    private var menuIsOpen = false

    /// Idle polling is deliberately lazy; we speed up only while the menu is
    /// on screen, where stale numbers would be visible.
    private let idleInterval: TimeInterval = 5
    private let activeInterval: TimeInterval = 1

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        menu.delegate = self
        // Rows carry no action, and AppKit greys out actionless items unless we
        // take over enabling ourselves.
        menu.autoenablesItems = false
        statusItem.menu = menu
        refresh()
        schedule(every: idleInterval)
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
        guard let snapshot = BatteryReader.read() else {
            statusItem.button?.title = " —"
            return
        }
        statusItem.button?.image = BattyIcon.menuBar(level: snapshot.percent,
                                                     charging: snapshot.isCharging)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.title = " " + MenuFormatter.statusTitle(snapshot)
        if menuIsOpen {
            MenuFormatter.populate(menu, with: snapshot, target: self,
                                   quitAction: #selector(quit))
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
