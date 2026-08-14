import SwiftUI

/// The string library, browsable and searchable, with a way to add whatever isn't
/// in it yet.
struct StringPickerSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var title: String
    @Binding var selection: UUID
    var tint: Color = Palette.ball

    @State private var query = ""
    @State private var filter: StringMaterial?
    @State private var addingString = false

    private var results: [StringSpec] {
        store.specs
            .filter { filter == nil || $0.material == filter }
            .filter {
                query.isEmpty
                    || $0.name.localizedCaseInsensitiveContains(query)
                    || $0.material.label.localizedCaseInsensitiveContains(query)
            }
            .sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
                return $0.name < $1.name
            }
    }

    var body: some View {
        ZStack {
            CourtBackdrop(tint: tint)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(Type.display(22))
                            .foregroundStyle(Palette.chalk)
                        Text("\(store.specs.count) strings in the library")
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

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.faint)
                    TextField("Search strings", text: $query)
                        .font(Type.body(14))
                        .foregroundStyle(Palette.chalk)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background {
                    Capsule().fill(Palette.surfaceRaised)
                        .overlay { Capsule().strokeBorder(Palette.hairline, lineWidth: 1) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        filterChip(nil, "All")
                        ForEach(StringMaterial.allCases) { material in
                            filterChip(material, material.short)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 12)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(results) { spec in
                            Button {
                                selection = spec.id
                                Haptics.impact(.light)
                                dismiss()
                            } label: {
                                row(spec)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            Haptics.tick()
                            addingString = true
                        } label: {
                            Label("Add a string", systemImage: "plus")
                        }
                        .buttonStyle(GhostButtonStyle())
                        .padding(.top, 6)

                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .presentationBackground(Palette.courtDeep)
        .sheet(isPresented: $addingString) {
            StringSpecEditor(spec: nil) { created in
                selection = created.id
                dismiss()
            }
        }
    }

    private func filterChip(_ material: StringMaterial?, _ label: String) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { filter = filter == material ? nil : material }
            Haptics.tick()
        } label: {
            Chip(
                text: label,
                color: material?.tint ?? Palette.chalk,
                filled: filter == material && material != nil || (material == nil && filter == nil)
            )
        }
        .buttonStyle(.plain)
    }

    private func row(_ spec: StringSpec) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(spec.color)
                .frame(width: 5, height: 38)
                .shadow(color: spec.color.opacity(0.5), radius: 5)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(spec.name)
                        .font(Type.body(14, weight: .semibold))
                        .foregroundStyle(Palette.chalk)
                    if spec.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Palette.ball)
                    }
                }
                Text("\(spec.material.label) · \(spec.gaugeDetail)")
                    .font(Type.body(10.5))
                    .foregroundStyle(Palette.faint)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(spec.pricePerSet.moneyLabel)")
                    .font(Type.readout(14))
                    .foregroundStyle(Palette.mute)
                if selection == spec.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(tint)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(selection == spec.id ? tint.opacity(0.10) : Palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(selection == spec.id ? tint.opacity(0.4) : Palette.hairline, lineWidth: 1)
                }
        }
    }
}

/// Add or edit an entry in the string library.
struct StringSpecEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let spec: StringSpec?
    var onSave: ((StringSpec) -> Void)? = nil

    @State private var brand = ""
    @State private var model = ""
    @State private var material: StringMaterial = .polyester
    @State private var gauge = 1.25
    @State private var colorHex = "B7BDC6"
    @State private var price = 15.0
    @State private var isFavorite = false

    private var isValid: Bool { !model.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        SheetScaffold(
            title: spec == nil ? "New string" : "Edit string",
            subtitle: material.blurb,
            confirmTitle: spec == nil ? "Add to library" : "Save",
            confirmEnabled: isValid,
            tint: Color(hex: colorHex),
            onConfirm: save
        ) {
            Card(tint: Color(hex: colorHex)) {
                VStack(spacing: 2) {
                    FieldRow(label: "Brand") { InputField(placeholder: "Luxilon", text: $brand) }
                    FieldRow(label: "Model") { InputField(placeholder: "ALU Power", text: $model) }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Material")
                    SegmentPicker(
                        options: StringMaterial.allCases, selection: $material,
                        label: { $0.short }, tint: Color(hex: colorHex)
                    )
                    Text(material.blurb)
                        .font(Type.body(11.5))
                        .foregroundStyle(Palette.mute)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("Gauge").scoreboard(size: 10, color: Palette.mute)
                            Spacer()
                            Text(String(format: "%.2f mm · %@", gauge, gaugeLabel))
                                .font(Type.readout(14))
                                .foregroundStyle(Palette.chalk)
                        }
                        Slider(value: $gauge, in: 1.00...1.45, step: 0.01)
                            .tint(Color(hex: colorHex))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("Price / set").scoreboard(size: 10, color: Palette.mute)
                            Spacer()
                            Text("$\(price.moneyLabel)")
                                .font(Type.readout(14))
                                .foregroundStyle(Palette.chalk)
                        }
                        Slider(value: $price, in: 0...60, step: 0.5)
                            .tint(Color(hex: colorHex))
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Colour on the reel")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                        ForEach(StringLibrary.swatches, id: \.self) { hex in
                            Button {
                                withAnimation(.snappy(duration: 0.2)) { colorHex = hex }
                                Haptics.tick()
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(height: 32)
                                    .overlay {
                                        Circle().strokeBorder(colorHex == hex ? Palette.chalk : .clear, lineWidth: 2)
                                            .padding(-3)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Toggle(isOn: $isFavorite) {
                        Text("Keep it near the top").font(Type.body(13)).foregroundStyle(Palette.chalk)
                    }
                    .tint(Color(hex: colorHex))
                }
            }
        }
        .onAppear(perform: load)
    }

    private var gaugeLabel: String {
        StringSpec(brand: "", model: "", material: material, gauge: gauge,
                   colorHex: colorHex, pricePerSet: 0).gaugeLabel
    }

    private func load() {
        guard let spec else { return }
        brand = spec.brand
        model = spec.model
        material = spec.material
        gauge = spec.gauge
        colorHex = spec.colorHex
        price = spec.pricePerSet
        isFavorite = spec.isFavorite
    }

    private func save() {
        var updated = spec ?? StringSpec(
            brand: "", model: "", material: .polyester,
            gauge: 1.25, colorHex: "B7BDC6", pricePerSet: 15
        )
        updated.brand = brand.trimmingCharacters(in: .whitespaces)
        updated.model = model.trimmingCharacters(in: .whitespaces)
        updated.material = material
        updated.gauge = gauge
        updated.colorHex = colorHex
        updated.pricePerSet = price
        updated.isFavorite = isFavorite

        store.upsert(updated)
        Haptics.success()
        onSave?(updated)
        dismiss()
    }
}
