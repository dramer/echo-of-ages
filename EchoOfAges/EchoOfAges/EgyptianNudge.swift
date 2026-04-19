// EgyptianNudge.swift
// EchoOfAges
//
// Interactive first-play coach mark for Egyptian Level 1.
//
// A floating tooltip card positions itself above (or below) whichever
// UI zone is spotlighted, with a small triangle pointer connecting the
// card to the target. A pulsing ripple marks the exact tap zone.
//
// Three steps auto-advance on real player actions:
//   Step 1 — palette:  advances when a glyph is selected
//   Step 2 — grid:     advances when a glyph is placed in a cell
//   Step 3 — decipher: player taps Decipher; "Got it" dismisses
//
// Fires exactly once. Persisted under EOA_hasSeenEgyptNudge.

import SwiftUI

// MARK: - One-shot flag

func shouldShowEgyptNudge() -> Bool {
    !UserDefaults.standard.bool(forKey: "EOA_hasSeenEgyptNudge")
}

func dismissEgyptNudge() {
    UserDefaults.standard.set(true, forKey: "EOA_hasSeenEgyptNudge")
}

// MARK: - Step model

enum NudgeStep: Int, CaseIterable {
    case palette  = 0
    case grid     = 1
    case decipher = 2
}

// MARK: - Layout constants

private let kCardWidth: CGFloat   = 270
private let kCardGap: CGFloat     = 14    // gap between spotlight edge and card
private let kArrowSize: CGFloat   = 10    // triangle height
private let kScreenPad: CGFloat   = 16    // min distance from screen edge

// MARK: - Main view

struct EgyptianNudge: View {
    @Binding var isVisible: Bool
    @EnvironmentObject var gameState: GameState

    let paletteFrame:  CGRect
    let gridFrame:     CGRect
    let decipherFrame: CGRect

    @State private var step: NudgeStep = .palette
    @State private var rippleScale1:   CGFloat = 0.6
    @State private var rippleOpacity1: Double  = 0.8
    @State private var rippleScale2:   CGFloat = 0.6
    @State private var rippleOpacity2: Double  = 0.8
    @State private var rippleBeat:     Bool    = false   // re-triggers ripple on step change
    @State private var observedGridHash: Int   = 0

    private var spotlight: CGRect {
        switch step {
        case .palette:  return paletteFrame.insetBy(dx: -10, dy: -10)
        case .grid:     return gridFrame.insetBy(dx: -10, dy: -10)
        case .decipher: return decipherFrame.insetBy(dx: -10, dy: -10)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let screen = geo.size

            ZStack {
                // 1 — Dimming overlay with cutout
                SpotlightOverlay(rect: spotlight)
                    .animation(.easeInOut(duration: 0.4), value: step)
                    .ignoresSafeArea()

                // 2 — Pulsing ripple inside the spotlight
                rippleView

                // 3 — Floating tooltip card + pointer
                tooltipView(screen: screen)
                    .animation(.easeInOut(duration: 0.35), value: step)

                // 4 — Skip button — top right
                VStack {
                    HStack {
                        Spacer()
                        Button(action: finish) {
                            Text("Skip")
                                .font(EgyptFont.body(13))
                                .foregroundStyle(Color.papyrus.opacity(0.50))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color.black.opacity(0.30)))
                        }
                    }
                    .padding(.top, 58)
                    .padding(.trailing, 16)
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            observedGridHash = gridHash()
            startRipple()
        }
        .onChange(of: step) { _, _ in
            // Restart ripple when spotlight changes
            rippleScale1 = 0.6; rippleOpacity1 = 0.8
            rippleScale2 = 0.6; rippleOpacity2 = 0.8
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { startRipple() }
        }
        .onChange(of: gameState.selectedGlyph) { _, glyph in
            if step == .palette, glyph != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.easeInOut(duration: 0.35)) { step = .grid }
                }
            }
        }
        .onChange(of: gameState.playerGrid) { _, _ in
            if step == .grid {
                let h = gridHash()
                if h != observedGridHash {
                    observedGridHash = h
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeInOut(duration: 0.35)) { step = .decipher }
                    }
                }
            }
        }
    }

    // MARK: - Tooltip layout

    /// Returns the card + triangle as a single positioned view.
    private func tooltipView(screen: CGSize) -> some View {
        let sl = spotlight

        // Estimate card height (rough — SwiftUI will size it naturally)
        let estimatedCardH: CGFloat = 140

        // Decide: place above or below the spotlight
        let spaceAbove = sl.minY - kCardGap - kArrowSize
        let placeAbove = spaceAbove >= estimatedCardH

        // Card vertical origin
        let cardY: CGFloat = placeAbove
            ? sl.minY - kArrowSize - kCardGap - estimatedCardH
            : sl.maxY + kArrowSize + kCardGap

        // Card horizontal origin — centre on spotlight, clamp to screen
        let idealX = sl.midX - kCardWidth / 2
        let cardX  = min(max(idealX, kScreenPad), screen.width - kCardWidth - kScreenPad)

        // Arrow tip X relative to card (where the pointer touches the spotlight)
        let arrowTipX = min(max(sl.midX - cardX, kArrowSize * 2), kCardWidth - kArrowSize * 2)

        return ZStack(alignment: .topLeading) {
            // The card body
            cardContent
                .frame(width: kCardWidth)
                .offset(y: placeAbove ? 0 : kArrowSize)   // leave room for arrow above card

            // Triangle pointer
            PointerTriangle(
                pointingDown: placeAbove,
                tipX: arrowTipX
            )
            .frame(width: kCardWidth, height: kArrowSize * 2)
            .offset(y: placeAbove
                    ? estimatedCardH       // below card, pointing down at spotlight
                    : 0)                   // above card, pointing up at spotlight
        }
        .position(x: cardX + kCardWidth / 2,
                  y: cardY + estimatedCardH / 2 + (placeAbove ? 0 : kArrowSize))
    }

    // MARK: - Card content

    private var stepTitle: String {
        switch step {
        case .palette:  return "1. Select a hieroglyph"
        case .grid:     return "2. Place it in an empty cell"
        case .decipher: return "3. Decipher when ready"
        }
    }

    private var stepBody: String {
        switch step {
        case .palette:
            return "Tap any glyph to arm it — it highlights. Each symbol appears once per row and column."
        case .grid:
            return "Tap any empty cell to place your glyph. Tap a different cell to move it."
        case .decipher:
            return "Fill every cell, then tap Decipher. Wrong cells flash red. Logic alone solves it."
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title row with step badge
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.goldMid.opacity(0.22))
                        .frame(width: 30, height: 30)
                    Text("\(step.rawValue + 1)")
                        .font(EgyptFont.titleBold(15))
                        .foregroundStyle(Color.goldBright)
                }
                Text(stepTitle)
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(Color.goldBright)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(stepBody)
                .font(EgyptFont.bodyItalic(13))
                .foregroundStyle(Color.papyrus.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Progress dots + Got it button
            HStack(spacing: 5) {
                ForEach(NudgeStep.allCases, id: \.rawValue) { s in
                    Circle()
                        .fill(s.rawValue <= step.rawValue
                              ? Color.goldBright
                              : Color.goldDark.opacity(0.28))
                        .frame(width: 5, height: 5)
                }
                Spacer()
                if step == .decipher {
                    Button(action: finish) {
                        Text("Got it")
                            .font(EgyptFont.titleBold(13))
                            .foregroundStyle(Color.stoneDark)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.goldMid))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.06, green: 0.04, blue: 0.01).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.goldDark.opacity(0.50), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.55), radius: 14, x: 0, y: 3)
    }

    // MARK: - Ripple

    private var rippleView: some View {
        let cx = spotlight.midX
        let cy = spotlight.midY
        let r  = min(spotlight.width, spotlight.height) * 0.30

        return ZStack {
            Circle()
                .stroke(Color.goldBright.opacity(rippleOpacity1), lineWidth: 2.5)
                .frame(width: r * 2, height: r * 2)
                .scaleEffect(rippleScale1)
            Circle()
                .stroke(Color.goldBright.opacity(rippleOpacity2), lineWidth: 1.5)
                .frame(width: r * 2, height: r * 2)
                .scaleEffect(rippleScale2)
            Circle()
                .fill(Color.goldBright.opacity(0.50))
                .frame(width: 9, height: 9)
        }
        .position(x: cx, y: cy)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.4), value: step)
    }

    private func startRipple() {
        withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) {
            rippleScale1 = 2.0; rippleOpacity1 = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) {
                rippleScale2 = 2.0; rippleOpacity2 = 0
            }
        }
    }

    // MARK: - Helpers

    private func gridHash() -> Int {
        gameState.playerGrid.flatMap { $0 }.compactMap { $0 }.map { $0.rawValue }.hashValue
    }

    private func finish() {
        withAnimation(.easeOut(duration: 0.25)) { isVisible = false }
        dismissEgyptNudge()
    }
}

// MARK: - Pointer triangle shape

/// A small triangle that points up or down, with its tip at `tipX` along its width.
private struct PointerTriangle: View {
    let pointingDown: Bool
    let tipX: CGFloat   // x position of the tip within the view's width

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            let h = size.height
            let w = size.width
            let tip = min(max(tipX, kArrowSize * 2), w - kArrowSize * 2)

            if pointingDown {
                // Base at top, tip at bottom
                path.move(to: CGPoint(x: tip - kArrowSize, y: 0))
                path.addLine(to: CGPoint(x: tip + kArrowSize, y: 0))
                path.addLine(to: CGPoint(x: tip, y: h))
            } else {
                // Base at bottom, tip at top
                path.move(to: CGPoint(x: tip - kArrowSize, y: h))
                path.addLine(to: CGPoint(x: tip + kArrowSize, y: h))
                path.addLine(to: CGPoint(x: tip, y: 0))
            }
            path.closeSubpath()
            ctx.fill(path, with: .color(Color(red: 0.06, green: 0.04, blue: 0.01).opacity(0.94)))
            ctx.stroke(path, with: .color(Color.goldDark.opacity(0.50)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Spotlight overlay

private struct SpotlightOverlay: View {
    let rect: CGRect

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(.black.opacity(0.65)))
            var hole = Path()
            hole.addRoundedRect(
                in: rect,
                cornerRadii: .init(topLeading: 12, bottomLeading: 12,
                                   bottomTrailing: 12, topTrailing: 12)
            )
            ctx.blendMode = .destinationOut
            ctx.fill(hole, with: .color(.black))
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }
}
