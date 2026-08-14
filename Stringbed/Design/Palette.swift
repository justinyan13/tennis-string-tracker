import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: Double
        switch cleaned.count {
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        default:
            r = 0.5; g = 0.5; b = 0.5; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// Night match under the floodlights: near-black court, chalk lines, one loud
/// tennis-ball accent and a clay counterpoint.
enum Palette {
    static let court = Color(hex: "070A08")
    static let courtDeep = Color(hex: "030504")
    static let courtRaised = Color(hex: "0E120F")

    static let chalk = Color(hex: "F1F5EE")
    static let mute = Color(hex: "8B948C")
    static let faint = Color(hex: "5A625C")

    static let ball = Color(hex: "D4FF3E")
    static let clay = Color(hex: "E2703A")
    static let net = Color(hex: "1B2320")

    static let surface = Color.white.opacity(0.045)
    static let surfaceRaised = Color.white.opacity(0.075)
    static let hairline = Color.white.opacity(0.09)
    static let hairlineBright = Color.white.opacity(0.16)

    static let fresh = Color(hex: "5FE3B0")
    static let prime = Color(hex: "D4FF3E")
    static let fading = Color(hex: "FFA23E")
    static let dead = Color(hex: "FF5470")
}

extension StringStatus {
    var tint: Color {
        switch self {
        case .fresh: return Palette.fresh
        case .prime: return Palette.prime
        case .fading: return Palette.fading
        case .dead: return Palette.dead
        }
    }
}

extension StringMaterial {
    /// Fallback colour when a string has no swatch of its own.
    var tint: Color {
        switch self {
        case .polyester: return Color(hex: "9BA6B4")
        case .multifilament: return Color(hex: "EDE4D2")
        case .naturalGut: return Color(hex: "F1DFBB")
        case .syntheticGut: return Color(hex: "D7DCE3")
        case .kevlar: return Color(hex: "D8C46A")
        }
    }
}

extension StringSpec {
    var color: Color { Color(hex: colorHex) }
}

extension Racket {
    var accent: Color { Color(hex: accentHex) }
}

extension Color {
    /// Linear blend in sRGB. Good enough for gauge gradients and colour lifts.
    func mix(with other: Color, by amount: Double) -> Color {
        let t = amount.clamped(to: 0...1)
        let a = UIColor(self).rgba
        let b = UIColor(other).rgba
        return Color(
            .sRGB,
            red: a.r + (b.r - a.r) * t,
            green: a.g + (b.g - a.g) * t,
            blue: a.b + (b.b - a.b) * t,
            opacity: a.a + (b.a - a.a) * t
        )
    }

    /// Black RPM Blast really is black, but a black string drawn on a black court is
    /// no string at all. Lift the darkest colours just enough to read.
    var onCourt: Color {
        let c = UIColor(self).rgba
        let luma = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
        guard luma < 0.34 else { return self }
        return mix(with: .white, by: (0.34 - luma) / 0.34 * 0.62)
    }
}

extension UIColor {
    var rgba: (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}

/// A freshness value rendered as a colour, blended across the four status bands.
func freshnessTint(_ freshness: Double) -> Color {
    switch freshness {
    case 0.82...: return Palette.fresh
    case 0.50..<0.82: return Palette.prime
    case 0.25..<0.50: return Palette.fading
    default: return Palette.dead
    }
}
