import SwiftUI

/// The tension story of one stringing: where it started, where it is now, and where
/// it's heading if you keep playing at your current rate.
struct DecayChart: View {
    var points: [TensionPoint]
    var reference: Double
    var mainsColor: Color
    var crossesColor: Color
    var sessions: [PlaySession]
    var unit: TensionUnit
    var showCrosses: Bool = true

    private let leftGutter: CGFloat = 34
    private let bottomGutter: CGFloat = 18
    private let topPad: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            guard points.count > 1, reference > 0 else { return }

            let plot = CGRect(
                x: leftGutter, y: topPad,
                width: max(1, size.width - leftGutter - 8),
                height: max(1, size.height - topPad - bottomGutter)
            )

            let lowest = points.map(\.crosses).min() ?? reference * 0.6
            let yMin = max(0, min(lowest, reference * 0.62) - 1.5)
            let yMax = reference + 2.5

            let t0 = points.first!.date.timeIntervalSince1970
            let t1 = points.last!.date.timeIntervalSince1970
            let span = max(1, t1 - t0)

            func px(_ date: Date) -> CGFloat {
                plot.minX + CGFloat((date.timeIntervalSince1970 - t0) / span) * plot.width
            }
            func py(_ value: Double) -> CGFloat {
                plot.maxY - CGFloat((value - yMin) / (yMax - yMin)) * plot.height
            }

            // The zone where a bed stops doing what you strung it to do.
            let deadLine = reference * 0.70
            if deadLine > yMin {
                let rect = CGRect(x: plot.minX, y: py(deadLine), width: plot.width, height: plot.maxY - py(deadLine))
                context.fill(Path(rect), with: .color(Palette.dead.opacity(0.07)))
                var edge = Path()
                edge.move(to: CGPoint(x: plot.minX, y: py(deadLine)))
                edge.addLine(to: CGPoint(x: plot.maxX, y: py(deadLine)))
                context.stroke(
                    edge,
                    with: .color(Palette.dead.opacity(0.35)),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 4])
                )
                context.draw(
                    Text("DEAD").font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.dead.opacity(0.7)),
                    at: CGPoint(x: plot.maxX - 2, y: py(deadLine) + 8), anchor: .topTrailing
                )
            }

            // Gridlines on round numbers.
            let step: Double = (yMax - yMin) > 22 ? 10 : 5
            var g = (yMin / step).rounded(.up) * step
            while g <= yMax {
                let y = py(g)
                var line = Path()
                line.move(to: CGPoint(x: plot.minX, y: y))
                line.addLine(to: CGPoint(x: plot.maxX, y: y))
                context.stroke(line, with: .color(.white.opacity(0.05)), lineWidth: 1)
                context.draw(
                    Text(StringJob.format(unit.display(g)))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.faint),
                    at: CGPoint(x: leftGutter - 6, y: y), anchor: .trailing
                )
                g += step
            }

            // Reference tension.
            var refLine = Path()
            refLine.move(to: CGPoint(x: plot.minX, y: py(reference)))
            refLine.addLine(to: CGPoint(x: plot.maxX, y: py(reference)))
            context.stroke(
                refLine,
                with: .color(Palette.chalk.opacity(0.25)),
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )

            let lived = points.filter { !$0.isProjection }
            let projected = points.filter { $0.isProjection }

            if showCrosses {
                stroke(&context, lived.map { ($0.date, $0.crosses) }, px: px, py: py,
                       color: crossesColor.opacity(0.55), width: 1.6, dash: [])
                stroke(&context, bridge(lived, projected).map { ($0.date, $0.crosses) }, px: px, py: py,
                       color: crossesColor.opacity(0.28), width: 1.4, dash: [3, 3])
            }

            // Mains, filled underneath so the curve has weight.
            if lived.count > 1 {
                var area = Path()
                area.move(to: CGPoint(x: px(lived[0].date), y: plot.maxY))
                for p in lived { area.addLine(to: CGPoint(x: px(p.date), y: py(p.mains))) }
                area.addLine(to: CGPoint(x: px(lived.last!.date), y: plot.maxY))
                area.closeSubpath()
                context.fill(area, with: .linearGradient(
                    Gradient(colors: [mainsColor.opacity(0.24), mainsColor.opacity(0.0)]),
                    startPoint: CGPoint(x: 0, y: plot.minY),
                    endPoint: CGPoint(x: 0, y: plot.maxY)
                ))
            }
            stroke(&context, lived.map { ($0.date, $0.mains) }, px: px, py: py,
                   color: mainsColor, width: 2.6, dash: [])
            stroke(&context, bridge(lived, projected).map { ($0.date, $0.mains) }, px: px, py: py,
                   color: mainsColor.opacity(0.45), width: 2, dash: [4, 4])

            // Where you actually played.
            for session in sessions {
                guard let nearest = points.min(by: {
                    abs($0.date.timeIntervalSince(session.date)) < abs($1.date.timeIntervalSince(session.date))
                }) else { continue }
                let point = CGPoint(x: px(session.date), y: py(nearest.mains))
                let r = 2.0 + min(2.2, session.hours * 0.9)
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                    with: .color(Palette.court)
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                    with: .color(mainsColor.opacity(0.9)), lineWidth: 1.4
                )
            }

            // "Now" marker, if there's a projection to separate from.
            if let last = lived.last, !projected.isEmpty {
                var now = Path()
                now.move(to: CGPoint(x: px(last.date), y: plot.minY))
                now.addLine(to: CGPoint(x: px(last.date), y: plot.maxY))
                context.stroke(
                    now, with: .color(Palette.chalk.opacity(0.22)),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 3])
                )
                context.draw(
                    Text("NOW").font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.mute),
                    at: CGPoint(x: px(last.date), y: plot.minY - 2), anchor: .bottom
                )
            }

            // X axis ends.
            context.draw(
                Text("STRUNG").font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.faint),
                at: CGPoint(x: plot.minX, y: plot.maxY + 5), anchor: .topLeading
            )
            let totalDays = Int(span / 86_400)
            context.draw(
                Text("\(totalDays)D").font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.faint),
                at: CGPoint(x: plot.maxX, y: plot.maxY + 5), anchor: .topTrailing
            )
        }
    }

    /// Projection needs to start where the lived curve ended, or the dashes float.
    private func bridge(_ lived: [TensionPoint], _ projected: [TensionPoint]) -> [TensionPoint] {
        guard let last = lived.last, !projected.isEmpty else { return projected }
        return [last] + projected
    }

    private func stroke(
        _ context: inout GraphicsContext,
        _ values: [(Date, Double)],
        px: (Date) -> CGFloat,
        py: (Double) -> CGFloat,
        color: Color,
        width: CGFloat,
        dash: [CGFloat]
    ) {
        guard values.count > 1 else { return }
        var path = Path()
        path.move(to: CGPoint(x: px(values[0].0), y: py(values[0].1)))
        for v in values.dropFirst() {
            path.addLine(to: CGPoint(x: px(v.0), y: py(v.1)))
        }
        context.stroke(
            path, with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash)
        )
    }
}
