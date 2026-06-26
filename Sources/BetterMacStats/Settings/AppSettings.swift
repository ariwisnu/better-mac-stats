import Foundation
import Combine
import BetterMacStatsCore

/// User preferences, persisted to UserDefaults. Observable so the menu bar and
/// settings UI react live to changes.
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults
    private var loaded = false

    @Published var enabledModules: Set<ModuleKind> { didSet { persist() } }
    @Published var moduleOrder: [ModuleKind] { didSet { persist() } }
    @Published var refreshInterval: Double { didSet { persist() } }
    @Published var useFahrenheit: Bool { didSet { persist() } }
    @Published var colorCoded: Bool { didSet { persist() } }
    @Published var showMenuBarIcons: Bool { didSet { persist() } }
    @Published var networkInBits: Bool { didSet { persist() } }
    @Published var clockZones: [ClockZone] { didSet { persist() } }
    @Published var launchAtLogin: Bool {
        didSet {
            guard loaded else { return }
            LoginItem.setEnabled(launchAtLogin)
            persist()
        }
    }

    static let refreshIntervalOptions: [Double] = [0.5, 1, 2, 3, 5, 10]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedEnabled = Self.decode([String].self, defaults, Keys.enabledModules)
            .map { Set($0.compactMap(ModuleKind.init(rawValue:))) }
        enabledModules = storedEnabled ?? Set(ModuleKind.allCases.filter { $0.enabledByDefault })

        let storedOrder = Self.decode([String].self, defaults, Keys.moduleOrder)?
            .compactMap(ModuleKind.init(rawValue:))
        moduleOrder = Self.normalizedOrder(storedOrder ?? ModuleKind.defaultOrder)

        refreshInterval = defaults.object(forKey: Keys.refreshInterval) as? Double ?? 2.0
        useFahrenheit = defaults.object(forKey: Keys.useFahrenheit) as? Bool ?? false
        colorCoded = defaults.object(forKey: Keys.colorCoded) as? Bool ?? true
        showMenuBarIcons = defaults.object(forKey: Keys.showMenuBarIcons) as? Bool ?? true
        networkInBits = defaults.object(forKey: Keys.networkInBits) as? Bool ?? false
        clockZones = Self.decode([ClockZone].self, defaults, Keys.clockZones) ?? ClockZone.defaults

        // Reflect the OS login-item state without re-triggering registration.
        launchAtLogin = LoginItem.isEnabled()

        loaded = true
    }

    // MARK: Derived

    /// Modules to display, in user order, filtered to the enabled set.
    var visibleModules: [ModuleKind] {
        moduleOrder.filter { enabledModules.contains($0) }
    }

    func isEnabled(_ kind: ModuleKind) -> Bool { enabledModules.contains(kind) }

    func setEnabled(_ kind: ModuleKind, _ on: Bool) {
        if on { enabledModules.insert(kind) } else { enabledModules.remove(kind) }
    }

    // MARK: Persistence

    private func persist() {
        guard loaded else { return }
        Self.encode(enabledModules.map(\.rawValue), defaults, Keys.enabledModules)
        Self.encode(moduleOrder.map(\.rawValue), defaults, Keys.moduleOrder)
        defaults.set(refreshInterval, forKey: Keys.refreshInterval)
        defaults.set(useFahrenheit, forKey: Keys.useFahrenheit)
        defaults.set(colorCoded, forKey: Keys.colorCoded)
        defaults.set(showMenuBarIcons, forKey: Keys.showMenuBarIcons)
        defaults.set(networkInBits, forKey: Keys.networkInBits)
        Self.encode(clockZones, defaults, Keys.clockZones)
        defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
    }

    private static func normalizedOrder(_ order: [ModuleKind]) -> [ModuleKind] {
        var result = order
        for kind in ModuleKind.defaultOrder where !result.contains(kind) { result.append(kind) }
        return result
    }

    private enum Keys {
        static let enabledModules = "enabledModules"
        static let moduleOrder = "moduleOrder"
        static let refreshInterval = "refreshInterval"
        static let useFahrenheit = "useFahrenheit"
        static let colorCoded = "colorCoded"
        static let showMenuBarIcons = "showMenuBarIcons"
        static let networkInBits = "networkInBits"
        static let clockZones = "clockZones"
        static let launchAtLogin = "launchAtLogin"
    }

    private static func encode<T: Encodable>(_ value: T, _ defaults: UserDefaults, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ defaults: UserDefaults, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
