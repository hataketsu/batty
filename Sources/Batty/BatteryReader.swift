import Foundation
import IOKit

/// Snapshot of everything we show in the UI, read from the AppleSmartBattery
/// IORegistry node in one pass.
struct BatterySnapshot {
    var percent: Int          // CurrentCapacity, 0...100
    var isCharging: Bool
    var isPluggedIn: Bool
    var isFullyCharged: Bool

    var amperage: Double      // mA, signed: > 0 charging, < 0 discharging
    var voltage: Double       // mV
    var watts: Double         // |amperage| * voltage / 1e6

    var rawCurrent: Int       // AppleRawCurrentCapacity, mAh
    var rawMax: Int           // AppleRawMaxCapacity, mAh — usable, reserve excluded
    var nominalCapacity: Int  // NominalChargeCapacity, mAh — what the pack holds
    var packReserve: Int      // mAh held back from the usable window
    var designCapacity: Int   // mAh
    var cycleCount: Int
    var temperature: Double   // celsius

    var minutesToFull: Int?   // nil when unknown / not charging
    var minutesToEmpty: Int?

    var adapterWatts: Int?    // rated wattage of the connected charger
    var adapterVoltage: Double?  // mV negotiated
    var adapterCurrent: Double?  // mA negotiated

    var systemPowerIn: Double?   // mW drawn from the wall right now
    var systemLoad: Double?      // mW consumed by the machine

    /// State of health. This compares NominalChargeCapacity — the charge the
    /// pack actually holds — against the design capacity. AppleRawMaxCapacity
    /// is the *usable* window, which excludes PackReserve, so using it would
    /// report a few percent of wear that does not exist.
    var health: Double? {
        let full = nominalCapacity > 0 ? nominalCapacity : rawMax
        guard designCapacity > 0, full > 0 else { return nil }
        return Double(full) / Double(designCapacity) * 100
    }

    /// Energy left in the usable window, in watt-hours.
    var wattHoursLeft: Double {
        Double(rawCurrent) * voltage / 1_000_000
    }

    /// How long the machine would run on battery at the power it is drawing
    /// right now. While discharging that is the pack's own output; while
    /// plugged in it is SystemLoad, i.e. what would be drawn if unplugged.
    var estimatedMinutesLeft: Int? {
        guard let load = machineWatts, load > 0.5, wattHoursLeft > 0 else { return nil }
        return Int(wattHoursLeft / load * 60)
    }

    /// Power the machine itself is consuming, charging excluded. On battery
    /// that is the pack's output; plugged in it is SystemLoad, which also
    /// carries whatever is going into the battery, so that part is subtracted.
    var machineWatts: Double? {
        guard isPluggedIn else { return watts > 0 ? watts : nil }
        guard let load = systemLoad else { return nil }
        return max(load / 1000 - (isCharging ? watts : 0), 0)
    }

    /// Charge added per hour, as a share of full capacity (e.g. "+62 %/h").
    var percentPerHour: Double? {
        guard rawMax > 0, amperage != 0 else { return nil }
        return amperage / Double(rawMax) * 100
    }
}

enum BatteryReader {
    static func read() -> BatterySnapshot? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0)
                == KERN_SUCCESS,
              let props = unmanaged?.takeRetainedValue() as? [String: Any]
        else { return nil }

        func int(_ key: String) -> Int? { props[key] as? Int }
        func bool(_ key: String) -> Bool { (props[key] as? Bool) ?? false }

        // Amperage is reported as an unsigned 64-bit value; discharging shows up
        // as a huge number that is really a negative two's-complement integer.
        func signedMilliAmps(_ key: String) -> Double {
            guard let raw = props[key] as? Int else { return 0 }
            return Double(Int64(truncatingIfNeeded: raw))
        }

        let amperage = signedMilliAmps("Amperage")
        let voltage = Double(int("Voltage") ?? 0)

        // 65535 is the sentinel the gauge uses while it is still estimating.
        func minutes(_ key: String) -> Int? {
            guard let v = int(key), v > 0, v != 65535 else { return nil }
            return v
        }

        let adapter = props["AdapterDetails"] as? [String: Any]
        let telemetry = props["PowerTelemetryData"] as? [String: Any]

        return BatterySnapshot(
            percent: int("CurrentCapacity") ?? 0,
            isCharging: bool("IsCharging"),
            isPluggedIn: bool("ExternalConnected"),
            isFullyCharged: bool("FullyCharged"),
            amperage: amperage,
            voltage: voltage,
            watts: abs(amperage) * voltage / 1_000_000,
            rawCurrent: int("AppleRawCurrentCapacity") ?? 0,
            rawMax: int("AppleRawMaxCapacity") ?? 0,
            nominalCapacity: int("NominalChargeCapacity") ?? 0,
            packReserve: int("PackReserve") ?? 0,
            designCapacity: int("DesignCapacity") ?? 0,
            cycleCount: int("CycleCount") ?? 0,
            temperature: Double(int("Temperature") ?? 0) / 100,
            minutesToFull: minutes("AvgTimeToFull"),
            minutesToEmpty: minutes("AvgTimeToEmpty"),
            adapterWatts: adapter?["Watts"] as? Int,
            adapterVoltage: (adapter?["AdapterVoltage"] as? Int).map(Double.init),
            adapterCurrent: (adapter?["Current"] as? Int).map(Double.init),
            systemPowerIn: (telemetry?["SystemPowerIn"] as? Int).map(Double.init),
            systemLoad: (telemetry?["SystemLoad"] as? Int).map(Double.init)
        )
    }
}
