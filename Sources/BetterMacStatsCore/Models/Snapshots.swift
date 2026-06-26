import Foundation

// MARK: - CPU

public struct CPULoad: Equatable {
    public var system: Double   // 0...1
    public var user: Double     // 0...1
    public var idle: Double     // 0...1
    public var nice: Double     // 0...1
    public var perCore: [Double] // total usage per core, each 0...1

    public init(system: Double, user: Double, idle: Double, nice: Double, perCore: [Double]) {
        self.system = system
        self.user = user
        self.idle = idle
        self.nice = nice
        self.perCore = perCore
    }

    /// Combined non-idle load, clamped to 0...1.
    public var total: Double { min(1, max(0, system + user + nice)) }

    public static let zero = CPULoad(system: 0, user: 0, idle: 1, nice: 0, perCore: [])
}

// MARK: - Memory

public struct MemoryUsage: Equatable {
    public var total: UInt64
    public var used: UInt64
    public var app: UInt64
    public var wired: UInt64
    public var compressed: UInt64
    public var cached: UInt64
    public var free: UInt64
    public var swapUsed: UInt64
    public var swapTotal: UInt64
    public var pressure: Double // 0...1

    public init(total: UInt64, used: UInt64, app: UInt64, wired: UInt64, compressed: UInt64,
                cached: UInt64, free: UInt64, swapUsed: UInt64, swapTotal: UInt64, pressure: Double) {
        self.total = total
        self.used = used
        self.app = app
        self.wired = wired
        self.compressed = compressed
        self.cached = cached
        self.free = free
        self.swapUsed = swapUsed
        self.swapTotal = swapTotal
        self.pressure = pressure
    }

    public var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    public static let zero = MemoryUsage(total: 0, used: 0, app: 0, wired: 0, compressed: 0,
                                         cached: 0, free: 0, swapUsed: 0, swapTotal: 0, pressure: 0)
}

// MARK: - Network

public struct NetworkUsage: Equatable {
    public var uploadBytesPerSec: Double
    public var downloadBytesPerSec: Double
    public var totalUploaded: UInt64
    public var totalDownloaded: UInt64
    public var interfaceName: String?
    public var localIP: String?
    public var connectionType: String? // "Wi-Fi", "Ethernet", ...

    public init(uploadBytesPerSec: Double, downloadBytesPerSec: Double, totalUploaded: UInt64,
                totalDownloaded: UInt64, interfaceName: String?, localIP: String?, connectionType: String?) {
        self.uploadBytesPerSec = uploadBytesPerSec
        self.downloadBytesPerSec = downloadBytesPerSec
        self.totalUploaded = totalUploaded
        self.totalDownloaded = totalDownloaded
        self.interfaceName = interfaceName
        self.localIP = localIP
        self.connectionType = connectionType
    }

    public static let zero = NetworkUsage(uploadBytesPerSec: 0, downloadBytesPerSec: 0, totalUploaded: 0,
                                          totalDownloaded: 0, interfaceName: nil, localIP: nil, connectionType: nil)
}

// MARK: - Disk

public struct DiskVolume: Equatable, Identifiable {
    public var name: String
    public var path: String
    public var total: UInt64
    public var free: UInt64
    public var isRemovable: Bool

    public init(name: String, path: String, total: UInt64, free: UInt64, isRemovable: Bool) {
        self.name = name
        self.path = path
        self.total = total
        self.free = free
        self.isRemovable = isRemovable
    }

    public var id: String { path }
    public var used: UInt64 { total > free ? total - free : 0 }
    public var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

public struct DiskUsage: Equatable {
    public var volumes: [DiskVolume]
    public var readBytesPerSec: Double
    public var writeBytesPerSec: Double

    public init(volumes: [DiskVolume], readBytesPerSec: Double, writeBytesPerSec: Double) {
        self.volumes = volumes
        self.readBytesPerSec = readBytesPerSec
        self.writeBytesPerSec = writeBytesPerSec
    }

    /// The boot volume ("/") if present, else the first volume.
    public var primary: DiskVolume? { volumes.first(where: { $0.path == "/" }) ?? volumes.first }

    public static let zero = DiskUsage(volumes: [], readBytesPerSec: 0, writeBytesPerSec: 0)
}

// MARK: - Battery

public struct BatteryInfo: Equatable {
    public var isPresent: Bool
    public var percentage: Int
    public var isCharging: Bool
    public var isCharged: Bool
    public var onACPower: Bool
    public var timeToEmptyMinutes: Int?
    public var timeToFullMinutes: Int?
    public var cycleCount: Int?
    public var healthPercent: Int?
    public var conditionString: String?
    public var temperature: Double?
    public var designCapacity: Int?
    public var maxCapacity: Int?

    public init(isPresent: Bool, percentage: Int, isCharging: Bool, isCharged: Bool, onACPower: Bool,
                timeToEmptyMinutes: Int?, timeToFullMinutes: Int?, cycleCount: Int?, healthPercent: Int?,
                conditionString: String?, temperature: Double?, designCapacity: Int?, maxCapacity: Int?) {
        self.isPresent = isPresent
        self.percentage = percentage
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.onACPower = onACPower
        self.timeToEmptyMinutes = timeToEmptyMinutes
        self.timeToFullMinutes = timeToFullMinutes
        self.cycleCount = cycleCount
        self.healthPercent = healthPercent
        self.conditionString = conditionString
        self.temperature = temperature
        self.designCapacity = designCapacity
        self.maxCapacity = maxCapacity
    }

    /// Used by desktops with no internal battery.
    public static let absent = BatteryInfo(isPresent: false, percentage: 0, isCharging: false, isCharged: false,
                                           onACPower: true, timeToEmptyMinutes: nil, timeToFullMinutes: nil,
                                           cycleCount: nil, healthPercent: nil, conditionString: nil,
                                           temperature: nil, designCapacity: nil, maxCapacity: nil)
}

// MARK: - GPU

public struct GPUInfo: Equatable, Identifiable {
    public var name: String
    public var utilization: Double?   // 0...1
    public var usedVRAM: UInt64?
    public var totalVRAM: UInt64?
    public var temperature: Double?
    public var fanSpeedRPM: Int?

    public init(name: String, utilization: Double?, usedVRAM: UInt64?, totalVRAM: UInt64?,
                temperature: Double?, fanSpeedRPM: Int?) {
        self.name = name
        self.utilization = utilization
        self.usedVRAM = usedVRAM
        self.totalVRAM = totalVRAM
        self.temperature = temperature
        self.fanSpeedRPM = fanSpeedRPM
    }

    public var id: String { name }
}

// MARK: - Sensors (temperatures, fans, power)

public enum SensorKind: String, Codable, Equatable {
    case temperature, fan, voltage, current, power, other
}

public struct SensorReading: Equatable, Identifiable {
    public var key: String      // raw SMC key, e.g. "TC0P"
    public var name: String     // friendly label
    public var value: Double
    public var unit: String     // "°C", "RPM", "V", ...
    public var kind: SensorKind

    public init(key: String, name: String, value: Double, unit: String, kind: SensorKind) {
        self.key = key
        self.name = name
        self.value = value
        self.unit = unit
        self.kind = kind
    }

    public var id: String { key }
}

// MARK: - Bluetooth

public struct BluetoothDeviceInfo: Equatable, Identifiable {
    public var name: String
    public var address: String
    public var isConnected: Bool
    public var batteryPercent: Int?
    public var rssi: Int?
    public var kind: String // "Headphones", "Mouse", "Keyboard", ...

    public init(name: String, address: String, isConnected: Bool, batteryPercent: Int?, rssi: Int?, kind: String) {
        self.name = name
        self.address = address
        self.isConnected = isConnected
        self.batteryPercent = batteryPercent
        self.rssi = rssi
        self.kind = kind
    }

    public var id: String { address }
}
