import Foundation

/// Where a stringbed is in its life.
enum StringStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case fresh
    case prime
    case fading
    case dead

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fresh: return "FRESH"
        case .prime: return "PRIME"
        case .fading: return "FADING"
        case .dead: return "DEAD"
        }
    }

    var blurb: String {
        switch self {
        case .fresh: return "Still settling. Boardy for a session or two, then it opens up."
        case .prime: return "The window. Everything you paid for is happening right now."
        case .fading: return "Losing bite. Balls sitting up, depth control going."
        case .dead: return "Trampoline. Cut it out before your elbow files a complaint."
        }
    }

    static func from(freshness: Double) -> StringStatus {
        switch freshness {
        case 0.82...: return .fresh
        case 0.50..<0.82: return .prime
        case 0.25..<0.50: return .fading
        default: return .dead
        }
    }
}

/// A single sampled point on the decay curve.
struct TensionPoint: Identifiable, Hashable {
    var id: Date { date }
    var date: Date
    var mains: Double
    var crosses: Double
    var isProjection: Bool
}

/// Everything the UI needs to know about how a stringbed is holding up.
struct TensionEstimate: Hashable {
    var referenceMains: Double
    var referenceCrosses: Double
    var currentMains: Double
    var currentCrosses: Double
    var mainsRetention: Double
    var crossesRetention: Double
    /// Raw logged hours.
    var hours: Double
    /// Wear-adjusted hours the engine actually consumed.
    var effectiveHours: Double
    var days: Double
    var sessionCount: Int
    /// Share of the set's expected life burned through, 0–1+.
    var lifeUsed: Double
    /// 0–1 composite of tension held and life left.
    var freshness: Double

    var status: StringStatus { .from(freshness: freshness) }

    var lostPoundsMains: Double { max(0, referenceMains - currentMains) }
    var lostPercentMains: Double { referenceMains > 0 ? (1 - mainsRetention) * 100 : 0 }

    static let empty = TensionEstimate(
        referenceMains: 0, referenceCrosses: 0, currentMains: 0, currentCrosses: 0,
        mainsRetention: 1, crossesRetention: 1, hours: 0, effectiveHours: 0, days: 0,
        sessionCount: 0, lifeUsed: 0, freshness: 1
    )
}

/// The model behind every number in the app.
///
/// Tension loss is treated as three independent multiplicative effects:
///
///   1. **Settling** — a fast exponential drop in the first ~48h as the knots seat
///      and the material relaxes. Prestretching front-loads most of this onto the
///      stringer's clock instead of yours.
///   2. **Creep** — slow logarithmic relaxation just from sitting in the bag.
///   3. **Play** — linear loss per wear-adjusted hour of ball striking.
///
/// Constants live on `StringMaterial` and are tuned to published tension-retention
/// testing plus the usual stringer rules of thumb. They are estimates, not gospel —
/// the point is a consistent, comparable signal across your own setups.
enum TensionEngine {

    /// Crosses sit lower in the load path and shed tension a little slower than mains.
    private static let crossPlayShare = 0.82
    /// Mains dominate how the bed feels, so they dominate the freshness score.
    private static let mainsFreshnessWeight = 0.65

    static func retention(
        material: StringMaterial,
        days: Double,
        effectiveHours: Double,
        settleDamping: Double = 1.0,
        patternFactor: Double = 1.0,
        playShare: Double = 1.0
    ) -> Double {
        let d = max(0, days)
        let h = max(0, effectiveHours)

        let settle = material.settleLoss * settleDamping * (1 - exp(-d / 1.5))
        let creep = material.creepPerWeek * log(1 + d / 7)
        let play = material.playLossPerHour * h * patternFactor * playShare

        let held = (1 - settle) * (1 - creep) * (1 - play)
        return held.clamped(to: 0.35...1.0)
    }

    static func estimate(
        job: StringJob,
        mainsSpec: StringSpec,
        crossesSpec: StringSpec,
        racket: Racket?,
        sessions: [PlaySession],
        asOf: Date = Date()
    ) -> TensionEstimate {
        let end = job.retiredAt ?? asOf
        let relevant = sessions.filter { $0.jobID == job.id && $0.date <= end }
        let rawHours = relevant.reduce(0) { $0 + $1.hours }
        let effHours = relevant.reduce(0) { $0 + $1.effectiveHours }
        let days = max(0, end.timeIntervalSince(job.installedAt) / 86_400)
        let pattern = racket?.patternWearFactor ?? 1.0

        let mainsR = retention(
            material: mainsSpec.material, days: days, effectiveHours: effHours,
            settleDamping: job.settleDamping, patternFactor: pattern
        )
        let crossR = retention(
            material: crossesSpec.material, days: days, effectiveHours: effHours,
            settleDamping: job.settleDamping, patternFactor: pattern,
            playShare: crossPlayShare
        )

        // A hybrid dies when its weakest element dies — poly mains saw through gut
        // crosses long before the poly itself gives up.
        let lifeHours = min(mainsSpec.material.expectedLifeHours, crossesSpec.material.expectedLifeHours)
        let lifeUsed = lifeHours > 0 ? effHours / lifeHours : 0

        let freshness = freshnessScore(mainsRetention: mainsR, crossesRetention: crossR, lifeUsed: lifeUsed)

        return TensionEstimate(
            referenceMains: job.mainsTension,
            referenceCrosses: job.crossesTension,
            currentMains: job.mainsTension * mainsR,
            currentCrosses: job.crossesTension * crossR,
            mainsRetention: mainsR,
            crossesRetention: crossR,
            hours: rawHours,
            effectiveHours: effHours,
            days: days,
            sessionCount: relevant.count,
            lifeUsed: lifeUsed,
            freshness: freshness
        )
    }

    /// Below this much tension held, the bed plays like a trampoline regardless of
    /// how much physical life is left in the string.
    private static let deadRetention = 0.70

    static func freshnessScore(mainsRetention: Double, crossesRetention: Double, lifeUsed: Double) -> Double {
        let blended = mainsRetention * mainsFreshnessWeight + crossesRetention * (1 - mainsFreshnessWeight)
        let tensionScore = ((blended - deadRetention) / (1 - deadRetention)).clamped(to: 0...1)
        let lifeScore = (1 - lifeUsed).clamped(to: 0...1)
        return (0.55 * tensionScore + 0.45 * lifeScore).clamped(to: 0...1)
    }

    // MARK: - Curve

    /// Samples the decay curve across the job's life, optionally projecting forward
    /// at the player's recent hours-per-week rate.
    static func curve(
        job: StringJob,
        mainsSpec: StringSpec,
        crossesSpec: StringSpec,
        racket: Racket?,
        sessions: [PlaySession],
        asOf: Date = Date(),
        projectDays: Double = 0,
        hoursPerWeek: Double = 0,
        samples: Int = 72
    ) -> [TensionPoint] {
        let end = job.retiredAt ?? asOf
        let livedDays = max(0.35, end.timeIntervalSince(job.installedAt) / 86_400)
        let totalDays = livedDays + max(0, projectDays)
        let relevant = sessions.filter { $0.jobID == job.id }.sorted { $0.date < $1.date }
        let pattern = racket?.patternWearFactor ?? 1.0
        let loggedEffective = relevant.reduce(0) { $0 + $1.effectiveHours }

        return (0...samples).map { step in
            let t = Double(step) / Double(samples) * totalDays
            let date = job.installedAt.addingTimeInterval(t * 86_400)
            let projecting = t > livedDays

            let hours: Double
            if projecting {
                let extraWeeks = (t - livedDays) / 7
                hours = loggedEffective + hoursPerWeek * extraWeeks
            } else {
                hours = relevant.filter { $0.date <= date }.reduce(0) { $0 + $1.effectiveHours }
            }

            let m = retention(
                material: mainsSpec.material, days: t, effectiveHours: hours,
                settleDamping: job.settleDamping, patternFactor: pattern
            )
            let c = retention(
                material: crossesSpec.material, days: t, effectiveHours: hours,
                settleDamping: job.settleDamping, patternFactor: pattern,
                playShare: crossPlayShare
            )
            return TensionPoint(
                date: date,
                mains: job.mainsTension * m,
                crosses: job.crossesTension * c,
                isProjection: projecting
            )
        }
    }

    /// Days from now until freshness crosses out of `.prime`, at the given play rate.
    /// Nil if it's already there, or if the horizon is beyond three months.
    static func daysUntilFade(
        job: StringJob,
        mainsSpec: StringSpec,
        crossesSpec: StringSpec,
        racket: Racket?,
        sessions: [PlaySession],
        hoursPerWeek: Double,
        asOf: Date = Date()
    ) -> Int? {
        let current = estimate(
            job: job, mainsSpec: mainsSpec, crossesSpec: crossesSpec,
            racket: racket, sessions: sessions, asOf: asOf
        )
        guard current.freshness > 0.50 else { return nil }

        let pattern = racket?.patternWearFactor ?? 1.0
        let lifeHours = min(mainsSpec.material.expectedLifeHours, crossesSpec.material.expectedLifeHours)
        let baseDays = current.days
        let baseHours = current.effectiveHours
        // Assume at least a token amount of play, or the curve never fades.
        let rate = max(hoursPerWeek, 0.75)

        for day in 1...92 {
            let d = baseDays + Double(day)
            let h = baseHours + rate * Double(day) / 7
            let m = retention(
                material: mainsSpec.material, days: d, effectiveHours: h,
                settleDamping: job.settleDamping, patternFactor: pattern
            )
            let c = retention(
                material: crossesSpec.material, days: d, effectiveHours: h,
                settleDamping: job.settleDamping, patternFactor: pattern,
                playShare: crossPlayShare
            )
            let f = freshnessScore(
                mainsRetention: m, crossesRetention: c,
                lifeUsed: lifeHours > 0 ? h / lifeHours : 0
            )
            if f <= 0.50 { return day }
        }
        return nil
    }

    /// The old stringer's rule: restring as many times per year as you play per week.
    static func ruleOfThumbIntervalDays(sessionsPerWeek: Double) -> Int {
        let perWeek = max(0.25, sessionsPerWeek)
        return Int((365.0 / perWeek).clamped(to: 14...365))
    }
}
