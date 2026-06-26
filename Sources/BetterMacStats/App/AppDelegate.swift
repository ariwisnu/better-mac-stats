import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: AppSettings!
    private var engine: StatsEngine!
    private var controller: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = AppSettings()
        engine = StatsEngine(settings: settings)
        controller = MenuBarController(settings: settings, engine: engine)
        controller.start()
    }
}
