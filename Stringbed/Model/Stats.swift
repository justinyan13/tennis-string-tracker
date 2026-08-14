import Foundation

/// How one string in the library has actually performed for you.
struct StringPerformance: Identifiable {
    var spec: StringSpec
    var jobCount: Int
    var completedJobs: Int
    var hours: Double
    var cost: Double
    var breaks: Int
    var ratingSum: Int
    var ratedJobs: Int

    var id: UUID { spec.id }
    var hoursPerSet: Double { jobCount > 0 ? hours / Double(jobCount) : 0 }
    var costPerHour: Double { hours > 0 ? cost / hours : 0 }
    var avgRating: Double { ratedJobs > 0 ? Double(ratingSum) / Double(ratedJobs) : 0 }
    /// Only meaningful once a set has actually been cut out.
    var hasDurabilityData: Bool { completedJobs > 0 }
}

struct WeekBucket: Identifiable {
    var id: Date { start }
    var start: Date
    var hours: Double
    var sessions: Int
}

extension Store {

    var totalHours: Double { sessions.reduce(0) { $0 + $1.hours } }
    var totalSpent: Double { jobs.reduce(0) { $0 + $1.cost } }
    var restringCount: Int { jobs.count }

    var costPerHour: Double { totalHours > 0 ? totalSpent / totalHours : 0 }

    /// Average days a stringbed survived, across jobs that have been cut out.
    var averageJobLifeDays: Double? {
        let finished = jobs.compactMap { job -> Double? in
            guard let retired = job.retiredAt else { return nil }
            return retired.timeIntervalSince(job.installedAt) / 86_400
        }
        guard !finished.isEmpty else { return nil }
        return finished.reduce(0, +) / Double(finished.count)
    }

    var averageJobLifeHours: Double? {
        let finished = jobs.filter { !$0.isLive }
        guard !finished.isEmpty else { return nil }
        let total = finished.reduce(0.0) { sum, job in
            sum + sessions.filter { $0.jobID == job.id }.reduce(0) { $0 + $1.hours }
        }
        return total / Double(finished.count)
    }

    var breakRate: Double {
        let finished = jobs.filter { !$0.isLive }
        guard !finished.isEmpty else { return 0 }
        return Double(finished.filter { $0.retireReason == .broke }.count) / Double(finished.count)
    }

    /// Per-string performance, ranked by how much you've actually used them.
    func stringPerformance() -> [StringPerformance] {
        var table: [UUID: StringPerformance] = [:]

        for job in jobs {
            let jobHours = sessions.filter { $0.jobID == job.id }.reduce(0) { $0 + $1.hours }
            let ids = job.isHybrid ? [job.mainsSpecID, job.crossesSpecID] : [job.mainsSpecID]
            // A hybrid uses half a set of each, so split the bill.
            let share = job.cost / Double(ids.count)

            for id in ids {
                var entry = table[id] ?? StringPerformance(
                    spec: spec(id), jobCount: 0, completedJobs: 0, hours: 0,
                    cost: 0, breaks: 0, ratingSum: 0, ratedJobs: 0
                )
                entry.jobCount += 1
                entry.hours += jobHours
                entry.cost += share
                if !job.isLive { entry.completedJobs += 1 }
                if job.retireReason == .broke { entry.breaks += 1 }
                if job.rating > 0 {
                    entry.ratingSum += job.rating
                    entry.ratedJobs += 1
                }
                table[id] = entry
            }
        }

        return table.values.sorted {
            if $0.hours != $1.hours { return $0.hours > $1.hours }
            return $0.spec.name < $1.spec.name
        }
    }

    /// Trailing weekly play, oldest first. Weeks start on the user's calendar week.
    func weeklyHours(weeks: Int = 12, calendar: Calendar = .current) -> [WeekBucket] {
        let now = Date()
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }

        return (0..<weeks).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeek),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            let inWeek = sessions.filter { $0.date >= start && $0.date < end }
            return WeekBucket(
                start: start,
                hours: inWeek.reduce(0) { $0 + $1.hours },
                sessions: inWeek.count
            )
        }
    }

    /// Days between consecutive stringings, most recent gap first.
    var restringGaps: [Double] {
        let dates = jobs.map(\.installedAt).sorted()
        guard dates.count > 1 else { return [] }
        let gaps = zip(dates.dropFirst(), dates).map { $0.timeIntervalSince($1) / 86_400 }
        return Array(gaps.reversed())
    }

    var averageRestringGap: Double? {
        let gaps = restringGaps
        guard !gaps.isEmpty else { return nil }
        return gaps.reduce(0, +) / Double(gaps.count)
    }
}
