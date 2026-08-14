import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case bag, log, lab

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bag: return "Bag"
        case .log: return "Log"
        case .lab: return "Lab"
        }
    }

    var symbol: String {
        switch self {
        case .bag: return "bag.fill"
        case .log: return "list.bullet"
        case .lab: return "chart.xyaxis.line"
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @State private var tab: Tab = .bag
    @State private var loggingSession = false
    @State private var showingSettings = false

    var body: some View {
        ZStack(alignment: .bottom) {
            CourtBackdrop()

            Group {
                switch tab {
                case .bag: BagView()
                case .log: LogView()
                case .lab: LabView()
                }
            }
            .transition(.opacity)

            TopScrim()

            TabBar(
                tab: $tab,
                onLog: {
                    Haptics.impact(.medium)
                    loggingSession = true
                },
                onSettings: {
                    Haptics.tick()
                    showingSettings = true
                }
            )
        }
        .sheet(isPresented: $loggingSession) {
            LogSessionSheet()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

/// A floating scoreboard strip instead of the standard tab bar, with the log button
/// living in the middle of it — the thing you press most often.
private struct TabBar: View {
    @Binding var tab: Tab
    var onLog: () -> Void
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            tabButton(.bag)
            tabButton(.log)

            Button(action: onLog) {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(Palette.courtDeep)
                    .frame(width: 50, height: 50)
                    .background {
                        Circle().fill(Palette.ball)
                            .shadow(color: Palette.ball.opacity(0.45), radius: 14, y: 4)
                    }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)

            tabButton(.lab)
            settingsButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay { Capsule().fill(Palette.courtDeep.opacity(0.55)) }
                .overlay { Capsule().strokeBorder(Palette.hairline, lineWidth: 1) }
        }
        .padding(.bottom, 6)
    }

    private func tabButton(_ target: Tab) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) { tab = target }
            Haptics.tick()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: target.symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(target.title)
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .textCase(.uppercase)
            }
            .foregroundStyle(tab == target ? Palette.ball : Palette.mute)
            .frame(width: 58, height: 44)
            .background {
                if tab == target {
                    Capsule().fill(Palette.ball.opacity(0.10))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var settingsButton: some View {
        Button(action: onSettings) {
            VStack(spacing: 3) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                Text("Setup")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .textCase(.uppercase)
            }
            .foregroundStyle(Palette.mute)
            .frame(width: 58, height: 44)
        }
        .buttonStyle(.plain)
    }
}
