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
            window.isOpaque = false
            window.backgroundColor = .clear
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

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.lockTop, Palette.lockBottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Palette.lockGlow.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: 520)

            VStack(spacing: 0) {
                Image(systemName: "keyboard")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 84, height: 84)
                    .background(SageFill(shape: RoundedRectangle(cornerRadius: 22, style: .continuous)))
                    .shadow(color: Palette.lockGlow.opacity(0.45), radius: 24, y: 6)
                    .accessibilityHidden(true)

                Text("Tastiera bloccata")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Palette.lockText)
                    .padding(.top, 28)

                Text("Pulisci pure: i tasti non fanno niente.")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.lockSecondary)
                    .padding(.top, 8)

                HoldToUnlockButton(onUnlock: onUnlock)
                    .padding(.top, 40)

                Text("Il tasto Touch ID resta attivo: lì passa il panno con delicatezza.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.lockSecondary.opacity(0.8))
                    .padding(.top, 20)
            }
            .multilineTextAlignment(.center)
            .padding(32)
        }
        .ignoresSafeArea()
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
        ZStack(alignment: .leading) {
            SageFill(shape: shape, pressed: isPressing)
            GeometryReader { proxy in
                shape
                    .fill(Palette.sageShade.opacity(0.35))
                    .frame(width: proxy.size.width * progress)
            }
            Label(isPressing ? "Continua a tenere premuto" : "Tieni premuto per sbloccare", systemImage: "lock.open.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
        }
        .frame(width: 300, height: 54)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.sageShade.opacity(0.6), lineWidth: 0.5))
        .shadow(color: Palette.lockGlow.opacity(isPressing ? 0.2 : 0.4), radius: isPressing ? 6 : 16, y: 4)
        .scaleEffect(isPressing ? 0.98 : 1)
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
        .animation(.easeOut(duration: 0.15), value: isPressing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sblocca tastiera")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onUnlock() }
    }
}
