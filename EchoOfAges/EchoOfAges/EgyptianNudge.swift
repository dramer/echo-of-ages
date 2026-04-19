// EgyptianNudge.swift
// EchoOfAges
//
// First-play coach mark overlay shown once on Egyptian Level 1.
// Three steps — palette → grid → decipher — each spotlighting the relevant UI zone.
// After the third step (or if the player taps Skip) the overlay is permanently dismissed.
//
// Usage: overlay EgyptianNudge() on top of GameView's ZStack when shouldShowNudge is true.
// The view dismisses itself by flipping EOA_hasSeenEgyptNudge in UserDefaults.

import SwiftUI

// MARK: - Nudge State

/// Returns true only on the very first time Egyptian Level 1 is opened.
/// Stored in UserDefaults so it fires exactly once, ever.
func shouldShowEgyptNudge() -> Bool {
    !UserDefaults.standard.bool(forKey: "EOA_hasSeenEgyptNudge")
}

func dismissEgyptNudge() {
    UserDefaults.standard.set(true, forKey: "EOA_hasSeenEgyptNudge")
}

// MARK: - Step Model

private enum NudgeStep: Int, CaseIterable {
    case palette   = 0   // spotlight on glyph palette
    case grid      = 1   // spotlight on the game grid
    case decipher  = 2   // spotlight on the Decipher button
}

// MARK: - EgyptianNudge View

struct EgyptianNudge: View {

    @Binding var isVisible: Bool

    @State private var step: NudgeStep = .palette
    @State private var cardOpacity: Double = 0

    // Frame anchors — these are set by GeometryReader anchors in GameView
    // and passed in so the spotlight renders over the right UI region.
    let paletteFrame:  CGRect
    let gridFrame:     CGRect
    let decipherFrame: CGRect

    private var spotlightFrame: CGRect {
        let padding: CGFloat = 12
        let f: CGRect
        switch step {
        case .palette:  f = paletteFrame
        case .grid:     f = gridFrame
        case .decipher: f = decipherFrame
        }
        return f.insetBy(dx: -padding, dy: -padding)
    }

    private var stepTitle: String {
        switch step {
        case .palette:  return "Select a hieroglyph"
        case .grid:     return "Place it on the grid"
        case .decipher: return "Decipher when ready"
        }
    }

    private var stepBody: String {
        switch step {
        case .palette:
            return "Tap any glyph from the palette below to arm it. The selected glyph is highlighted."
        case .grid:
            return "Tap any empty cell to place your glyph. Each symbol appears exactly once in every row and column — logic alone will solve it."
        case .decipher:
            return "When every cell is filled, tap Decipher. Wrong cells flash red. The correct answer is never shown — you must find it yourself."
        }
    }

    private var isLastStep: Bool { step == .decipher }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dim layer with spotlight cutout
                SpotlightOverlay(rect: spotlightFrame, screenSize: geo.size)
                    .animation(.easeInOut(duration: 0.35), value: step)

                // Instruction card — positioned above or below the spotlight
                instructionCard(screenSize: geo.size)
                    .opacity(cardOpacity)
                    .animation(.easeInOut(duration: 0.25), value: step)

                // Skip button — top right
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            finish()
                        } label: {
                            Text("Skip")
                                .font(EgyptFont.body(14))
                                .foregroundStyle(Color.papyrus.opacity(0.55))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 56)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) { cardOpacity = 1 }
        }
        .ignoresSafeArea()
    }

    // MARK: - Instruction Card

    private func instructionCard(screenSize: CGSize) -> some View {
        let sf = spotlightFrame
        let cardHeight: CGFloat = 170
        let padding: CGFloat = 24
        let spaceBelow = screenSize.height - sf.maxY - padding
        let placeBelow = spaceBelow >= cardHeight

        let cardY: CGFloat = placeBelow
            ? sf.maxY + padding
            : sf.minY - cardHeight - padding

        return VStack(alignment: .leading, spacing: 10) {
            // Step indicator dots
            HStack(spacing: 6) {
                ForEach(NudgeStep.allCases, id: \.rawValue) { s in
                    Circle()
                        .fill(s == step ? Color.goldBright : Color.goldDark.opacity(0.35))
                        .frame(width: 7, height: 7)
                }
                Spacer()
                Text("\(step.rawValue + 1) of \(NudgeStep.allCases.count)")
                    .font(EgyptFont.body(12))
                    .foregroundStyle(Color.papyrus.opacity(0.45))
            }

            Text(stepTitle)
                .font(EgyptFont.titleBold(18))
                .foregroundStyle(Color.goldBright)

            Text(stepBody)
                .font(EgyptFont.bodyItalic(15))
                .foregroundStyle(Color.papyrus.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 6)

            // Next / Got it button
            Button(action: advance) {
                Text(isLastStep ? "Got it" : "Next →")
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(Color.stoneDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.goldMid)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.08, green: 0.05, blue: 0.02).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.goldDark.opacity(0.50), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.55), radius: 16, x: 0, y: 4)
        .padding(.horizontal, 24)
        .frame(maxWidth: 500)
        .position(x: screenSize.width / 2, y: cardY + cardHeight / 2)
    }

    // MARK: - Actions

    private func advance() {
        if isLastStep {
            finish()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                step = NudgeStep(rawValue: step.rawValue + 1) ?? .decipher
            }
        }
    }

    private func finish() {
        withAnimation(.easeOut(duration: 0.3)) { cardOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismissEgyptNudge()
            isVisible = false
        }
    }
}

// MARK: - Spotlight Overlay

/// Full-screen dark overlay with a rounded-rect hole cut out over `rect`.
private struct SpotlightOverlay: View {
    let rect: CGRect
    let screenSize: CGSize

    var body: some View {
        Canvas { ctx, size in
            // Draw full-screen dark rectangle
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.72))
            )
            // Cut out the spotlight — subtract the rect using blendMode
            var spotlight = Path()
            spotlight.addRoundedRect(
                in: rect,
                cornerRadii: .init(topLeading: 12, bottomLeading: 12,
                                   bottomTrailing: 12, topTrailing: 12)
            )
            ctx.blendMode = .destinationOut
            ctx.fill(spotlight, with: .color(.black))
        }
        .compositingGroup()             // required for destinationOut to work
        .allowsHitTesting(false)        // spotlight region is still tappable
    }
}
