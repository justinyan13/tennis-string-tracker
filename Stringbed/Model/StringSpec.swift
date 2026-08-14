import Foundation

/// What the string is actually made of. Drives every number in the tension engine —
/// a co-poly and a natural gut age nothing like each other.
enum StringMaterial: String, Codable, CaseIterable, Identifiable, Hashable {
    case polyester
    case multifilament
    case naturalGut
    case syntheticGut
    case kevlar

    var id: String { rawValue }

    var label: String {
        switch self {
        case .polyester: return "Polyester"
        case .multifilament: return "Multifilament"
        case .naturalGut: return "Natural Gut"
        case .syntheticGut: return "Synthetic Gut"
        case .kevlar: return "Kevlar"
        }
    }

    /// Four-ish characters, for tape labels and dense chips.
    var short: String {
        switch self {
        case .polyester: return "POLY"
        case .multifilament: return "MULTI"
        case .naturalGut: return "GUT"
        case .syntheticGut: return "SYN"
        case .kevlar: return "KEV"
        }
    }

    var blurb: String {
        switch self {
        case .polyester: return "Control and spin. Drops tension fast, goes dead before it breaks."
        case .multifilament: return "Comfort and power. Soft on the arm, frays when it's done."
        case .naturalGut: return "The benchmark. Best tension retention there is, hates humidity."
        case .syntheticGut: return "The all-rounder. Cheap, predictable, nothing special."
        case .kevlar: return "For chronic breakers. Brutally stiff, lasts forever."
        }
    }

    // MARK: - Decay constants
    // Fractions, tuned to published tension-loss testing and stringer rules of thumb.

    /// Share of reference tension surrendered in the first couple of days, before
    /// you've even hit with it. Poly is the worst offender here.
    var settleLoss: Double {
        switch self {
        case .polyester: return 0.11
        case .multifilament: return 0.07
        case .naturalGut: return 0.05
        case .syntheticGut: return 0.08
        case .kevlar: return 0.06
        }
    }

    /// Ambient creep per week of just sitting in the bag, logarithmically damped.
    var creepPerWeek: Double {
        switch self {
        case .polyester: return 0.022
        case .multifilament: return 0.014
        case .naturalGut: return 0.008
        case .syntheticGut: return 0.016
        case .kevlar: return 0.006
        }
    }

    /// Tension surrendered per hour of actual ball striking.
    var playLossPerHour: Double {
        switch self {
        case .polyester: return 0.0085
        case .multifilament: return 0.0060
        case .naturalGut: return 0.0042
        case .syntheticGut: return 0.0070
        case .kevlar: return 0.0030
        }
    }

    /// Hours of play before the average set is done — dead, frayed, or notched through.
    var expectedLifeHours: Double {
        switch self {
        case .polyester: return 16
        case .multifilament: return 22
        case .naturalGut: return 20
        case .syntheticGut: return 18
        case .kevlar: return 45
        }
    }

    /// How this material usually announces the end.
    var failureMode: String {
        switch self {
        case .polyester: return "goes dead"
        case .multifilament: return "frays"
        case .naturalGut: return "frays"
        case .syntheticGut: return "notches"
        case .kevlar: return "saws the crosses"
        }
    }
}

/// One entry in your string library — a product you buy, not a specific stringing.
struct StringSpec: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var brand: String
    var model: String
    var material: StringMaterial
    /// Diameter in millimetres. The number on the packet.
    var gauge: Double
    var colorHex: String
    var pricePerSet: Double
    var isFavorite: Bool = false

    var name: String { "\(brand) \(model)" }

    /// US gauge number for a metric diameter, using the conventional bands.
    var gaugeLabel: String {
        switch gauge {
        case ..<1.06: return "19"
        case ..<1.16: return "18"
        case ..<1.20: return "17L"
        case ..<1.24: return "17"
        case ..<1.28: return "16L"
        case ..<1.34: return "16"
        case ..<1.41: return "15L"
        default: return "15"
        }
    }

    var gaugeDetail: String { String(format: "%.2fmm · %@", gauge, gaugeLabel) }
}
