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
    var rawMax: Int           // AppleRawMaxCapacity, mAh
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

    /// State of health: usable capacity vs. the capacity it shipped with.
    var health: Double? {
        guard designCapacity > 0, rawMax > 0 else { return nil }
        return Double(rawMax) / Double(designCapacity) * 100
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
