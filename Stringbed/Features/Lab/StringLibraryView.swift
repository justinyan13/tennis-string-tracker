import SwiftUI

/// Everything you might put in a frame, and what each one costs you per hour.
struct StringLibraryView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var editingSpec: StringSpec?
    @State private var addingSpec = false

    private var grouped: [(StringMaterial, [StringSpec])] {
        StringMaterial.allCases.compactMap { material in
            let specs = store.specs
                .filter { $0.material == material }
                .sorted { $0.name < $1.name }
            return specs.isEmpty ? nil : (material, specs)
        }
    }

    var body: some View {
        ZStack {
            CourtBackdrop()

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("String library")
                            .font(Type.display(22))
                            .foregroundStyle(Palette.chalk)
                        Text("\(store.specs.count) strings on the shelf")
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
                    VStack(spacing: 20) {
                        ForEach(grouped, id: \.0) { material, specs in
                            VStack(alignment: .leading, spacing: 9) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(material.label).scoreboard(size: 11, color: material.tint)
                                    Spacer()
                                    Text("~\(Int(material.expectedLifeHours))h life · \(Int(material.settleLoss * 100))% settle")
                                        .scoreboard(size: 8.5, color: Palette.faint)
                                }
                                Text(material.blurb)
                                    .font(Type.body(11))
                                    .foregroundStyle(Palette.faint)

                                VStack(spacing: 8) {
                                    ForEach(specs) { spec in
                                        Button {
                                            Haptics.tick()
                                            editingSpec = spec
                                        } label: {
                                            row(spec)
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button("Edit", systemImage: "pencil") { editingSpec = spec }
                                            if !inUse(spec) {
                                                Button("Delete", systemImage: "trash", role: .destructive) {
                                                    store.delete(spec: spec)
                                                    Haptics.warning()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Button {
                            Haptics.tick()
                            addingSpec = true
                        } label: {
                            Label("Add a string", systemImage: "plus")
                        }
                        .buttonStyle(GhostButtonStyle())

                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .presentationBackground(Palette.courtDeep)
        .sheet(item: $editingSpec) { spec in
            StringSpecEditor(spec: spec)
        }
        .sheet(isPresented: $addingSpec) {
            StringSpecEditor(spec: nil)
        }
    }

    private func inUse(_ spec: StringSpec) -> Bool {
        store.jobs.contains { $0.mainsSpecID == spec.id || $0.crossesSpecID == spec.id }
    }

    private func row(_ spec: StringSpec) -> some View {
        let performance = store.stringPerformance().first { $0.spec.id == spec.id }
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(spec.color)
                .frame(width: 5, height: 36)
                .shadow(color: spec.color.opacity(0.45), radius: 5)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(spec.name)
                        .font(Type.body(13.5, weight: .semibold))
                        .foregroundStyle(Palette.chalk)
                    if spec.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Palette.ball)
                    }
                }
                HStack(spacing: 6) {
                    Text(spec.gaugeDetail)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.faint)
                    if let performance, performance.hours > 0 {
                        Text("· \(performance.hours.hoursLabel)h played")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.mute)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("$\(spec.pricePerSet.moneyLabel)")
                    .font(Type.readout(14))
                    .foregroundStyle(Palette.chalk)
                Text("per set").scoreboard(size: 7.5, color: Palette.faint)
            }
        }
        .padding(.horizontal, 13)
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
}
