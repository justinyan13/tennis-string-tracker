import SwiftUI
import UIKit

/// A 270° tachometer for a stringbed. Ticks light up as freshness climbs, and the
/// arc runs the full status spectrum: dead red → amber → ball green → mint.
struct FreshnessGauge<Content: View>: View, Animatable {
    var freshness: Double
    var lineWidth: CGFloat = 9
    var tickCount: Int = 28
    var showTicks: Bool = true
    @ViewBuilder var content: () -> Content

    var animatableData: Double {
        get { freshness }
        set { freshness = newValue }
    }

    private let sweep: Double = 270
    private let startAngle: Double = 135

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - lineWidth / 2 - (showTicks ? lineWidth * 1.1 : 0)
                let value = freshness.clamped(to: 0...1)

                // Track
                context.stroke(
                    arcPath(center: center, radius: radius, from: 0, to: 1),
                    with: .color(.white.opacity(0.07)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

                // Value arc, drawn as short segments so it can carry a spectrum.
                if value > 0.004 {
                    let steps = max(2, Int(value * 90))
                    for i in 0..<steps {
                        let t0 = Double(i) / Double(steps) * value
                        let t1 = Double(i + 1) / Double(steps) * value
                        context.stroke(
                            arcPath(center: center, radius: radius, from: t0, to: t1 + 0.004),
                            with: .color(spectrum(at: t1)),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                        )
                    }

                    // Bright cap where the needle would be.
                    let capAngle = Angle(degrees: startAngle + sweep * value).radians
                    let cap = CGPoint(
                        x: center.x + cos(capAngle) * radius,
                        y: center.y + sin(capAngle) * radius
                    )
                    let capRect = CGRect(
                        x: cap.x - lineWidth * 0.62, y: cap.y - lineWidth * 0.62,
                        width: lineWidth * 1.24, height: lineWidth * 1.24
                    )
                    context.drawLayer { layer in
                        layer.addFilter(.blur(radius: lineWidth * 0.5))
                        layer.fill(Path(ellipseIn: capRect.insetBy(dx: -lineWidth * 0.3, dy: -lineWidth * 0.3)),
                                   with: .color(spectrum(at: value).opacity(0.55)))
                    }
                    context.fill(Path(ellipseIn: capRect), with: .color(spectrum(at: value)))
                    context.fill(
                        Path(ellipseIn: capRect.insetBy(dx: lineWidth * 0.38, dy: lineWidth * 0.38)),
                        with: .color(Palette.courtDeep)
                    )
                }

                if showTicks {
                    let tickRadius = radius + lineWidth * 1.05
                    for i in 0...tickCount {
                        let t = Double(i) / Double(tickCount)
                        let angle = Angle(degrees: startAngle + sweep * t).radians
                        let major = i % 7 == 0
                        let length = major ? lineWidth * 0.75 : lineWidth * 0.42
                        let inner = CGPoint(
                            x: center.x + cos(angle) * tickRadius,
                            y: center.y + sin(angle) * tickRadius
                        )
                        let outer = CGPoint(
                            x: center.x + cos(angle) * (tickRadius + length),
                            y: center.y + sin(angle) * (tickRadius + length)
                        )
                        var path = Path()
                        path.move(to: inner)
                        path.addLine(to: outer)
                        let lit = t <= value
                        context.stroke(
                            path,
                            with: .color(lit ? spectrum(at: t).opacity(0.85) : .white.opacity(major ? 0.16 : 0.08)),
                            style: StrokeStyle(lineWidth: major ? 2 : 1.2, lineCap: .round)
                        )
                    }
                }
            }
            content()
        }
    }

    private func arcPath(center: CGPoint, radius: CGFloat, from: Double, to: Double) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle + sweep * from),
            endAngle: .degrees(startAngle + sweep * to),
            clockwise: false
        )
        return path
    }

    /// Colour at a point along the gauge, matching the status bands.
    private func spectrum(at t: Double) -> Color {
        switch t {
        case ..<0.25: return Palette.dead.mix(with: Palette.fading, by: t / 0.25)
        case ..<0.50: return Palette.fading.mix(with: Palette.prime, by: (t - 0.25) / 0.25)
        case ..<0.82: return Palette.prime
        default: return Palette.prime.mix(with: Palette.fresh, by: (t - 0.82) / 0.18)
        }
    }
}

extension FreshnessGauge where Content == EmptyView {
    init(freshness: Double, lineWidth: CGFloat = 9, showTicks: Bool = true) {
        self.init(freshness: freshness, lineWidth: lineWidth, showTicks: showTicks) { EmptyView() }
    }
}

