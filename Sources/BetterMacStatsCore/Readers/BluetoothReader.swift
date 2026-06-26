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
            return BluetoothDeviceInfo(
                name: dev.name ?? dev.addressString ?? "Unknown",
                address: dev.addressString ?? "",
                isConnected: connected,
                batteryPercent: nil,
                rssi: connected ? Int(dev.rawRSSI()) : nil,
                kind: Self.kind(major: dev.deviceClassMajor, minor: dev.deviceClassMinor)
            )
        }
        #else
        return []
        #endif
    }

    #if canImport(IOBluetooth)
    /// Map Bluetooth Class-of-Device major/minor to a coarse, user-friendly label.
    private static func kind(major: BluetoothClassOfDevice, minor: BluetoothClassOfDevice) -> String {
        switch major {
        case 0x01: return "Computer"
        case 0x02: return "Phone"
        case 0x04: return "Audio"
        case 0x05: // Peripheral
            if minor & 0x10 != 0 { return "Keyboard" }
            if minor & 0x20 != 0 { return "Mouse" }
            return "Input Device"
        default: return "Device"
        }
    }
    #endif
}
