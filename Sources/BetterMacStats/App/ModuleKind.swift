import Foundation

/// The set of menu bar modules the app can display. Each maps to one reader and
/// one NSStatusItem.
enum ModuleKind: String, CaseIterable, Codable, Identifiable {
    case cpu, gpu, memory, disk, network, battery, sensors, bluetooth, clock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .memory: return "Memory"
        case .disk: return "Disk"
        case .network: return "Network"
        case .battery: return "Battery"
        case .sensors: return "Sensors"
        case .bluetooth: return "Bluetooth"
        case .clock: return "Clock"
        }
    }

    /// SF Symbol name. Rendered with a nil-safe lookup, so an unavailable symbol
    /// simply shows no icon instead of crashing.
    var symbol: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "cube.transparent"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .battery: return "battery.100"
        case .sensors: return "thermometer.medium"
        case .bluetooth: return "dot.radiowaves.right"
        case .clock: return "clock"
        }
    }

    /// Lightweight defaults; heavier/optional modules are opt-in to save battery.
    var enabledByDefault: Bool {
        switch self {
        case .cpu, .memory, .network, .battery, .clock: return true
        case .gpu, .disk, .sensors, .bluetooth: return false
        }
    }

    /// Natural left-to-right order in the menu bar.
    static let defaultOrder: [ModuleKind] = [.cpu, .gpu, .memory, .disk, .network, .sensors, .battery, .bluetooth, .clock]
}
