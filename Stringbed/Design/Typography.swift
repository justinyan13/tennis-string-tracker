import SwiftUI

/// Two voices: wide, tracked-out uppercase for labels (scoreboard), and heavy
/// rounded monospaced digits for anything numeric (readout).
enum Type {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func readout(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded).monospacedDigit()
    }

    static func body(_ size: CGFloat = 15, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct ScoreboardLabel: ViewModifier {
    var size: CGFloat = 11
    var color: Color = Palette.mute
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .bold, design: .rounded))
            .tracking(size * 0.16)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

extension View {
    func scoreboard(size: CGFloat = 11, color: Color = Palette.mute) -> some View {
        modifier(ScoreboardLabel(size: size, color: color))
    }
}
