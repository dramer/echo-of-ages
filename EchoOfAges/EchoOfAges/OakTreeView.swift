// OakTreeView.swift
// EchoOfAges
//
// Canvas-drawn oak tree that grows as `progress` goes from 0 → 1.
// Designed to render on a dark (near-black) background.
//
// Growth phases:
//   0.00–0.20 : roots shoot out from the base
//   0.16–0.44 : trunk rises
//   0.40–0.65 : main branches fan out from the trunk top
//   0.57–0.78 : secondary branches extend from main branch tips
//   0.72–0.92 : leaf clusters swell at all branch tips
//   0.88–1.00 : gold sun pulses in above the canopy

import SwiftUI

struct OakTreeView: View {
    var progress: CGFloat   // 0 = nothing drawn, 1 = fully grown

    var body: some View {
        Canvas { ctx, size in
            Self.draw(ctx: ctx, size: size, p: progress)
        }
    }

    // MARK: - Phase Helpers

    private static func remap(_ t: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(1, max(0, (t - lo) / (hi - lo)))
    }

    private static func ease(_ t: CGFloat) -> CGFloat {
        // Smooth ease-in-out
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    private static func phase(_ t: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        ease(remap(t, lo, hi))
    }

    // MARK: - Main Draw

    private static func draw(ctx: GraphicsContext, size: CGSize, p: CGFloat) {
        let cx     = size.width  / 2
        let ground = size.height * 0.76
        let trunkH = size.height * 0.335
        let trunkW = max(9, size.width * 0.038)

        let rootP    = phase(p, 0.00, 0.20)
        let trunkP   = phase(p, 0.16, 0.44)
        let branch1P = phase(p, 0.40, 0.65)
        let branch2P = phase(p, 0.57, 0.78)
        let leafP    = phase(p, 0.72, 0.92)
        let sunP     = phase(p, 0.88, 1.00)

        // Trunk tip — branches always anchor to the final trunk top so they
        // don't float as the trunk finishes growing (trunk is ~96% grown when
        // branches first appear, so the gap is imperceptible).
        let trunkTopY = ground - trunkH

        if rootP    > 0 { drawRoots(ctx: ctx, cx: cx, ground: ground, trunkW: trunkW, p: rootP) }
        if trunkP   > 0 { drawTrunk(ctx: ctx, cx: cx, ground: ground, trunkH: trunkH * trunkP, trunkW: trunkW) }
        if branch1P > 0 { drawMainBranches(ctx: ctx, cx: cx, topY: trunkTopY, trunkH: trunkH, p: branch1P) }
        if branch2P > 0 { drawSecondaryBranches(ctx: ctx, cx: cx, topY: trunkTopY, trunkH: trunkH, p: branch2P) }
        if leafP    > 0 { drawLeaves(ctx: ctx, cx: cx, topY: trunkTopY, trunkH: trunkH, p: leafP) }
        if sunP     > 0 { drawSun(ctx: ctx, cx: cx, topY: trunkTopY, trunkH: trunkH, p: sunP) }
    }

    // MARK: - Roots

    private static func drawRoots(ctx: GraphicsContext, cx: CGFloat, ground: CGFloat,
                                   trunkW: CGFloat, p: CGFloat) {
        let c = Color(red: 0.48, green: 0.30, blue: 0.10)
        // (horizontal offset, vertical drop, stroke width)
        let roots: [(CGFloat, CGFloat, CGFloat)] = [
            (-54, 26, 7.5),
            (-26, 38, 5.5),
            ( 26, 38, 5.5),
            ( 54, 26, 7.5),
        ]
        for (dx, dy, w) in roots {
            let end = CGPoint(x: cx + dx * p, y: ground + dy * p)
            let cp  = CGPoint(x: cx + dx * 0.40, y: ground + dy * 0.12)
            var path = Path()
            path.move(to: CGPoint(x: cx, y: ground))
            path.addQuadCurve(to: end, control: cp)
            ctx.stroke(path, with: .color(c.opacity(0.88)),
                       style: StrokeStyle(lineWidth: w * (0.45 + 0.55 * p), lineCap: .round))
        }
    }

    // MARK: - Trunk

    private static func drawTrunk(ctx: GraphicsContext, cx: CGFloat, ground: CGFloat,
                                   trunkH: CGFloat, trunkW: CGFloat) {
        let c = Color(red: 0.56, green: 0.35, blue: 0.13)
        let topW = trunkW * 0.52
        var path = Path()
        path.move(to: CGPoint(x: cx - trunkW / 2, y: ground))
        path.addLine(to: CGPoint(x: cx + trunkW / 2, y: ground))
        path.addLine(to: CGPoint(x: cx + topW / 2,  y: ground - trunkH))
        path.addLine(to: CGPoint(x: cx - topW / 2,  y: ground - trunkH))
        path.closeSubpath()
        ctx.fill(path, with: .color(c))
    }

    // MARK: - Branch Geometry

    /// (angle from vertical °, length factor × trunkH, stroke width)
    private static let mainDefs: [(CGFloat, CGFloat, CGFloat)] = [
        (-56, 0.52, 4.2),
        (-36, 0.62, 5.2),
        (-14, 0.68, 6.2),
        ( 14, 0.68, 6.2),
        ( 36, 0.62, 5.2),
        ( 56, 0.52, 4.2),
    ]

    private static func branchTip(cx: CGFloat, topY: CGFloat, trunkH: CGFloat,
                                   angle: CGFloat, factor: CGFloat, p: CGFloat = 1) -> CGPoint {
        let rad = angle * .pi / 180
        let len = trunkH * factor * p
        return CGPoint(x: cx + sin(rad) * len, y: topY - cos(rad) * len)
    }

    // MARK: - Main Branches

    private static func drawMainBranches(ctx: GraphicsContext, cx: CGFloat, topY: CGFloat,
                                          trunkH: CGFloat, p: CGFloat) {
        let c = Color(red: 0.56, green: 0.35, blue: 0.13)
        for (angle, factor, w) in mainDefs {
            let tip = branchTip(cx: cx, topY: topY, trunkH: trunkH, angle: angle, factor: factor, p: p)
            let rad = angle * .pi / 180
            let halfLen = trunkH * factor * p * 0.5
            // Slight outward curve at mid-point
            let cp = CGPoint(x: cx + sin(rad) * halfLen + cos(rad) * 7,
                             y: topY - cos(rad) * halfLen + sin(rad).magnitude * 4)
            var path = Path()
            path.move(to: CGPoint(x: cx, y: topY))
            path.addQuadCurve(to: tip, control: cp)
            ctx.stroke(path, with: .color(c),
                       style: StrokeStyle(lineWidth: w * (1 - 0.32 * p), lineCap: .round))
        }
    }

    // MARK: - Secondary Branches

    private static func drawSecondaryBranches(ctx: GraphicsContext, cx: CGFloat, topY: CGFloat,
                                               trunkH: CGFloat, p: CGFloat) {
        let c = Color(red: 0.56, green: 0.35, blue: 0.13)
        for (angle, factor, _) in mainDefs {
            let base    = branchTip(cx: cx, topY: topY, trunkH: trunkH, angle: angle, factor: factor)
            let subLen  = trunkH * factor * 0.43
            for delta: CGFloat in [-21, 21] {
                let sa  = (angle + delta) * .pi / 180
                let tip = CGPoint(x: base.x + sin(sa) * subLen * p,
                                  y: base.y - cos(sa) * subLen * p)
                var path = Path()
                path.move(to: base)
                path.addLine(to: tip)
                ctx.stroke(path, with: .color(c.opacity(0.82)),
                           style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
            }
        }
    }

    // MARK: - Leaves

    private static func drawLeaves(ctx: GraphicsContext, cx: CGFloat, topY: CGFloat,
                                    trunkH: CGFloat, p: CGFloat) {
        let g = Color(red: 0.25, green: 0.54, blue: 0.19)

        // Soft canopy blob — fills the body of the tree
        let cr = trunkH * 0.56 * p
        ctx.fill(
            Ellipse().path(in: CGRect(x: cx - cr, y: topY - cr * 0.52,
                                      width: cr * 2, height: cr * 1.38)),
            with: .color(g.opacity(0.30 * p))
        )

        // Clusters at every main-branch tip
        for (angle, factor, _) in mainDefs {
            let base = branchTip(cx: cx, topY: topY, trunkH: trunkH, angle: angle, factor: factor)
            let r = trunkH * 0.126 * p
            ctx.fill(Ellipse().path(in: CGRect(x: base.x - r, y: base.y - r, width: r * 2, height: r * 2)),
                     with: .color(g.opacity(0.82 * p)))

            // And at secondary tips
            let subLen = trunkH * factor * 0.43
            for delta: CGFloat in [-21, 21] {
                let sa  = (angle + delta) * .pi / 180
                let tip = CGPoint(x: base.x + sin(sa) * subLen, y: base.y - cos(sa) * subLen)
                let sr  = trunkH * 0.090 * p
                ctx.fill(Ellipse().path(in: CGRect(x: tip.x - sr, y: tip.y - sr, width: sr * 2, height: sr * 2)),
                         with: .color(g.opacity(0.70 * p)))
            }
        }
    }

    // MARK: - Sun

    private static func drawSun(ctx: GraphicsContext, cx: CGFloat, topY: CGFloat,
                                 trunkH: CGFloat, p: CGFloat) {
        let gold  = Color(red: 0.92, green: 0.75, blue: 0.35)
        let sunCY = topY - trunkH * 0.30
        let sunR  = trunkH * 0.155 * p

        // Three-ring glow
        for (factor, opacity) in [(2.8, 0.14), (1.8, 0.24)] {
            let gr = sunR * factor
            ctx.fill(Ellipse().path(in: CGRect(x: cx - gr, y: sunCY - gr, width: gr * 2, height: gr * 2)),
                     with: .color(gold.opacity(opacity * p)))
        }
        // Disc
        ctx.fill(Ellipse().path(in: CGRect(x: cx - sunR, y: sunCY - sunR, width: sunR * 2, height: sunR * 2)),
                 with: .color(gold.opacity(0.92 * p)))
    }
}

// MARK: - Animatable

extension OakTreeView: Animatable {
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OakTreeView(progress: 1.0)
            .frame(width: 320, height: 300)
    }
}
