import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var stringer = ""
    @State private var confirmingReset = false

    var body: some View {
        ZStack {
            CourtBackdrop()

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Setup")
                            .font(Type.display(22))
                            .foregroundStyle(Palette.chalk)
                        Text("Units, defaults, and how the maths works")
                            .font(Type.body(12))
                            .foregroundStyle(Palette.mute)
                    }
                    Spacer()
                    Button {
                        Haptics.tick()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Palette.mute)
                            .frame(width: 34, height: 34)
                            .background { Circle().fill(Palette.surfaceRaised) }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 14)

                ScrollView {
                    VStack(spacing: 16) {
                        preferencesCard
                        modelCard
                        dataCard
                        aboutCard
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .presentationBackground(Palette.courtDeep)
        .onAppear { stringer = store.defaultStringer }
    }

    private var preferencesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Preferences")

                VStack(alignment: .leading, spacing: 7) {
                    Text("Tension unit").scoreboard(size: 10, color: Palette.mute)
                    SegmentPicker(
                        options: TensionUnit.allCases,
                        selection: Binding(
                            get: { store.tensionUnit },
                            set: { store.setTensionUnit($0) }
                        ),
                        label: { $0 == .pounds ? "Pounds" : "Kilograms" }
                    )
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Default stringer").scoreboard(size: 10, color: Palette.mute)
                    InputField(placeholder: "Who strings your frames?", text: $stringer)
                        .onChange(of: stringer) {
                            store.defaultStringer = stringer
                            store.persist()
                        }
                }
            }
        }
    }

    private var modelCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "How the numbers work")

                bullet(
                    "Settling",
                    "Every bed drops fast in the first two days as the knots seat and the material relaxes — about \(Int(StringMaterial.polyester.settleLoss * 100))% for poly, \(Int(StringMaterial.naturalGut.settleLoss * 100))% for gut. Mark a job prestretched and Stringbed halves it, because the stringer already took most of it out."
                )
                bullet(
                    "Creep",
                    "Strings keep relaxing in the bag, logarithmically — quickly at first, then barely."
                )
                bullet(
                    "Play",
                    "Each hour of ball striking takes a slice off. Serve baskets and clay count for more than a lesson indoors, because they are."
                )
                bullet(
                    "Freshness",
                    "A blend of tension held and life used. It falls out of PRIME when the bed has given back roughly 30% of what you strung it at, or when the set has taken the hours its material usually survives."
                )

                Text("These constants are tuned to published tension-retention testing and the usual stringer rules of thumb. They're estimates. What they're genuinely good at is comparing your own setups against each other.")
                    .font(Type.body(11.5))
                    .foregroundStyle(Palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }

    private func bullet(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).scoreboard(size: 9.5, color: Palette.ball)
            Text(body)
                .font(Type.body(12))
                .foregroundStyle(Palette.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dataCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Data")
                HStack(spacing: 0) {
                    StatBlock(label: "Frames", value: "\(store.rackets.count)", size: 18)
                    StatBlock(label: "Stringings", value: "\(store.jobs.count)", size: 18)
                    StatBlock(label: "Sessions", value: "\(store.sessions.count)", size: 18)
                    StatBlock(label: "Strings", value: "\(store.specs.count)", size: 18)
                }
                Text("Everything lives on this device, in one JSON file. Nothing is sent anywhere.")
                    .font(Type.body(11.5))
                    .foregroundStyle(Palette.faint)

                if confirmingReset {
                    VStack(spacing: 8) {
                        Text("This wipes your frames, stringings and sessions, and puts the demo bag back.")
                            .font(Type.body(12))
                            .foregroundStyle(Palette.clay)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Button("Cancel") {
                                withAnimation(.snappy) { confirmingReset = false }
                            }
                            .buttonStyle(GhostButtonStyle())
                            Button("Wipe it") {
                                store.resetToSeed()
                                Haptics.warning()
                                withAnimation(.snappy) { confirmingReset = false }
                            }
                            .buttonStyle(PrimaryButtonStyle(tint: Palette.dead))
                        }
                    }
                } else {
                    Button("Reset to demo bag") {
                        Haptics.tick()
                        withAnimation(.snappy) { confirmingReset = true }
                    }
                    .buttonStyle(GhostButtonStyle(tint: Palette.clay))
                }
            }
        }
    }

    private var aboutCard: some View {
        Card(tint: Palette.ball) {
            VStack(alignment: .leading, spacing: 8) {
                Text("STRINGBED")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .tracking(3.5)
                    .foregroundStyle(Palette.chalk)
                Text("A tracker for people who can tell when the bed has gone, but can never remember what they strung it at.")
                    .font(Type.body(12.5))
                    .foregroundStyle(Palette.mute)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Version 1.0")
                    .scoreboard(size: 9, color: Palette.faint)
            }
        }
    }
}
