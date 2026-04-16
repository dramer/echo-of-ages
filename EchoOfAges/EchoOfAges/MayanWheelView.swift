// MayanWheelView.swift
// EchoOfAges
//
// Rotating wheel puzzle view for Maya levels 2–5.
// Two concentric rings rotate in opposite directions.
// Outer ring clockwise, inner counter-clockwise.
// Each ring independently pauses when a blank reaches 12 o'clock.
// Center symbol cycles through all 5 glyphs; palette items are only
// tappable when the center matches them. Fill the blank by arming a
// palette symbol then tapping the glowing circle at 12 o'clock.
// Decipher checks all fills at once — no immediate error feedback.

import SwiftUI
import Combine

// MARK: - Ring State

/// Tracks the current rotation and step cursor for one ring.
private class RingState: ObservableObject {
    @Published var rotationDeg: Double = 0.0
    @Published var currentStep: Int = 0      // which position is at 12 o'clock
    @Published var isPaused: Bool = false    // waiting for player to fill blank
    var isAnimating: Bool = false            // mid-step animation guard
}

// MARK: - MayanWheelView

struct MayanWheelView: View {
    @EnvironmentObject var gameState: GameState

    // Ring states — outer = index 0, inner = index 1
    @StateObject private var outerRing = RingState()
    @StateObject private var innerRing = RingState()

    // Center cycling glyph
    @State private var centerGlyphIndex: Int = 0
    @State private var centerGlyphVisible: Bool = true
    // No fixed timer — center uses a self-scheduling function so the delay
    // can vary: 1.5 s while rings are moving, 3.5 s while a ring is paused.

    // Completion overlay
    @State private var showComplete: Bool = false
    @State private var messageRevealed: Bool = false

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
        ZStack {
            jungleBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        levelHeader
                        wheelCanvas
                        paletteRow
                        actionRow
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }

            if showComplete {
                Color.black.opacity(0.55).ignoresSafeArea()
                    .transition(.opacity).zIndex(9)
                levelCompleteCard
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .zIndex(10)
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

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Button(action: { gameState.closeMayanGame() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Journal")
                        .font(EgyptFont.body(17))
                }
                .foregroundStyle(jadeColor)
            }
            Spacer()
            VStack(spacing: 1) {
                Text("MAYA")
                    .font(EgyptFont.titleBold(16))
                    .tracking(3)
                    .foregroundStyle(jadeColor)
                Text("Calendar Puzzles")
                    .font(EgyptFont.body(12))
                    .foregroundStyle(jadeColor.opacity(0.6))
            }
            Spacer()
            Text(level.romanNumeral)
                .font(EgyptFont.titleBold(22))
                .foregroundStyle(jadeColor)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
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

    /// Canvas size adapts to the screen so the wheel fills the available width on every device.
    private var adaptiveCanvasSize: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let available   = screenWidth - 36 - 28  // outer padding (18×2) + inner padding (14×2)
        return min(available, 640)
    }

    private var wheelCanvas: some View {
        let canvasSize    = adaptiveCanvasSize
        let outerRadius   = canvasSize * 0.4375   // matches original 140/320
        let innerRadius   = canvasSize * 0.256    // matches original 82/320
        let cellSize      = canvasSize * 0.106    // matches original 34/320
        let centerRadius  = canvasSize * 0.1125   // matches original 36/320

        return VStack(spacing: 12) {
            ZStack {
                // Ring tracks
                Circle()
                    .stroke(jadeColor.opacity(0.12), lineWidth: 1)
                    .frame(width: outerRadius * 2, height: outerRadius * 2)
                Circle()
                    .stroke(jadeColor.opacity(0.12), lineWidth: 1)
                    .frame(width: innerRadius * 2, height: innerRadius * 2)

                // 12 o'clock indicator — thin vertical gold line
                Rectangle()
                    .fill(Color.goldBright.opacity(0.60))
                    .frame(width: 1.5, height: outerRadius + cellSize * 0.5 + 6)
                    .offset(y: -(outerRadius * 0.5 + cellSize * 0.25 + 3))
                    .allowsHitTesting(false)

                // Outer ring (clockwise) — ZStack rotates counter-clockwise so cells advance CW past 12 o'clock
                outerRingView(radius: outerRadius, cellSize: cellSize)

                // Inner ring (counter-clockwise) — ZStack rotates clockwise so cells advance CCW past 12 o'clock
                innerRingView(radius: innerRadius, cellSize: cellSize)

                // Center cycling symbol
                centerCircle(radius: centerRadius)
            }
            .frame(width: canvasSize, height: canvasSize)

            // Ring labels
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
        .animation(.easeInOut(duration: 0.65), value: outerRing.rotationDeg)
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
        .animation(.easeInOut(duration: 0.65), value: innerRing.rotationDeg)
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

        let isBlankAtTop = isAtTop && !isRevealed && playerVal == nil && outerRing.isPaused
        let isFilled     = !isRevealed && playerVal != nil

        wheelCell(
            displayGlyph: displayGlyph,
            isRevealed: isRevealed,
            isError: isError,
            isBlankAtTop: isBlankAtTop,
            isFilled: isFilled,
            size: size
        ) {
            guard isBlankAtTop, let armed = gameState.mayanArmedGlyph else { return }
            HapticFeedback.tap()
            gameState.placeMayanGlyph(armed, at: coord)
            gameState.mayanArmedGlyph = nil
            // Resume the outer ring after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                outerRing.isPaused = false
                advanceRing(outerRing, direction: -1)
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

        let isBlankAtTop = isAtTop && !isRevealed && playerVal == nil && innerRing.isPaused
        let isFilled     = !isRevealed && playerVal != nil

        wheelCell(
            displayGlyph: displayGlyph,
            isRevealed: isRevealed,
            isError: isError,
            isBlankAtTop: isBlankAtTop,
            isFilled: isFilled,
            size: size
        ) {
            guard isBlankAtTop, let armed = gameState.mayanArmedGlyph else { return }
            HapticFeedback.tap()
            gameState.placeMayanGlyph(armed, at: coord)
            gameState.mayanArmedGlyph = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                innerRing.isPaused = false
                advanceRing(innerRing, direction: +1)
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
        isFilled: Bool,
        size: CGFloat,
        onTap: @escaping () -> Void
    ) -> some View {
        let fillColor: Color = {
            if isError      { return Color(red: 0.55, green: 0.06, blue: 0.06).opacity(0.85) }
            if isRevealed   { return jadeColor.opacity(0.25) }
            if isFilled     { return Color.white.opacity(0.10) }
            if isBlankAtTop { return Color.clear }
            return Color.white.opacity(0.05)
        }()
        let strokeColor: Color = {
            if isError      { return Color.red.opacity(0.75) }
            if isRevealed   { return jadeColor.opacity(0.50) }
            if isBlankAtTop { return Color.goldBright.opacity(0.85) }
            return jadeColor.opacity(0.20)
        }()
        let strokeWidth: CGFloat = isBlankAtTop ? 1.8 : 0.8
        return ZStack {
            // Background circle
            Circle()
                .fill(fillColor)
                .overlay(
                    Circle()
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )

            // Pulsing glow for tappable blank at 12 o'clock
            if isBlankAtTop {
                Circle()
                    .fill(Color.goldBright.opacity(0.18))
                    .scaleEffect(isBlankAtTop ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.85).repeatForever(autoreverses: true),
                        value: isBlankAtTop
                    )
                Image(systemName: "plus.circle")
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(Color.goldBright.opacity(0.80))
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
                    let isActive  = glyph == centerGlyph
                    let isArmed   = gameState.mayanArmedGlyph == glyph

                    Button(action: {
                        guard isActive else { return }
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

            Text("Only the symbol matching the centre circle is available.")
                .font(EgyptFont.bodyItalic(11))
                .foregroundStyle(jadeColor.opacity(0.38))
                .frame(maxWidth: .infinity, alignment: .center)
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
        HStack(spacing: 12) {
            Button(action: {
                HapticFeedback.tap()
                gameState.verifyMayanPlacement()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 15))
                    Text("Decipher").font(EgyptFont.title(15))
                }
                .foregroundStyle(jadeColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(jadeColor.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(jadeColor.opacity(0.45), lineWidth: 1))
                )
            }

            Button(action: {
                HapticFeedback.tap()
                gameState.resetMayanGrid()
                // Reset ring state
                outerRing.rotationDeg = 0
                outerRing.currentStep = 0
                outerRing.isPaused    = false
                outerRing.isAnimating = false
                innerRing.rotationDeg = 0
                innerRing.currentStep = 0
                innerRing.isPaused    = false
                innerRing.isAnimating = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    startBothRings()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 15))
                    Text("Reset").font(EgyptFont.title(15))
                }
                .foregroundStyle(Color(red: 0.75, green: 0.55, blue: 0.35))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.75, green: 0.55, blue: 0.35).opacity(0.35), lineWidth: 1))
                )
            }
        }
    }

    // MARK: - Level Complete Card

    private var levelCompleteCard: some View {
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
        .frame(maxHeight: UIScreen.main.bounds.height * 0.82)
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

    /// True while either ring is paused waiting for the player to fill a blank.
    private var isAnyRingPaused: Bool { outerRing.isPaused || innerRing.isPaused }

    /// Self-scheduling center advance: 1.5 s while rings are moving, 3.5 s while
    /// a ring is paused so the player has time to spot, arm, and place the glyph.
    private func scheduleCenterAdvance() {
        let delay: TimeInterval = isAnyRingPaused ? 3.5 : 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
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
        scheduleNextStep(for: outerRing, direction: -1, delay: 0.0)
        scheduleNextStep(for: innerRing, direction: +1, delay: 0.3)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            ring.isAnimating = false
            // Advance step cursor
            ring.currentStep = (ring.currentStep + 1) % level.sequenceLength

            // Determine which cycle this ring corresponds to and whether the new top is blank
            let cycleIdx = (ring === outerRing) ? 0 : 1
            let stepAtTop = ring.currentStep
            let shouldPause = checkIfBlankAtTop(cycleIdx: cycleIdx, seqPos: stepAtTop)

            if shouldPause {
                ring.isPaused = true
                // Ring stays paused; resumed by tap handler after fill
            } else {
                // Dwell briefly on the anchor symbol, then advance again
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    guard !ring.isPaused else { return }
                    advanceRing(ring, direction: direction)
                }
            }
        }
    }

    /// Returns true if the position `seqPos` for `cycleIdx` is an unfilled blank.
    private func checkIfBlankAtTop(cycleIdx: Int, seqPos: Int) -> Bool {
        guard level.cycles.indices.contains(cycleIdx) else { return false }
        let cycle = level.cycles[cycleIdx]
        if cycle.isRevealed(seqPos) { return false }
        guard gameState.mayanPlayerGrid.indices.contains(cycleIdx),
              gameState.mayanPlayerGrid[cycleIdx].indices.contains(seqPos)
        else { return false }
        return gameState.mayanPlayerGrid[cycleIdx][seqPos] == nil
    }
}
