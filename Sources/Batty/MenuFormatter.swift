import AppKit

enum MenuFormatter {
    static func statusTitle(_ s: BatterySnapshot) -> String {
        let percent = "\(s.percent)%"
        guard s.watts >= 0.1 else { return percent }
        let sign = s.isCharging ? "+" : "−"
        return String(format: "%@ %@%.1fW", percent, sign, s.watts)
    }

    static func populate(_ menu: NSMenu, with s: BatterySnapshot,
                         target: AnyObject, quitAction: Selector) {
        menu.removeAllItems()

        menu.addItem(header(state(s)))

        if let eta = etaLine(s) { menu.addItem(row("Còn lại", eta)) }

        if s.watts >= 0.1 {
            menu.addItem(row("Công suất", String(
                format: "%.2f W  (%.0f mA @ %.2f V)",
                s.watts, abs(s.amperage), s.voltage / 1000)))
        }

        if let rate = s.percentPerHour, abs(rate) >= 0.1 {
            menu.addItem(row("Tốc độ", String(format: "%+.1f %%/giờ", rate)))
        }

        if s.isPluggedIn, let w = s.adapterWatts {
            var detail = "\(w) W"
            if let v = s.adapterVoltage, let a = s.adapterCurrent {
                detail += String(format: "  (%.0f V / %.2f A)", v / 1000, a / 1000)
            }
            menu.addItem(row("Sạc", detail))
        }

        if let wall = s.systemPowerIn, let load = s.systemLoad {
            menu.addItem(row("Nguồn vào", String(
                format: "%.1f W  ·  máy dùng %.1f W", wall / 1000, load / 1000)))
        }

        menu.addItem(.separator())

        menu.addItem(row("Dung lượng", "\(s.rawCurrent) / \(s.rawMax) mAh dùng được"))
        if s.nominalCapacity > 0 {
            menu.addItem(row("Pin thật", "\(s.nominalCapacity) mAh  ·  dự trữ \(s.packReserve) mAh"))
        }
        if let health = s.health {
            menu.addItem(row("Sức khỏe", String(
                format: "%.1f%%  (thiết kế %d mAh)", health, s.designCapacity)))
        }
        menu.addItem(row("Chu kỳ sạc", "\(s.cycleCount)"))
        menu.addItem(row("Nhiệt độ", String(format: "%.1f °C", s.temperature)))

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Thoát Batty", action: quitAction, keyEquivalent: "q")
        quit.target = target
        menu.addItem(quit)
    }

    private static func state(_ s: BatterySnapshot) -> String {
        if s.isFullyCharged && s.isPluggedIn { return "🦇 \(s.percent)% · đã sạc đầy" }
        if s.isCharging { return "🦇 \(s.percent)% · đang sạc" }
        if s.isPluggedIn { return "🦇 \(s.percent)% · cắm điện, không sạc" }
        return "🦇 \(s.percent)% · dùng pin"
    }

    private static func etaLine(_ s: BatterySnapshot) -> String? {
        if s.isCharging, let m = s.minutesToFull { return "\(duration(m)) đến khi đầy" }
        if !s.isPluggedIn, let m = s.minutesToEmpty { return "\(duration(m)) đến khi cạn" }
        return nil
    }

    private static func duration(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h) giờ \(m) phút" : "\(m) phút"
    }

    private static func header(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold)
        ])
        item.isEnabled = false
        return item
    }

    /// A menu row rendered as "label" on the left and a monospaced value on the
    /// right, so the numbers stay aligned while they tick.
    private static func row(_ label: String, _ value: String) -> NSMenuItem {
        let item = NSMenuItem(title: "\(label)  \(value)", action: nil, keyEquivalent: "")
        let text = NSMutableAttributedString(string: label + "   ", attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
        text.append(NSAttributedString(string: value, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]))
        item.attributedTitle = text
        item.isEnabled = false
        return item
    }
}
