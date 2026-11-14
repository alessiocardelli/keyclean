import SwiftUI

/// Colori dell'interfaccia: verde salvia, stesso schema di BatteryGuard (luce in alto, ombra in basso, inchiostro scuro sul bottone).
enum Palette {
    // Salvia del bottone, dal chiaro in alto al più pieno in basso. In Display P3 come BatteryGuard
    static let sageTop = Color(.displayP3, red: 0.74, green: 0.83, blue: 0.69)
    static let sageMid = Color(.displayP3, red: 0.60, green: 0.72, blue: 0.56)
    static let sageShade = Color(.displayP3, red: 0.24, green: 0.34, blue: 0.24)

    // Inchiostro verde scurissimo sul bottone salvia: contrasto sopra 7:1
    static let ink = Color(red: 0.06, green: 0.12, blue: 0.07)

    // Schermata di blocco: salvia profondo, quasi bosco
    static let lockTop = Color(.displayP3, red: 0.19, green: 0.25, blue: 0.20)
    static let lockBottom = Color(.displayP3, red: 0.08, green: 0.11, blue: 0.09)
    static let lockGlow = Color(.displayP3, red: 0.55, green: 0.68, blue: 0.52)
    static let lockText = Color(red: 0.93, green: 0.96, blue: 0.92)
    static let lockSecondary = Color(red: 0.93, green: 0.96, blue: 0.92).opacity(0.72)

    static func secondaryText(isDark: Bool, highContrast: Bool) -> Color {
        if highContrast { return .primary }
        return isDark ? Color.white.opacity(0.76) : Color.black.opacity(0.62)
    }
}
