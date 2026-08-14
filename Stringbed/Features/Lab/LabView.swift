import SwiftUI

/// What your own history says, once there's enough of it: which strings last, which
/// ones you actually liked, and what each hour on court is costing you.
struct LabView: View {
    @Environment(Store.self) private var store
    @State private var showingLibrary = false
    @State private var sort: LabSort = .hours

    enum LabSort: String, CaseIterable, Identifiable {
        case hours, durability, value, rating
        var id: String { rawValue }
        var label: String {
            switch self {
            case .hours: return "Used"
            case .durability: return "Lasts"
            case .value: return "Value"
            case .rating: return "Liked"
            }
        }
    }

    private var performances: [StringPerformance] {
        let all = store.stringPerformance()
        switch sort {
        case .hours: return all
        case .durability: return all.sorted { $0.hoursPerSet > $1.hoursPerSet }
        case .value: return all.sorted {
            let a = $0.costPerHour == 0 ? .infinity : $0.costPerHour
            let b = $1.costPerHour == 0 ? .infinity : $1.costPerHour
            return a < b
        }
        case .rating: return all.sorted { $0.avgRating > $1.avgRating }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header

                if store.jobs.isEmpty {
                    EmptyStateView(
                        symbol: "chart.xyaxis.line",
                        title: "No data yet",
                        message: "Record a couple of stringings and start logging hours. The Lab needs history before it can tell you anything true."
                    )
                } else {
                    ledgerCard
                    verdictCard
                    leaderboardCard
                    habitsCard
                }

                Button {
                    Haptics.tick()
                    showingLibrary = true
                } label: {
                    Label("String library", systemImage: "books.vertical")
                }
                .buttonStyle(GhostButtonStyle())

                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showingLibrary) {
            StringLibraryView()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LAB")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .tracking(4.5)
                    .foregroundStyle(Palette.chalk)
                Text("What your own history says")
                    .font(Type.body(12))
                    .foregroundStyle(Palette.mute)
            }
            Spacer()
        }
        .padding(.top, 6)
    }

    // MARK: - Ledger

    private var ledgerCard: some View {
        Card(tint: Palette.ball) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "The ledger", trailing: "All time")
                HStack(spacing: 0) {
                    StatBlock(label: "Restrings", value: "\(store.restringCount)", size: 24)
                    StatBlock(label: "On court", value: store.totalHours.hoursLabel, unit: "hrs", size: 24)
                }
                HStack(spacing: 0) {
                    StatBlock(label: "Spent", value: "$\(Int(store.totalSpent))", tint: Palette.clay, size: 24)
                    StatBlock(
                        label: "Per hour",
                        value: store.costPerHour > 0 ? String(format: "$%.2f", store.costPerHour) : "—",
                        tint: Palette.ball, size: 24
                    )
                }
            }
        }
    }

    // MARK: - Verdict

    @ViewBuilder
    private var verdictCard: some View {
        let all = store.stringPerformance().filter { $0.hours > 0 }
        if !all.isEmpty {
            let longest = all.filter(\.hasDurabilityData).max { $0.hoursPerSet < $1.hoursPerSet }
            let cheapest = all.filter { $0.costPerHour > 0 }.min { $0.costPerHour < $1.costPerHour }
            let favourite = all.filter { $0.ratedJobs > 0 }.max { $0.avgRating < $1.avgRating }

            Card {
                VStack(alignment: .leading, spacing: 13) {
                    SectionHeader(title: "The verdict")
                    if let longest {
                        verdictRow(
                            symbol: "hourglass",
                            title: "Lasts longest",
                            detail: longest.spec.name,
                            value: "\(longest.hoursPerSet.hoursLabel)h / set",
                            color: Palette.fresh
                        )
                    }
                    if let cheapest {
                        verdictRow(
                            symbol: "dollarsign.circle",
                            title: "Best value",
                            detail: cheapest.spec.name,
                            value: String(format: "$%.2f/hr", cheapest.costPerHour),
                            color: Palette.ball
                        )
                    }
                    if let favourite, favourite.avgRating > 0 {
                        verdictRow(
                            symbol: "heart",
                            title: "You rate it highest",
                            detail: favourite.spec.name,
                            value: String(format: "%.1f / 5", favourite.avgRating),
                            color: Palette.clay
                        )
                    }
                    if longest == nil && cheapest == nil && favourite == nil {
                        Text("Cut a set out and rate it, and this fills in.")
                            .font(Type.body(11.5))
                            .foregroundStyle(Palette.faint)
                    }
                }
            }
        }
    }

    private func verdictRow(symbol: String, title: String, detail: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background { Circle().fill(color.opacity(0.12)) }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).scoreboard(size: 8.5, color: Palette.faint)
                Text(detail)
                    .font(Type.body(13, weight: .semibold))
                    .foregroundStyle(Palette.chalk)
                    .lineLimit(1)
            }
            Spacer()
            Text(value)
                .font(Type.readout(15))
                .foregroundStyle(color)
        }
    }

    // MARK: - Leaderboard

    private var leaderboardCard: some View {
        let rows = performances
        let peak = max(0.01, rows.map(\.hours).max() ?? 1)

        return Card {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    SectionHeader(title: "Strings you've played")
                    Spacer()
                }
                SegmentPicker(options: LabSort.allCases, selection: $sort, label: { $0.label })

                VStack(spacing: 12) {
                    ForEach(rows) { row in
                        performanceRow(row, peak: peak)
                    }
                }

                Text("Durability is measured from sets you've cut out. A live bed only counts the hours it's already taken.")
                    .font(Type.body(10.5))
                    .foregroundStyle(Palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func performanceRow(_ row: StringPerformance, peak: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(row.spec.color)
                    .frame(width: 4, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.spec.name)
                        .font(Type.body(13, weight: .semibold))
                        .foregroundStyle(Palette.chalk)
                        .lineLimit(1)
                    Text("\(row.spec.material.short) · \(row.jobCount) set\(row.jobCount == 1 ? "" : "s")")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.faint)
                }
                Spacer()
                Text(headlineValue(row))
                    .font(Type.readout(15))
                    .foregroundStyle(Palette.chalk)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surfaceRaised)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [row.spec.color.opacity(0.9), row.spec.color.opacity(0.45)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * CGFloat((row.hours / peak).clamped(to: 0...1)))
                }
            }
            .frame(height: 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if row.hasDurabilityData {
                        Chip(text: "\(row.hoursPerSet.hoursLabel)h/set", color: Palette.mute)
                    }
                    if row.costPerHour > 0 {
                        Chip(text: String(format: "$%.2f/hr", row.costPerHour), color: Palette.mute)
                    }
                    if row.breaks > 0 {
                        Chip(text: "\(row.breaks) snapped", color: Palette.dead, systemImage: "bolt.horizontal")
                    }
                    if row.avgRating > 0 {
                        Chip(text: String(format: "%.1f★", row.avgRating), color: Palette.ball)
                    }
                    Chip(text: "\(row.jobCount) set\(row.jobCount == 1 ? "" : "s")", color: Palette.mute)
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func headlineValue(_ row: StringPerformance) -> String {
        switch sort {
        case .hours: return "\(row.hours.hoursLabel)h"
        case .durability: return row.hasDurabilityData ? "\(row.hoursPerSet.hoursLabel)h" : "—"
        case .value: return row.costPerHour > 0 ? String(format: "$%.2f", row.costPerHour) : "—"
        case .rating: return row.avgRating > 0 ? String(format: "%.1f", row.avgRating) : "—"
        }
    }

    // MARK: - Habits

    private var habitsCard: some View {
        let recommended = TensionEngine.ruleOfThumbIntervalDays(sessionsPerWeek: store.sessionsPerWeek)
        let actual = store.averageRestringGap

        return Card {
            VStack(alignment: .leading, spacing: 13) {
                SectionHeader(title: "Your habits")

                HStack(spacing: 0) {
                    StatBlock(
                        label: "Restring every",
                        value: actual.map { "\(Int($0.rounded()))" } ?? "—",
                        unit: "days", size: 20
                    )
                    StatBlock(
                        label: "Rule of thumb",
                        value: "\(recommended)", unit: "days", tint: Palette.ball, size: 20
                    )
                    StatBlock(
                        label: "Set lasts",
                        value: store.averageJobLifeHours.map { $0.hoursLabel } ?? "—",
                        unit: "hrs", size: 20
                    )
                }

                if let actual {
                    Text(habitVerdict(actual: actual, recommended: Double(recommended)))
                        .font(Type.body(12))
                        .foregroundStyle(Palette.mute)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if store.breakRate > 0 {
                    HStack(spacing: 6) {
                        Chip(
                            text: "\(Int((store.breakRate * 100).rounded()))% snapped",
                            color: Palette.dead, systemImage: "bolt.horizontal"
                        )
                        Text("the rest you cut out yourself")
                            .font(Type.body(10.5))
                            .foregroundStyle(Palette.faint)
                    }
                }
            }
        }
    }

    private func habitVerdict(actual: Double, recommended: Double) -> String {
        let ratio = actual / recommended
        if ratio > 1.4 {
            return "You're riding your strings about \(Int(actual - recommended)) days past the old rule — restring as many times a year as you play per week. That's where the dead beds are coming from."
        }
        if ratio < 0.7 {
            return "You restring more often than the rule of thumb suggests. Nothing wrong with that, but there's money in stretching it a little."
        }
        return "You're right about where the old rule says you should be: restring as many times a year as you play per week."
    }
}
