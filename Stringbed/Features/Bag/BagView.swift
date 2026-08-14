import SwiftUI

struct BagView: View {
    @Environment(Store.self) private var store
    @State private var editingRacket: Racket?
    @State private var addingRacket = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    statusStrip

                    if !store.needsAttention.isEmpty {
                        attentionBanner
                    }

                    if store.activeRackets.isEmpty {
                        EmptyStateView(
                            symbol: "bag",
                            title: "Empty bag",
                            message: "Add the frame you actually play with. Everything else in here hangs off it.",
                            actionTitle: "Add a racket",
                            action: { addingRacket = true }
                        )
                    } else {
                        VStack(spacing: 14) {
                            SectionHeader(
                                title: "In the bag",
                                trailing: "\(store.activeRackets.count) frame\(store.activeRackets.count == 1 ? "" : "s")"
                            )
                            ForEach(Array(store.activeRackets.enumerated()), id: \.element.id) { index, racket in
                                NavigationLink(value: racket.id) {
                                    RacketCard(racket: racket, animate: appeared, delay: Double(index) * 0.12)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Edit frame", systemImage: "pencil") { editingRacket = racket }
                                    Button("Retire frame", systemImage: "archivebox") { retire(racket) }
                                }
                            }
                        }
                    }

                    retiredSection

                    Button {
                        Haptics.tick()
                        addingRacket = true
                    } label: {
                        Label("Add a frame", systemImage: "plus")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .padding(.top, 2)

                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .background(Color.clear)
            .navigationDestination(for: UUID.self) { id in
                if let racket = store.racket(id) {
                    RacketDetailView(racketID: racket.id)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $editingRacket) { racket in
            RacketEditor(racket: racket)
        }
        .sheet(isPresented: $addingRacket) {
            RacketEditor(racket: nil)
        }
        .task {
            // Let the beds string themselves in on first paint.
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeOut(duration: 1.5)) { appeared = true }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("STRINGBED")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .tracking(4.5)
                    .foregroundStyle(Palette.chalk)
                Text(subtitleLine)
                    .font(Type.body(12))
                    .foregroundStyle(Palette.mute)
            }
            Spacer()
            Image(systemName: "tennisball.fill")
                .font(.system(size: 22))
                .foregroundStyle(Palette.ball)
                .padding(10)
                .background { Circle().fill(Palette.ball.opacity(0.12)) }
        }
        .padding(.top, 6)
    }

    private var subtitleLine: String {
        let hours = store.hoursPerWeek
        if hours <= 0 { return "Log a hit and the numbers start moving" }
        return String(format: "%.1f hrs a week · %.1f sessions", hours, store.sessionsPerWeek)
    }

    private var statusStrip: some View {
        HStack(spacing: 10) {
            statTile(
                label: "Live beds",
                value: "\(store.activeRackets.filter { store.liveJob(for: $0.id) != nil }.count)",
                tint: Palette.chalk
            )
            statTile(
                label: "Hrs / week",
                value: store.hoursPerWeek.hoursLabel,
                tint: Palette.chalk
            )
            statTile(
                label: nextRestringLabel.0,
                value: nextRestringLabel.1,
                tint: nextRestringLabel.2
            )
        }
    }

    private func statTile(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).scoreboard(size: 8.5, color: Palette.faint)
            Text(value)
                .font(Type.readout(20))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                }
        }
    }

    private var nextRestringLabel: (String, String, Color) {
        let live = store.activeRackets.compactMap { store.liveJob(for: $0.id) }
        guard !live.isEmpty else { return ("Next restring", "—", Palette.mute) }

        let overdue = store.needsAttention.count
        if overdue > 0 {
            return ("Restring now", "\(overdue)", Palette.fading)
        }
        let soonest = live.compactMap { store.daysUntilFade(for: $0) }.min()
        guard let soonest else { return ("Next restring", "60d+", Palette.fresh) }
        return ("Next restring", "\(soonest)d", soonest <= 7 ? Palette.fading : Palette.chalk)
    }

    private var attentionBanner: some View {
        let items = store.needsAttention
        return VStack(spacing: 0) {
            ForEach(items, id: \.job.id) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.estimate.status == .dead ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(item.estimate.status.tint)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(item.racket.title) is \(item.estimate.status.label.lowercased())")
                            .font(Type.body(13, weight: .semibold))
                            .foregroundStyle(Palette.chalk)
                        Text(String(
                            format: "%@ down %.0f%% · %@ on court",
                            store.spec(item.job.mainsSpecID).model,
                            item.estimate.lostPercentMains,
                            item.estimate.hours.hoursLabel + "h"
                        ))
                        .font(Type.body(11))
                        .foregroundStyle(Palette.mute)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.faint)
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 14)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.fading.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Palette.fading.opacity(0.30), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private var retiredSection: some View {
        let retired = store.rackets.filter(\.isRetired)
        if !retired.isEmpty {
            VStack(spacing: 10) {
                SectionHeader(title: "Retired", trailing: "\(retired.count)")
                ForEach(retired) { racket in
                    HStack(spacing: 12) {
                        Circle().fill(racket.accent.opacity(0.5)).frame(width: 8, height: 8)
                        Text(racket.title)
                            .font(Type.body(13, weight: .semibold))
                            .foregroundStyle(Palette.mute)
                        Text(racket.subtitle)
                            .font(Type.body(11))
                            .foregroundStyle(Palette.faint)
                        Spacer()
                        Button("Unretire") { unretire(racket) }
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.ball)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface)
                    }
                }
            }
        }
    }

    private func retire(_ racket: Racket) {
        var updated = racket
        updated.isRetired = true
        store.upsert(updated)
        Haptics.impact(.rigid)
    }

    private func unretire(_ racket: Racket) {
        var updated = racket
        updated.isRetired = false
        store.upsert(updated)
        Haptics.tick()
    }
}
