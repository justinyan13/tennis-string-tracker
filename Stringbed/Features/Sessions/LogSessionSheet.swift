import SwiftUI

/// Log court time against whatever is currently in the frame.
struct LogSessionSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var preselectedRacketID: UUID? = nil
    var editing: PlaySession? = nil

    @State private var racketID: UUID?
    @State private var hours = 1.5
    @State private var kind: SessionKind = .practice
    @State private var surface: Surface = .hard
    @State private var feel = 0
    @State private var date = Date()
    @State private var notes = ""

    private var racket: Racket? { racketID.flatMap { store.racket($0) } }
    private var job: StringJob? { racketID.flatMap { store.liveJob(for: $0) } }
    private var accent: Color { racket?.accent ?? Palette.ball }

    private let quickHours: [Double] = [0.5, 1, 1.5, 2, 2.5, 3]

    var body: some View {
        SheetScaffold(
            title: editing == nil ? "Log a hit" : "Edit session",
            subtitle: subtitle,
            confirmTitle: job == nil ? "String it first" : "Add to the tally",
            confirmEnabled: job != nil,
            tint: accent,
            onConfirm: save
        ) {
            racketPicker
            hoursCard
            contextCard
            feelCard
        }
        .onAppear(perform: load)
    }

    private var subtitle: String {
        guard let racket else { return "Which frame?" }
        guard let job else { return "\(racket.title) has no strings in it" }
        return "\(store.spec(job.mainsSpecID).name) · \(job.tensionLabel) \(store.tensionUnit.short)"
    }

    // MARK: - Racket picker

    private var racketPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "Frame")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.activeRackets) { r in
                        Button {
                            withAnimation(.snappy(duration: 0.22)) { racketID = r.id }
                            Haptics.tick()
                        } label: {
                            racketChip(r)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private func racketChip(_ r: Racket) -> some View {
        let selected = racketID == r.id
        let live = store.liveJob(for: r.id)
        return VStack(spacing: 7) {
            StringBedView.forJob(
                live,
                racket: r,
                mainsSpec: live.map { store.spec($0.mainsSpecID) },
                crossesSpec: live.map { store.spec($0.crossesSpecID) },
                freshness: live.map { store.estimate(for: $0).freshness } ?? 0,
                progress: 1,
                includeHandle: false,
                glow: false
            )
            .frame(width: 54, height: 68)

            Text(r.title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Palette.chalk : Palette.mute)
                .lineLimit(1)

            if live == nil {
                Text("unstrung").scoreboard(size: 7, color: Palette.dead)
            } else {
                Text(store.spec(live!.mainsSpecID).model)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.faint)
                    .lineLimit(1)
            }
        }
        .frame(width: 96)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(selected ? r.accent.opacity(0.12) : Palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(selected ? r.accent.opacity(0.55) : Palette.hairline, lineWidth: 1)
                }
        }
    }

    // MARK: - Hours

    private var hoursCard: some View {
        Card(tint: accent) {
            VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(title: "Court time")
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(hours.hoursLabel)
                            .font(Type.readout(34))
                            .foregroundStyle(accent)
                            .contentTransition(.numericText())
                        Text("hrs").scoreboard(size: 10, color: Palette.mute)
                    }
                }

                HStack(spacing: 6) {
                    ForEach(quickHours, id: \.self) { h in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) { hours = h }
                            Haptics.tick()
                        } label: {
                            Text(h.hoursLabel)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(hours == h ? Palette.courtDeep : Palette.mute)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(hours == h ? accent : Palette.surfaceRaised)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Slider(value: $hours, in: 0.25...6, step: 0.25)
                    .tint(accent)

                if let job, let racket {
                    impactLine(job: job, racket: racket)
                }
            }
        }
    }

    /// Shows what this session will do to the bed before you commit it.
    private func impactLine(job: StringJob, racket: Racket) -> some View {
        let before = store.estimate(for: job)
        let hypothetical = PlaySession(
            jobID: job.id, racketID: racket.id, date: date,
            hours: hours, kind: kind, surface: surface
        )
        let after = TensionEngine.estimate(
            job: job,
            mainsSpec: store.spec(job.mainsSpecID),
            crossesSpec: store.spec(job.crossesSpecID),
            racket: racket,
            sessions: store.sessions + [hypothetical]
        )
        let unit = store.tensionUnit

        return HStack(spacing: 10) {
            Image(systemName: "arrow.down.right")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Palette.clay)
            Text("After this session")
                .font(Type.body(11))
                .foregroundStyle(Palette.mute)
            Spacer()
            Text(unit.display(before.currentMains).liveTension)
                .font(Type.readout(13))
                .foregroundStyle(Palette.faint)
            Image(systemName: "arrow.right")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(Palette.faint)
            Text("\(unit.display(after.currentMains).liveTension) \(unit.short)")
                .font(Type.readout(14))
                .foregroundStyle(after.status.tint)
        }
        .padding(.top, 2)
    }

    // MARK: - Context

    private var contextCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 13) {
                SectionHeader(title: "Kind", trailing: kindHint)
                SegmentPicker(options: SessionKind.allCases, selection: $kind,
                              label: { $0 == .serves ? "Serves" : $0.label }, tint: accent)

                SectionHeader(title: "Surface")
                SegmentPicker(options: Surface.allCases, selection: $surface,
                              label: { $0.label }, tint: accent)

                FieldRow(label: "Date") {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .tint(accent)
                }
            }
        }
    }

    private var kindHint: String {
        let wear = kind.wearMultiplier * surface.wearMultiplier
        if wear > 1.05 { return "\(Int((wear - 1) * 100))% harder on strings" }
        if wear < 0.95 { return "\(Int((1 - wear) * 100))% easier on strings" }
        return "Baseline wear"
    }

    private var feelCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "How did it feel?", trailing: "Optional")
                RatingPicker(rating: $feel, tint: accent)
                TextField("Depth control was gone by the third set…", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .font(Type.body(13.5))
                    .foregroundStyle(Palette.chalk)
            }
        }
    }

    // MARK: - Data

    private func load() {
        if let editing {
            racketID = editing.racketID
            hours = editing.hours
            kind = editing.kind
            surface = editing.surface
            feel = editing.feel
            date = editing.date
            notes = editing.notes
            return
        }
        racketID = preselectedRacketID
            ?? store.sharpestRacket?.id
            ?? store.activeRackets.first?.id
        if let last = store.recentSessions.first {
            surface = last.surface
        }
    }

    private func save() {
        guard let racketID, let job else { return }
        var session = editing ?? PlaySession(jobID: job.id, racketID: racketID, date: date, hours: hours)
        session.jobID = job.id
        session.racketID = racketID
        session.date = date
        session.hours = hours
        session.kind = kind
        session.surface = surface
        session.feel = feel
        session.notes = notes.trimmingCharacters(in: .whitespaces)

        store.upsert(session)
        Haptics.success()
        dismiss()
    }
}
