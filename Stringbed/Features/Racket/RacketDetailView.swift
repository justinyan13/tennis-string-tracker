import SwiftUI

struct RacketDetailView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let racketID: UUID

    @State private var strung = false
    @State private var restringing = false
    @State private var loggingSession = false
    @State private var editing = false
    @State private var retiring = false
    @State private var showProjection = true

    private var racket: Racket? { store.racket(racketID) }
    private var job: StringJob? { store.liveJob(for: racketID) }
    private var estimate: TensionEstimate? { job.map { store.estimate(for: $0) } }

    var body: some View {
        ZStack {
            CourtBackdrop(tint: racket?.accent ?? Palette.ball)

            if let racket {
                ScrollView {
                    VStack(spacing: 18) {
                        navBar(racket)
                        hero(racket)

                        if let job, let estimate {
                            verdict(job: job, estimate: estimate)
                            setupCard(racket: racket, job: job, estimate: estimate)
                            chartCard(racket: racket, job: job)
                            actionRow
                            sessionsCard(job: job)
                        } else {
                            unstrungCard(racket)
                        }

                        specsCard(racket)
                        historyCard(racket)

                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, 18)
                }
                .scrollIndicators(.hidden)

                TopScrim()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $restringing) {
            if let racket { RestringSheet(racket: racket) }
        }
        .sheet(isPresented: $loggingSession) {
            LogSessionSheet(preselectedRacketID: racketID)
        }
        .sheet(isPresented: $editing) {
            if let racket { RacketEditor(racket: racket) }
        }
        .sheet(isPresented: $retiring) {
            if let job { RetireStringsSheet(job: job) }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.easeOut(duration: 1.8)) { strung = true }
        }
    }

    // MARK: - Header

    private func navBar(_ racket: Racket) -> some View {
        HStack {
            Button {
                Haptics.tick()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.chalk)
                    .frame(width: 38, height: 38)
                    .background { Circle().fill(Palette.surfaceRaised) }
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 1) {
                Text(racket.title)
                    .font(Type.display(16))
                    .foregroundStyle(Palette.chalk)
                Text(racket.subtitle).scoreboard(size: 8.5, color: Palette.mute)
            }

            Spacer()

            Menu {
                Button("Edit frame", systemImage: "pencil") { editing = true }
                Button("Restring", systemImage: "scissors") { restringing = true }
                if job != nil {
                    Button("Cut out strings", systemImage: "xmark.bin", role: .destructive) { retiring = true }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.chalk)
                    .frame(width: 38, height: 38)
                    .background { Circle().fill(Palette.surfaceRaised) }
            }
        }
        .padding(.top, 4)
    }

    private func hero(_ racket: Racket) -> some View {
        StringBedView.forJob(
            job,
            racket: racket,
            mainsSpec: job.map { store.spec($0.mainsSpecID) },
            crossesSpec: job.map { store.spec($0.crossesSpecID) },
            freshness: estimate?.freshness ?? 0,
            progress: strung ? 1 : 0,
            includeHandle: false
        )
        .frame(height: 300)
        .animation(.easeOut(duration: 1.8), value: strung)
        .padding(.vertical, 4)
    }

    // MARK: - Verdict

    private func verdict(job: StringJob, estimate: TensionEstimate) -> some View {
        Card(padding: 16, tint: estimate.status.tint) {
            HStack(alignment: .center, spacing: 16) {
                FreshnessGauge(freshness: estimate.freshness, lineWidth: 7) {
                    VStack(spacing: -2) {
                        Text("\(Int((estimate.freshness * 100).rounded()))")
                            .font(Type.readout(26))
                            .foregroundStyle(estimate.status.tint)
                        Text("fresh").scoreboard(size: 7, color: Palette.faint)
                    }
                }
                .frame(width: 92, height: 92)
                .animation(.easeOut(duration: 1.0).delay(0.4), value: strung)

                VStack(alignment: .leading, spacing: 6) {
                    Text(estimate.status.label)
                        .font(Type.display(24))
                        .foregroundStyle(estimate.status.tint)
                    Text(estimate.status.blurb)
                        .font(Type.body(12))
                        .foregroundStyle(Palette.mute)
                        .fixedSize(horizontal: false, vertical: true)

                    if let days = store.daysUntilFade(for: job) {
                        Label("Prime for about \(days) more day\(days == 1 ? "" : "s")", systemImage: "clock")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.ball)
                    } else if estimate.freshness <= 0.50 {
                        Label("Restring it", systemImage: "scissors")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.fading)
                    }
                }
            }
        }
    }

    // MARK: - Setup

    private func setupCard(racket: Racket, job: StringJob, estimate: TensionEstimate) -> some View {
        let mains = store.spec(job.mainsSpecID)
        let crosses = store.spec(job.crossesSpecID)
        let unit = store.tensionUnit

        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionHeader(title: job.isHybrid ? "Hybrid setup" : "Full bed")
                    Spacer()
                    if job.prestretched { Chip(text: "Prestretched", color: Palette.fresh) }
                }

                // The headline: what you asked for versus what you've got left.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Strung at").scoreboard(size: 9, color: Palette.faint)
                        Text(StringJob.format(unit.display(job.mainsTension)))
                            .font(Type.readout(30))
                            .foregroundStyle(Palette.mute)
                    }
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Palette.faint)
                        .padding(.horizontal, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Playing at now").scoreboard(size: 9, color: Palette.faint)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(unit.display(estimate.currentMains).liveTension)
                                .font(Type.readout(38))
                                .foregroundStyle(estimate.status.tint)
                            Text(unit.short).scoreboard(size: 10, color: Palette.mute)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Lost").scoreboard(size: 9, color: Palette.faint)
                        Text("\(Int(estimate.lostPercentMains.rounded()))%")
                            .font(Type.readout(20))
                            .foregroundStyle(Palette.clay)
                    }
                }

                Divider().overlay(Palette.hairline)

                VStack(spacing: 12) {
                    TapeLabel(
                        spec: mains, role: "Mains",
                        tension: StringJob.format(unit.display(job.mainsTension)),
                        unit: unit.short
                    )
                    TapeLabel(
                        spec: crosses, role: "Crosses",
                        tension: StringJob.format(unit.display(job.crossesTension)),
                        unit: unit.short
                    )
                }

                Divider().overlay(Palette.hairline)

                HStack(spacing: 0) {
                    StatBlock(label: "On court", value: estimate.hours.hoursLabel, unit: "hrs", size: 19)
                    StatBlock(label: "Sessions", value: "\(estimate.sessionCount)", size: 19)
                    StatBlock(label: "In frame", value: "\(Int(estimate.days))", unit: "days", size: 19)
                    StatBlock(
                        label: "Cost / hr",
                        value: estimate.hours > 0 ? String(format: "%.2f", job.cost / estimate.hours) : "—",
                        tint: Palette.chalk, size: 19
                    )
                }

                if !job.stringer.isEmpty || !job.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        if !job.stringer.isEmpty {
                            Label(job.stringer, systemImage: "wrench.adjustable")
                                .font(Type.body(11))
                                .foregroundStyle(Palette.mute)
                        }
                        if !job.notes.isEmpty {
                            Text("“\(job.notes)”")
                                .font(Type.body(12))
                                .italic()
                                .foregroundStyle(Palette.mute)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Chart

    private func chartCard(racket: Racket, job: StringJob) -> some View {
        let points = TensionEngine.curve(
            job: job,
            mainsSpec: store.spec(job.mainsSpecID),
            crossesSpec: store.spec(job.crossesSpecID),
            racket: racket,
            sessions: store.sessions,
            projectDays: showProjection ? 21 : 0,
            hoursPerWeek: store.hoursPerWeek
        )

        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader(title: "Tension decay")
                    Spacer()
                    Button {
                        withAnimation(.snappy) { showProjection.toggle() }
                        Haptics.tick()
                    } label: {
                        Chip(
                            text: showProjection ? "3wk forecast" : "So far",
                            color: Palette.ball,
                            filled: showProjection,
                            systemImage: "chart.line.uptrend.xyaxis"
                        )
                    }
                    .buttonStyle(.plain)
                }

                DecayChart(
                    points: points,
                    reference: job.mainsTension,
                    mainsColor: store.spec(job.mainsSpecID).color,
                    crossesColor: store.spec(job.crossesSpecID).color,
                    sessions: store.sessions(forJob: job.id),
                    unit: store.tensionUnit,
                    showCrosses: true
                )
                .frame(height: 170)

                HStack(spacing: 14) {
                    legendDot(color: store.spec(job.mainsSpecID).color, label: "Mains")
                    legendDot(color: store.spec(job.crossesSpecID).color, label: "Crosses")
                    Spacer()
                    Text("Dots are sessions").scoreboard(size: 8, color: Palette.faint)
                }
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).scoreboard(size: 9, color: Palette.mute)
        }
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.impact(.medium)
                loggingSession = true
            } label: {
                Label("Log a hit", systemImage: "figure.tennis")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                Haptics.impact(.medium)
                restringing = true
            } label: {
                Label("Restring", systemImage: "scissors")
            }
            .buttonStyle(GhostButtonStyle(tint: Palette.chalk))
        }
    }

    // MARK: - Sessions

    private func sessionsCard(job: StringJob) -> some View {
        let sessions = store.sessions(forJob: job.id)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "On this bed",
                    trailing: sessions.isEmpty ? nil : "\(sessions.count) sessions"
                )
                if sessions.isEmpty {
                    Text("Nothing logged yet. Go hit with it.")
                        .font(Type.body(12))
                        .foregroundStyle(Palette.faint)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 10) {
                        ForEach(sessions.prefix(6)) { session in
                            SessionRow(session: session, accent: racket?.accent ?? Palette.ball)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Unstrung

    private func unstrungCard(_ racket: Racket) -> some View {
        Card(tint: racket.accent) {
            VStack(spacing: 14) {
                Text("UNSTRUNG")
                    .font(Type.display(26))
                    .tracking(3)
                    .foregroundStyle(Palette.chalk)
                Text("There's nothing in this hoop. Record a stringing and Stringbed starts tracking the tension from the moment the clamps come off.")
                    .font(Type.body(13))
                    .foregroundStyle(Palette.mute)
                    .multilineTextAlignment(.center)
                Button {
                    Haptics.impact(.medium)
                    restringing = true
                } label: {
                    Label("String it up", systemImage: "scissors")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Specs

    private func specsCard(_ racket: Racket) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "The frame")
                HStack(spacing: 0) {
                    StatBlock(label: "Head", value: "\(racket.headSize)", unit: "in²", size: 18)
                    StatBlock(label: "Weight", value: "\(racket.weightGrams)", unit: "g", size: 18)
                    StatBlock(label: "Pattern", value: racket.patternLabel, size: 18)
                }
                HStack(spacing: 0) {
                    StatBlock(label: "Balance", value: racket.balanceLabel, size: 15)
                    StatBlock(label: "Grip", value: racket.gripSize, size: 15)
                    StatBlock(label: "Owned", value: racket.acquired.daysAgoLabel, size: 15)
                }
                if !racket.notes.isEmpty {
                    Text(racket.notes)
                        .font(Type.body(12))
                        .foregroundStyle(Palette.mute)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - History

    @ViewBuilder
    private func historyCard(_ racket: Racket) -> some View {
        let past = store.jobs(for: racket.id).filter { !$0.isLive }
        if !past.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "String history", trailing: "\(past.count) jobs")
                    ForEach(past) { old in
                        PastJobRow(job: old, racket: racket)
                        if old.id != past.last?.id {
                            Divider().overlay(Palette.hairline)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Rows

struct SessionRow: View {
    @Environment(Store.self) private var store
    var session: PlaySession
    var accent: Color = Palette.ball

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.kind.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 30, height: 30)
                .background { Circle().fill(accent.opacity(0.12)) }

            VStack(alignment: .leading, spacing: 1) {
                Text(session.kind.label)
                    .font(Type.body(13, weight: .semibold))
                    .foregroundStyle(Palette.chalk)
                Text("\(session.date.shortDate) · \(session.surface.label)")
                    .font(Type.body(10.5))
                    .foregroundStyle(Palette.faint)
            }

            Spacer()

            if session.feel > 0 {
                StarRow(rating: session.feel, size: 7)
            }

            Text("\(session.hours.hoursLabel)h")
                .font(Type.readout(14))
                .foregroundStyle(Palette.mute)
        }
    }
}

struct PastJobRow: View {
    @Environment(Store.self) private var store
    var job: StringJob
    var racket: Racket

    private var hours: Double {
        store.sessions(forJob: job.id).reduce(0) { $0 + $1.hours }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: -4) {
                    Circle().fill(store.spec(job.mainsSpecID).color)
                        .frame(width: 12, height: 12)
                    if job.isHybrid {
                        Circle().fill(store.spec(job.crossesSpecID).color)
                            .frame(width: 12, height: 12)
                            .overlay { Circle().strokeBorder(Palette.court, lineWidth: 1) }
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(job.isHybrid
                         ? "\(store.spec(job.mainsSpecID).model) / \(store.spec(job.crossesSpecID).model)"
                         : store.spec(job.mainsSpecID).name)
                        .font(Type.body(12.5, weight: .semibold))
                        .foregroundStyle(Palette.chalk)
                        .lineLimit(1)
                    Text("\(job.installedAt.mediumDate) · \(job.tensionLabel) \(store.tensionUnit.short)")
                        .font(Type.body(10))
                        .foregroundStyle(Palette.faint)
                }

                Spacer()

                if job.rating > 0 { StarRow(rating: job.rating, size: 7) }
            }

            HStack(spacing: 6) {
                if let reason = job.retireReason {
                    Chip(text: reason.label, color: reason == .broke ? Palette.dead : Palette.mute,
                         systemImage: reason.symbol)
                }
                Chip(text: "\(hours.hoursLabel)h", color: Palette.mute)
                if hours > 0 {
                    Chip(text: "$\(String(format: "%.2f", job.cost / hours))/hr", color: Palette.mute)
                }
                if let retired = job.retiredAt {
                    let days = Int(retired.timeIntervalSince(job.installedAt) / 86_400)
                    Chip(text: "\(days)d", color: Palette.mute)
                }
            }
        }
    }
}
