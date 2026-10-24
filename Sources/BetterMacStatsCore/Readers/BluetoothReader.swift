import Foundation
#if canImport(IOBluetooth)
import IOBluetooth
#endif

/// Paired Bluetooth devices via IOBluetooth. Battery level is not exposed by the
/// classic IOBluetooth API, so it is left nil (handled gracefully by the UI).
public final class BluetoothReader {
    public init() {}

    public func read() -> [BluetoothDeviceInfo] {
        #if canImport(IOBluetooth)
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return [] }
        return paired.map { dev in
            let connected = dev.isConnected()
            let name = dev.name ?? dev.addressString ?? "Unknown"
            return BluetoothDeviceInfo(
                name: name,
                address: dev.addressString ?? "",
                isConnected: connected,
                batteryPercent: nil,
                rssi: connected ? Int(dev.rawRSSI()) : nil,
                kind: Self.kind(major: dev.deviceClassMajor, minor: dev.deviceClassMinor, name: name)
            )
        }
        #else
        return []
        #endif
    }

    /// Map Bluetooth Class-of-Device major/minor to a coarse, user-friendly label.
    /// Bluetooth LE devices report no class, so fall back to hints in the name.
    static func kind(major: UInt32, minor: UInt32, name: String) -> String {
        switch major {
        case 0x01: return "Computer"
        case 0x02: return "Phone"
        case 0x04: return "Audio"
        case 0x05: // Peripheral
            if minor & 0x10 != 0 { return "Keyboard" }
            if minor & 0x20 != 0 { return "Mouse" }
            return "Input Device"
        default: break
        }
        let lower = name.lowercased()
        let hints: [(String, String)] = [
            ("mouse", "Mouse"), ("trackpad", "Trackpad"), ("keyboard", "Keyboard"),
            ("watch", "Watch"), ("iphone", "Phone"), ("ipad", "Tablet"),
            ("airpods", "Audio"), ("headphone", "Audio"), ("buds", "Audio"), ("speaker", "Audio"),
        ]
        return hints.first { lower.contains($0.0) }?.1 ?? "Device"
    }
}
