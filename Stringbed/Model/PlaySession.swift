import Foundation

enum SessionKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case match
    case practice
    case drills
    case lesson
    case serves

    var id: String { rawValue }

    var label: String {
        switch self {
        case .match: return "Match"
        case .practice: return "Practice"
        case .drills: return "Drills"
        case .lesson: return "Lesson"
        case .serves: return "Serve basket"
        }
    }

    var symbol: String {
        switch self {
        case .match: return "trophy.fill"
        case .practice: return "figure.tennis"
        case .drills: return "arrow.left.arrow.right"
        case .lesson: return "person.2.fill"
        case .serves: return "arrow.up.forward"
        }
    }

    /// Not all court time is equal wear. A basket of serves shreds a stringbed;
    /// a lesson is mostly standing around.
    var wearMultiplier: Double {
        switch self {
        case .match: return 1.15
        case .practice: return 1.0
        case .drills: return 1.1
        case .lesson: return 0.7
        case .serves: return 1.35
        }
    }
}

enum Surface: String, Codable, CaseIterable, Identifiable, Hashable {
    case hard
    case clay
    case grass
    case indoor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hard: return "Hard"
        case .clay: return "Clay"
        case .grass: return "Grass"
        case .indoor: return "Indoor"
        }
    }

    /// Clay grit works its way into the bed and abrades it; indoor is kind.
    var wearMultiplier: Double {
        switch self {
        case .hard: return 1.0
        case .clay: return 1.2
        case .grass: return 0.95
        case .indoor: return 0.9
        }
    }
}

/// Court time logged against a specific stringing.
struct PlaySession: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var jobID: UUID
    var racketID: UUID
    var date: Date
    var hours: Double
    var kind: SessionKind = .practice
    var surface: Surface = .hard
    /// 1–5, how the bed felt that day. 0 = unrated.
    var feel: Int = 0
    var notes: String = ""

    /// Wear-adjusted hours — what the tension engine actually consumes.
    var effectiveHours: Double {
        hours * kind.wearMultiplier * surface.wearMultiplier
    }
}
