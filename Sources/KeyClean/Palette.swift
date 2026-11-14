import SwiftUI

/// Colori dell'interfaccia: verde salvia, stesso schema di BatteryGuard (luce in alto, ombra in basso, inchiostro scuro sul bottone).
enum Palette {
    // Salvia del bottone, dal chiaro in alto al più pieno in basso. In Display P3 come BatteryGuard
    static let sageTop = Color(.displayP3, red: 0.74, green: 0.83, blue: 0.69)
    static let sageMid = Color(.displayP3, red: 0.60, green: 0.72, blue: 0.56)
    static let sageShade = Color(.displayP3, red: 0.24, green: 0.34, blue: 0.24)

    // Inchiostro verde scurissimo sul bottone salvia: contrasto sopra 7:1
    static let ink = Color(red: 0.06, green: 0.12, blue: 0.07)

    // Schermata di blocco: quasi bianco con un velo salvia, testi in salvia scuro (contrasto sopra 4,5:1)
    static let lockTop = Color(.displayP3, red: 0.99, green: 0.995, blue: 0.985)
    static let lockBottom = Color(.displayP3, red: 0.93, green: 0.955, blue: 0.92)
    static let lockGlow = Color(.displayP3, red: 0.55, green: 0.68, blue: 0.52)
    static let lockText = sageShade
    static let lockLabel = Color(.displayP3, red: 0.31, green: 0.43, blue: 0.30)
    static let lockSecondary = ink.opacity(0.66)

    static func secondaryText(isDark: Bool, highContrast: Bool) -> Color {
        if highContrast { return .primary }
        return isDark ? Color.white.opacity(0.76) : Color.black.opacity(0.62)
    }
}
