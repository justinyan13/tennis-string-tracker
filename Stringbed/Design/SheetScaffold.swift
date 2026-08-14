import SwiftUI

/// Shared chrome for every sheet: court backdrop, a scoreboard title, and one
/// unmissable confirm button pinned to the bottom.
struct SheetScaffold<Content: View>: View {
    var title: String
    var subtitle: String? = nil
    var confirmTitle: String
    var confirmEnabled: Bool = true
    var tint: Color = Palette.ball
    var onConfirm: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CourtBackdrop(tint: tint)

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(Type.display(22))
                            .foregroundStyle(Palette.chalk)
                        if let subtitle {
                            Text(subtitle)
                                .font(Type.body(12))
                                .foregroundStyle(Palette.mute)
                        }
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
                        content()
                        Color.clear.frame(height: 12)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)

                Button {
                    onConfirm()
                } label: {
                    Text(confirmTitle)
                }
                .buttonStyle(PrimaryButtonStyle(tint: tint))
                .opacity(confirmEnabled ? 1 : 0.35)
                .disabled(!confirmEnabled)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background {
                    LinearGradient(
                        colors: [Palette.courtDeep.opacity(0), Palette.courtDeep.opacity(0.9)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
            }
        }
        .presentationBackground(Palette.courtDeep)
        .presentationDragIndicator(.hidden)
    }
}
