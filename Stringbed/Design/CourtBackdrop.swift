import SwiftUI

/// The app sits on a court seen from above at night — chalk lines just barely
/// catching the floodlight, everything else swallowed by the dark.
struct CourtBackdrop: View {
    var tint: Color = Palette.ball

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0A0F0C"), Palette.court, Palette.courtDeep],
                startPoint: .top, endPoint: .bottom
            )

            Canvas { context, size in
                // Court is 36ft × 78ft doubles. Oversize it so it bleeds off every edge.
                let unit = size.width / 27.0
                let courtW = 36 * unit
                let courtH = 78 * unit
                let origin = CGPoint(x: (size.width - courtW) / 2, y: -courtH * 0.06)
                let court = CGRect(x: origin.x, y: origin.y, width: courtW, height: courtH)

                let chalk = GraphicsContext.Shading.color(Palette.chalk.opacity(0.085))
                let chalkFaint = GraphicsContext.Shading.color(Palette.chalk.opacity(0.05))
                let lw: CGFloat = max(1, unit * 0.12)

                context.stroke(Path(court), with: chalk, lineWidth: lw)

                // Singles sidelines, 4.5ft inside each doubles line.
                for dx in [4.5 * unit, courtW - 4.5 * unit] {
                    var line = Path()
                    line.move(to: CGPoint(x: court.minX + dx, y: court.minY))
                    line.addLine(to: CGPoint(x: court.minX + dx, y: court.maxY))
                    context.stroke(line, with: chalk, lineWidth: lw)
                }

                // Net.
                var net = Path()
                net.move(to: CGPoint(x: court.minX - unit * 1.5, y: court.midY))
                net.addLine(to: CGPoint(x: court.maxX + unit * 1.5, y: court.midY))
                context.stroke(net, with: .color(Palette.chalk.opacity(0.075)), lineWidth: lw * 1.4)

                // Service lines, 21ft from the net.
                for dy in [court.midY - 21 * unit, court.midY + 21 * unit] {
                    var line = Path()
                    line.move(to: CGPoint(x: court.minX + 4.5 * unit, y: dy))
                    line.addLine(to: CGPoint(x: court.maxX - 4.5 * unit, y: dy))
                    context.stroke(line, with: chalkFaint, lineWidth: lw)
                }

                // Centre service line.
                var centre = Path()
                centre.move(to: CGPoint(x: court.midX, y: court.midY - 21 * unit))
                centre.addLine(to: CGPoint(x: court.midX, y: court.midY + 21 * unit))
                context.stroke(centre, with: chalkFaint, lineWidth: lw)

                // Centre marks on the baselines.
                for y in [court.minY, court.maxY] {
                    var mark = Path()
                    let dir: CGFloat = y == court.minY ? 1 : -1
                    mark.move(to: CGPoint(x: court.midX, y: y))
                    mark.addLine(to: CGPoint(x: court.midX, y: y + dir * unit * 0.5))
                    context.stroke(mark, with: chalk, lineWidth: lw)
                }
            }

            // Floodlight from above.
            RadialGradient(
                colors: [tint.opacity(0.10), tint.opacity(0.02), .clear],
                center: .init(x: 0.5, y: -0.05),
                startRadius: 0, endRadius: 460
            )
            .blendMode(.plusLighter)

            // Vignette to keep the eye centred.
            RadialGradient(
                colors: [.clear, .black.opacity(0.55)],
                center: .center, startRadius: 180, endRadius: 620
            )
        }
        .ignoresSafeArea()
    }
}
