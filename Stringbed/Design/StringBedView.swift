import SwiftUI

/// Where the hoop, the string plane and the yoke sit inside a given canvas.
private struct BedGeometry {
    var center: CGPoint
    /// Outer semi-axes of the hoop.
    var a: CGFloat
    var b: CGFloat
    var frameWidth: CGFloat
    /// Inner semi-axes — the string plane.
    var ia: CGFloat
    var ib: CGFloat
    /// The bed is flat-bottomed at the yoke, like a real frame.
    var yokeY: CGFloat
    var canvasHeight: CGFloat

    init(size: CGSize, includeHandle: Bool) {
        let usableHeight = includeHandle ? size.height * 0.615 : size.height
        var semiB = usableHeight / 2
        var semiA = semiB * 0.80
        if semiA * 2 > size.width {
            semiA = size.width / 2
            semiB = semiA / 0.80
        }
        a = semiA
        b = semiB
        frameWidth = max(2, semiA * 0.085)
        ia = semiA - frameWidth
        ib = semiB - frameWidth
        center = CGPoint(x: size.width / 2, y: semiB + frameWidth * 0.35)
        yokeY = center.y + ib * 0.70
        canvasHeight = size.height
    }

    /// Half-height of the string plane at a given x.
    func halfHeight(atX x: CGFloat) -> CGFloat {
        let n = (x - center.x) / ia
        guard abs(n) < 1 else { return 0 }
        return ib * sqrt(1 - n * n)
    }

    /// Half-width of the string plane at a given y.
    func halfWidth(atY y: CGFloat) -> CGFloat {
        let n = (y - center.y) / ib
        guard abs(n) < 1 else { return 0 }
        return ia * sqrt(1 - n * n)
    }
}

/// The signature view: an actual stringbed, drawn string by string.
///
/// The pattern is the racket's real pattern, the colours are the real strings, and
/// the bed ages on screen — as `wear` climbs, mains drift out of line, crossings
/// notch, and the whole plane loses its snap.
struct StringBedView: View, Animatable {
    var mains: Int = 16
    var crosses: Int = 19
    var mainsColor: Color = Palette.mute
    var crossesColor: Color = Palette.mute
    var frameColor: Color = Color(hex: "20262A")
    var accent: Color = Palette.ball
    /// 0 = box fresh, 1 = cut it out.
    var wear: Double = 0
    /// Stringing animation. Mains go in first, from the centre out, then crosses top down.
    var progress: Double = 1
    var includeHandle: Bool = false
    var showDampener: Bool = true
    var glow: Bool = true

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(progress, wear) }
        set {
            progress = newValue.first
            wear = newValue.second
        }
    }

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            let g = BedGeometry(size: size, includeHandle: includeHandle)
            let w = wear.clamped(to: 0...1)
            let p = progress.clamped(to: 0...1)

            if glow { drawGlow(&context, g: g, wear: w) }
            if includeHandle { drawHandle(&context, g: g) }
            drawStrings(&context, g: g, wear: w, progress: p)
            if w > 0.35 { drawNotches(&context, g: g, wear: w, progress: p) }
            drawFrame(&context, g: g)
            drawGrommets(&context, g: g, progress: p)
            if showDampener && p > 0.98 { drawDampener(&context, g: g) }
        }
        .drawingGroup()
    }

    // MARK: - Layers

    private func drawGlow(_ ctx: inout GraphicsContext, g: BedGeometry, wear: Double) {
        // The sweet spot sits a little above the geometric centre.
        let sweetY = g.center.y - g.ib * 0.12
        let radius = g.ia * 1.05
        let intensity = (1 - wear) * 0.5 + 0.08
        let rect = CGRect(
            x: g.center.x - radius, y: sweetY - radius * 0.9,
            width: radius * 2, height: radius * 1.8
        )
        let shading = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [
                accent.opacity(0.28 * intensity),
                accent.opacity(0.10 * intensity),
                .clear,
            ]),
            center: CGPoint(x: g.center.x, y: sweetY),
            startRadius: 0,
            endRadius: radius
        )
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: g.a * 0.12))
            layer.fill(Path(ellipseIn: rect), with: shading)
        }
    }

    private func drawFrame(_ ctx: inout GraphicsContext, g: BedGeometry) {
        let mid = CGRect(
            x: g.center.x - (g.ia + g.a) / 2,
            y: g.center.y - (g.ib + g.b) / 2,
            width: (g.ia + g.a),
            height: (g.ib + g.b)
        )
        ctx.stroke(Path(ellipseIn: mid), with: .color(frameColor), lineWidth: g.frameWidth)

        // Outer edge catches the floodlight.
        let outer = CGRect(
            x: g.center.x - g.a, y: g.center.y - g.b,
            width: g.a * 2, height: g.b * 2
        )
        ctx.stroke(Path(ellipseIn: outer), with: .color(.white.opacity(0.13)), lineWidth: 0.8)

        // The yoke closing off the bottom of the bed.
        let half = g.halfWidth(atY: g.yokeY)
        var yoke = Path()
        yoke.move(to: CGPoint(x: g.center.x - half - g.frameWidth * 0.4, y: g.yokeY))
        yoke.addQuadCurve(
            to: CGPoint(x: g.center.x + half + g.frameWidth * 0.4, y: g.yokeY),
            control: CGPoint(x: g.center.x, y: g.yokeY + g.frameWidth * 0.9)
        )
        ctx.stroke(yoke, with: .color(frameColor), lineWidth: g.frameWidth * 0.85)
    }

    private func drawHandle(_ ctx: inout GraphicsContext, g: BedGeometry) {
        let half = g.halfWidth(atY: g.yokeY)
        let gripHalf = g.a * 0.115
        let gripTop = g.yokeY + (g.b - g.ib) + g.b * 0.18
        let bottom = g.canvasHeight

        var throat = Path()
        throat.move(to: CGPoint(x: g.center.x - half * 0.92, y: g.yokeY))
        throat.addQuadCurve(
            to: CGPoint(x: g.center.x - gripHalf, y: gripTop),
            control: CGPoint(x: g.center.x - half * 0.55, y: g.yokeY + g.b * 0.30)
        )
        throat.addLine(to: CGPoint(x: g.center.x + gripHalf, y: gripTop))
        throat.addQuadCurve(
            to: CGPoint(x: g.center.x + half * 0.92, y: g.yokeY),
            control: CGPoint(x: g.center.x + half * 0.55, y: g.yokeY + g.b * 0.30)
        )
        ctx.fill(throat, with: .color(frameColor))

        let grip = CGRect(
            x: g.center.x - gripHalf, y: gripTop,
            width: gripHalf * 2, height: max(0, bottom - gripTop)
        )
        ctx.fill(
            Path(roundedRect: grip, cornerRadius: gripHalf * 0.5),
            with: .color(Color(hex: "15191C"))
        )

        // Overgrip wraps.
        let wraps = 7
        for i in 0..<wraps {
            let t = CGFloat(i) / CGFloat(wraps)
            let y = grip.minY + grip.height * (0.10 + t * 0.85)
            var wrap = Path()
            wrap.move(to: CGPoint(x: grip.minX, y: y))
            wrap.addLine(to: CGPoint(x: grip.maxX, y: y - grip.height * 0.045))
            ctx.stroke(wrap, with: .color(.white.opacity(0.07)), lineWidth: 1)
        }

        // Butt cap tape, in the frame's own colour.
        let cap = CGRect(
            x: grip.minX - 1, y: max(grip.minY, grip.maxY - grip.height * 0.10),
            width: grip.width + 2, height: grip.height * 0.10
        )
        if cap.height > 1 {
            ctx.fill(Path(roundedRect: cap, cornerRadius: 3), with: .color(accent.opacity(0.85)))
        }
    }

    private func drawStrings(_ ctx: inout GraphicsContext, g: BedGeometry, wear: Double, progress: Double) {
        let lineWidth = max(0.7, g.ia * 0.017)
        let alive = 1 - wear
        let mainsAlpha = 0.45 + 0.55 * alive
        let crossAlpha = 0.42 + 0.52 * alive
        let mainsInk = mainsColor.onCourt
        let crossesInk = crossesColor.onCourt

        // Mains go in first, from the centre pair outwards — the way you'd actually string it.
        let mainsPhase = (progress / 0.55).clamped(to: 0...1)
        let centreIndex = Double(mains - 1) / 2
        let spacing = g.ia * 2 / Double(mains + 1)

        for i in 0..<mains {
            let orderNorm = centreIndex > 0 ? abs(Double(i) - centreIndex) / centreIndex : 0
            let frac = revealFraction(phase: mainsPhase, order: orderNorm)
            guard frac > 0.001 else { continue }

            let t = (Double(i) + 1) / Double(mains + 1)
            var x = g.center.x + CGFloat(t * 2 - 1) * g.ia * 0.93

            // Dead beds have strings that have wandered and never been straightened.
            let drift = sin(Double(i) * 1.7) * wear * spacing * 0.30
            x += CGFloat(drift)

            let half = g.halfHeight(atX: x)
            guard half > 1 else { continue }
            let top = g.center.y - half
            let bottom = min(g.center.y + half, g.yokeY)
            guard bottom > top else { continue }

            let end = top + (bottom - top) * frac
            var path = Path()
            path.move(to: CGPoint(x: x, y: top))
            path.addQuadCurve(
                to: CGPoint(x: x, y: end),
                control: CGPoint(x: x + CGFloat(drift * 0.6), y: (top + end) / 2)
            )
            ctx.stroke(
                path,
                with: .color(mainsInk.opacity(mainsAlpha)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        }

        // Then the crosses, top down.
        let crossPhase = ((progress - 0.50) / 0.50).clamped(to: 0...1)
        let topY = g.center.y - g.ib * 0.965

        for j in 0..<crosses {
            let orderNorm = crosses > 1 ? Double(j) / Double(crosses - 1) : 0
            let frac = revealFraction(phase: crossPhase, order: orderNorm)
            guard frac > 0.001 else { continue }

            let t = (Double(j) + 1) / Double(crosses + 1)
            let y = topY + CGFloat(t) * (g.yokeY - topY)
            let half = g.halfWidth(atY: y)
            guard half > 1 else { continue }

            let left = g.center.x - half
            let right = g.center.x + half
            let end = left + (right - left) * frac

            var path = Path()
            path.move(to: CGPoint(x: left, y: y))
            path.addLine(to: CGPoint(x: end, y: y))
            ctx.stroke(
                path,
                with: .color(crossesInk.opacity(crossAlpha)),
                style: StrokeStyle(lineWidth: lineWidth * 0.94, lineCap: .round)
            )
        }
    }

    /// Each string draws over a short window, so several are in flight at once and
    /// the whole bed fills in as a wave rather than a metronome.
    private func revealFraction(phase: Double, order: Double) -> Double {
        let window = 0.32
        let start = order * (1 - window)
        return ((phase - start) / window).clamped(to: 0...1)
    }

    /// Worn beds notch where the strings saw across each other.
    private func drawNotches(_ ctx: inout GraphicsContext, g: BedGeometry, wear: Double, progress: Double) {
        guard progress > 0.9 else { return }
        let intensity = ((wear - 0.35) / 0.65).clamped(to: 0...1)
        let dot = max(1.0, g.ia * 0.026)
        let topY = g.center.y - g.ib * 0.965

        for i in stride(from: 0, to: mains, by: 1) {
            let tx = (Double(i) + 1) / Double(mains + 1)
            guard abs(tx - 0.5) < 0.30 else { continue }
            let x = g.center.x + CGFloat(tx * 2 - 1) * g.ia * 0.93

            for j in stride(from: 0, to: crosses, by: 1) {
                let ty = (Double(j) + 1) / Double(crosses + 1)
                guard abs(ty - 0.46) < 0.26 else { continue }
                let y = topY + CGFloat(ty) * (g.yokeY - topY)

                let rect = CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .color(.black.opacity(0.30 * intensity))
                )
            }
        }
    }

    private func drawGrommets(_ ctx: inout GraphicsContext, g: BedGeometry, progress: Double) {
        guard progress > 0.6 else { return }
        let r = max(0.8, g.frameWidth * 0.20)
        let fade = ((progress - 0.6) / 0.4).clamped(to: 0...1)
        let shade = GraphicsContext.Shading.color(.white.opacity(0.20 * fade))

        for i in 0..<mains {
            let t = (Double(i) + 1) / Double(mains + 1)
            let x = g.center.x + CGFloat(t * 2 - 1) * g.ia * 0.93
            let half = g.halfHeight(atX: x)
            guard half > 1 else { continue }
            for y in [g.center.y - half, min(g.center.y + half, g.yokeY)] {
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: shade)
            }
        }
    }

    private func drawDampener(_ ctx: inout GraphicsContext, g: BedGeometry) {
        let w = g.ia * 0.16
        let h = w * 0.62
        let y = g.yokeY - (g.yokeY - (g.center.y - g.ib)) * 0.045 - h / 2
        let rect = CGRect(x: g.center.x - w / 2, y: y - h, width: w, height: h)
        ctx.fill(Path(roundedRect: rect, cornerRadius: h * 0.35), with: .color(accent.opacity(0.9)))
        ctx.fill(
            Path(roundedRect: rect.insetBy(dx: w * 0.28, dy: h * 0.30), cornerRadius: 2),
            with: .color(.black.opacity(0.35))
        )
    }
}

// MARK: - Convenience

extension StringBedView {
    /// Builds a bed straight from the model layer.
    static func forJob(
        _ job: StringJob?,
        racket: Racket,
        mainsSpec: StringSpec?,
        crossesSpec: StringSpec?,
        freshness: Double,
        progress: Double = 1,
        includeHandle: Bool = false,
        glow: Bool = true
    ) -> StringBedView {
        StringBedView(
            mains: racket.mains,
            crosses: racket.crosses,
            mainsColor: mainsSpec?.color ?? Palette.faint,
            crossesColor: crossesSpec?.color ?? Palette.faint,
            frameColor: Color(hex: "1C2226"),
            accent: racket.accent,
            wear: job == nil ? 1 : (1 - freshness).clamped(to: 0...1),
            progress: job == nil ? 0 : progress,
            includeHandle: includeHandle,
            showDampener: job != nil,
            glow: glow && job != nil
        )
    }
}

#Preview {
    ZStack {
        Palette.court.ignoresSafeArea()
        HStack(spacing: 12) {
            StringBedView(mains: 16, crosses: 19, mainsColor: Palette.chalk,
                          crossesColor: Palette.ball, accent: Palette.ball, wear: 0.05)
            StringBedView(mains: 18, crosses: 20, mainsColor: Color(hex: "F1DFBB"),
                          crossesColor: Color(hex: "23262B"), accent: Palette.clay,
                          wear: 0.85, includeHandle: true)
        }
        .padding(24)
    }
}
