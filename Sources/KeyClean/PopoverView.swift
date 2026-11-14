import SwiftUI

/// Pannello della barra dei menu: titolo, stato del permesso, bottone di blocco, uscita.
struct PopoverView: View {
    @ObservedObject var model: AppModel
    var onLock: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private var secondaryText: Color {
        Palette.secondaryText(isDark: colorScheme == .dark, highContrast: contrast == .increased)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if model.isTrusted {
                Button(action: onLock) {
                    Label("Blocca tastiera", systemImage: "keyboard.badge.ellipsis")
                }
                .buttonStyle(SageButtonStyle())
                .padding(.top, 20)

                Text("Per sbloccarla tieni premuto il bottone con il trackpad.")
                    .font(.system(size: 11))
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            } else {
                Text("Per bloccare i tasti KeyClean ha bisogno del permesso di Accessibilità. Attivalo nelle Impostazioni, poi torna qui.")
                    .font(.system(size: 12))
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)

                Button("Apri Impostazioni") { model.requestTrust() }
                    .buttonStyle(SageButtonStyle())
                    .padding(.top, 16)
            }

            if let message = model.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }

            Rectangle()
                .fill(Color.primary.opacity(contrast == .increased ? 0.3 : 0.1))
                .frame(height: 1)
                .padding(.top, 20)

            HStack {
                Spacer()
                Button("Esci") { NSApp.terminate(nil) }
                    .buttonStyle(QuietButtonStyle())
            }
            .padding(.horizontal, -8)
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(width: 280)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 48, height: 48)
                .padding(-4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("KeyClean")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.2)
                HStack(spacing: 5) {
                    Circle()
                        .fill(model.isTrusted ? Palette.sageMid : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(model.isTrusted ? "Pronta" : "Manca un permesso")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(secondaryText)
                }
            }
            Spacer()
        }
    }
}
