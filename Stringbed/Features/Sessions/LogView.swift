import SwiftUI

/// Everything you've hit, newest first, with a twelve-week rhythm chart on top.
struct LogView: View {
    @Environment(Store.self) private var store
    @State private var editingSession: PlaySession?

    private var grouped: [(label: String, sessions: [PlaySession])] {
        let calendar = Calendar.current
        let all = store.recentSessions
        var order: [String] = []
        var buckets: [String: [PlaySession]] = [:]

        for session in all {
            let key: String
            if calendar.isDateInToday(session.date) {
                key = "Today"
            } else if calendar.isDateInYesterday(session.date) {
                key = "Yesterday"
            } else if calendar.isDate(session.date, equalTo: Date(), toGranularity: .weekOfYear) {
                key = "This week"
            } else {
                key = session.date.formatted(.dateTime.month(.wide).year())
            }
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(session)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                rhythmCard

                if store.sessions.isEmpty {
                    EmptyStateView(
                        symbol: "list.bullet",
                        title: "Nothing logged",
                        message: "Every hour you log pulls the tension estimate down and the Lab into focus."
                    )
                } else {
                    ForEach(grouped, id: \.label) { group in
                        VStack(spacing: 10) {
                            SectionHeader(
                                title: group.label,
                                trailing: "\(group.sessions.reduce(0) { $0 + $1.hours }.hoursLabel)h"
                            )
                            VStack(spacing: 8) {
                                ForEach(group.sessions) { session in
                                    Button {
                                        Haptics.tick()
                                        editingSession = session
                                    } label: {
                                        feedRow(session)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            store.delete(session: session)
                                            Haptics.warning()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $editingSession) { session in
            LogSessionSheet(editing: session)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LOG")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .tracking(4.5)
                    .foregroundStyle(Palette.chalk)
                Text("\(store.sessions.count) sessions · \(store.totalHours.hoursLabel) hours on court")
                    .font(Type.body(12))
                    .foregroundStyle(Palette.mute)
            }
            Spacer()
        }
        .padding(.top, 6)
    }

    private var rhythmCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Last 12 weeks", trailing: "\(store.hoursPerWeek.hoursLabel) hrs/wk avg")
                WeeklyBars(buckets: store.weeklyHours())
                    .frame(height: 74)
            }
        }
    }

    private func feedRow(_ session: PlaySession) -> some View {
        let racket = store.racket(session.racketID)
        let accent = racket?.accent ?? Palette.ball
        return HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text(session.date.formatted(.dateTime.day()))
                    .font(Type.readout(15))
                    .foregroundStyle(Palette.chalk)
                Text(session.date.formatted(.dateTime.month(.abbreviated)))
                    .scoreboard(size: 7.5, color: Palette.faint)
            }
            .frame(width: 34)

            Rectangle().fill(accent.opacity(0.6)).frame(width: 2, height: 34).cornerRadius(1)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: session.kind.symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accent)
                    Text(session.kind.label)
                        .font(Type.body(13, weight: .semibold))
                        .foregroundStyle(Palette.chalk)
                }
                Text("\(racket?.title ?? "Unknown frame") · \(session.surface.label)")
                    .font(Type.body(10.5))
                    .foregroundStyle(Palette.faint)
                    .lineLimit(1)
            }

            Spacer()

            if session.feel > 0 { StarRow(rating: session.feel, size: 6.5) }

            Text("\(session.hours.hoursLabel)h")
                .font(Type.readout(15))
                .foregroundStyle(Palette.mute)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                }
        }
    }
}

/// Twelve weeks of court time as a bar per week — the rhythm you actually keep.
struct WeeklyBars: View {
    var buckets: [WeekBucket]

    var body: some View {
        GeometryReader { proxy in
            let peak = max(1, buckets.map(\.hours).max() ?? 1)
            let gap: CGFloat = 5
            let count = max(1, buckets.count)
            let barWidth = max(3, (proxy.size.width - gap * CGFloat(count - 1)) / CGFloat(count))

            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                    let isCurrent = index == buckets.count - 1
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.035))
                                .frame(height: proxy.size.height - 14)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: isCurrent
                                            ? [Palette.ball, Palette.ball.opacity(0.7)]
                                            : [Palette.chalk.opacity(0.72), Palette.chalk.opacity(0.38)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(height: max(bucket.hours > 0 ? 3 : 0,
                                                   (proxy.size.height - 14) * CGFloat(bucket.hours / peak)))
                        }
                        Text(bucket.start.formatted(.dateTime.day()))
                            .font(.system(size: 7.5, weight: .bold, design: .rounded))
                            .foregroundStyle(isCurrent ? Palette.ball : Palette.faint)
                    }
                    .frame(width: barWidth)
                }
            }
        }
    }
}
