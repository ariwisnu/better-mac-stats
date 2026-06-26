import AppKit

// Better Mac Stats runs as a menu bar agent (LSUIElement), so it owns its
// NSApplication lifecycle directly rather than using the SwiftUI App lifecycle
// (whose MenuBarExtra requires macOS 13 — this app targets macOS 12).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
