import AppKit

/// Ciclo di vita AppKit senza scene SwiftUI: l'interfaccia è il pannello della barra dei menu e la schermata di blocco.
@main
enum KeyCleanApp {
    static func main() {
        let delegate = AppDelegate()
        let app = NSApplication.shared
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel()
        let menuBar = MenuBarController(model: model)
        self.model = model
        self.menuBar = menuBar

        // Solo per i test: blocca subito all'avvio
        if ProcessInfo.processInfo.environment["KEYCLEAN_LOCK_ON_LAUNCH"] == "1" {
            model.lock()
        } else if !KeyboardBlocker.isTrusted {
            // Primo avvio: richiesta di sistema del permesso di Accessibilità
            KeyboardBlocker.requestTrust()
        }
    }

    /// Riaperta dal Finder o da Launchpad: si apre il pannello.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menuBar?.showPanel()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.unlock()
    }
}

