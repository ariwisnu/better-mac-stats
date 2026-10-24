import AppKit
import SwiftUI
import BetterMacStatsCore

/// Native preferences window: icon tabs in the toolbar, one fixed-size pane per tab.
final class SettingsWindowController: NSWindowController {
    init(settings: AppSettings) {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        func add<V: View>(_ title: String, _ symbol: String, height: CGFloat, _ view: V) {
            let pane = NSHostingController(rootView: view.frame(width: Self.width, height: height))
            pane.title = title
            pane.preferredContentSize = NSSize(width: Self.width, height: height)
            let item = NSTabViewItem(viewController: pane)
            item.label = title
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            tabs.addTabViewItem(item)
        }
        add("General", "gearshape", height: 170, GeneralTab(settings: settings))
        add("Modules", "square.grid.2x2", height: 430, ModulesTab(settings: settings))
        add("Appearance", "paintbrush", height: 270, AppearanceTab(settings: settings))
        add("Clock", "clock", height: 430, ClockTab(settings: settings))
        add("About", "info.circle", height: 320, AboutTab())

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    private static let width: CGFloat = 500

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible == false { window?.center() }
        window?.makeKeyAndOrderFront(nil)
    }
}

private extension View {
    /// System Settings-style grouped rows on macOS 13+; padded columns on macOS 12.
    @ViewBuilder func groupedForm() -> some View {
        if #available(macOS 13.0, *) {
            formStyle(.grouped)
        } else {
            padding(20)
        }
    }
}

/// A rounded, tinted symbol tile, as System Settings uses for its rows.
private struct IconTile: View {
    var symbol: String
    var color: Color
    var size: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(LinearGradient(colors: [color.opacity(0.8), color], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay(Image(systemName: symbol)
                .font(.system(size: size * 0.55, weight: .semibold))
                .foregroundColor(.white))
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .toggleStyle(.switch)
            }
            Section {
                Picker("Update interval", selection: $settings.refreshInterval) {
                    ForEach(AppSettings.refreshIntervalOptions, id: \.self) { v in
                        Text(intervalLabel(v)).tag(v)
                    }
                }
            } footer: {
                Text("A slower interval uses less CPU and battery. Disabled modules are not polled at all.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .groupedForm()
    }

    private func intervalLabel(_ v: Double) -> String {
        v < 1 ? "\(Int(v * 1000)) ms" : v == 1 ? "1 second" : "\(Int(v)) seconds"
    }
}

// MARK: - Modules

private struct ModulesTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose what appears in the menu bar. Drag to change the order.")
                .font(.callout).foregroundColor(.secondary)
            List {
                ForEach(settings.moduleOrder) { kind in
                    HStack(spacing: 10) {
                        IconTile(symbol: kind.symbol, color: kind.tint)
                        Text(kind.title)
                        Spacer()
                        Toggle(kind.title, isOn: binding(for: kind))
                            .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    }
                    .padding(.vertical, 3)
                }
                .onMove { source, destination in
                    settings.moduleOrder.move(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.1)))
        }
        .padding(20)
    }

    private func binding(for kind: ModuleKind) -> Binding<Bool> {
        Binding(get: { settings.isEnabled(kind) }, set: { settings.setEnabled(kind, $0) })
    }
}

private extension ModuleKind {
    var tint: Color {
        switch self {
        case .cpu: return .blue
        case .gpu: return .purple
        case .memory: return .green
        case .disk: return .gray
        case .network: return .teal
        case .battery: return .mint
        case .sensors: return .orange
        case .bluetooth: return .indigo
        case .clock: return .red
        }
    }
}

// MARK: - Appearance

private struct AppearanceTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Show icons", isOn: $settings.showMenuBarIcons)
                Toggle("Color-code values by load", isOn: $settings.colorCoded)
            } header: {
                Text("Menu Bar")
            }
            .toggleStyle(.switch)
            Section {
                Picker("Network speed", selection: $settings.networkInBits) {
                    Text("Bytes (MB/s)").tag(false)
                    Text("Bits (Mbps)").tag(true)
                }
                Picker("Temperature", selection: $settings.useFahrenheit) {
                    Text("Celsius (°C)").tag(false)
                    Text("Fahrenheit (°F)").tag(true)
                }
            } header: {
                Text("Units")
            }
        }
        .groupedForm()
    }
}

// MARK: - Clock

private struct ClockTab: View {
    @ObservedObject var settings: AppSettings
    private let zoneIDs = TimeZone.knownTimeZoneIdentifiers.sorted()

    var body: some View {
        Form {
            if settings.clockZones.isEmpty {
                Section {
                    Text("No clocks yet. Add one to show the time in the menu bar.")
                        .foregroundColor(.secondary)
                }
            }
            ForEach(settings.clockZones) { zone in
                Section {
                    TextField("Name", text: binding(zone.id, \.label, ""))
                    Picker("Time zone", selection: binding(zone.id, \.timeZoneID, zone.timeZoneID)) {
                        ForEach(zoneIDs, id: \.self) { Text(zoneName($0)).tag($0) }
                    }
                    Toggle("24-hour time", isOn: binding(zone.id, \.use24Hour, true))
                    Toggle("Show seconds", isOn: binding(zone.id, \.showSeconds, false))
                } header: {
                    HStack {
                        Text(zone.label.isEmpty ? "Clock" : zone.label)
                        Spacer()
                        Button(role: .destructive) {
                            settings.clockZones.removeAll { $0.id == zone.id }
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove this clock")
                    }
                }
                .toggleStyle(.switch)
            }
            Section {
                Button {
                    settings.clockZones.append(ClockZone(label: "New Clock", timeZoneID: TimeZone.current.identifier))
                } label: {
                    Label("Add Clock", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            } footer: {
                Text("The first clock is shown in the menu bar; all of them appear in its popover.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .groupedForm()
    }

    private func zoneName(_ id: String) -> String {
        id.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "/", with: " / ")
    }

    /// Looks the zone up by id on every access. `ForEach($array)` bindings capture
    /// an index, so deleting a row while one of its fields is live can crash.
    private func binding<Value>(_ id: UUID, _ keyPath: WritableKeyPath<ClockZone, Value>,
                                _ fallback: Value) -> Binding<Value> {
        Binding(
            get: { settings.clockZones.first { $0.id == id }?[keyPath: keyPath] ?? fallback },
            set: { value in
                guard let i = settings.clockZones.firstIndex(where: { $0.id == id }) else { return }
                settings.clockZones[i][keyPath: keyPath] = value
            })
    }
}

// MARK: - About

private struct AboutTab: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
            VStack(spacing: 3) {
                Text("Better Mac Stats").font(.title2).fontWeight(.semibold)
                Text("Version \(version)").font(.callout).foregroundColor(.secondary)
            }
            Text("A lightweight, native menu bar monitor for CPU, GPU, memory, disk, network, battery, sensors, Bluetooth and world clocks.")
                .font(.callout).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 360)
            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com/ariwisnu/better-mac-stats")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/ariwisnu/better-mac-stats/issues")!)
            }
            .font(.callout)
            .padding(.top, 4)
            Text("MIT License").font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
