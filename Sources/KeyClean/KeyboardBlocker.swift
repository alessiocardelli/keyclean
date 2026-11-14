import AppKit
import ApplicationServices

/// Scarta tutti gli eventi di tastiera con un event tap di sessione. Il tap esiste solo durante il blocco
/// e muore con il processo: chiudere l'app sblocca sempre la tastiera.
final class KeyboardBlocker {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isActive: Bool { tap != nil }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Mostra la richiesta di sistema e aggiunge KeyClean alla lista di Accessibilità.
    static func requestTrust() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Restituisce false se macOS non concede il tap (permesso mancante).
    func start() -> Bool {
        guard tap == nil else { return true }
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        var mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        // NX_SYSDEFINED (14): tasti multimediali, luminosità, volume
        mask |= CGEventMask(1) << 14

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: KeyboardBlocker.callback,
            userInfo: refcon
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        self.source = nil
    }

    private static let callback: CGEventTapCallBack = { _, type, event, refcon in
        // macOS spegne il tap se risponde lento o su richiesta dell'utente: si riaccende subito
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let refcon {
                let blocker = Unmanaged<KeyboardBlocker>.fromOpaque(refcon).takeUnretainedValue()
                if let tap = blocker.tap { CGEvent.tapEnable(tap: tap, enable: true) }
            }
            return Unmanaged.passUnretained(event)
        }
        if type.rawValue == 14 {
            // Tra gli eventi di sistema si scartano solo i tasti speciali (sottotipo 8), il resto passa
            let subtype = NSEvent(cgEvent: event)?.subtype.rawValue
            return subtype == 8 ? nil : Unmanaged.passUnretained(event)
        }
        return nil
    }
}
