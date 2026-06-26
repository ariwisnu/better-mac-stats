import Foundation
import ServiceManagement

/// Launch-at-login support. Uses `SMAppService` on macOS 13+ (visible in System
/// Settings › Login Items) and falls back to a user LaunchAgent plist on macOS 12.
enum LoginItem {
    private static let label = "com.bettermacstats.app"

    static func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return FileManager.default.fileExists(atPath: legacyPlistURL().path)
    }

    static func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                let service = SMAppService.mainApp
                if enabled {
                    if service.status != .enabled { try service.register() }
                } else {
                    if service.status == .enabled { try service.unregister() }
                }
            } catch {
                NSLog("[BetterMacStats] login item error: \(error.localizedDescription)")
            }
            return
        }
        enabled ? installLegacyAgent() : removeLegacyAgent()
    }

    // MARK: macOS 12 fallback

    private static func legacyPlistURL() -> URL {
        let agents = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        return agents.appendingPathComponent("\(label).plist")
    }

    private static func installLegacyAgent() {
        guard let exec = Bundle.main.executablePath else { return }
        let url = legacyPlistURL()
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [exec],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
        ]
        if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? data.write(to: url)
            launchctl(["load", "-w", url.path])
        }
    }

    private static func removeLegacyAgent() {
        let url = legacyPlistURL()
        launchctl(["unload", "-w", url.path])
        try? FileManager.default.removeItem(at: url)
    }

    private static func launchctl(_ args: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = args
        try? process.run()
        process.waitUntilExit()
    }
}
