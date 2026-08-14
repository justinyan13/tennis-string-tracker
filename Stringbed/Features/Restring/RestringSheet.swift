import SwiftUI

/// Record a stringing. The preview at the top strings itself as you pick — mains
/// from the centre out, then crosses top down, the same order it happens on a machine.
struct RestringSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let racket: Racket

    @State private var isHybrid = false
    @State private var mainsSpecID = UUID()
    @State private var crossesSpecID = UUID()
    @State private var mainsTension = 50.0
    @State private var crossesTension = 50.0
    @State private var linkCrosses = true
    @State private var prestretched = false
    @State private var installedAt = Date()
    @State private var stringer = ""
    @State private var cost = 0.0
    @State private var notes = ""
    @State private var retireReason: RetireReason = .wentDead

    @State private var pickingMains = false
    @State private var pickingCrosses = false
    @State private var previewProgress = 0.0

    private var mainsSpec: StringSpec { store.spec(mainsSpecID) }
    private var crossesSpec: StringSpec { store.spec(isHybrid ? crossesSpecID : mainsSpecID) }
    private var outgoing: StringJob? { store.liveJob(for: racket.id) }

    private var suggestedCost: Double {
        isHybrid ? (mainsSpec.pricePerSet + crossesSpec.pricePerSet) / 2 : mainsSpec.pricePerSet
    }

    var body: some View {
        SheetScaffold(
            title: "Restring",
            subtitle: racket.title,
            confirmTitle: "Clamps off",
            tint: racket.accent,
            onConfirm: save
        ) {
            preview
            if outgoing != nil { outgoingCard }
            stringsCard
            tensionCard
            detailsCard
        }
        .onAppear(perform: load)
        .sheet(isPresented: $pickingMains) {
            StringPickerSheet(title: isHybrid ? "Mains" : "String", selection: $mainsSpecID, tint: racket.accent)
        }
        .sheet(isPresented: $pickingCrosses) {
            StringPickerSheet(title: "Crosses", selection: $crossesSpecID, tint: racket.accent)
        }
        .onChange(of: mainsSpecID) { restringPreview() }
        .onChange(of: crossesSpecID) { restringPreview() }
        .onChange(of: isHybrid) { restringPreview() }
    }

    // MARK: - Preview

    private var preview: some View {
        StringBedView(
            mains: racket.mains,
            crosses: racket.crosses,
            mainsColor: mainsSpec.color,
            crossesColor: crossesSpec.color,
            frameColor: Color(hex: "1C2226"),
            accent: racket.accent,
            wear: 0,
            progress: previewProgress,
            includeHandle: false
        )
        .frame(height: 216)
        .onAppear { restringPreview() }
    }

    private func restringPreview() {
        previewProgress = 0
        withAnimation(.easeOut(duration: 1.5)) { previewProgress = 1 }
    }

    // MARK: - Cards

    private var outgoingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 11) {
                SectionHeader(title: "Coming out")
                if let outgoing {
                    let e = store.estimate(for: outgoing)
                    HStack(spacing: 10) {
                        Circle().fill(store.spec(outgoing.mainsSpecID).color).frame(width: 10, height: 10)
                        Text(store.spec(outgoing.mainsSpecID).name)
                            .font(Type.body(13, weight: .semibold))
                            .foregroundStyle(Palette.chalk)
                        Spacer()
                        Chip(text: e.status.label, color: e.status.tint)
                        Text("\(e.hours.hoursLabel)h")
                            .font(Type.readout(13))
                            .foregroundStyle(Palette.mute)
                    }
                    Text("Why?").scoreboard(size: 10, color: Palette.mute)
                    SegmentPicker(
                        options: RetireReason.allCases, selection: $retireReason,
                        label: { $0.shortLabel }, tint: racket.accent
                    )
                }
            }
        }
    }

    private var stringsCard: some View {
        Card(tint: racket.accent) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    SectionHeader(title: isHybrid ? "Hybrid" : "Full bed")
                    Spacer()
                    Toggle("", isOn: $isHybrid)
                        .labelsHidden()
                        .tint(racket.accent)
                }

                Button {
                    Haptics.tick()
                    pickingMains = true
                } label: {
                    stringButton(spec: mainsSpec, role: isHybrid ? "Mains" : "String")
                }
                .buttonStyle(.plain)

                if isHybrid {
                    Button {
                        Haptics.tick()
                        pickingCrosses = true
                    } label: {
                        stringButton(spec: store.spec(crossesSpecID), role: "Crosses")
                    }
                    .buttonStyle(.plain)
                }

                Text(isHybrid
                     ? "Mains do most of the moving, so they set the feel — and in a hybrid they'll saw through the crosses first."
                     : "One string, both directions. Simplest thing to compare against later.")
                    .font(Type.body(11))
                    .foregroundStyle(Palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func stringButton(spec: StringSpec, role: String) -> some View {
        HStack {
            TapeLabel(spec: spec, role: role)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.faint)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.surfaceRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                }
        }
    }

    private var tensionCard: some View {
        Card {
            VStack(spacing: 14) {
                SectionHeader(title: "Tension", trailing: "Turn the dial")

                TensionDial(
                    pounds: $mainsTension,
                    unit: store.tensionUnit,
                    caption: isHybrid ? "Mains" : "Reference",
                    tint: racket.accent
                )
                .frame(height: 220)
                .onChange(of: mainsTension) {
                    if linkCrosses { crossesTension = mainsTension }
                }

                Divider().overlay(Palette.hairline)

                Toggle(isOn: $linkCrosses) {
                    Text("Crosses same as mains")
                        .font(Type.body(13))
                        .foregroundStyle(Palette.chalk)
                }
                .tint(racket.accent)
                .onChange(of: linkCrosses) {
                    if linkCrosses { crossesTension = mainsTension }
                }

                if !linkCrosses {
                    TensionStepper(
                        pounds: $crossesTension, unit: store.tensionUnit,
                        label: "Crosses", tint: racket.accent
                    )
                }

                Toggle(isOn: $prestretched) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Prestretched")
                            .font(Type.body(13))
                            .foregroundStyle(Palette.chalk)
                        Text("Front-loads the settling drop onto the machine, not your first session")
                            .font(Type.body(10.5))
                            .foregroundStyle(Palette.faint)
                    }
                }
                .tint(racket.accent)
            }
        }
    }

    private var detailsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Paperwork")

                FieldRow(label: "Date") {
                    DatePicker("", selection: $installedAt, displayedComponents: .date)
                        .labelsHidden()
                        .tint(racket.accent)
                }
                FieldRow(label: "Stringer") {
                    InputField(placeholder: "Self", text: $stringer)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Cost").scoreboard(size: 10, color: Palette.mute)
                        Spacer()
                        Text("$\(cost.moneyLabel)")
                            .font(Type.readout(16))
                            .foregroundStyle(Palette.chalk)
                        Button {
                            withAnimation(.snappy) { cost = suggestedCost }
                            Haptics.tick()
                        } label: {
                            Chip(text: "$\(suggestedCost.moneyLabel) string", color: racket.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    Slider(value: $cost, in: 0...150, step: 1)
                        .tint(racket.accent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes").scoreboard(size: 10, color: Palette.mute)
                    TextField("How did you want this one to play?", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .font(Type.body(13.5))
                        .foregroundStyle(Palette.chalk)
                }
            }
        }
    }

    // MARK: - Data

    private func load() {
        let previous = store.liveJob(for: racket.id) ?? store.jobs(for: racket.id).first
        if let previous {
            mainsSpecID = previous.mainsSpecID
            crossesSpecID = previous.crossesSpecID
            isHybrid = previous.isHybrid
            mainsTension = previous.mainsTension
            crossesTension = previous.crossesTension
            linkCrosses = abs(previous.mainsTension - previous.crossesTension) < 0.25
            prestretched = previous.prestretched
            cost = previous.cost
        } else {
            let favorite = store.specs.first(where: \.isFavorite) ?? store.specs.first
            mainsSpecID = favorite?.id ?? UUID()
            crossesSpecID = mainsSpecID
            cost = favorite?.pricePerSet ?? 0
        }
        stringer = store.defaultStringer
    }

    private func save() {
        let job = StringJob(
            racketID: racket.id,
            mainsSpecID: mainsSpecID,
            crossesSpecID: isHybrid ? crossesSpecID : mainsSpecID,
            mainsTension: mainsTension,
            crossesTension: linkCrosses ? mainsTension : crossesTension,
            installedAt: installedAt,
            stringer: stringer.trimmingCharacters(in: .whitespaces),
            cost: cost,
            prestretched: prestretched,
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        store.install(job, retiring: retireReason)
        if !stringer.trimmingCharacters(in: .whitespaces).isEmpty {
            store.defaultStringer = stringer.trimmingCharacters(in: .whitespaces)
            store.persist()
        }
        Haptics.success()
        dismiss()
    }
}

/// Cut the strings out without putting new ones in — and rate the set on the way out,
/// which is what feeds the Lab.
struct RetireStringsSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let job: StringJob
    @State private var reason: RetireReason = .broke
    @State private var rating = 0
    @State private var date = Date()
    @State private var notes = ""

    var body: some View {
        SheetScaffold(
            title: "Cut them out",
            subtitle: store.spec(job.mainsSpecID).name,
            confirmTitle: "Retire this bed",
            tint: Palette.clay,
            onConfirm: save
        ) {
            Card {
                VStack(alignment: .leading, spacing: 13) {
                    SectionHeader(title: "What happened")
                    VStack(spacing: 7) {
                        ForEach(RetireReason.allCases) { option in
                            Button {
                                withAnimation(.snappy(duration: 0.2)) { reason = option }
                                Haptics.tick()
                            } label: {
                                HStack(spacing: 11) {
                                    Image(systemName: option.symbol)
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(width: 22)
                                    Text(option.label)
                                        .font(Type.body(13.5, weight: .medium))
                                    Spacer()
                                    if reason == option {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                }
                                .foregroundStyle(reason == option ? Palette.clay : Palette.mute)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 11)
                                .background {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(reason == option ? Palette.clay.opacity(0.12) : Palette.surfaceRaised)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 13) {
                    SectionHeader(title: "How did it play?", trailing: "Feeds the Lab")
                    RatingPicker(rating: $rating, tint: Palette.clay)
                    FieldRow(label: "Date") {
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                            .tint(Palette.clay)
                    }
                    TextField("Anything worth remembering?", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .font(Type.body(13.5))
                        .foregroundStyle(Palette.chalk)
                }
            }
        }
        .onAppear { rating = job.rating }
    }

    private func save() {
        var updated = job
        updated.retiredAt = date
        updated.retireReason = reason
        updated.rating = rating
        if !notes.trimmingCharacters(in: .whitespaces).isEmpty {
            updated.notes = updated.notes.isEmpty
                ? notes
                : updated.notes + " — " + notes
        }
        store.upsert(updated)
        Haptics.warning()
        dismiss()
    }
}
