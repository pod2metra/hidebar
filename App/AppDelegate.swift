import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = AppController()
        self.controller = controller
        controller.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        controller?.permissionsMayHaveChanged()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }
}
