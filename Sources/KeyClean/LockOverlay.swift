import AppKit
import SwiftUI

/// Copre tutti gli schermi durante il blocco. Il mouse e il trackpad restano attivi: servono per sbloccare.
@MainActor
final class LockOverlayController {
    private var windows: [NSWindow] = []
    private let onUnlock: () -> Void

    init(onUnlock: @escaping () -> Void) {
        self.onUnlock = onUnlock
    }

    func show() {
        guard windows.isEmpty else { return }
        for screen in NSScreen.screens {
            let window = OverlayWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: false)
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.backgroundColor = .white
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: LockView(onUnlock: onUnlock))
            window.alphaValue = 0
            window.orderFrontRegardless()
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            windows.forEach { $0.animator().alphaValue = 1 }
        }
    }

    func hide() {
        let closing = windows
        windows = []
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            closing.forEach { $0.orderOut(nil) }
        })
    }
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

struct LockView: View {
    var onUnlock: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Fondo chiaro e pieno: fa luce sulla tastiera e si vede lo sporco
            LinearGradient(colors: [Palette.lockTop, Palette.lockBottom], startPoint: .top, endPoint: .bottom)

            VStack(spacing: 0) {
                Spacer()

                KeyboardIllustration()
                    .frame(width: 520, height: 330)

                Text("KEYCLEAN")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(Palette.lockLabel)
                    .padding(.top, 20)

                Text("Tastiera bloccata")
                    .font(.system(size: 44, weight: .semibold))
                    .tracking(-0.8)
                    .foregroundStyle(Palette.lockText)
                    .padding(.top, 10)

                Text("Pulisci pure: i tasti non fanno niente.")
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.lockSecondary)
                    .padding(.top, 10)

                HoldToUnlockButton(onUnlock: onUnlock)
                    .padding(.top, 44)

                Spacer()

                Label("Il tasto Touch ID resta attivo: lì passa il panno con delicatezza.", systemImage: "touchid")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.lockSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Palette.sageMid.opacity(0.14)))
                    .overlay(Capsule().strokeBorder(Palette.sageShade.opacity(0.16), lineWidth: 0.5))
                    .padding(.bottom, 48)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
        }
        .ignoresSafeArea()
        .onAppear {
            // Ingresso una volta sola
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { appeared = true }
        }
    }
}

/// Si sblocca solo tenendo premuto 1,5 secondi: un tocco involontario mentre si pulisce non basta.
struct HoldToUnlockButton: View {
    var onUnlock: () -> Void

    private static let holdDuration = 1.5
    @State private var progress: CGFloat = 0
    @State private var isPressing = false

    var body: some View {
        let shape = Capsule(style: .continuous)
        ZStack {
            SageFill(shape: shape, pressed: isPressing)
            // Riempimento di avanzamento: scala in orizzontale, non cambia la larghezza
            shape
                .fill(Palette.sageShade.opacity(0.32))
                .scaleEffect(x: progress, y: 1, anchor: .leading)
            HStack(spacing: 10) {
                Image(systemName: isPressing ? "lock.open.fill" : "hand.tap.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 18)
                Text(isPressing ? "Continua a tenere premuto" : "Tieni premuto per sbloccare")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Palette.ink)
        }
        .frame(width: 320, height: 58)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5).blendMode(.overlay))
        .overlay(shape.strokeBorder(Palette.sageShade.opacity(0.5), lineWidth: 0.5))
        .shadow(color: Palette.lockGlow.opacity(isPressing ? 0.2 : 0.45), radius: isPressing ? 8 : 22, y: isPressing ? 2 : 8)
        .scaleEffect(isPressing ? 0.97 : 1)
        .contentShape(shape)
        .onLongPressGesture(minimumDuration: Self.holdDuration, maximumDistance: 60, perform: {
            onUnlock()
        }, onPressingChanged: { pressing in
            isPressing = pressing
            if pressing {
                withAnimation(.linear(duration: Self.holdDuration)) { progress = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.25)) { progress = 0 }
            }
        })
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sblocca tastiera")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onUnlock() }
    }
}
