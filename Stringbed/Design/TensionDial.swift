import SwiftUI

/// A knurled tension knob you actually turn. Drag around it to dial in the number,
/// with a haptic detent every half pound — the closest thing to a real crank handle
/// a phone can manage.
struct TensionDial: View {
    @Binding var pounds: Double
    var unit: TensionUnit = .pounds
    var range: ClosedRange<Double> = 35...70
    var caption: String = "Mains"
    var tint: Color = Palette.ball

    @State private var lastAngle: Double?
    @State private var lastDetent: Double = 0

    private let sweep: Double = 270
    private let startAngle: Double = 135

    private var normalized: Double {
        ((pounds - range.lowerBound) / (range.upperBound - range.lowerBound)).clamped(to: 0...1)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                dialFace(size: size)
                readout
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(in: proxy.size))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func dialFace(size: CGFloat) -> some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = size / 2 - 14

            // Detent ticks all the way round the sweep.
            let ticks = 45
            for i in 0...ticks {
                let t = Double(i) / Double(ticks)
                let angle = Angle(degrees: startAngle + sweep * t).radians
                let major = i % 5 == 0
                let lit = t <= normalized
                let innerR = radius - (major ? 13 : 8)
                var path = Path()
                path.move(to: CGPoint(x: center.x + cos(angle) * innerR, y: center.y + sin(angle) * innerR))
                path.addLine(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
                context.stroke(
                    path,
                    with: .color(lit ? tint.opacity(major ? 0.95 : 0.55) : .white.opacity(major ? 0.18 : 0.09)),
                    style: StrokeStyle(lineWidth: major ? 2.4 : 1.3, lineCap: .round)
                )
            }

            // Knob body.
            let knobR = radius - 22
            let knob = CGRect(x: center.x - knobR, y: center.y - knobR, width: knobR * 2, height: knobR * 2)
            context.fill(
                Path(ellipseIn: knob),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: "141A16"), Color(hex: "090C0A")]),
                    center: CGPoint(x: center.x - knobR * 0.3, y: center.y - knobR * 0.4),
                    startRadius: 0, endRadius: knobR * 1.6
                )
            )
            context.stroke(Path(ellipseIn: knob), with: .color(.white.opacity(0.10)), lineWidth: 1)

            // Pointer.
            let pointerAngle = Angle(degrees: startAngle + sweep * normalized).radians
            var pointer = Path()
            pointer.move(to: CGPoint(
                x: center.x + cos(pointerAngle) * (knobR * 0.70),
                y: center.y + sin(pointerAngle) * (knobR * 0.70)
            ))
            pointer.addLine(to: CGPoint(
                x: center.x + cos(pointerAngle) * (knobR - 5),
                y: center.y + sin(pointerAngle) * (knobR - 5)
            ))
            context.stroke(pointer, with: .color(tint), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }

    private var readout: some View {
        VStack(spacing: 0) {
            Text(caption)
                .scoreboard(size: 10, color: Palette.mute)
            Text(StringJob.format(unit.display(pounds)))
                .font(Type.readout(44))
                .foregroundStyle(Palette.chalk)
                .contentTransition(.numericText())
            Text(unit.short)
                .scoreboard(size: 10, color: tint)
        }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                guard dx * dx + dy * dy > 100 else { return }
                let angle = atan2(dy, dx) * 180 / .pi

                if let last = lastAngle {
                    var delta = angle - last
                    if delta > 180 { delta -= 360 }
                    if delta < -180 { delta += 360 }
                    let span = range.upperBound - range.lowerBound
                    let next = (pounds + delta / sweep * span).clamped(to: range)
                    let snapped = (next * 2).rounded() / 2
                    if snapped != lastDetent {
                        lastDetent = snapped
                        Haptics.tick()
                    }
                    pounds = snapped
                }
                lastAngle = angle
            }
            .onEnded { _ in
                lastAngle = nil
                Haptics.impact(.soft)
            }
    }
}

/// Compact stepper for places where a full dial would be overkill.
struct TensionStepper: View {
    @Binding var pounds: Double
    var unit: TensionUnit = .pounds
    var label: String
    var tint: Color = Palette.ball
    var range: ClosedRange<Double> = 35...70

    var body: some View {
        HStack(spacing: 14) {
            Text(label)
                .scoreboard(size: 11, color: Palette.mute)
                .lineLimit(1)
                .fixedSize()
                .frame(width: 80, alignment: .leading)

            Button {
                adjust(-0.5)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .black))
                    .frame(width: 34, height: 34)
                    .background(Palette.surfaceRaised, in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.chalk)

            Text(StringJob.format(unit.display(pounds)))
                .font(Type.readout(24))
                .foregroundStyle(tint)
                .frame(minWidth: 54)
                .contentTransition(.numericText())

            Button {
                adjust(0.5)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .black))
                    .frame(width: 34, height: 34)
                    .background(Palette.surfaceRaised, in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.chalk)

            Text(unit.short)
                .scoreboard(size: 10, color: Palette.faint)
        }
    }

    private func adjust(_ delta: Double) {
        withAnimation(.snappy(duration: 0.18)) {
            pounds = (pounds + delta).clamped(to: range)
        }
        Haptics.tick()
    }
}
