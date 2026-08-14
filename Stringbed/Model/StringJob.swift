import Foundation

enum RetireReason: String, Codable, CaseIterable, Identifiable, Hashable {
    case broke
    case wentDead
    case experimenting
    case tooStiff
    case tooPowerful

    var id: String { rawValue }

    var label: String {
        switch self {
        case .broke: return "Snapped"
        case .wentDead: return "Went dead"
        case .experimenting: return "Trying something else"
        case .tooStiff: return "Too stiff"
        case .tooPowerful: return "Too powerful"
        }
    }

    /// One word, for places where five options share a row.
    var shortLabel: String {
        switch self {
        case .broke: return "Snapped"
        case .wentDead: return "Dead"
        case .experimenting: return "Switch"
        case .tooStiff: return "Stiff"
        case .tooPowerful: return "Hot"
        }
    }

    var symbol: String {
        switch self {
        case .broke: return "bolt.horizontal.fill"
        case .wentDead: return "waveform.path"
        case .experimenting: return "arrow.triangle.2.circlepath"
        case .tooStiff: return "hand.raised.fill"
        case .tooPowerful: return "flame.fill"
        }
    }
}

enum TensionUnit: String, Codable, CaseIterable, Identifiable, Hashable {
    case pounds
    case kilograms

    var id: String { rawValue }
    var short: String { self == .pounds ? "lb" : "kg" }

    func display(_ pounds: Double) -> Double {
        self == .pounds ? pounds : pounds * 0.45359237
    }
}

/// One stringing. The unit of truth in this app — a racket without a live job
/// is an unstrung frame, and every stat rolls up from these.
struct StringJob: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var racketID: UUID
    var mainsSpecID: UUID
    var crossesSpecID: UUID
    /// Always stored in pounds. Display conversion happens at the edge.
    var mainsTension: Double
    var crossesTension: Double
    var installedAt: Date
    var stringer: String = ""
    var cost: Double = 0
    var prestretched: Bool = false
    var notes: String = ""
    var retiredAt: Date? = nil
    var retireReason: RetireReason? = nil
    /// How it felt, 0 = unrated.
    var rating: Int = 0

    var isHybrid: Bool { mainsSpecID != crossesSpecID }
    var isLive: Bool { retiredAt == nil }

    /// The single number people quote when asked "what are you playing?".
    var tensionLabel: String {
        if abs(mainsTension - crossesTension) < 0.25 {
            return Self.format(mainsTension)
        }
        return "\(Self.format(mainsTension))/\(Self.format(crossesTension))"
    }

    static func format(_ value: Double) -> String {
        let rounded = (value * 2).rounded() / 2
        return rounded == rounded.rounded()
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", rounded)
    }

    /// Prestretching front-loads the settling, so less of it happens on your time.
    var settleDamping: Double { prestretched ? 0.55 : 1.0 }
}
