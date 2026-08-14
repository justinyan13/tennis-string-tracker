import Foundation

/// A believable bag on first launch, so the app has something to say before you've
/// typed anything. Wipe it from Settings once you've entered your own frames.
enum SeedData {

    private static func ago(_ days: Double) -> Date {
        Date().addingTimeInterval(-days * 86_400)
    }

    static func snapshot() -> Snapshot {
        let specs = StringLibrary.defaults()

        func specID(_ brand: String, _ model: String) -> UUID {
            specs.first { $0.brand == brand && $0.model == model }?.id ?? specs[0].id
        }

        let alu = specID("Luxilon", "ALU Power")
        let rpm = specID("Babolat", "RPM Blast")
        let hyperG = specID("Solinco", "Hyper-G")
        let lynx = specID("Head", "Lynx Tour")
        let vsTouch = specID("Babolat", "VS Touch")

        // MARK: Frames

        let blade = Racket(
            nickname: "Blue Tape", brand: "Wilson", model: "Blade 98 v9",
            headSize: 98, weightGrams: 305, balancePoints: -7, gripSize: "4 3/8",
            mains: 16, crosses: 19, accentHex: "2F6BFF", acquired: ago(410),
            notes: "Match frame. Two strips of lead at 3 and 9."
        )
        let ezone = Racket(
            nickname: "The Sharp One", brand: "Yonex", model: "EZONE 98",
            headSize: 98, weightGrams: 305, balancePoints: -6, gripSize: "4 3/8",
            mains: 16, crosses: 19, accentHex: "D4FF3E", acquired: ago(180),
            notes: "Newest frame. Softer than the Blade, more free depth."
        )
        let strike = Racket(
            nickname: "Gut Job", brand: "Babolat", model: "Pure Strike 97",
            headSize: 97, weightGrams: 320, balancePoints: -4, gripSize: "4 1/2",
            mains: 18, crosses: 20, accentHex: "E2703A", acquired: ago(620),
            notes: "Only comes out for hybrids. Too heavy for a three-hour day."
        )

        // MARK: Stringings

        var jobs: [StringJob] = []
        var sessions: [PlaySession] = []

        func log(_ job: StringJob, _ entries: [(Double, Double, SessionKind, Surface, Int)]) {
            for (daysAgo, hours, kind, surface, feel) in entries {
                sessions.append(PlaySession(
                    jobID: job.id, racketID: job.racketID, date: ago(daysAgo),
                    hours: hours, kind: kind, surface: surface, feel: feel
                ))
            }
        }

        // Blade — three generations of stringbed, the oldest snapped.
        let bladeA = StringJob(
            racketID: blade.id, mainsSpecID: alu, crossesSpecID: alu,
            mainsTension: 50, crossesTension: 48, installedAt: ago(96),
            stringer: "Court One Racquet Lab", cost: 45,
            notes: "Standard reference tension.",
            retiredAt: ago(62), retireReason: .broke, rating: 4
        )
        log(bladeA, [
            (92, 1.5, .practice, .hard, 5), (88, 2.0, .match, .hard, 5),
            (83, 1.5, .drills, .hard, 4), (79, 2.0, .match, .clay, 4),
            (74, 1.5, .practice, .hard, 4), (70, 2.0, .match, .hard, 3),
            (66, 1.5, .serves, .hard, 3), (63, 2.0, .match, .hard, 3),
        ])

        let bladeB = StringJob(
            racketID: blade.id, mainsSpecID: rpm, crossesSpecID: rpm,
            mainsTension: 52, crossesTension: 50, installedAt: ago(62),
            stringer: "Court One Racquet Lab", cost: 40,
            notes: "Went up two pounds after the ALU let go. Felt boardy for a week.",
            retiredAt: ago(26), retireReason: .wentDead, rating: 3
        )
        log(bladeB, [
            (60, 1.5, .practice, .hard, 3), (55, 2.0, .match, .hard, 4),
            (50, 1.5, .drills, .hard, 4), (45, 1.5, .practice, .clay, 3),
            (40, 2.0, .match, .hard, 3), (34, 1.5, .practice, .hard, 2),
            (29, 2.0, .match, .hard, 2), (27, 1.0, .serves, .hard, 2),
        ])

        let bladeLive = StringJob(
            racketID: blade.id, mainsSpecID: alu, crossesSpecID: lynx,
            mainsTension: 50, crossesTension: 48, installedAt: ago(26),
            stringer: "Court One Racquet Lab", cost: 48,
            notes: "First hybrid in this frame. ALU mains for bite, Lynx crosses for comfort.",
            rating: 5
        )
        log(bladeLive, [
            (24, 1.5, .practice, .hard, 5), (20, 2.0, .match, .hard, 5),
            (16, 1.5, .drills, .hard, 5), (12, 2.0, .match, .clay, 4),
            (8, 1.5, .practice, .hard, 4), (4, 2.0, .match, .hard, 4),
            (1, 1.0, .serves, .hard, 3),
        ])

        // EZONE — one dead full bed of Hyper-G, one brand new.
        let ezoneA = StringJob(
            racketID: ezone.id, mainsSpecID: hyperG, crossesSpecID: hyperG,
            mainsTension: 48, crossesTension: 46, installedAt: ago(70),
            stringer: "Court One Racquet Lab", cost: 38,
            notes: "Rode this one way too long.",
            retiredAt: ago(5), retireReason: .wentDead, rating: 4
        )
        log(ezoneA, [
            (68, 2.0, .match, .hard, 5), (62, 1.5, .practice, .hard, 5),
            (57, 1.5, .drills, .hard, 4), (51, 2.0, .match, .hard, 4),
            (44, 1.5, .practice, .clay, 4), (38, 2.0, .match, .hard, 3),
            (31, 1.5, .practice, .hard, 3), (25, 1.5, .drills, .hard, 2),
            (18, 2.0, .match, .hard, 2), (11, 1.5, .practice, .indoor, 2),
            (7, 1.5, .match, .hard, 1),
        ])

        let ezoneLive = StringJob(
            racketID: ezone.id, mainsSpecID: hyperG, crossesSpecID: hyperG,
            mainsTension: 48, crossesTension: 46, installedAt: ago(5),
            stringer: "Court One Racquet Lab", cost: 38,
            notes: "Same recipe. It works, stop experimenting."
        )
        log(ezoneLive, [
            (3, 1.5, .practice, .hard, 5), (1, 2.0, .match, .hard, 5),
        ])

        // Pure Strike — the gut hybrid, prestretched.
        let strikeLive = StringJob(
            racketID: strike.id, mainsSpecID: vsTouch, crossesSpecID: rpm,
            mainsTension: 54, crossesTension: 50, installedAt: ago(12),
            stringer: "Self", cost: 72, prestretched: true,
            notes: "Gut mains, poly crosses. Expensive, and worth every cent for two weeks.",
            rating: 5
        )
        log(strikeLive, [
            (10, 2.0, .match, .hard, 5), (7, 1.5, .practice, .hard, 5),
            (4, 1.5, .drills, .clay, 5), (2, 1.5, .match, .hard, 5),
        ])

        jobs = [bladeA, bladeB, bladeLive, ezoneA, ezoneLive, strikeLive]

        return Snapshot(
            rackets: [blade, ezone, strike],
            specs: specs,
            jobs: jobs,
            sessions: sessions,
            tensionUnit: .pounds,
            defaultStringer: "Court One Racquet Lab"
        )
    }
}
