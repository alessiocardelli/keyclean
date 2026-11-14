import SwiftUI

/// CTA principale: salvia con inchiostro scuro, luce in alto, si abbassa quando premuta. Come EnergyButton di BatteryGuard.
struct SageButtonStyle: ButtonStyle {
    var height: CGFloat = 36
    var fontSize: CGFloat = 13

    func makeBody(configuration: Configuration) -> some View {
        SageButton(configuration: configuration, height: height, fontSize: fontSize)
    }

    private struct SageButton: View {
        let configuration: Configuration
        let height: CGFloat
        let fontSize: CGFloat
        @State private var isHovering = false
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
            let pressed = configuration.isPressed
            configuration.label
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(SageFill(shape: shape, pressed: pressed))
                .overlay(shape.fill(Color.white.opacity(isHovering && !pressed ? 0.1 : 0)))
                .overlay(shape.fill(Palette.sageShade.opacity(pressed ? 0.14 : 0)))
                .overlay(shape.strokeBorder(Palette.sageShade.opacity(colorScheme == .dark ? 0.6 : 0.35), lineWidth: 0.5))
                .shadow(color: Palette.sageMid.opacity(pressed ? 0.15 : 0.35), radius: pressed ? 2 : 6, y: pressed ? 1 : 2)
                .opacity(isEnabled ? 1 : 0.6)
                .onHover { isHovering = $0 }
                .animation(.easeOut(duration: 0.12), value: pressed)
                .animation(.easeOut(duration: 0.12), value: isHovering)
        }
    }
}

/// Riempimento salvia condiviso tra il bottone del pannello e quello di sblocco.
struct SageFill<S: Shape>: View {
    let shape: S
    var pressed = false

    var body: some View {
        shape.fill(
            LinearGradient(colors: [Palette.sageTop, Palette.sageMid], startPoint: .top, endPoint: .bottom)
                .shadow(.inner(color: Color.white.opacity(pressed ? 0.15 : 0.55), radius: 0.5, y: 1))
                .shadow(.inner(color: Palette.sageShade.opacity(0.35), radius: 2, y: -1))
        )
    }
}

/// Azione discreta del footer: solo testo, alone leggero al passaggio del mouse.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        QuietButton(configuration: configuration)
    }

    private struct QuietButton: View {
        let configuration: Configuration
        @State private var isHovering = false
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.colorSchemeContrast) private var contrast

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovering
                                 ? Color.primary
                                 : Palette.secondaryText(isDark: colorScheme == .dark, highContrast: contrast == .increased))
                .padding(.horizontal, 8)
                .frame(minHeight: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : isHovering ? 0.07 : 0))
                )
                .contentShape(Rectangle())
                .onHover { isHovering = $0 }
        }
    }
}
