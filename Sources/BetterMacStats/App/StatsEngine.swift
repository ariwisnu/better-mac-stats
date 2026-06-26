import Foundation
import Combine
import BetterMacStatsCore

/// Owns every reader and the latest snapshot + rolling history for each module.
/// `tick()` refreshes only the modules the user has enabled, so disabled modules
/// cost nothing.
final class StatsEngine: ObservableObject {
    // Latest snapshots
    @Published private(set) var cpu: CPULoad = .zero
    @Published private(set) var memory: MemoryUsage = .zero
    @Published private(set) var network: NetworkUsage = .zero
    @Published private(set) var disk: DiskUsage = .zero
    @Published private(set) var battery: BatteryInfo = .absent
    @Published private(set) var gpus: [GPUInfo] = []
    @Published private(set) var sensors: [SensorReading] = []
    @Published private(set) var bluetooth: [BluetoothDeviceInfo] = []
    @Published private(set) var clocks: [ClockReading] = []

    // Rolling history (oldest → newest) for sparklines
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var memHistory: [Double] = []
    @Published private(set) var netDownHistory: [Double] = []
    @Published private(set) var netUpHistory: [Double] = []
    @Published private(set) var diskReadHistory: [Double] = []
    @Published private(set) var diskWriteHistory: [Double] = []
    @Published private(set) var gpuHistory: [Double] = []

    let cpuStatic: CPUStaticInfo

    private let cpuReader = CPUReader()
    private let memReader = MemoryReader()
    private let netReader = NetworkReader()
    private let diskReader = DiskReader()
    private let batteryReader = BatteryReader()
    private let gpuReader = GPUReader()
    private let smcReader = SMCReader()
    private let btReader = BluetoothReader()
    private let clockReader = ClockReader()

    private let historySize = 60
    private lazy var cpuBuf = RingBuffer<Double>(capacity: historySize)
    private lazy var memBuf = RingBuffer<Double>(capacity: historySize)
    private lazy var netDownBuf = RingBuffer<Double>(capacity: historySize)
    private lazy var netUpBuf = RingBuffer<Double>(capacity: historySize)
    private lazy var diskRBuf = RingBuffer<Double>(capacity: historySize)
    private lazy var diskWBuf = RingBuffer<Double>(capacity: historySize)
    private lazy var gpuBuf = RingBuffer<Double>(capacity: historySize)

    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        self.cpuStatic = cpuReader.staticInfo()
    }

    func tick() {
        let on = settings.enabledModules

        if on.contains(.cpu) {
            cpu = cpuReader.read()
            cpuBuf.push(cpu.total); cpuHistory = cpuBuf.values
        }
        if on.contains(.memory) {
            memory = memReader.read()
            memBuf.push(memory.usedFraction); memHistory = memBuf.values
        }
        if on.contains(.network) {
            network = netReader.read()
            netDownBuf.push(network.downloadBytesPerSec); netDownHistory = netDownBuf.values
            netUpBuf.push(network.uploadBytesPerSec); netUpHistory = netUpBuf.values
        }
        if on.contains(.disk) {
            disk = diskReader.read()
            diskRBuf.push(disk.readBytesPerSec); diskReadHistory = diskRBuf.values
            diskWBuf.push(disk.writeBytesPerSec); diskWriteHistory = diskWBuf.values
        }
        if on.contains(.battery) { battery = batteryReader.read() }
        if on.contains(.gpu) {
            gpus = gpuReader.read()
            gpuBuf.push(gpus.first?.utilization ?? 0); gpuHistory = gpuBuf.values
        }
        if on.contains(.sensors) { sensors = smcReader.read() }
        if on.contains(.bluetooth) { bluetooth = btReader.read() }
        if on.contains(.clock) { clocks = clockReader.read(zones: settings.clockZones) }
    }

    // MARK: Derived

    var temperatureSensors: [SensorReading] { sensors.filter { $0.kind == .temperature } }
    var fanSensors: [SensorReading] { sensors.filter { $0.kind == .fan } }
    var powerSensors: [SensorReading] { sensors.filter { $0.kind == .power } }

    /// Mean CPU-core temperature, or the hottest temperature available.
    var cpuTemperature: Double? {
        let cores = temperatureSensors.filter { $0.name.contains("CPU") }
        if !cores.isEmpty { return cores.map(\.value).reduce(0, +) / Double(cores.count) }
        return temperatureSensors.map(\.value).max()
    }

    var hottestTemperature: Double? { temperatureSensors.map(\.value).max() }

    var connectedBluetoothCount: Int { bluetooth.filter(\.isConnected).count }
}
