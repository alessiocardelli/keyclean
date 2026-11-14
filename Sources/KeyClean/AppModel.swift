import AppKit
import Combine

@MainActor
final class AppModel: NSObject, ObservableObject {
    @Published private(set) var isTrusted = KeyboardBlocker.isTrusted
    @Published private(set) var isLocked = false
    @Published var errorMessage: String?

    var onLockChange: ((Bool) -> Void)?

    private let blocker = KeyboardBlocker()
    private var trustTimer: Timer?

    /// Mentre manca il permesso si ricontrolla ogni secondo: appena Alessio lo concede il pannello si aggiorna da solo.
    func watchTrust() {
        refreshTrust()
        guard !isTrusted, trustTimer == nil else { return }
        trustTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(refreshTrust), userInfo: nil, repeats: true)
    }

    @objc private func refreshTrust() {
        isTrusted = KeyboardBlocker.isTrusted
        if isTrusted {
            trustTimer?.invalidate()
            trustTimer = nil
        }
    }

    func requestTrust() {
        KeyboardBlocker.requestTrust()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        watchTrust()
    }

    func lock() {
        errorMessage = nil
        guard blocker.start() else {
            errorMessage = "macOS non ha concesso il blocco. Controlla il permesso di Accessibilità."
            refreshTrust()
            return
        }
        isLocked = true
        onLockChange?(true)
    }

    func unlock() {
        blocker.stop()
        isLocked = false
        onLockChange?(false)
    }
}
