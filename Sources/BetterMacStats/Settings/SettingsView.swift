import AppKit
import SwiftUI
import BetterMacStatsCore

/// Hosts the SwiftUI settings UI in a standard window.
final class SettingsWindowController: NSWindowController {
    init(settings: AppSettings) {
        let hosting = NSHostingController(rootView: SettingsView(settings: settings))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Better Mac Stats"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 470, height: 440))
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        TabView {
            GeneralTab(settings: settings).tabItem { Label("General", systemImage: "gearshape") }
            ModulesTab(settings: settings).tabItem { Label("Modules", systemImage: "square.grid.2x2") }
            AppearanceTab(settings: settings).tabItem { Label("Appearance", systemImage: "paintbrush") }
            ClockTab(settings: settings).tabItem { Label("Clock", systemImage: "clock") }
            AboutTab().tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 470, height: 440)
        .padding(16)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
            Picker("Update interval", selection: $settings.refreshInterval) {
                ForEach(AppSettings.refreshIntervalOptions, id: \.self) { v in
                    Text(intervalLabel(v)).tag(v)
                }
            }
            Text("A slower interval uses less CPU and battery. Disabled modules are not polled at all.")
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func intervalLabel(_ v: Double) -> String {
        v < 1 ? "\(Int(v * 1000)) ms" : "\(Int(v)) s"
    }
}

// MARK: - Modules

private struct ModulesTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Drag to reorder. Toggle to show or hide a module in the menu bar.")
                .font(.caption).foregroundColor(.secondary)
            List {
                ForEach(settings.moduleOrder) { kind in
                    HStack {
                        Image(systemName: kind.symbol).frame(width: 20)
                        Text(kind.title)
                        Spacer()
                        Toggle("", isOn: binding(for: kind)).labelsHidden()
                    }
                }
                .onMove { source, destination in
                    settings.moduleOrder.move(fromOffsets: source, toOffset: destination)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func binding(for kind: ModuleKind) -> Binding<Bool> {
        Binding(get: { settings.isEnabled(kind) }, set: { settings.setEnabled(kind, $0) })
    }
}

// MARK: - Appearance

private struct AppearanceTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Toggle("Show icons in the menu bar", isOn: $settings.showMenuBarIcons)
            Toggle("Color-code values by load", isOn: $settings.colorCoded)
            Toggle("Show network speed in bits per second", isOn: $settings.networkInBits)
            Picker("Temperature unit", selection: $settings.useFahrenheit) {
                Text("Celsius (°C)").tag(false)
                Text("Fahrenheit (°F)").tag(true)
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Clock

private struct ClockTab: View {
    @ObservedObject var settings: AppSettings
    private let zoneIDs = TimeZone.knownTimeZoneIdentifiers.sorted()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("World clocks").font(.headline)
                Spacer()
                Button {
                    settings.clockZones.append(ClockZone(label: "New", timeZoneID: TimeZone.current.identifier))
                } label: { Image(systemName: "plus") }
            }
            List {
                ForEach($settings.clockZones) { $zone in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            TextField("Label", text: $zone.label).frame(width: 90)
                            Picker("", selection: $zone.timeZoneID) {
                                ForEach(zoneIDs, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            Button {
                                settings.clockZones.removeAll { $0.id == zone.id }
                            } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                        }
                        HStack(spacing: 16) {
                            Toggle("24-hour", isOn: $zone.use24Hour)
                            Toggle("Seconds", isOn: $zone.showSeconds)
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - About

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 44)).foregroundColor(.accentColor)
            Text("Better Mac Stats").font(.title2).fontWeight(.semibold)
            Text("Version 0.1.0").font(.caption).foregroundColor(.secondary)
            Text("A lightweight, native macOS menu bar monitor for CPU, GPU, memory, disk, network, battery, sensors, Bluetooth and world clocks.")
                .font(.system(size: 12)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 20)
    }
}
