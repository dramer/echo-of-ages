// GlyphGridView.swift
// EchoOfAges
//
// Contains the full game screen (GameView) and the puzzle grid sub-view (GlyphGridView).
// Layout is fully responsive — portrait stacks vertically, landscape splits grid/controls
// side-by-side. No scrolling: everything fits on one screen.
//
// Toast hints:
//   • Decipher on incomplete grid → "fill all tiles" warning toast
//   • Idle (8 s of no interaction) → tutorial / pattern-reminder toast

import SwiftUI

// MARK: - Game Screen

struct GameView: View {
    @EnvironmentObject var gameState: GameState
    @State private var fieldNotesExpanded = false
    @State private var codexExpanded = false

    // ── Toast state ──────────────────────────────────────────────────────────
    @State private var toastMessage: String = ""
    @State private var toastVisible: Bool = false
    @State private var toastDismissTask: Task<Void, Never>? = nil
    @State private var idleHintTask:    Task<Void, Never>? = nil

    /// Tracks whether the player has touched any editable cell since this level loaded.
    @State private var hasInteracted: Bool = false
    /// Snapshot of the grid exactly when the level was loaded (or last reset).
    @State private var levelInitialGrid: [[Glyph?]] = []

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {

                // ── Main layout (portrait or landscape) ──────────────────────
                if geo.size.width > geo.size.height {
                    landscapeLayout(geo: geo)
                } else {
                    portraitLayout(geo: geo)
                }

                // ── Toast overlay ────────────────────────────────────────────
                if toastVisible {
                    ToastView(message: toastMessage)
                        .padding(.bottom, 26)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal:   .opacity
                            )
                        )
                        .zIndex(10)
                }
            }
        }
        .background(stoneBackground)
        // ── Toast / hint lifecycle hooks ──────────────────────────────────────
        .onAppear {
            levelInitialGrid = gameState.playerGrid
            hasInteracted    = false
            scheduleIdleHint()
        }
        .onChange(of: gameState.currentLevelIndex) { _, _ in
            // New level loaded — reset everything and start a fresh idle timer
            levelInitialGrid = gameState.playerGrid
            hasInteracted    = false
            cancelIdleHint()
            scheduleIdleHint()
        }
        .onChange(of: gameState.playerGrid) { _, newGrid in
            guard !hasInteracted else { return }
            if newGrid != levelInitialGrid {
                // Player actually touched a cell — cancel the idle hint forever for this level
                hasInteracted = true
                cancelIdleHint()
            } else {
                // Grid was reset back to initial state (player hit Reset)
                hasInteracted = false
                cancelIdleHint()
                scheduleIdleHint()
            }
        }
    }

    // MARK: Toast helpers

    /// Show a toast that auto-dismisses after `duration` seconds.
    private func showToast(_ message: String, duration: Double = 5.0) {
        toastDismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.45)) {
            toastMessage = message
            toastVisible = true
        }
        toastDismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            withAnimation(.easeIn(duration: 0.55)) {
                toastVisible = false
            }
        }
    }

    /// Schedule the idle hint to fire after 8 seconds (if no interaction yet).
    private func scheduleIdleHint() {
        idleHintTask?.cancel()
        idleHintTask = Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !hasInteracted else { return }
            showToast(idleHintText, duration: 6.5)
        }
    }

    private func cancelIdleHint() {
        idleHintTask?.cancel()
        idleHintTask = nil
    }

    /// Hint text tailored to the current level index.
    private var idleHintText: String {
        let idx = gameState.currentLevelIndex
        if idx == 0 {
            return "Tap any empty cell, then choose a glyph from the palette below. Each glyph must appear exactly once in every row and column — no repeats anywhere."
        } else {
            let prev = Level.allLevels[idx - 1]
            return "You solved the \(prev.title) tablet — each glyph appeared once per row and column. This inscription follows the same sacred rule, but the arrangement is completely different. Study the fixed symbols first for your opening clues."
        }
    }

    // MARK: Grid completeness

    private var isGridComplete: Bool {
        let level = gameState.currentLevel
        for row in 0..<level.rows {
            for col in 0..<level.cols {
                if gameState.playerGrid[row][col] == nil { return false }
            }
        }
        return true
    }

    // MARK: Portrait Layout

    @ViewBuilder
    private func portraitLayout(geo: GeometryProxy) -> some View {
        let topBarH:    CGFloat = 64
        let headerH:    CGFloat = 72
        let paletteH:   CGFloat = 78
        let panelsH:    CGFloat = 44 * 2
        let buttonsH:   CGFloat = 52
        let margins:    CGFloat = 10 * 7
        let safeBottom: CGFloat = 16
        let reservedH = topBarH + headerH + paletteH + panelsH + buttonsH + margins + safeBottom
        let gridAvailH = geo.size.height - reservedH
        let gridAvailW = geo.size.width - 32

        VStack(spacing: 0) {
            topBar.padding(.horizontal, 16)
            Spacer(minLength: 6)
            levelHeader.padding(.horizontal, 16)
            Spacer(minLength: 10)
            GlyphGridView(availableWidth: gridAvailW,
                          availableHeight: max(gridAvailH, 100))
                .padding(.horizontal, 16)
            Spacer(minLength: 10)
            palette.padding(.horizontal, 16)
            Spacer(minLength: 8)
            knownGlyphsPanel.padding(.horizontal, 16)
            Spacer(minLength: 6)
            fieldNotesPanel.padding(.horizontal, 16)
            Spacer(minLength: 8)
            actionButtons.padding(.horizontal, 16)
            Spacer(minLength: safeBottom)
        }
    }

    // MARK: Landscape Layout

    @ViewBuilder
    private func landscapeLayout(geo: GeometryProxy) -> some View {
        let leftW  = geo.size.width * 0.52
        let rightW = geo.size.width - leftW
        let topBarH: CGFloat = 50
        let gridAvailW = leftW - 28
        let gridAvailH = geo.size.height - topBarH - 28

        HStack(spacing: 0) {

            // ── Left: diary button + grid ──
            VStack(spacing: 8) {
                topBarLandscape.padding(.horizontal, 14)
                GlyphGridView(availableWidth: gridAvailW,
                              availableHeight: max(gridAvailH, 80))
                    .padding(.horizontal, 14)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .frame(width: leftW)

            Rectangle()
                .fill(Color.goldDark.opacity(0.22))
                .frame(width: 1)
                .padding(.vertical, 20)

            // ── Right: level info + palette + panels + buttons ──
            VStack(spacing: 0) {
                levelHeaderCompact
                Spacer(minLength: 8)
                palette
                Spacer(minLength: 10)
                knownGlyphsPanel
                Spacer(minLength: 6)
                fieldNotesPanel
                Spacer(minLength: 0)
                actionButtons
                Spacer(minLength: 12)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: rightW)
        }
    }

    // MARK: Top Bar (Portrait)

    private var topBar: some View {
        HStack(alignment: .center) {
            Button(action: { gameState.openJournal() }) {
                Image("diary")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .shadow(color: Color.goldDark.opacity(0.5), radius: 6, x: 0, y: 2)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(gameState.currentLevel.title.uppercased())
                    .font(EgyptFont.title(11))
                    .foregroundStyle(Color.goldDark)
                    .tracking(2)
                    .lineLimit(1)
                Text("Chamber \(gameState.currentLevel.romanNumeral) of V")
                    .font(EgyptFont.body(12))
                    .foregroundStyle(Color.stoneSurface)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: Top Bar (Landscape — compact)

    private var topBarLandscape: some View {
        HStack(spacing: 8) {
            Button(action: { gameState.openJournal() }) {
                HStack(spacing: 6) {
                    Image("diary")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                    Text("Field Diary")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(Color.stoneSurface)
                }
            }
            Spacer()
        }
    }

    // MARK: Level Header (Portrait)

    private var levelHeader: some View {
        VStack(spacing: 4) {
            Text("· \(gameState.currentLevel.romanNumeral) ·")
                .font(EgyptFont.title(12))
                .foregroundStyle(Color.goldDark)
                .tracking(4)
            Text(gameState.currentLevel.title.uppercased())
                .font(EgyptFont.titleBold(22))
                .foregroundStyle(Color.goldBright)
                .tracking(3)
                .shadow(color: .goldDark.opacity(0.5), radius: 4, x: 0, y: 2)
            Text(gameState.currentLevel.subtitle)
                .font(EgyptFont.bodyItalic(14))
                .foregroundStyle(Color.papyrus.opacity(0.8))
                .lineLimit(2)
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 2)
    }

    // MARK: Level Header (Landscape — compact one-liner)

    private var levelHeaderCompact: some View {
        VStack(spacing: 3) {
            Text("· \(gameState.currentLevel.romanNumeral) · \(gameState.currentLevel.title.uppercased())")
                .font(EgyptFont.titleBold(15))
                .foregroundStyle(Color.goldBright)
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(gameState.currentLevel.subtitle)
                .font(EgyptFont.bodyItalic(13))
                .foregroundStyle(Color.papyrus.opacity(0.75))
                .lineLimit(2)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: Glyph Palette

    private var palette: some View {
        VStack(spacing: 8) {
            Text("Place a Glyph")
                .font(EgyptFont.body(12))
                .foregroundStyle(Color.stoneSurface)
            HStack(spacing: 8) {
                ForEach(gameState.currentLevel.availableGlyphs) { glyph in
                    PaletteButton(
                        glyph: glyph,
                        isSelected: gameState.selectedGlyph == glyph
                    ) {
                        gameState.selectGlyph(glyph)
                    }
                }
            }
        }
    }

    // MARK: Known Glyphs (Codex)

    private var knownGlyphsPanel: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) { codexExpanded.toggle() }
                HapticFeedback.tap()
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                    Text("Known Glyphs")
                        .font(EgyptFont.title(13))
                    Spacer()
                    Text("\(gameState.codexGlyphs.count) recorded")
                        .font(EgyptFont.body(11))
                        .foregroundStyle(Color.stoneSurface)
                    Image(systemName: codexExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.goldMid)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.stoneMid)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.stoneLight.opacity(0.5), lineWidth: 0.8))
                )
            }

            if codexExpanded {
                ScrollView(showsIndicators: false) {
                    if gameState.codexGlyphs.isEmpty {
                        Text("No glyphs recorded yet. Solve the first puzzle to fill your codex.")
                            .font(EgyptFont.bodyItalic(12))
                            .foregroundStyle(Color.papyrus.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(12)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(gameState.codexGlyphs) { glyph in
                                HStack(spacing: 10) {
                                    Text(glyph.rawValue)
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color.goldBright)
                                        .frame(width: 30)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(glyph.displayName)
                                            .font(EgyptFont.titleBold(12))
                                            .foregroundStyle(Color.goldBright)
                                        Text(glyph.meaning)
                                            .font(EgyptFont.bodyItalic(11))
                                            .foregroundStyle(Color.papyrus.opacity(0.7))
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.stoneMid.opacity(0.5))
                                )
                            }
                        }
                        .padding(10)
                    }
                }
                .frame(maxHeight: 150)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.stoneDark.opacity(0.7))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.stoneLight.opacity(0.3), lineWidth: 0.5))
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: Field Notes Panel

    private var fieldNotesPanel: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) { fieldNotesExpanded.toggle() }
                HapticFeedback.tap()
            }) {
                HStack {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                    Text("Field Notes")
                        .font(EgyptFont.title(13))
                    Spacer()
                    Image(systemName: fieldNotesExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.goldMid)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.stoneMid)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.stoneLight.opacity(0.5), lineWidth: 0.8))
                )
            }

            if fieldNotesExpanded {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(gameState.currentLevel.inscriptions.enumerated()), id: \.offset) { _, note in
                            HStack(alignment: .top, spacing: 8) {
                                Text("𓏲")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.goldDark)
                                Text(note)
                                    .font(EgyptFont.bodyItalic(13))
                                    .foregroundStyle(Color.papyrus.opacity(0.9))
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.stoneDark.opacity(0.7))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.stoneLight.opacity(0.3), lineWidth: 0.5))
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                if isGridComplete {
                    gameState.verifyPlacement()
                } else {
                    HapticFeedback.error()
                    showToast(
                        "Every tile must be filled before deciphering. Tap the empty cells and place a glyph in each one.",
                        duration: 5.0
                    )
                }
            }) {
                StoneButton(title: "Decipher", icon: "eye", style: .gold)
            }
            Button(action: { gameState.resetCurrentLevel() }) {
                StoneButton(title: "Reset", icon: "arrow.counterclockwise", style: .muted)
            }
        }
    }

    // MARK: Background

    private var stoneBackground: some View {
        ZStack {
            Color.stoneDark.ignoresSafeArea()
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.35)],
                center: .center,
                startRadius: 200,
                endRadius: 500
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Glyph Grid

struct GlyphGridView: View {
    @EnvironmentObject var gameState: GameState
    let availableWidth: CGFloat
    let availableHeight: CGFloat

    private var level: Level { gameState.currentLevel }

    /// Cell size constrained by both available width and height, capped at 80 pt.
    private var cellSize: CGFloat {
        let hSpacing = CGFloat(level.cols - 1) * 6
        let vSpacing = CGFloat(level.rows - 1) * 6
        let gridPad:  CGFloat = 20
        let byWidth  = (availableWidth  - hSpacing - gridPad) / CGFloat(level.cols)
        let byHeight = (availableHeight - vSpacing - gridPad) / CGFloat(level.rows)
        return min(byWidth, byHeight, 80)
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<level.rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<level.cols, id: \.self) { col in
                        let pos = GridPosition(row: row, col: col)
                        GlyphCellView(
                            glyph: gameState.playerGrid[row][col],
                            isFixed: level.isFixed(pos),
                            isError: gameState.errorCells.contains(pos),
                            isComplete: gameState.isAnimatingCompletion,
                            size: cellSize,
                            onTap: { gameState.tapCell(at: pos) },
                            onLongPress: { gameState.clearCell(at: pos) }
                        )
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.stoneMid.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.goldDark.opacity(0.35), lineWidth: 1)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.goldBright, lineWidth: 2.5)
                .opacity(gameState.isAnimatingCompletion ? 1 : 0)
                .animation(
                    .easeInOut(duration: 0.5).repeatCount(3, autoreverses: true),
                    value: gameState.isAnimatingCompletion
                )
        )
    }
}

// MARK: - Palette Button

private struct PaletteButton: View {
    let glyph: Glyph
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(glyph.rawValue)
                    .font(.system(size: 26))
                Text(glyph.displayName.replacingOccurrences(of: "The ", with: ""))
                    .font(EgyptFont.body(10))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.stoneDark : Color.goldMid)
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected
                          ? LinearGradient(colors: [.goldBright, .goldMid], startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [.stoneMid, .stoneDark], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(isSelected ? Color.goldBright : Color.stoneLight.opacity(0.4), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
            .scaleEffect(isSelected ? 1.06 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
        }
    }
}
