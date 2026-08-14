import Foundation

/// A frame in the bag.
struct Racket: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// What you actually call it — "Blue Tape", "The Backup", "Match Stick".
    var nickname: String
    var brand: String
    var model: String
    /// Head size in square inches.
    var headSize: Int
    /// Strung weight in grams.
    var weightGrams: Int
    /// Balance in points. Negative is head-light.
    var balancePoints: Double
    var gripSize: String
    var mains: Int
    var crosses: Int
    /// Butt-cap tape colour, so the card reads like the frame looks.
    var accentHex: String
    var acquired: Date
    var isRetired: Bool = false
    var notes: String = ""

    var patternLabel: String { "\(mains)×\(crosses)" }

    var balanceLabel: String {
        let pts = abs(balancePoints)
        let rounded = pts.rounded(.toNearestOrEven)
        let text = rounded == pts ? String(format: "%.0f", pts) : String(format: "%.1f", pts)
        if balancePoints < 0 { return "\(text) pts HL" }
        if balancePoints > 0 { return "\(text) pts HH" }
        return "Even"
    }

    var title: String { nickname.isEmpty ? "\(brand) \(model)" : nickname }
    var subtitle: String { "\(brand) \(model)" }

    /// Denser patterns hold tension marginally better and eat strings slower.
    /// 16×19 is the baseline; 18×20 gets a small durability credit.
    var patternWearFactor: Double {
        let density = Double(mains * crosses)
        let baseline = 16.0 * 19.0
        return (baseline / density).clamped(to: 0.85...1.15)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
