import SwiftUI
import AppKit

// MARK: - Hex helpers

extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green:   CGFloat((hex >> 8) & 0xFF) / 255,
            blue:    CGFloat(hex & 0xFF) / 255,
            alpha:   alpha
        )
    }
}

extension Color {
    init(hex: Int, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:     Double((hex >> 16) & 0xFF) / 255,
            green:   Double((hex >> 8) & 0xFF) / 255,
            blue:    Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// An appearance-adaptive color. Resolves light/dark at draw time via an
/// `NSColor` dynamic provider, so it follows the macOS system appearance
/// everywhere (SwiftUI + AppKit-backed controls) with no `colorScheme`
/// plumbing. This is the native equivalent of the design system's "Auto" mode.
private func adaptive(light: Int, dark: Int, lightA: CGFloat = 1, darkA: CGFloat = 1) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor(hex: isDark ? dark : light, alpha: isDark ? darkA : lightA)
    })
}

/// Voxly "Signal" design tokens, native translation of `claudedocs/voxly-design-system.md`.
/// Fonts use SF (display) + SF Mono (detail) as the native stand-ins for
/// Satoshi + Geist Mono; everything else maps 1:1 to the locked hex tokens.
enum Theme {

    // MARK: Surfaces (light → dark)
    static let bg            = adaptive(light: 0xFCFCFD, dark: 0x08080A)
    static let surface       = adaptive(light: 0xFFFFFF, dark: 0x131318)
    static let surface2      = adaptive(light: 0xF4F5F7, dark: 0x1C1C23)
    static let border        = adaptive(light: 0xE6E8EB, dark: 0x2C2C35)
    static let borderStrong  = adaptive(light: 0xD5D8DD, dark: 0x3A3A45)
    static let text          = adaptive(light: 0x0A0A0B, dark: 0xF7F7F9)
    static let muted         = adaptive(light: 0x6B7075, dark: 0x9A9AA4)

    // MARK: Accent (brand rose, same fill both modes)
    static let accent        = Color(hex: 0xE11D54)
    static let accentInk     = Color.white
    static let accentText    = adaptive(light: 0xBE123C, dark: 0xFF5C86)
    static let accentSoft    = adaptive(light: 0xE11D54, dark: 0xFF5C86, lightA: 0.08, darkA: 0.12)

    // MARK: Functional status — restrained and intentional, not SwiftUI's default rainbow
    static let positive      = adaptive(light: 0x0F7A52, dark: 0x37D399)
    static let warning       = adaptive(light: 0xB45309, dark: 0xF5B454)

    // MARK: Metrics
    static let radius:   CGFloat = 6
    static let radiusLg: CGFloat = 12

    // MARK: Fonts
    static func display(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Text style modifiers

extension View {
    /// Heavy SF with tight tracking — the Signal display voice.
    func displayStyle(_ size: CGFloat, weight: Font.Weight = .heavy) -> some View {
        font(Theme.display(size, weight)).tracking(size * -0.03)
    }

    /// Mono kicker / eyebrow: small, uppercase, wide-tracked, muted.
    func kickerStyle(_ color: Color = Theme.muted) -> some View {
        font(Theme.mono(10.5, .medium))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundColor(color)
    }

    /// Surface card: filled surface, hairline border, 12px radius.
    func voxlyCard(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}
