import Foundation
import Observation

/// Everything on disk, in one envelope.
struct Snapshot: Codable {
    var rackets: [Racket] = []
    var specs: [StringSpec] = []
    var jobs: [StringJob] = []
    var sessions: [PlaySession] = []
    var tensionUnit: TensionUnit = .pounds
    var defaultStringer: String = ""
}

@Observable
final class Store {
    var rackets: [Racket] = []
    var specs: [StringSpec] = []
    var jobs: [StringJob] = []
    var sessions: [PlaySession] = []
    var tensionUnit: TensionUnit = .pounds
    var defaultStringer: String = ""

    private let fileURL: URL
    private var loaded = false

    init(fileName: String = "stringbed.json", seedIfEmpty: Bool = true) {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? URL.temporaryDirectory
        fileURL = base.appendingPathComponent(fileName)
        load(seedIfEmpty: seedIfEmpty)
    }

    // MARK: - Persistence

    private func load(seedIfEmpty: Bool) {
        defer { loaded = true }
        if let data = try? Data(contentsOf: fileURL),
           let snapshot = try? JSONDecoder.stringbed.decode(Snapshot.self, from: data),
           !snapshot.rackets.isEmpty {
            apply(snapshot)
            return
        }
        if seedIfEmpty {
            apply(SeedData.snapshot())
            persist()
        }
    }

    private func apply(_ snapshot: Snapshot) {
        rackets = snapshot.rackets
        specs = snapshot.specs
        jobs = snapshot.jobs
        sessions = snapshot.sessions
        tensionUnit = snapshot.tensionUnit
        defaultStringer = snapshot.defaultStringer
    }

    func persist() {
        guard loaded else { return }
        let snapshot = Snapshot(
            rackets: rackets, specs: specs, jobs: jobs, sessions: sessions,
            tensionUnit: tensionUnit, defaultStringer: defaultStringer
        )
        guard let data = try? JSONEncoder.stringbed.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func resetToSeed() {
        loaded = true
        apply(SeedData.snapshot())
        persist()
    }

    // MARK: - Lookups

    var activeRackets: [Racket] {
        rackets.filter { !$0.isRetired }
    }

    func racket(_ id: UUID) -> Racket? { rackets.first { $0.id == id } }

    func spec(_ id: UUID) -> StringSpec {
        specs.first { $0.id == id } ?? StringSpec(
            id: id, brand: "Unknown", model: "String", material: .syntheticGut,
            gauge: 1.25, colorHex: "9AA3AD", pricePerSet: 0
        )
    }

    func jobs(for racketID: UUID) -> [StringJob] {
        jobs.filter { $0.racketID == racketID }.sorted { $0.installedAt > $1.installedAt }
    }

    func liveJob(for racketID: UUID) -> StringJob? {
        jobs(for: racketID).first { $0.isLive }
    }

    func sessions(forJob jobID: UUID) -> [PlaySession] {
        sessions.filter { $0.jobID == jobID }.sorted { $0.date > $1.date }
    }

    func sessions(forRacket racketID: UUID) -> [PlaySession] {
        sessions.filter { $0.racketID == racketID }.sorted { $0.date > $1.date }
    }

    /// Every session, newest first — the global feed.
    var recentSessions: [PlaySession] {
        sessions.sorted { $0.date > $1.date }
    }

    // MARK: - Derived

    func estimate(for job: StringJob, asOf: Date = Date()) -> TensionEstimate {
        TensionEngine.estimate(
            job: job,
            mainsSpec: spec(job.mainsSpecID),
            crossesSpec: spec(job.crossesSpecID),
            racket: racket(job.racketID),
            sessions: sessions,
            asOf: asOf
        )
    }

    func liveEstimate(for racketID: UUID) -> TensionEstimate? {
        guard let job = liveJob(for: racketID) else { return nil }
        return estimate(for: job)
    }

    /// Hours per week over the trailing eight weeks — the play rate used for projections.
    var hoursPerWeek: Double {
        let cutoff = Date().addingTimeInterval(-56 * 86_400)
        let recent = sessions.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(0) { $0 + $1.hours } / 8
    }

    /// Sessions per week over the trailing eight weeks.
    var sessionsPerWeek: Double {
        let cutoff = Date().addingTimeInterval(-56 * 86_400)
        return Double(sessions.filter { $0.date >= cutoff }.count) / 8
    }

    func daysUntilFade(for job: StringJob) -> Int? {
        TensionEngine.daysUntilFade(
            job: job,
            mainsSpec: spec(job.mainsSpecID),
            crossesSpec: spec(job.crossesSpecID),
            racket: racket(job.racketID),
            sessions: sessions,
            hoursPerWeek: hoursPerWeek
        )
    }

    /// The frame you should be reaching for — freshest live bed in the bag.
    var sharpestRacket: Racket? {
        activeRackets
            .compactMap { r -> (Racket, Double)? in
                guard let e = liveEstimate(for: r.id) else { return nil }
                return (r, e.freshness)
            }
            .max { $0.1 < $1.1 }?.0
    }

    /// Live jobs that have crossed out of prime, worst first.
    var needsAttention: [(racket: Racket, job: StringJob, estimate: TensionEstimate)] {
        activeRackets.compactMap { r in
            guard let job = liveJob(for: r.id) else { return nil }
            let e = estimate(for: job)
            guard e.freshness < 0.50 else { return nil }
            return (r, job, e)
        }
        .sorted { $0.estimate.freshness < $1.estimate.freshness }
    }

    /// Frames in the bag with nothing strung in them.
    var unstrungRackets: [Racket] {
        activeRackets.filter { liveJob(for: $0.id) == nil }
    }

    // MARK: - Mutations

    func upsert(_ racket: Racket) {
        if let idx = rackets.firstIndex(where: { $0.id == racket.id }) {
            rackets[idx] = racket
        } else {
            rackets.append(racket)
        }
        persist()
    }

    func delete(racket: Racket) {
        rackets.removeAll { $0.id == racket.id }
        let doomed = Set(jobs.filter { $0.racketID == racket.id }.map(\.id))
        jobs.removeAll { $0.racketID == racket.id }
        sessions.removeAll { doomed.contains($0.jobID) }
        persist()
    }

    func upsert(_ spec: StringSpec) {
        if let idx = specs.firstIndex(where: { $0.id == spec.id }) {
            specs[idx] = spec
        } else {
            specs.append(spec)
        }
        persist()
    }

    func delete(spec: StringSpec) {
        guard !jobs.contains(where: { $0.mainsSpecID == spec.id || $0.crossesSpecID == spec.id }) else { return }
        specs.removeAll { $0.id == spec.id }
        persist()
    }

    /// Records a new stringing and retires whatever was in the frame.
    func install(_ job: StringJob, retiring reason: RetireReason = .experimenting) {
        if var previous = liveJob(for: job.racketID), previous.id != job.id {
            previous.retiredAt = job.installedAt
            previous.retireReason = reason
            upsert(previous)
        }
        upsert(job)
    }

    func upsert(_ job: StringJob) {
        if let idx = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[idx] = job
        } else {
            jobs.append(job)
        }
        persist()
    }

    func retire(job: StringJob, reason: RetireReason, on date: Date = Date()) {
        var updated = job
        updated.retiredAt = date
        updated.retireReason = reason
        upsert(updated)
    }

    func delete(job: StringJob) {
        jobs.removeAll { $0.id == job.id }
        sessions.removeAll { $0.jobID == job.id }
        persist()
    }

    func upsert(_ session: PlaySession) {
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = session
        } else {
            sessions.append(session)
        }
        persist()
    }

    func delete(session: PlaySession) {
        sessions.removeAll { $0.id == session.id }
        persist()
    }

    func setTensionUnit(_ unit: TensionUnit) {
        tensionUnit = unit
        persist()
    }
}

// MARK: - Coding helpers

extension JSONEncoder {
    static var stringbed: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var stringbed: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
