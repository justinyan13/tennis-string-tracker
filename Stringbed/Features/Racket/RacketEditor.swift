import SwiftUI

/// Add or edit a frame, with a live silhouette at the top that redraws as you change
/// the pattern and tape colour.
struct RacketEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let racket: Racket?

    @State private var nickname = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var headSize = 98.0
    @State private var weight = 305.0
    @State private var balance = -6.0
    @State private var gripSize = "4 3/8"
    @State private var mains = 16
    @State private var crosses = 19
    @State private var accentHex = "D4FF3E"
    @State private var acquired = Date()
    @State private var notes = ""

    private let gripSizes = ["4 1/8", "4 1/4", "4 3/8", "4 1/2", "4 5/8"]
    private let mainOptions = [14, 16, 18]
    private let crossOptions = [16, 18, 19, 20, 21]

    private var isValid: Bool {
        !brand.trimmingCharacters(in: .whitespaces).isEmpty
            || !nickname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        SheetScaffold(
            title: racket == nil ? "New frame" : "Edit frame",
            subtitle: racket == nil ? "What are you playing with?" : racket?.subtitle,
            confirmTitle: racket == nil ? "Add to bag" : "Save changes",
            confirmEnabled: isValid,
            tint: Color(hex: accentHex),
            onConfirm: save
        ) {
            preview
            identityCard
            specsCard
            tapeCard
            notesCard
        }
        .onAppear(perform: load)
    }

    private var preview: some View {
        StringBedView(
            mains: mains,
            crosses: crosses,
            mainsColor: Palette.chalk.opacity(0.75),
            crossesColor: Palette.chalk.opacity(0.6),
            frameColor: Color(hex: "1C2226"),
            accent: Color(hex: accentHex),
            wear: 0,
            progress: 1,
            includeHandle: true,
            showDampener: true
        )
        .frame(height: 210)
        .animation(.snappy(duration: 0.35), value: mains)
        .animation(.snappy(duration: 0.35), value: crosses)
    }

    private var identityCard: some View {
        Card {
            VStack(spacing: 2) {
                FieldRow(label: "Nickname") {
                    InputField(placeholder: "Blue Tape", text: $nickname)
                }
                FieldRow(label: "Brand") {
                    InputField(placeholder: "Wilson", text: $brand)
                }
                FieldRow(label: "Model") {
                    InputField(placeholder: "Blade 98 v9", text: $model)
                }
                FieldRow(label: "Acquired") {
                    DatePicker("", selection: $acquired, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color(hex: accentHex))
                }
            }
        }
    }

    private var specsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Specs")

                sliderRow(label: "Head", value: $headSize, range: 85...125, step: 1,
                          display: "\(Int(headSize)) in²")
                sliderRow(label: "Weight", value: $weight, range: 250...370, step: 1,
                          display: "\(Int(weight)) g")
                sliderRow(label: "Balance", value: $balance, range: -12...6, step: 0.5,
                          display: balanceLabel)

                VStack(alignment: .leading, spacing: 7) {
                    Text("Pattern").scoreboard(size: 10, color: Palette.mute)
                    HStack(spacing: 10) {
                        SegmentPicker(options: mainOptions, selection: $mains, label: { "\($0)" },
                                      tint: Color(hex: accentHex))
                        Text("×").font(Type.readout(15)).foregroundStyle(Palette.faint)
                        SegmentPicker(options: crossOptions, selection: $crosses, label: { "\($0)" },
                                      tint: Color(hex: accentHex))
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Grip").scoreboard(size: 10, color: Palette.mute)
                    SegmentPicker(options: gripSizes, selection: $gripSize, label: { $0 },
                                  tint: Color(hex: accentHex))
                }
            }
        }
    }

    private var balanceLabel: String {
        if balance < 0 { return String(format: "%.1f HL", abs(balance)) }
        if balance > 0 { return String(format: "%.1f HH", balance) }
        return "Even"
    }

    private func sliderRow(
        label: String, value: Binding<Double>,
        range: ClosedRange<Double>, step: Double, display: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).scoreboard(size: 10, color: Palette.mute)
                Spacer()
                Text(display)
                    .font(Type.readout(15))
                    .foregroundStyle(Palette.chalk)
            }
            Slider(value: value, in: range, step: step)
                .tint(Color(hex: accentHex))
        }
    }

    private var tapeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Butt cap tape", trailing: "How you tell them apart")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                    ForEach(StringLibrary.swatches, id: \.self) { hex in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) { accentHex = hex }
                            Haptics.tick()
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(height: 34)
                                .overlay {
                                    Circle().strokeBorder(
                                        accentHex == hex ? Palette.chalk : .clear,
                                        lineWidth: 2
                                    )
                                    .padding(-3)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var notesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Notes")
                TextField("Lead at 3 and 9, leather grip…", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .font(Type.body(14))
                    .foregroundStyle(Palette.chalk)
            }
        }
    }

    // MARK: - Data

    private func load() {
        guard let racket else { return }
        nickname = racket.nickname
        brand = racket.brand
        model = racket.model
        headSize = Double(racket.headSize)
        weight = Double(racket.weightGrams)
        balance = racket.balancePoints
        gripSize = gripSizes.contains(racket.gripSize) ? racket.gripSize : gripSizes[2]
        mains = mainOptions.contains(racket.mains) ? racket.mains : 16
        crosses = crossOptions.contains(racket.crosses) ? racket.crosses : 19
        accentHex = racket.accentHex
        acquired = racket.acquired
        notes = racket.notes
    }

    private func save() {
        var updated = racket ?? Racket(
            nickname: "", brand: "", model: "", headSize: 98, weightGrams: 305,
            balancePoints: -6, gripSize: "4 3/8", mains: 16, crosses: 19,
            accentHex: "D4FF3E", acquired: Date()
        )
        updated.nickname = nickname.trimmingCharacters(in: .whitespaces)
        updated.brand = brand.trimmingCharacters(in: .whitespaces)
        updated.model = model.trimmingCharacters(in: .whitespaces)
        updated.headSize = Int(headSize)
        updated.weightGrams = Int(weight)
        updated.balancePoints = balance
        updated.gripSize = gripSize
        updated.mains = mains
        updated.crosses = crosses
        updated.accentHex = accentHex
        updated.acquired = acquired
        updated.notes = notes

        store.upsert(updated)
        Haptics.success()
        dismiss()
    }
}
