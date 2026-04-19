// MayanWheelView.swift
// EchoOfAges
//
// Rotating wheel puzzle view for Maya levels 2–5.
//
// Level 2 (independent mode): outer ring and inner ring rotate in opposite
// directions independently. Each ring pauses when a non-anchor reaches 12 o'clock.
//
// Level 4 (synchronized mode, usesSynchronizedRotation = true):
//   • Inner ring spins continuously, one step every ~1 second.
//   • Outer ring advances one step each time the inner ring completes a full loop.
//   • When inner.currentStep == outer.currentStep ("sync"), both 12 o'clock cells
//     glow gold. Inner ring always shows the yellow fill-indicator for blank cells.
//     Outer ring additionally shows the fill-indicator only during sync.
//   • At sync, if any cell is blank the inner ring pauses so the player can fill.
//     After both cells are satisfied the inner ring resumes.
//
// Center symbol cycles through all 5 glyphs; palette items are only tappable
// when the center matches them. Fill blanks by arming a palette symbol then
// tapping the glowing circle at 12 o'clock.
// Decipher checks all fills at once — no immediate error feedback.

import SwiftUI
import Combine

// MARK: - Ring State

/// Tracks the current rotation and step cursor for one ring.
private class RingState: ObservableObject {
    @Published var rotationDeg: Double = 0.0
    @Published var currentStep: Int = 0      // which position is at 12 o'clock
    @Published var isPaused: Bool = false    // waiting for player to fill/replace
    var isAnimating: Bool = false            // mid-step animation guard
    var pauseID: Int = 0                     // incremented each pause; used to cancel stale auto-resume timers
}

// MARK: - MayanWheelView

struct MayanWheelView: View {
    @EnvironmentObject var gameState: GameState

    // Ring states — outer = index 0, inner = index 1
    @StateObject private var outerRing = RingState()
    @StateObject private var innerRing = RingState()

    // Synchronized-mode highlight (Level 4): true when inner.currentStep == outer.currentStep
    @State private var isSynced: Bool = false

    // Center cycling glyph
    @State private var centerGlyphIndex: Int = 0
    @State private var centerGlyphVisible: Bool = true
    // No fixed timer — center uses a self-scheduling function so the delay
    // can vary: 1.5 s while rings are moving, 3.5 s while a ring is paused.

    // Completion overlay
    @State private var showComplete: Bool = false
    @State private var messageRevealed: Bool = false

    // Help overlay
    @State private var showHelp: Bool = false

    // Jade green matching MayanGameView
    private var jadeColor: Color { Color(red: 0.18, green: 0.72, blue: 0.42) }

    private var level: MayanLevel { gameState.mayanCurrentLevel }

    private var outerCycle: MayanCycle { level.cycles[0] }
    private var innerCycle: MayanCycle { level.cycles[1] }

    // stepDeg — angular degrees per one position advance
    private var stepDeg: Double { 360.0 / Double(level.sequenceLength) }

    // The glyph currently shown in the center
    private var centerGlyph: MayanGlyph { MayanGlyph.allCases[centerGlyphIndex % MayanGlyph.allCases.count] }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                jungleBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar
                    mainContent(geo: geo)
                }

                if showComplete {
                    Color.black.opacity(0.55).ignoresSafeArea()
                        .transition(.opacity).zIndex(9)
                    levelCompleteCard(maxHeight: geo.size.height * 0.88)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                        .zIndex(10)
                }

                if showHelp {
                    Color.black.opacity(0.50).ignoresSafeArea()
                        .onTapGesture { withAnimation { showHelp = false } }
                        .transition(.opacity).zIndex(11)
                    mayanWheelHelpDialog
                        .transition(.scale(scale: 0.93).combined(with: .opacity))
                        .zIndex(12)
                }
            }
        }
        .onAppear {
            startBothRings()
            scheduleCenterAdvance()
        }
        .onChange(of: gameState.mayanPendingComplete) { _, newVal in
            if newVal {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    showComplete = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    withAnimation(.easeOut(duration: 0.6)) { messageRevealed = true }
                }
            }
        }
        .onDisappear {
            showComplete = false
            messageRevealed = false
        }
    }

    // MARK: - Layout Branches

    @ViewBuilder
    private func mainContent(geo: GeometryProxy) -> some View {
        if geo.size.width > geo.size.height && UIDevice.current.userInterfaceIdiom == .pad {
            landscapeContent(geo)
        } else {
            portraitContent(geo)
        }
    }

    private func portraitContent(_ geo: GeometryProxy) -> some View {
        let cSize = wheelCanvasSize(geo: geo, isLandscape: false)
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                levelHeader
                wheelCanvas(cSize)
                paletteRow
                actionRow
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private func landscapeContent(_ geo: GeometryProxy) -> some View {
        let cSize = wheelCanvasSize(geo: geo, isLandscape: true)
        return HStack(alignment: .top, spacing: 0) {
            // Left column: wheel only, vertically centred in available height
            wheelCanvas(cSize)
                .frame(maxHeight: .infinity, alignment: .center)

            // Right column: compact scrollable controls
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    levelHeader
                    paletteRow
                    actionRow
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func wheelCanvasSize(geo: GeometryProxy, isLandscape: Bool) -> CGFloat {
        if isLandscape {
            // Wheel shares the left half; must also fit within the available height
            let leftColW = geo.size.width * 0.50 - 64   // padding on left col
            let availH   = geo.size.height - 36          // top/bottom breathing room
            return min(leftColW, availH, 600)
        } else {
            return min(geo.size.width - 64, 640)
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Button {
                HapticFeedback.tap()
                gameState.closeMayanGame()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Return")
                        .font(EgyptFont.titleBold(15))
                }
                .foregroundStyle(jadeColor)
            }
            .frame(minWidth: 80, alignment: .leading)

            Spacer()

            Text("🌿  Maya")
                .font(EgyptFont.titleBold(16))
                .foregroundStyle(jadeColor)
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            HStack(spacing: 10) {
                Text(level.romanNumeral)
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(jadeColor.opacity(0.75))
                Button { withAnimation { showHelp = true } } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(jadeColor)
                }
                .buttonStyle(.plain)
            }
            .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(red: 0.06, green: 0.12, blue: 0.08)
                .overlay(
                    Rectangle()
                        .fill(jadeColor.opacity(0.3))
                        .frame(height: 0.8),
                    alignment: .bottom
                )
        )
    }

    // MARK: - Level Header

    private var levelHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(level.title)
                .font(EgyptFont.titleBold(20))
                .foregroundStyle(jadeColor)
            Text(level.subtitle)
                .font(EgyptFont.bodyItalic(14))
                .foregroundStyle(jadeColor.opacity(0.65))
            Text(level.lore)
                .font(EgyptFont.body(13))
                .foregroundStyle(Color.papyrus.opacity(0.80))
                .lineSpacing(3)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.14, blue: 0.10).opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(jadeColor.opacity(0.25), lineWidth: 0.8))
        )
    }

    // MARK: - Wheel Canvas

    private func wheelCanvas(_ canvasSize: CGFloat) -> some View {
        let outerRadius   = canvasSize * 0.4375
        let innerRadius   = canvasSize * 0.256
        let cellSize      = canvasSize * 0.106
        let centerRadius  = canvasSize * 0.1125

        return VStack(spacing: 12) {
            ZStack {
                // Ring tracks
                Circle()
                    .stroke(jadeColor.opacity(0.12), lineWidth: 1)
                    .frame(width: outerRadius * 2, height: outerRadius * 2)
                Circle()
                    .stroke(jadeColor.opacity(0.12), lineWidth: 1)
                    .frame(width: innerRadius * 2, height: innerRadius * 2)

                // 12 o'clock indicator line.
                // Level 4 (sync mode): always extends from center to inner ring;
                // extends further to the outer ring only when the rings are aligned (isSynced).
                // Other levels: always extends from center all the way to the outer ring.
                let seg1H   = innerRadius + cellSize * 0.5 + 6          // center → inner ring
                let seg2H   = outerRadius - innerRadius                  // inner ring → outer ring
                let seg2Off = -((innerRadius + outerRadius) * 0.5 + cellSize * 0.5 + 6)

                Rectangle()                                              // always: center → inner ring
                    .fill(Color.goldBright.opacity(0.60))
                    .frame(width: 1.5, height: seg1H)
                    .offset(y: -(seg1H * 0.5))
                    .allowsHitTesting(false)

                if level.usesSynchronizedRotation {
                    // Extension: inner ring → outer ring, visible only during sync
                    Rectangle()
                        .fill(Color.goldBright.opacity(isSynced ? 0.60 : 0.0))
                        .frame(width: 1.5, height: seg2H)
                        .offset(y: seg2Off)
                        .animation(.easeInOut(duration: 0.35), value: isSynced)
                        .allowsHitTesting(false)
                } else {
                    // Non-sync levels: always show full line to outer ring
                    Rectangle()
                        .fill(Color.goldBright.opacity(0.60))
                        .frame(width: 1.5, height: seg2H)
                        .offset(y: seg2Off)
                        .allowsHitTesting(false)
                }

                outerRingView(radius: outerRadius, cellSize: cellSize)
                innerRingView(radius: innerRadius, cellSize: cellSize)
                centerCircle(radius: centerRadius)
            }
            .frame(width: canvasSize, height: canvasSize)

            HStack(spacing: 28) {
                ringLabel(outerCycle.label, color: jadeColor)
                ringLabel(innerCycle.label, color: jadeColor.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.05, green: 0.10, blue: 0.07))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(jadeColor.opacity(0.20), lineWidth: 0.8))
        )
    }

    // MARK: - Outer Ring View

    private func outerRingView(radius: CGFloat, cellSize: CGFloat) -> some View {
        let n = level.sequenceLength
        // ZStack rotates so that outerRing.rotationDeg < 0 advances cells clockwise past 12 o'clock.
        // Each advance: outerDeg -= stepDeg (rotate ZStack CCW = content moves CW)
        return ZStack {
            ForEach(0..<n, id: \.self) { i in
                let angle = Double(i) * 2.0 * .pi / Double(n)
                let x = radius * CGFloat(sin(angle))
                let y = -radius * CGFloat(cos(angle))
                // position in the cycle currently at this slot
                let seqPos = (i + outerRing.currentStep) % n
                outerCell(seqPos: seqPos, slotIndex: i, size: cellSize)
                    .offset(x: x, y: y)
                    // Counter-rotate each cell to keep it upright
                    .rotationEffect(.degrees(-outerRing.rotationDeg))
            }
        }
        .rotationEffect(.degrees(outerRing.rotationDeg))
        .animation(.easeInOut(duration: 0.85), value: outerRing.rotationDeg)
    }

    // MARK: - Inner Ring View

    private func innerRingView(radius: CGFloat, cellSize: CGFloat) -> some View {
        let n = level.sequenceLength
        // ZStack rotates so that innerRing.rotationDeg > 0 advances cells counter-clockwise past 12 o'clock.
        // Each advance: innerDeg += stepDeg (rotate ZStack CW = content moves CCW)
        return ZStack {
            ForEach(0..<n, id: \.self) { i in
                let angle = Double(i) * 2.0 * .pi / Double(n)
                let x = radius * CGFloat(sin(angle))
                let y = -radius * CGFloat(cos(angle))
                let seqPos = (i + innerRing.currentStep) % n
                innerCell(seqPos: seqPos, slotIndex: i, size: cellSize)
                    .offset(x: x, y: y)
                    .rotationEffect(.degrees(-innerRing.rotationDeg))
            }
        }
        .rotationEffect(.degrees(innerRing.rotationDeg))
        .animation(.easeInOut(duration: 0.85), value: innerRing.rotationDeg)
    }

    // MARK: - Outer Cell

    @ViewBuilder
    private func outerCell(seqPos: Int, slotIndex: Int, size: CGFloat) -> some View {
        let cycleIdx = 0
        let isAtTop  = slotIndex == 0    // slot 0 is at 12 o'clock
        outerRingCell(cycleIdx: cycleIdx, seqPos: seqPos, isAtTop: isAtTop, size: size)
    }

    @ViewBuilder
    private func outerRingCell(cycleIdx: Int, seqPos: Int, isAtTop: Bool, size: CGFloat) -> some View {
        let cycle      = level.cycles[cycleIdx]
        let isRevealed = cycle.isRevealed(seqPos)
        let correct    = cycle.symbol(at: seqPos)
        let playerVal: MayanGlyph? = {
            guard gameState.mayanPlayerGrid.indices.contains(cycleIdx),
                  gameState.mayanPlayerGrid[cycleIdx].indices.contains(seqPos)
            else { return nil }
            return gameState.mayanPlayerGrid[cycleIdx][seqPos]
        }()
        let coord   = MayanCellCoord(cycle: cycleIdx, position: seqPos)
        let isError = gameState.mayanErrorCells.contains(coord)
        let displayGlyph: MayanGlyph? = isRevealed ? correct : playerVal

        // In sync mode: outer is tappable only when inner is paused at the same position (sync).
        // In normal mode: outer is tappable when the outer ring itself is paused at a non-anchor.
        let isPausedAtTop: Bool = {
            guard isAtTop && !isRevealed else { return false }
            if level.usesSynchronizedRotation {
                return isSynced && innerRing.isPaused
            } else {
                return outerRing.isPaused
            }
        }()
        let isBlankAtTop       = isPausedAtTop && playerVal == nil
        let isReplaceableAtTop = isPausedAtTop && playerVal != nil
        let isFilled           = !isRevealed && playerVal != nil
        // Sync glow: golden highlight on the 12 o'clock cell whenever rings are aligned
        let isSyncTop          = level.usesSynchronizedRotation && isAtTop && isSynced

        wheelCell(
            displayGlyph: displayGlyph,
            isRevealed: isRevealed,
            isError: isError,
            isBlankAtTop: isBlankAtTop,
            isReplaceableAtTop: isReplaceableAtTop,
            isFilled: isFilled,
            isSyncTop: isSyncTop,
            size: size
        ) {
            // Level 4: tapping a red cell that is NOT yet at 12 o'clock rotates it there.
            if level.usesSynchronizedRotation && isError && !isAtTop {
                guard !innerRing.isAnimating, !outerRing.isAnimating else { return }
                HapticFeedback.tap()
                rotateToSyncPosition(seqPos)
                return
            }
            guard isPausedAtTop, let armed = gameState.mayanArmedGlyph else { return }
            HapticFeedback.tap()
            gameState.placeMayanGlyph(armed, at: coord)
            gameState.mayanArmedGlyph = nil
            if level.usesSynchronizedRotation {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    resumeInnerSyncedIfReady()
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    outerRing.isPaused = false
                    advanceRing(outerRing, direction: -1)
                }
            }
        }
    }

    // MARK: - Inner Cell

    @ViewBuilder
    private func innerCell(seqPos: Int, slotIndex: Int, size: CGFloat) -> some View {
        let cycleIdx = 1
        let isAtTop  = slotIndex == 0
        innerRingCell(cycleIdx: cycleIdx, seqPos: seqPos, isAtTop: isAtTop, size: size)
    }

    @ViewBuilder
    private func innerRingCell(cycleIdx: Int, seqPos: Int, isAtTop: Bool, size: CGFloat) -> some View {
        let cycle      = level.cycles[cycleIdx]
        let isRevealed = cycle.isRevealed(seqPos)
        let correct    = cycle.symbol(at: seqPos)
        let playerVal: MayanGlyph? = {
            guard gameState.mayanPlayerGrid.indices.contains(cycleIdx),
                  gameState.mayanPlayerGrid[cycleIdx].indices.contains(seqPos)
            else { return nil }
            return gameState.mayanPlayerGrid[cycleIdx][seqPos]
        }()
        let coord   = MayanCellCoord(cycle: cycleIdx, position: seqPos)
        let isError = gameState.mayanErrorCells.contains(coord)
        let displayGlyph: MayanGlyph? = isRevealed ? correct : playerVal

        let isPausedAtTop      = isAtTop && !isRevealed && innerRing.isPaused
        let isBlankAtTop       = isPausedAtTop && playerVal == nil
        let isReplaceableAtTop = isPausedAtTop && playerVal != nil
        let isFilled           = !isRevealed && playerVal != nil
        // Sync glow: golden highlight on the 12 o'clock cell whenever rings are aligned
        let isSyncTop          = level.usesSynchronizedRotation && isAtTop && isSynced

        wheelCell(
            displayGlyph: displayGlyph,
            isRevealed: isRevealed,
            isError: isError,
            isBlankAtTop: isBlankAtTop,
            isReplaceableAtTop: isReplaceableAtTop,
            isFilled: isFilled,
            isSyncTop: isSyncTop,
            size: size
        ) {
            // Level 4: tapping a red cell that is NOT yet at 12 o'clock rotates it there.
            if level.usesSynchronizedRotation && isError && !isAtTop {
                guard !innerRing.isAnimating, !outerRing.isAnimating else { return }
                HapticFeedback.tap()
                rotateToSyncPosition(seqPos)
                return
            }
            guard isPausedAtTop, let armed = gameState.mayanArmedGlyph else { return }
            HapticFeedback.tap()
            gameState.placeMayanGlyph(armed, at: coord)
            gameState.mayanArmedGlyph = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if level.usesSynchronizedRotation {
                    resumeInnerSyncedIfReady()
                } else {
                    innerRing.isPaused = false
                    advanceRing(innerRing, direction: +1)
                }
            }
        }
    }

    // MARK: - Shared Cell Renderer

    @ViewBuilder
    private func wheelCell(
        displayGlyph: MayanGlyph?,
        isRevealed: Bool,
        isError: Bool,
        isBlankAtTop: Bool,
        isReplaceableAtTop: Bool,
        isFilled: Bool,
        isSyncTop: Bool,
        size: CGFloat,
        onTap: @escaping () -> Void
    ) -> some View {
        let isInteractiveTop = isBlankAtTop || isReplaceableAtTop
        let fillColor: Color = {
            if isError             { return Color(red: 0.55, green: 0.06, blue: 0.06).opacity(0.85) }
            if isSyncTop           { return Color(red: 0.80, green: 0.60, blue: 0.10).opacity(0.15) }
            if isRevealed          { return jadeColor.opacity(0.25) }
            if isFilled            { return Color.white.opacity(0.10) }
            if isBlankAtTop        { return Color.clear }
            return Color.white.opacity(0.05)
        }()
        let strokeColor: Color = {
            if isError             { return Color.red.opacity(0.75) }
            if isInteractiveTop    { return Color.goldBright.opacity(0.85) }
            if isSyncTop           { return Color.goldBright.opacity(0.70) }
            if isRevealed          { return jadeColor.opacity(0.50) }
            return jadeColor.opacity(0.20)
        }()
        let strokeWidth: CGFloat = (isInteractiveTop || isSyncTop) ? 1.8 : 0.8
        return ZStack {
            // Background circle
            Circle()
                .fill(fillColor)
                .overlay(
                    Circle()
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )

            // Sync glow ring — golden pulse when outer and inner are aligned at 12 o'clock
            if isSyncTop && !isInteractiveTop {
                Circle()
                    .fill(Color.goldBright.opacity(0.12))
                    .scaleEffect(1.25)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: isSyncTop
                    )
            }

            // Pulsing glow for blank at 12 o'clock — show + icon
            if isBlankAtTop {
                Circle()
                    .fill(Color.goldBright.opacity(0.18))
                    .scaleEffect(1.2)
                    .animation(
                        .easeInOut(duration: 0.85).repeatForever(autoreverses: true),
                        value: isBlankAtTop
                    )
                Image(systemName: "plus.circle")
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(Color.goldBright.opacity(0.80))
            } else if isReplaceableAtTop, let glyph = displayGlyph {
                // Filled cell at top — show glyph with gold tint to signal replaceability
                Image(systemName: glyph.sfSymbol)
                    .font(.system(size: size * 0.44))
                    .foregroundStyle(Color.goldBright.opacity(0.90))
            } else if let glyph = displayGlyph {
                Image(systemName: glyph.sfSymbol)
                    .font(.system(size: size * 0.44))
                    .foregroundStyle(isRevealed ? jadeColor : Color.white)
            }
        }
        .frame(width: size, height: size)
        .onTapGesture {
            onTap()
        }
    }

    // MARK: - Center Circle

    private func centerCircle(radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        jadeColor.opacity(0.18),
                        Color(red: 0.04, green: 0.08, blue: 0.05)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius
                ))
                .frame(width: radius * 2, height: radius * 2)

            Circle()
                .stroke(Color.goldBright.opacity(0.55), lineWidth: 1.2)
                .frame(width: radius * 2, height: radius * 2)

            if centerGlyphVisible {
                Image(systemName: centerGlyph.sfSymbol)
                    .font(.system(size: radius * 0.80))
                    .foregroundStyle(Color.goldBright)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: centerGlyphIndex)
    }

    // MARK: - Palette Row

    private var paletteRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ARM A SYMBOL")
                .font(EgyptFont.title(11))
                .foregroundStyle(jadeColor.opacity(0.55))
                .tracking(2)

            HStack(spacing: 8) {
                ForEach(MayanGlyph.allCases) { glyph in
                    let isActive  = level.usesSynchronizedRotation ? true : glyph == centerGlyph
                    let isArmed   = gameState.mayanArmedGlyph == glyph

                    Button(action: {
                        HapticFeedback.tap()
                        gameState.mayanArmedGlyph = isArmed ? nil : glyph
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: glyph.sfSymbol)
                                .font(.system(size: 20))
                                .foregroundStyle(isActive
                                    ? (isArmed ? Color.goldBright : Color.white)
                                    : Color.white.opacity(0.22))

                            Text(glyph.displayName)
                                .font(EgyptFont.body(9))
                                .foregroundStyle(isActive
                                    ? jadeColor.opacity(0.85)
                                    : jadeColor.opacity(0.22))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isArmed
                                    ? jadeColor.opacity(0.30)
                                    : isActive
                                        ? Color.white.opacity(0.08)
                                        : Color.white.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isArmed
                                            ? Color.goldBright.opacity(0.85)
                                            : isActive
                                                ? jadeColor.opacity(0.45)
                                                : jadeColor.opacity(0.12),
                                                lineWidth: isArmed ? 1.6 : 0.7)
                                )
                        )
                        .opacity(isActive ? 1.0 : 0.45)
                        .animation(.easeInOut(duration: 0.2), value: isActive)
                        .animation(.easeInOut(duration: 0.15), value: isArmed)
                    }
                    .disabled(!isActive)
                }
            }

            if level.usesSynchronizedRotation {
                Text("Select any symbol to place when the rings align at 12 o'clock.")
                    .font(EgyptFont.bodyItalic(11))
                    .foregroundStyle(jadeColor.opacity(0.38))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("Only the symbol matching the centre circle is available.")
                    .font(EgyptFont.bodyItalic(11))
                    .foregroundStyle(jadeColor.opacity(0.38))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.05, green: 0.10, blue: 0.07))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(jadeColor.opacity(0.20), lineWidth: 0.8))
        )
    }

    // MARK: - Action Row

    private var actionRow: some View {
        let canDecipher = level.isFullyFilled(gameState.mayanPlayerGrid)
        return HStack(spacing: 12) {
            Button(action: {
                HapticFeedback.tap()
                gameState.resetMayanGrid()
                outerRing.rotationDeg = 0
                outerRing.currentStep = 0
                outerRing.isPaused    = false
                outerRing.isAnimating = false
                innerRing.rotationDeg = 0
                innerRing.currentStep = 0
                innerRing.isPaused    = false
                innerRing.isAnimating = false
                isSynced = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { startBothRings() }
            }) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(jadeColor.opacity(0.80))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.white.opacity(0.04))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(jadeColor.opacity(0.25), lineWidth: 1))
                    )
            }

            Button(action: {
                HapticFeedback.tap()
                gameState.verifyMayanPlacement()
            }) {
                Label("Decipher", systemImage: "checkmark.seal")
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(canDecipher
                                     ? Color(red: 0.06, green: 0.12, blue: 0.08)
                                     : jadeColor.opacity(0.40))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(canDecipher ? jadeColor : jadeColor.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(jadeColor.opacity(canDecipher ? 0.6 : 0.20), lineWidth: 1))
                    )
            }
            .disabled(!canDecipher)
        }
    }

    // MARK: - Level Complete Card

    private func levelCompleteCard(maxHeight: CGFloat) -> some View {
        let isLastLevel = gameState.mayanCurrentLevelIndex == MayanLevel.allLevels.count - 1
        let newCivs     = isLastLevel ? gameState.newlyUnlockedCivs(completingLevel5Of: .maya) : []

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer(minLength: 20)

                Image(systemName: level.artifact)
                    .font(.system(size: 60))
                    .foregroundStyle(jadeColor)
                    .shadow(color: jadeColor.opacity(0.7), radius: 12, x: 0, y: 0)

                VStack(spacing: 8) {
                    Text("Calendar Decoded")
                        .font(EgyptFont.titleBold(26))
                        .foregroundStyle(jadeColor)
                        .tracking(2)
                    Text(level.journalTitle)
                        .font(EgyptFont.bodyItalic(17))
                        .foregroundStyle(Color.papyrus)
                }

                if messageRevealed {
                    Text(level.decodedMessage)
                        .font(EgyptFont.bodyItalic(15))
                        .foregroundStyle(Color.papyrus.opacity(0.85))
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .transition(.opacity)

                    HStack(spacing: 8) {
                        Image(systemName: "book.fill").font(.system(size: 11))
                            .foregroundStyle(jadeColor.opacity(0.60))
                        Text("A new entry has been written in your Field Diary.")
                            .font(EgyptFont.bodyItalic(13))
                            .foregroundStyle(jadeColor.opacity(0.60))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .transition(.opacity)

                    if isLastLevel {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "key.fill").font(.system(size: 12))
                                    .foregroundStyle(jadeColor)
                                Text("The Maya key has been carved in your Field Diary.")
                                    .font(EgyptFont.bodyItalic(13))
                                    .foregroundStyle(jadeColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if !newCivs.isEmpty {
                                Text("NEW PATHS OPEN")
                                    .font(EgyptFont.title(11))
                                    .foregroundStyle(jadeColor.opacity(0.55))
                                    .tracking(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(newCivs) { civ in
                                    HStack(spacing: 12) {
                                        Text(civ.emblem).font(.system(size: 24))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(civ.name).font(EgyptFont.titleBold(14))
                                                .foregroundStyle(civ.accentColor)
                                            Text(civ.era).font(EgyptFont.bodyItalic(12))
                                                .foregroundStyle(Color.papyrus.opacity(0.55))
                                        }
                                        Spacer()
                                        Image(systemName: "lock.open.fill").font(.system(size: 12))
                                            .foregroundStyle(Color.goldMid)
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(red: 0.05, green: 0.10, blue: 0.07).opacity(0.8))
                                            .overlay(RoundedRectangle(cornerRadius: 8)
                                                .stroke(civ.accentColor.opacity(0.35), lineWidth: 1))
                                    )
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.04, green: 0.09, blue: 0.06).opacity(0.8))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(jadeColor.opacity(0.30), lineWidth: 1))
                        )
                        .transition(.opacity)
                    }
                }

                VStack(spacing: 10) {
                    if isLastLevel && gameState.allSixCivsComplete {
                        Button {
                            HapticFeedback.heavy()
                            gameState.mayanPendingComplete = false
                            withAnimation(.easeInOut(duration: 0.4)) { gameState.openManduTablet() }
                        } label: {
                            StoneButton(title: "Open the Mandu Tablet", icon: "seal.fill", style: .gold)
                        }
                    } else if isLastLevel {
                        Button {
                            HapticFeedback.heavy()
                            gameState.mayanPendingComplete = false
                            withAnimation(.easeInOut(duration: 0.4)) { gameState.startNewGame() }
                        } label: {
                            StoneButton(title: "Continue Expedition", icon: "arrow.right", style: .gold)
                        }
                    } else {
                        Button {
                            HapticFeedback.tap()
                            gameState.advanceMayanToNextLevel()
                        } label: {
                            StoneButton(title: "Next Tablet", icon: "arrow.right", style: .gold)
                        }
                    }
                    Button {
                        HapticFeedback.tap()
                        gameState.openJournal()
                    } label: {
                        StoneButton(title: "Open Field Diary", icon: "book.fill", style: .muted)
                    }
                }
                .padding(.horizontal, 8)

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.06, green: 0.12, blue: 0.08))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(jadeColor.opacity(0.5), lineWidth: 1.2))
        )
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
        .padding(.horizontal, 24)
        .frame(maxHeight: maxHeight)
    }

    // MARK: - Help Dialog

    private var mayanWheelHelpDialog: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("🌿  How to Play")
                    .font(EgyptFont.titleBold(20))
                    .foregroundStyle(jadeColor)
                Spacer()
                Button { withAnimation { showHelp = false } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(jadeColor.opacity(0.70))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 14)

            mayanHelpRow(number: "1", title: "Spin the outer wheel",
                         body: "Tap any outer cell to cycle its glyph. Each glyph must appear once in the outer ring.")
            mayanHelpRow(number: "2", title: "Spin the inner wheel",
                         body: "Tap any inner cell to cycle its glyph. Each glyph must appear once in the inner ring.")
            mayanHelpRow(number: "3", title: "Decipher when ready",
                         body: "Tap Decipher when both rings are filled. Wrong cells flash red — use logic to find the correct positions.")

            Button { withAnimation { showHelp = false } } label: {
                Text("Got it")
                    .font(EgyptFont.titleBold(17))
                    .foregroundStyle(Color(red: 0.06, green: 0.12, blue: 0.08))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 10).fill(jadeColor))
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.04, green: 0.08, blue: 0.05))
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .stroke(jadeColor.opacity(0.45), lineWidth: 1.5))
        )
        .padding(.horizontal, 20)
    }

    private func mayanHelpRow(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(EgyptFont.titleBold(16))
                .foregroundStyle(jadeColor)
                .frame(width: 22, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(Color.papyrus)
                Text(body)
                    .font(EgyptFont.body(13))
                    .foregroundStyle(Color.papyrus.opacity(0.75))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Background & Helpers

    private var jungleBackground: some View {
        ZStack {
            Color(red: 0.04, green: 0.08, blue: 0.05)
            RadialGradient(
                colors: [Color(red: 0.10, green: 0.22, blue: 0.12).opacity(0.6), .clear],
                center: .topLeading, startRadius: 60, endRadius: 420
            )
        }
    }

    private func ringLabel(_ text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .stroke(color, lineWidth: 1.0)
                .frame(width: 7, height: 7)
            Text(text)
                .font(EgyptFont.body(11))
                .foregroundStyle(color)
        }
    }

    // MARK: - Center Glyph Cycling

    /// Self-scheduling center advance at a fixed 3.5 s interval.
    /// Rings auto-resume after 15 s, so the player always has time regardless of center speed.
    private func scheduleCenterAdvance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            advanceCenterGlyph()
            scheduleCenterAdvance()
        }
    }

    private func advanceCenterGlyph() {
        withAnimation(.easeInOut(duration: 0.18)) {
            centerGlyphVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            centerGlyphIndex = (centerGlyphIndex + 1) % MayanGlyph.allCases.count
            withAnimation(.easeInOut(duration: 0.18)) {
                centerGlyphVisible = true
            }
        }
    }

    // MARK: - Ring Sequencing

    /// Kick off both rings from their current state.
    private func startBothRings() {
        if level.usesSynchronizedRotation {
            // Sync mode: both rings always start at step 0 — that is always a sync position.
            let step = innerRing.currentStep   // == outerRing.currentStep == 0
            isSynced = true
            handleSyncPosition(at: step)
        } else {
            scheduleNextStep(for: outerRing, direction: -1, delay: 0.0)
            scheduleNextStep(for: innerRing, direction: +1, delay: 0.3)
        }
    }

    /// Schedule one step for a ring after `delay` seconds.
    /// direction: -1 = outer (CCW rotation = CW content), +1 = inner (CW rotation = CCW content)
    private func scheduleNextStep(for ring: RingState, direction: Double, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard !ring.isPaused, !ring.isAnimating else { return }
            advanceRing(ring, direction: direction)
        }
    }

    /// Advance ring by one step, then check if the new 12 o'clock position is a blank.
    private func advanceRing(_ ring: RingState, direction: Double) {
        guard !ring.isAnimating else { return }
        ring.isAnimating = true

        // Apply rotation — animation is driven by SwiftUI via .animation modifier on the ZStack
        ring.rotationDeg += direction * stepDeg

        // After animation completes, update step counter and check for blank
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            ring.isAnimating = false
            // Advance step cursor
            ring.currentStep = (ring.currentStep + 1) % level.sequenceLength

            // Determine which cycle this ring corresponds to and whether the new top is blank
            let cycleIdx = (ring === outerRing) ? 0 : 1
            let stepAtTop = ring.currentStep
            let shouldPause = checkIfBlankAtTop(cycleIdx: cycleIdx, seqPos: stepAtTop)

            if shouldPause {
                ring.isPaused = true
                ring.pauseID += 1
                let capturedPauseID = ring.pauseID
                // Auto-resume after ~1 full center cycle (5 symbols × 3.5 s ≈ 18 s, capped at 15 s).
                // The pauseID check ensures a stale timer from a previous pause won't fire.
                DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
                    guard ring.isPaused, ring.pauseID == capturedPauseID else { return }
                    ring.isPaused = false
                    advanceRing(ring, direction: direction)
                }
            } else {
                // Dwell on the anchor symbol so the player can read it
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    guard !ring.isPaused else { return }
                    advanceRing(ring, direction: direction)
                }
            }
        }
    }

    /// Returns true if the ring should pause at this position.
    /// Pauses at every non-anchor position — whether empty (needs filling)
    /// or filled by the player (can be replaced). Skips anchor positions.
    private func checkIfBlankAtTop(cycleIdx: Int, seqPos: Int) -> Bool {
        guard level.cycles.indices.contains(cycleIdx) else { return false }
        let cycle = level.cycles[cycleIdx]
        return !cycle.isRevealed(seqPos)
    }

    // MARK: - Synchronized Mode Engine (Level 4)

    /// True when a position is either an anchor OR the player has filled it correctly.
    /// An error cell (flagged by Decipher) is treated as unsatisfied so the sync
    /// pause fires there and the player can correct the wrong glyph.
    private func isPositionSatisfied(cycleIdx: Int, seqPos: Int) -> Bool {
        let cycle = level.cycles[cycleIdx]
        if cycle.isRevealed(seqPos) { return true }
        let coord = MayanCellCoord(cycle: cycleIdx, position: seqPos)
        if gameState.mayanErrorCells.contains(coord) { return false }
        guard gameState.mayanPlayerGrid.indices.contains(cycleIdx),
              gameState.mayanPlayerGrid[cycleIdx].indices.contains(seqPos)
        else { return false }
        return gameState.mayanPlayerGrid[cycleIdx][seqPos] != nil
    }

    /// After the player fills a cell in sync mode, resume the inner ring only if
    /// both the inner and outer cells at the current sync position are satisfied.
    /// Inner only pauses at sync positions, so both checks are always applicable.
    private func resumeInnerSyncedIfReady() {
        let step = innerRing.currentStep   // == outerRing.currentStep at a sync pause
        let innerSat = isPositionSatisfied(cycleIdx: 1, seqPos: step)
        let outerSat = isPositionSatisfied(cycleIdx: 0, seqPos: step)
        guard innerSat && outerSat else { return }
        innerRing.isPaused = false
        isSynced = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            advanceInnerRingSynced()
        }
    }

    /// Advance the inner ring by one step in synchronized mode.
    /// Inner always moves direction -1 (same as outer). After each step:
    ///   • If inner completed a full loop, advance the outer ring one step.
    ///   • Check sync (inner.currentStep == outer.currentStep) and update isSynced.
    ///   • Pause inner at non-anchor positions so the player can fill.
    private func advanceInnerRingSynced() {
        guard !innerRing.isAnimating, !innerRing.isPaused else { return }
        innerRing.isAnimating = true
        innerRing.rotationDeg += -1 * stepDeg   // same direction as outer

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            innerRing.isAnimating = false
            innerRing.currentStep = (innerRing.currentStep + 1) % level.sequenceLength
            let innerStep = innerRing.currentStep

            if innerStep == 0 {
                // Inner just completed a full loop → advance the outer ring one step.
                advanceOuterRingSynced {
                    checkSyncAndHandleInner(innerStep: 0)
                }
            } else {
                checkSyncAndHandleInner(innerStep: innerStep)
            }
        }
    }

    /// Animate the outer ring forward one step, then call `completion`.
    private func advanceOuterRingSynced(completion: @escaping () -> Void) {
        guard !outerRing.isAnimating else { return }
        outerRing.isAnimating = true
        outerRing.rotationDeg += -1 * stepDeg

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            outerRing.isAnimating = false
            outerRing.currentStep = (outerRing.currentStep + 1) % level.sequenceLength
            completion()
        }
    }

    /// After an inner ring step completes, determine sync state and whether to pause.
    /// In sync mode the inner ring only ever stops at the alignment position (inner == outer).
    /// Between alignment positions it spins continuously with a minimal dwell (~0.1 s).
    private func checkSyncAndHandleInner(innerStep: Int) {
        let outerStep = outerRing.currentStep
        let synced = (innerStep == outerStep)
        isSynced = synced

        if synced {
            handleSyncPosition(at: innerStep)
        } else {
            // Not aligned — spin through quickly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                guard !innerRing.isPaused else { return }
                advanceInnerRingSynced()
            }
        }
    }

    /// Rotate both rings step-by-step (0.85 s per step) so that `seqPos` arrives at
    /// 12 o'clock on both rings simultaneously, then hand off to handleSyncPosition.
    /// Used when the player taps a red (error) cell that is not yet at the top.
    private func rotateToSyncPosition(_ targetSeqPos: Int) {
        let n = level.sequenceLength
        let outerSteps = (targetSeqPos - outerRing.currentStep + n) % n
        let innerSteps = (targetSeqPos - innerRing.currentStep + n) % n

        // Stop any in-progress rotation
        innerRing.isPaused = true
        innerRing.pauseID += 1
        innerRing.isAnimating = false
        outerRing.isAnimating = false
        isSynced = false

        if outerSteps == 0 && innerSteps == 0 {
            // Already at the target sync position
            isSynced = true
            handleSyncPosition(at: targetSeqPos)
            return
        }

        let capturedID = innerRing.pauseID
        rotateStepByStep(outerRemaining: outerSteps, innerRemaining: innerSteps,
                         targetSeqPos: targetSeqPos, pauseID: capturedID)
    }

    /// Recursive helper that moves both rings one step per call at the normal 0.85 s
    /// animation cadence until both reach targetSeqPos at 12 o'clock.
    private func rotateStepByStep(outerRemaining: Int, innerRemaining: Int,
                                   targetSeqPos: Int, pauseID: Int) {
        guard innerRing.pauseID == pauseID else { return }   // cancelled by newer action

        guard outerRemaining > 0 || innerRemaining > 0 else {
            isSynced = true
            handleSyncPosition(at: targetSeqPos)
            return
        }

        if outerRemaining > 0 {
            outerRing.isAnimating = true
            outerRing.rotationDeg -= stepDeg
        }
        if innerRemaining > 0 {
            innerRing.isAnimating = true
            innerRing.rotationDeg -= stepDeg
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            guard innerRing.pauseID == pauseID else { return }
            if outerRemaining > 0 {
                outerRing.isAnimating = false
                outerRing.currentStep = (outerRing.currentStep + 1) % level.sequenceLength
            }
            if innerRemaining > 0 {
                innerRing.isAnimating = false
                innerRing.currentStep = (innerRing.currentStep + 1) % level.sequenceLength
            }
            rotateStepByStep(outerRemaining: max(0, outerRemaining - 1),
                             innerRemaining: max(0, innerRemaining - 1),
                             targetSeqPos: targetSeqPos,
                             pauseID: pauseID)
        }
    }

    /// Called whenever inner and outer are aligned at a sync position.
    /// Pauses if either cell needs filling; dwells briefly if both are already satisfied.
    private func handleSyncPosition(at step: Int) {
        let outerNeedsFill = !isPositionSatisfied(cycleIdx: 0, seqPos: step)
        let innerNeedsFill = !isPositionSatisfied(cycleIdx: 1, seqPos: step)

        if outerNeedsFill || innerNeedsFill {
            // Pause so the player can fill one or both cells.
            innerRing.isPaused = true
            innerRing.pauseID += 1
            let capturedID = innerRing.pauseID
            DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
                guard innerRing.isPaused, innerRing.pauseID == capturedID else { return }
                innerRing.isPaused = false
                isSynced = false
                advanceInnerRingSynced()
            }
        } else {
            // Both already filled — hold the sync glow long enough for the centre
            // palette to cycle through all 5 symbols twice (5 × 3.5 s × 2 = 35 s),
            // giving the player time to study the aligned pair before the inner ring
            // resumes spinning.  The ring is not paused; it just waits.
            DispatchQueue.main.asyncAfter(deadline: .now() + 35.0) {
                guard !innerRing.isPaused else { return }
                isSynced = false
                advanceInnerRingSynced()
            }
        }
    }
}
