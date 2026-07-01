import SwiftUI

// MARK: - Button styles

/// Rose-fill primary action. White ink, 6px radius, tactile press.
struct PrimaryButtonStyle: ButtonStyle {
    var compact: Bool = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(compact ? 12.5 : 14.5, .bold))
            .foregroundColor(Theme.accentInk)
            .padding(.horizontal, compact ? 13 : 22)
            .padding(.vertical, compact ? 6 : 12)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : (enabled ? 1 : 0.5))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Outlined secondary action. Transparent, fills `surface-2` on press.
struct GhostButtonStyle: ButtonStyle {
    var compact: Bool = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(compact ? 12.5 : 14.5, .semibold))
            .foregroundColor(Theme.text)
            .padding(.horizontal, compact ? 13 : 20)
            .padding(.vertical, compact ? 6 : 11)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .fill(configuration.isPressed ? Theme.surface2 : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(Theme.borderStrong, lineWidth: 1)
            )
            .opacity(enabled ? 1 : 0.5)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Brand mark

/// Rose rounded-square with an inset dot — the menu-bar/web brand mark.
struct BrandMark: View {
    var size: CGFloat = 22
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(Theme.accent)
            .frame(width: size, height: size)
            .overlay(
                Circle().fill(Theme.accentInk).frame(width: size * 0.32, height: size * 0.32)
            )
    }
}

// MARK: - Badge

struct Badge: View {
    let text: String
    var systemImage: String? = nil
    var accent: Bool = false
    var dot: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if dot {
                Circle().fill(accent ? Theme.accentText : Theme.muted).frame(width: 6, height: 6)
            }
            if let s = systemImage {
                Image(systemName: s).font(.system(size: 10))
            }
            Text(text).font(Theme.mono(11))
        }
        .foregroundColor(accent ? Theme.accentText : Theme.muted)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(accent ? Theme.accentSoft : Color.clear))
        .overlay(
            Capsule().stroke(accent ? Theme.accentText.opacity(0.4) : Theme.borderStrong, lineWidth: 1)
        )
    }
}

// MARK: - Keycap

struct Keycap: View {
    let label: String
    var body: some View {
        Text(label)
            .font(Theme.mono(11, .medium))
            .foregroundColor(Theme.text)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

// MARK: - Thin divider

struct ThinDivider: View {
    var body: some View { Rectangle().fill(Theme.border).frame(height: 1) }
}

// MARK: - Recording chip (signature motif)

/// The live "Option+D" recording moment: pulsing rose dot, animated waveform,
/// keycaps. Loops collapse to static under Reduce Motion.
struct RecordingChip: View {
    var label: String = "Recording"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 9) {
            PulsingDot(animated: !reduceMotion)
            Text(label).font(Theme.mono(12)).foregroundColor(Theme.text)
            Waveform(animated: !reduceMotion)
            HStack(spacing: 4) { Keycap(label: "⌥"); Keycap(label: "D") }
        }
        .padding(.leading, 13)
        .padding(.trailing, 7)
        .padding(.vertical, 7)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
    }
}

private struct PulsingDot: View {
    let animated: Bool
    @State private var dim = false
    var body: some View {
        Circle()
            .fill(Theme.accent)
            .frame(width: 8, height: 8)
            .opacity(animated ? (dim ? 0.35 : 1) : 1)
            .onAppear {
                guard animated else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}

private struct Waveform: View {
    let animated: Bool
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                WaveBar(delay: Double(i) * 0.13, animated: animated)
            }
        }
        .frame(height: 14, alignment: .bottom)
    }
}

private struct WaveBar: View {
    let delay: Double
    let animated: Bool
    @State private var tall = false
    var body: some View {
        Capsule()
            .fill(Theme.accent)
            .frame(width: 2, height: animated ? (tall ? 14 : 4) : 8)
            .onAppear {
                guard animated else { return }
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true).delay(delay)) {
                    tall = true
                }
            }
    }
}
