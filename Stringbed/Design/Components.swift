import SwiftUI

// MARK: - Containers

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    var tint: Color = .clear
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.10), .clear],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: 1)
                    }
            }
    }
}

struct SectionHeader: View {
    var title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).scoreboard(size: 11, color: Palette.mute)
            Spacer()
            if let trailing {
                Text(trailing).scoreboard(size: 10, color: Palette.faint)
            }
        }
    }
}

/// Keeps scrolled content from colliding with the clock and the Dynamic Island.
struct TopScrim: View {
    var height: CGFloat = 26

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Palette.courtDeep, Palette.courtDeep.opacity(0.92), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: height)
            .ignoresSafeArea(edges: .top)
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Small pieces

struct Chip: View {
    var text: String
    var color: Color = Palette.mute
    var filled: Bool = false
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.5)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(filled ? Palette.courtDeep : color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule().fill(filled ? color : color.opacity(0.14))
        }
        .overlay {
            Capsule().strokeBorder(filled ? .clear : color.opacity(0.28), lineWidth: 1)
        }
    }
}

/// A string, labelled the way stringers label a reel — a strip of tape with the
/// string's own colour on it.
struct TapeLabel: View {
    var spec: StringSpec
    var role: String?
    var tension: String?
    var unit: String = "lb"
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(spec.color)
                .frame(width: 4, height: compact ? 20 : 30)
                .shadow(color: spec.color.opacity(0.5), radius: 4)

            VStack(alignment: .leading, spacing: 1) {
                if let role {
                    Text(role).scoreboard(size: 8.5, color: Palette.faint)
                }
                Text(spec.name)
                    .font(Type.body(compact ? 12.5 : 14, weight: .semibold))
                    .foregroundStyle(Palette.chalk)
                    .lineLimit(1)
                if !compact {
                    Text("\(spec.material.short) · \(spec.gaugeDetail)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.faint)
                }
            }

            Spacer(minLength: 4)

            if let tension {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(tension)
                        .font(Type.readout(compact ? 15 : 18))
                        .foregroundStyle(Palette.chalk)
                    Text(unit).scoreboard(size: 8, color: Palette.faint)
                }
            }
        }
    }
}

struct StatBlock: View {
    var label: String
    var value: String
    var unit: String? = nil
    var tint: Color = Palette.chalk
    var size: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).scoreboard(size: 9, color: Palette.faint)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(Type.readout(size))
                    .foregroundStyle(tint)
                if let unit {
                    Text(unit).scoreboard(size: 9, color: Palette.mute)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StarRow: View {
    var rating: Int
    var max: Int = 5
    var size: CGFloat = 11
    var tint: Color = Palette.ball

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...max, id: \.self) { i in
                Image(systemName: i <= rating ? "circle.fill" : "circle")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(i <= rating ? tint : Palette.faint.opacity(0.5))
            }
        }
    }
}

struct RatingPicker: View {
    @Binding var rating: Int
    var tint: Color = Palette.ball

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { i in
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        rating = rating == i ? 0 : i
                    }
                    Haptics.tick()
                } label: {
                    Image(systemName: i <= rating ? "circle.fill" : "circle")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(i <= rating ? tint : Palette.faint.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Palette.ball
    var full: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .black, design: .rounded))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(Palette.courtDeep)
            .padding(.vertical, 15)
            .padding(.horizontal, 22)
            .frame(maxWidth: full ? .infinity : nil)
            .background {
                Capsule().fill(tint)
                    .shadow(color: tint.opacity(0.35), radius: 14, y: 5)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var tint: Color = Palette.chalk
    var full: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(tint)
            .padding(.vertical, 13)
            .padding(.horizontal, 18)
            .frame(maxWidth: full ? .infinity : nil)
            .background {
                Capsule().fill(Palette.surfaceRaised)
                    .overlay { Capsule().strokeBorder(Palette.hairline, lineWidth: 1) }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

// MARK: - States

struct EmptyStateView: View {
    var symbol: String
    var title: String
    var message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Palette.faint)
            VStack(spacing: 6) {
                Text(title)
                    .font(Type.display(19))
                    .foregroundStyle(Palette.chalk)
                Text(message)
                    .font(Type.body(13))
                    .foregroundStyle(Palette.mute)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle(full: false))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }
}

// MARK: - Field styling

struct FieldRow<Content: View>: View {
    var label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .scoreboard(size: 10, color: Palette.mute)
                .frame(width: 84, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 9)
    }
}

struct InputField: View {
    var placeholder: String
    @Binding var text: String
    var alignment: TextAlignment = .leading

    var body: some View {
        TextField(placeholder, text: $text)
            .font(Type.body(15))
            .foregroundStyle(Palette.chalk)
            .multilineTextAlignment(alignment)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.surfaceRaised)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: 1)
                    }
            }
    }
}

/// Horizontal segmented picker that doesn't look like every other iOS app.
struct SegmentPicker<T: Hashable>: View {
    var options: [T]
    @Binding var selection: T
    var label: (T) -> String
    var tint: Color = Palette.ball

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let active = option == selection
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = option }
                    Haptics.tick()
                } label: {
                    Text(label(option))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.4)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(active ? Palette.courtDeep : Palette.mute)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background {
                            Capsule().fill(active ? tint : Palette.surfaceRaised)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Formatting

extension Double {
    /// Estimated tension is a continuous number, so it gets a decimal — rounding it to
    /// the nearest half pound like a reference tension would hide the decay.
    var liveTension: String { String(format: "%.1f", self) }

    var hoursLabel: String {
        self >= 10 ? String(format: "%.0f", self) : String(format: "%.1f", self)
    }

    var moneyLabel: String {
        self >= 100 ? String(format: "%.0f", self) : String(format: "%.2f", self)
    }
}

extension Date {
    var shortDate: String {
        formatted(.dateTime.month(.abbreviated).day())
    }

    var mediumDate: String {
        formatted(.dateTime.month(.abbreviated).day().year())
    }

    var daysAgoLabel: String {
        let days = Int((Date().timeIntervalSince(self) / 86_400).rounded())
        switch days {
        case ..<0: return "scheduled"
        case 0: return "today"
        case 1: return "yesterday"
        case 2..<14: return "\(days)d ago"
        case 14..<60: return "\(days / 7)w ago"
        default: return "\(days / 30)mo ago"
        }
    }
}
