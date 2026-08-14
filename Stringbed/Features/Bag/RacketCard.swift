import SwiftUI

struct RacketCard: View {
    @Environment(Store.self) private var store
    var racket: Racket
    var animate: Bool
    var delay: Double = 0

    private var job: StringJob? { store.liveJob(for: racket.id) }
    private var estimate: TensionEstimate? { job.map { store.estimate(for: $0) } }

    var body: some View {
        Card(padding: 14, tint: racket.accent) {
            HStack(alignment: .top, spacing: 12) {
                frameArt
                details
            }
        }
    }

    private var frameArt: some View {
        StringBedView.forJob(
            job,
            racket: racket,
            mainsSpec: job.map { store.spec($0.mainsSpecID) },
            crossesSpec: job.map { store.spec($0.crossesSpecID) },
            freshness: estimate?.freshness ?? 0,
            progress: animate ? 1 : 0,
            includeHandle: true
        )
        .frame(width: 92, height: 178)
        .rotationEffect(.degrees(-9))
        .animation(.easeOut(duration: 1.6).delay(delay), value: animate)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(racket.title)
                        .font(Type.display(19))
                        .foregroundStyle(Palette.chalk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(racket.subtitle)
                        .font(Type.body(11))
                        .foregroundStyle(Palette.mute)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                gauge
            }

            if let job, let estimate {
                strungDetails(job: job, estimate: estimate)
            } else {
                unstrungDetails
            }
        }
    }

    @ViewBuilder
    private var gauge: some View {
        if let estimate {
            FreshnessGauge(freshness: estimate.freshness, lineWidth: 4.5, tickCount: 20) {
                VStack(spacing: -1) {
                    Text("\(Int((estimate.freshness * 100).rounded()))")
                        .font(Type.readout(16))
                        .foregroundStyle(estimate.status.tint)
                    Text("%").scoreboard(size: 7, color: Palette.faint)
                }
            }
            .frame(width: 52, height: 52)
            .animation(.easeOut(duration: 0.8).delay(delay + 0.3), value: estimate.freshness)
        } else {
            Image(systemName: "scissors")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.faint)
                .frame(width: 52, height: 52)
        }
    }

    @ViewBuilder
    private func strungDetails(job: StringJob, estimate: TensionEstimate) -> some View {
        let mains = store.spec(job.mainsSpecID)
        let crosses = store.spec(job.crossesSpecID)

        VStack(alignment: .leading, spacing: 6) {
            TapeLabel(
                spec: mains,
                role: job.isHybrid ? "Mains" : nil,
                tension: store.tensionUnit.display(estimate.currentMains).liveTension,
                unit: store.tensionUnit.short,
                compact: true
            )
            if job.isHybrid {
                TapeLabel(
                    spec: crosses,
                    role: "Crosses",
                    tension: store.tensionUnit.display(estimate.currentCrosses).liveTension,
                    unit: store.tensionUnit.short,
                    compact: true
                )
            }
        }

        // Kept as a plain row rather than a scroller: this card is a navigation link,
        // and a nested scroll view swallows the tap.
        HStack(spacing: 5) {
            Chip(text: estimate.status.label, color: estimate.status.tint, filled: estimate.status == .dead)
            Chip(text: "\(Int(estimate.days))d", color: Palette.mute)
            Chip(text: "\(estimate.hours.hoursLabel)h", color: Palette.mute)
            if job.isHybrid { Chip(text: "Hybrid", color: racket.accent) }
            Spacer(minLength: 0)
        }

        lifeBar(estimate: estimate)
    }

    private var unstrungDetails: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("No strings in this frame")
                .font(Type.body(12.5, weight: .semibold))
                .foregroundStyle(Palette.mute)
            Text("It's just an expensive fly swatter until you string it.")
                .font(Type.body(11))
                .foregroundStyle(Palette.faint)
                .lineLimit(2)
            Chip(text: "String it", color: Palette.ball, filled: true, systemImage: "plus")
        }
    }

    private func lifeBar(estimate: TensionEstimate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surfaceRaised)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [estimate.status.tint.opacity(0.7), estimate.status.tint],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * CGFloat(estimate.lifeUsed.clamped(to: 0...1)))
                }
            }
            .frame(height: 3)

            Text("\(Int((estimate.lifeUsed * 100).rounded()))% of expected life used")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.faint)
        }
    }
}
