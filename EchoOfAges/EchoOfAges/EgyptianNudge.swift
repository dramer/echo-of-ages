// EgyptianNudge.swift
// EchoOfAges
//
// Interactive first-play coach mark for Egyptian Level 1.
//
// Three steps — each spotlights a UI zone with a pulsing ripple and
// a bouncing arrow. The nudge auto-advances when the player actually
// performs the action (glyph selected → glyph placed → tap Decipher).
//
// Fires exactly once, persisted under EOA_hasSeenEgyptNudge.

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
    case palette  = 0   // tap a glyph in the palette
    case grid     = 1   // tap an empty cell to place it
    case decipher = 2   // tap Decipher when finished
}

// MARK: - Main view

struct EgyptianNudge: View {
    @Binding var isVisible: Bool
    @EnvironmentObject var gameState: GameState

    let paletteFrame:  CGRect
    let gridFrame:     CGRect
    let decipherFrame: CGRect

    @State private var step: NudgeStep = .palette

    // Ripple animation
    @State private var rippleScale1: CGFloat = 0.6
    @State private var rippleOpacity1: Double = 0.8
    @State private var rippleScale2: CGFloat = 0.6
    @State private var rippleOpacity2: Double = 0.8

    // Arrow bounce
    @State private var arrowBounce: CGFloat = 0

    // Track game state to auto-advance
    @State private var observedGlyph: Glyph? = nil
    @State private var observedGridHash: Int = 0

    private var spotlightFrame: CGRect {
        let f: CGRect
        switch step {
        case .palette:  f = paletteFrame
        case .grid:     f = gridFrame
        case .decipher: f = decipherFrame
        }
        return f.insetBy(dx: -10, dy: -10)
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // 1 — Dim overlay with cutout
            SpotlightOverlay(rect: spotlightFrame)
                .animation(.easeInOut(duration: 0.4), value: step)
                .ignoresSafeArea()

            // 2 — Pulsing ripple at spotlight centre
            rippleView
                .animation(.easeInOut(duration: 0.4), value: step)

            // 3 — Bouncing arrow pointing into the spotlight
            arrowView
                .animation(.easeInOut(duration: 0.4), value: step)

            // 4 — Instruction card anchored to bottom
            instructionCard
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)

            // 5 — Skip — top right
            VStack {
                HStack {
                    Spacer()
                    Button(action: finish) {
                        Text("Skip")
                            .font(EgyptFont.body(13))
                            .foregroundStyle(Color.papyrus.opacity(0.50))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.30))
                            )
                    }
                }
                .padding(.top, 58)
                .padding(.trailing, 16)
                Spacer()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startRipple()
            startArrowBounce()
            observedGlyph    = gameState.selectedGlyph
            observedGridHash = gridHash()
        }
        // Auto-advance Step 1 → 2 when a glyph is selected
        .onChange(of: gameState.selectedGlyph) { _, glyph in
            if step == .palette, glyph != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.35)) { step = .grid }
                }
            }
        }
        // Auto-advance Step 2 → 3 when a cell is filled
        .onChange(of: gameState.playerGrid) { _, _ in
            if step == .grid {
                let newHash = gridHash()
                if newHash != observedGridHash {
                    observedGridHash = newHash
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.35)) { step = .decipher }
                    }
                }
            }
        }
    }

    // MARK: - Ripple

    private var rippleView: some View {
        let cx = spotlightFrame.midX
        let cy = spotlightFrame.midY
        let radius = min(spotlightFrame.width, spotlightFrame.height) * 0.38

        return ZStack {
            Circle()
                .stroke(Color.goldBright.opacity(rippleOpacity1), lineWidth: 2.5)
                .frame(width: radius * 2, height: radius * 2)
                .scaleEffect(rippleScale1)
            Circle()
                .stroke(Color.goldBright.opacity(rippleOpacity2), lineWidth: 1.5)
                .frame(width: radius * 2, height: radius * 2)
                .scaleEffect(rippleScale2)
            // Static centre dot
            Circle()
                .fill(Color.goldBright.opacity(0.55))
                .frame(width: 10, height: 10)
        }
        .position(x: cx, y: cy)
        .allowsHitTesting(false)
    }

    private func startRipple() {
        // Ring 1
        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
            rippleScale1   = 1.9
            rippleOpacity1 = 0
        }
        // Ring 2 — delayed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                rippleScale2   = 1.9
                rippleOpacity2 = 0
            }
        }
    }

    // MARK: - Arrow

    private var arrowView: some View {
        // Place arrow just below the spotlight, centred on it
        let cx = spotlightFrame.midX
        let arrowTop = spotlightFrame.maxY + 6

        return VStack(spacing: -4) {
            Image(systemName: "chevron.up")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.goldBright)
                .opacity(0.9)
            Image(systemName: "chevron.up")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.goldBright)
                .opacity(0.55)
            Image(systemName: "chevron.up")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.goldBright)
                .opacity(0.25)
        }
        .offset(y: arrowBounce)
        .position(x: cx, y: arrowTop + 42)
        .allowsHitTesting(false)
    }

    private func startArrowBounce() {
        withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
            arrowBounce = -8
        }
    }

    // MARK: - Instruction Card

    private var stepTitle: String {
        switch step {
        case .palette:  return "1. Select a hieroglyph"
        case .grid:     return "2. Place it in an empty cell"
        case .decipher: return "3. Decipher when you're ready"
        }
    }

    private var stepBody: String {
        switch step {
        case .palette:
            return "Tap any glyph below — watch it highlight. Each symbol must appear exactly once per row and column."
        case .grid:
            return "Tap any empty cell on the grid to place your selected glyph. Tap another empty cell to move it."
        case .decipher:
            return "When every cell is filled, tap Decipher. Wrong cells flash red — the correct answer is never given. Logic alone will solve it."
        }
    }

    private var instructionCard: some View {
        HStack(alignment: .top, spacing: 14) {
            // Step icon
            ZStack {
                Circle()
                    .fill(Color.goldMid.opacity(0.20))
                    .frame(width: 40, height: 40)
                Text("\(step.rawValue + 1)")
                    .font(EgyptFont.titleBold(18))
                    .foregroundStyle(Color.goldBright)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(stepTitle)
                    .font(EgyptFont.titleBold(16))
                    .foregroundStyle(Color.goldBright)

                Text(stepBody)
                    .font(EgyptFont.bodyItalic(14))
                    .foregroundStyle(Color.papyrus.opacity(0.85))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Step dots
                HStack(spacing: 5) {
                    ForEach(NudgeStep.allCases, id: \.rawValue) { s in
                        Circle()
                            .fill(s.rawValue <= step.rawValue
                                  ? Color.goldBright
                                  : Color.goldDark.opacity(0.30))
                            .frame(width: 6, height: 6)
                    }
                    Spacer()
                    if step == .decipher {
                        Button(action: finish) {
                            Text("Got it")
                                .font(EgyptFont.titleBold(14))
                                .foregroundStyle(Color.stoneDark)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(Color.goldMid)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.06, green: 0.04, blue: 0.01).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.goldDark.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.60), radius: 18, x: 0, y: 4)
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

// MARK: - Spotlight Overlay

private struct SpotlightOverlay: View {
    let rect: CGRect

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(.black.opacity(0.68)))
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
