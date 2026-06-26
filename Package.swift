// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "BetterMacStats",
    // Deployment target: macOS 12 Monterey. Newer APIs (MenuBarExtra is 13+, so we
    // deliberately use NSStatusItem; SMAppService is 13+ with a LaunchAgent fallback)
    // are guarded with `if #available` at the call site.
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "BetterMacStats", targets: ["BetterMacStats"]),
        .library(name: "BetterMacStatsCore", targets: ["BetterMacStatsCore"]),
    ],
    targets: [
        .target(
            name: "BetterMacStatsCore"
        ),
        .executableTarget(
            name: "BetterMacStats",
            dependencies: ["BetterMacStatsCore"]
        ),
        .testTarget(
            name: "BetterMacStatsCoreTests",
            dependencies: ["BetterMacStatsCore"]
        ),
    ],
    // Swift 5 language mode: avoids Swift 6 strict-concurrency friction with the
    // long-lived AppKit singletons (NSApplication, NSStatusItem) this app relies on.
    swiftLanguageModes: [.v5]
)
// NOTE: This manifest is correct for full Xcode / a healthy toolchain. The
// Command Line Tools build (swift 6.3.2) on the development machine ships a
// broken libPackageDescription that fails to link ANY manifest, so the canonical
// local build path is `Scripts/build.sh` (raw swiftc). See README.
