// CelticGameView.swift
// EchoOfAges
//
// Game view for the Celtic / Druidic civilization.
// Puzzle: fill a grid of Ogham letters so every row and column is
// non-decreasing, AND every row/column sum matches the carved targets.

import SwiftUI

// MARK: - Main View

struct CelticGameView: View {
    @EnvironmentObject var gameState: GameState

    @State private var showComplete    = false
    @State private var messageRevealed = false
    @State private var showInscriptions = false
    @State private var showHelp        = false

    private var difficulty: CelticDifficulty { gameState.celticCurrentDifficulty }
    private var puzzle: CelticPuzzle?         { gameState.celticCurrentPuzzle }

    private var cellSize: CGFloat {
        guard let p = puzzle else { return 80 }
        let screenW = UIScreen.main.bounds.width
        // 68 px for horizontal padding + row-sum column; max cell capped at 160
        let available = min(screenW - 68, 800.0)
        return min(160, floor(available / CGFloat(p.cols)))
    }

    /// Linear scale relative to iPhone 16 (390 pt wide), clamped 1–2.
    private var uiScale: CGFloat {
        min(2.0, max(1.0, UIScreen.main.bounds.width / 390.0))
    }

    var body: some View {
        ZStack {
            Color.celticForest.ignoresSafeArea()

            VStack(spacing: 0) {
                celticHeader
                ScrollView {
                    VStack(spacing: 20) {
                        subtitleText
                        if gameState.celticCurrentLevelIndex == 0
                            && gameState.needsKeyGate(for: .celtic) {
                            celticMysteryMarkSlot
                                .padding(.horizontal, 16)
                        }
                        if let p = puzzle {
                            gridView(p)
                        }
                        inscriptionsSection
                        paletteView
                        actionButtons
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
            }

            if showHelp {
                Color.black.opacity(0.55).ignoresSafeArea()
                    .onTapGesture { withAnimation { showHelp = false } }
                    .transition(.opacity).zIndex(9)
                celticHelpDialog
                    .transition(.scale(scale: 0.93).combined(with: .opacity))
                    .zIndex(10)
            }

            if showComplete {
                Color.black.opacity(0.60).ignoresSafeArea()
                    .transition(.opacity).zIndex(9)
                levelCompleteCard
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .onDisappear {
            showComplete = false
            messageRevealed = false
        }
        .onChange(of: gameState.celticPendingComplete) { _, newVal in
            if newVal {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    showComplete = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    withAnimation(.easeOut(duration: 0.6)) { messageRevealed = true }
                }
            } else {
                withAnimation(.easeOut(duration: 0.25)) {
                    showComplete = false
                    messageRevealed = false
                }
            }
        }
    }

    // MARK: - Header

    private var celticHeader: some View {
        ZStack {
            Color.celticStone.opacity(0.25)
            HStack {
                Button {
                    gameState.closeCelticGame()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Return")
                            .font(EgyptFont.body(15))
                    }
                    .foregroundStyle(Color.celticGold)
                    .padding(.leading, 16)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(difficulty.title)
                        .font(.custom("Cinzel-Regular", size: 15))
                        .foregroundStyle(Color.celticGold)
                    Text("Stone \(difficulty.romanNumeral)  ·  Celtic / Druidic")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.celticParchment.opacity(0.6))
                }
                Spacer()
                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { i in
                        Circle()
                            .fill(gameState.celticUnlockedLevels.contains(i)
                                  ? Color.celticGold
                                  : (i == difficulty.id
                                     ? Color.celticGold.opacity(0.5)
                                     : Color.celticParchment.opacity(0.2)))
                            .frame(width: 6, height: 6)
                    }
                    Button { withAnimation { showHelp = true } } label: {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.celticGold.opacity(0.80))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 16)
            }
            .padding(.vertical, 12)
        }
        .frame(height: 60)
    }

    // MARK: - Subtitle

    private var subtitleText: some View {
        VStack(spacing: 4) {
            Text("ᚁ · ᚂ · ᚃ · ᚄ · ᚅ")
                .font(.system(size: 22 * uiScale, weight: .light))
                .foregroundStyle(Color.celticGold.opacity(0.8))
            Text(difficulty.subtitle)
                .font(.custom("Cinzel-Regular", size: 13 * uiScale))
                .foregroundStyle(Color.celticParchment.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Mystery Mark Slot (Celtic Level 1 key gate)

    private var celticMysteryMarkSlot: some View {
        let symbol = gameState.mysteryMarkCurrent(for: .celtic)
        let isWrong = gameState.mysteryMarkWrongFlash
        return HStack(spacing: 8) {
            Button {
                gameState.cycleMysteryMark(for: .celtic)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isWrong
                            ? Color(red: 0.55, green: 0.10, blue: 0.08)
                            : Color.celticForest.opacity(0.90))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .stroke(isWrong
                                ? Color.red.opacity(0.70)
                                : Color.celticGold.opacity(0.85),
                                    lineWidth: 1.8))
                    VStack(spacing: 2) {
                        Text(symbol)
                            .font(.system(size: 26))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .frame(width: 36, height: 30)
                            .foregroundStyle(isWrong
                                ? Color(red: 1.0, green: 0.55, blue: 0.45)
                                : Color.celticGold)
                            .contentTransition(.numericText())
                        Image(systemName: "arrow.2.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.celticGold.opacity(0.65))
                    }
                }
                .frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.25), value: isWrong)

            VStack(alignment: .leading, spacing: 3) {
                Text(isWrong ? "Not recognized — check your Field Diary" : "Identify the foreign mark")
                    .font(EgyptFont.bodyItalic(13))
                    .foregroundStyle(isWrong
                        ? Color(red: 0.90, green: 0.40, blue: 0.35)
                        : Color.celticParchment.opacity(0.85))
                    .animation(.easeInOut(duration: 0.2), value: isWrong)
                Text("Tap the symbol to cycle through candidates")
                    .font(EgyptFont.body(11))
                    .foregroundStyle(Color.celticParchment.opacity(0.50))
            }
            Spacer()
        }
    }

    // MARK: - Grid

    private func gridView(_ p: CelticPuzzle) -> some View {
        VStack(spacing: 3) {
            // Cell rows + row-sum labels on the right
            ForEach(0..<p.rows, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(0..<p.cols, id: \.self) { c in
                        celticCell(row: r, col: c, puzzle: p)
                    }
                    // Row sum
                    Text("\(p.rowSums[r])")
                        .font(.system(size: 14 * uiScale, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.celticGold.opacity(0.85))
                        .frame(width: 32 * uiScale, alignment: .leading)
                        .padding(.leading, 6)
                }
            }

            // Column sum labels under each column
            HStack(spacing: 3) {
                ForEach(0..<p.cols, id: \.self) { c in
                    Text("\(p.colSums[c])")
                        .font(.system(size: 14 * uiScale, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.celticGold.opacity(0.85))
                        .frame(width: cellSize, alignment: .center)
                }
                Spacer().frame(width: 38 * uiScale)   // align with row-sum column
            }
            .padding(.top, 6)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.celticStone.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.celticGold.opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func celticCell(row: Int, col: Int, puzzle p: CelticPuzzle) -> some View {
        let coord   = CelticCellCoord(row: row, col: col)
        let isFixed = p.fixedCells.contains(coord)
        let isError = gameState.celticErrorCells.contains(coord)
        let glyph   = gameState.celticPlayerGrid.indices.contains(row)
                   && gameState.celticPlayerGrid[row].indices.contains(col)
                    ? gameState.celticPlayerGrid[row][col] : nil

        let bg: Color = {
            if isError  { return Color.celticRed }
            if isFixed  { return Color.celticStone.opacity(0.55) }
            if glyph != nil { return Color.celticStone.opacity(0.80) }
            return Color.celticStone.opacity(0.30)
        }()

        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isFixed ? Color.celticGold.opacity(0.45)
                                        : Color.celticStone.opacity(0.6),
                                lineWidth: isFixed ? 1.5 : 1)
                )

            VStack(spacing: 2) {
                if let g = glyph {
                    Text(g.rawValue)
                        .font(.system(size: cellSize * 0.44, weight: .medium))
                        .foregroundStyle(isFixed ? Color.celticInk : Color.celticInk.opacity(0.85))
                    Text(g.treeName)
                        .font(.system(size: cellSize * 0.15))
                        .foregroundStyle(Color.celticInk.opacity(0.55))
                } else {
                    Text("·")
                        .font(.system(size: cellSize * 0.3))
                        .foregroundStyle(Color.celticParchment.opacity(0.2))
                }
            }
        }
        .frame(width: cellSize, height: cellSize)
        .onTapGesture { gameState.tapCelticCell(row: row, col: col) }
        .onLongPressGesture { if !isFixed { gameState.clearCelticCell(row: row, col: col) } }
        .animation(.easeInOut(duration: 0.12), value: glyph)
        .animation(.easeInOut(duration: 0.12), value: isError)
    }

    // MARK: - Palette

    private var paletteView: some View {
        VStack(spacing: 8 * uiScale) {
            Text("Select a mark to place")
                .font(.system(size: 11 * uiScale))
                .foregroundStyle(Color.celticParchment.opacity(0.45))

            HStack(spacing: 10 * uiScale) {
                ForEach(OghamGlyph.allCases) { glyph in
                    palettePieceButton(glyph)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func palettePieceButton(_ glyph: OghamGlyph) -> some View {
        let isArmed = gameState.celticArmedGlyph == glyph
        Button {
            gameState.armCelticGlyph(glyph)
        } label: {
            VStack(spacing: 4 * uiScale) {
                Text(glyph.rawValue)
                    .font(.system(size: 26 * uiScale, weight: .medium))
                    .foregroundStyle(isArmed ? Color.celticGold : Color.celticInk)
                Text(glyph.treeName)
                    .font(.system(size: 10 * uiScale))
                    .foregroundStyle(isArmed ? Color.celticGold.opacity(0.8) : Color.celticInk.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10 * uiScale)
            .background(
                RoundedRectangle(cornerRadius: 8 * uiScale)
                    .fill(isArmed ? Color.celticGreen.opacity(0.35) : Color.celticStone.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8 * uiScale)
                            .stroke(isArmed ? Color.celticGold : Color.clear, lineWidth: 1.5)
                    )
            )
        }
    }

    // MARK: - Inscriptions

    private var inscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showInscriptions.toggle() }
            } label: {
                HStack {
                    Text(showInscriptions ? "▾  Druid's Notes" : "▸  Druid's Notes")
                        .font(.custom("Cinzel-Regular", size: 13 * uiScale))
                        .foregroundStyle(Color.celticGold.opacity(0.8))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }

            if showInscriptions {
                let acrostic = TreeOfLifeKeys.acrosticLetter(for: .celtic, levelIndex: gameState.celticCurrentLevelIndex)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(difficulty.inscriptions.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: 8) {
                            Text("·")
                                .foregroundStyle(Color.celticGold.opacity(0.6))
                            Text(acrosticUnderlined(difficulty.inscriptions[i], letter: acrostic))
                                .font(.system(size: 13 * uiScale, design: .serif))
                                .foregroundStyle(Color.celticParchment.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.celticStone.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 14) {
            Button { gameState.verifyCelticPlacement() } label: {
                StoneButton(title: "Verify", icon: "checkmark.seal")
            }
            Button { gameState.resetCelticGrid() } label: {
                StoneButton(title: "Reset", icon: "arrow.counterclockwise", style: .muted)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Help Dialog

    private var celticHelpDialog: some View {
        let accent = Color.celticGold
        let bg     = Color(red: 0.07, green: 0.12, blue: 0.05)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ᚁ  How to Play")
                    .font(EgyptFont.titleBold(20))
                    .foregroundStyle(accent)
                Spacer()
                Button { withAnimation { showHelp = false } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(accent.opacity(0.70))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 14)

            celticHelpRow(number: "1", title: "Fill every cell with an Ogham value",
                          body: "Each cell holds a value from 1 (ᚁ Beith) to 5 (ᚅ Nion). Every cell must be filled — no cell can be left blank.")
            celticHelpRow(number: "2", title: "No value repeats in any row or column",
                          body: "Each number 1–5 appears exactly once per row and exactly once per column, like a Latin square.")
            celticHelpRow(number: "3", title: "Match the carved totals",
                          body: "The sum shown at the end of each row and column is the target total. Your filled values must add up to those numbers.")
            celticHelpRow(number: "4", title: "Arm and place",
                          body: "Tap a symbol in the palette to arm it, then tap any empty cell to place it. Tap Decipher to check your work.")

            Button { withAnimation { showHelp = false } } label: {
                Text("Got it")
                    .font(EgyptFont.titleBold(17))
                    .foregroundStyle(bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 10).fill(accent))
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(bg)
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .stroke(accent.opacity(0.55), lineWidth: 1.5))
        )
        .padding(.horizontal, 20)
    }

    private func celticHelpRow(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(EgyptFont.titleBold(16))
                .foregroundStyle(Color.celticGold)
                .frame(width: 22, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(Color.celticParchment)
                Text(body)
                    .font(EgyptFont.body(13))
                    .foregroundStyle(Color.celticParchment.opacity(0.75))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Level Complete Card

    private var levelCompleteCard: some View {
        let isLastLevel = gameState.celticCurrentLevelIndex == CelticDifficulty.all.count - 1
        let newCivs     = isLastLevel ? gameState.newlyUnlockedCivs(completingLevel5Of: .celtic) : []

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer(minLength: 20)

                Text("ᚁ ᚂ ᚃ ᚄ ᚅ")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.celticGold)
                    .shadow(color: Color.celticGold.opacity(0.55), radius: 14, x: 0, y: 0)

                VStack(spacing: 8) {
                    Text("Stone Decoded")
                        .font(EgyptFont.titleBold(26))
                        .foregroundStyle(Color.celticGold)
                        .tracking(2)
                    Text(difficulty.title)
                        .font(EgyptFont.bodyItalic(17))
                        .foregroundStyle(Color.celticGold.opacity(0.75))
                }

                WinnerScene(imageName: "celtic_final",
                            completedLevelIndex: gameState.celticCurrentLevelIndex)

                if messageRevealed {
                    Text(difficulty.decodedMessage)
                        .font(EgyptFont.bodyItalic(15))
                        .foregroundStyle(Color.celticParchment.opacity(0.85))
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .transition(.opacity)

                    // Journal nudge
                    HStack(spacing: 8) {
                        Image(systemName: "book.fill").font(.system(size: 11))
                            .foregroundStyle(Color.celticGold.opacity(0.60))
                        Text("A new entry has been written in your Field Diary.")
                            .font(EgyptFont.bodyItalic(13))
                            .foregroundStyle(Color.celticGold.opacity(0.60))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .transition(.opacity)

                    // Level 5 — key earned + newly unlocked civs
                    if isLastLevel {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "key.fill").font(.system(size: 12))
                                    .foregroundStyle(Color.celticGold)
                                Text("The Celtic key has been carved in your Field Diary.")
                                    .font(EgyptFont.bodyItalic(13))
                                    .foregroundStyle(Color.celticGold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if !newCivs.isEmpty {
                                Text("NEW PATHS OPEN")
                                    .font(EgyptFont.title(11))
                                    .foregroundStyle(Color.celticGold.opacity(0.55))
                                    .tracking(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(newCivs) { civ in
                                    HStack(spacing: 12) {
                                        Text(civ.emblem).font(.system(size: 24))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(civ.name).font(EgyptFont.titleBold(14))
                                                .foregroundStyle(civ.accentColor)
                                            Text(civ.era).font(EgyptFont.bodyItalic(12))
                                                .foregroundStyle(Color.celticParchment.opacity(0.55))
                                        }
                                        Spacer()
                                        Image(systemName: "lock.open.fill").font(.system(size: 12))
                                            .foregroundStyle(Color.goldMid)
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.celticStone.opacity(0.15))
                                            .overlay(RoundedRectangle(cornerRadius: 8)
                                                .stroke(civ.accentColor.opacity(0.35), lineWidth: 1))
                                    )
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.celticForest.opacity(0.6))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.celticGold.opacity(0.30), lineWidth: 1))
                        )
                        .transition(.opacity)
                    }
                } else {
                    Text("Deciphering inscription…")
                        .font(EgyptFont.bodyItalic(14))
                        .foregroundStyle(Color.celticParchment.opacity(0.35))
                        .italic()
                }

                VStack(spacing: 10) {
                    if isLastLevel && gameState.allSixCivsComplete {
                        Button {
                            HapticFeedback.heavy()
                            gameState.celticPendingComplete = false
                            withAnimation(.easeInOut(duration: 0.4)) { gameState.openManduTablet() }
                        } label: {
                            StoneButton(title: "Open the Mandu Tablet", icon: "seal.fill", style: .gold)
                        }
                        .buttonStyle(.plain)
                    } else if isLastLevel {
                        Button {
                            HapticFeedback.heavy()
                            gameState.celticPendingComplete = false
                            withAnimation(.easeInOut(duration: 0.4)) { gameState.startNewGame() }
                        } label: {
                            StoneButton(title: "Continue Expedition", icon: "arrow.right", style: .gold)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            HapticFeedback.tap()
                            gameState.advanceCelticToNextLevel()
                        } label: {
                            StoneButton(title: "Next Stone", icon: "arrow.right", style: .gold)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        HapticFeedback.tap()
                        gameState.openJournal()
                    } label: {
                        StoneButton(title: "Open Field Diary", icon: "book.fill", style: .muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.stoneDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.celticGold.opacity(0.45), lineWidth: 1.2)
                )
        )
        .shadow(color: .black.opacity(0.55), radius: 22, x: 0, y: 8)
        .padding(.horizontal, 24)
        .frame(maxHeight: UIScreen.main.bounds.height * 0.82)
    }
}

// MARK: - Celtic Color Palette

private extension Color {
    static let celticForest    = Color(red: 0.07, green: 0.12, blue: 0.05)
    static let celticStone     = Color(red: 0.68, green: 0.64, blue: 0.56)
    static let celticGreen     = Color(red: 0.30, green: 0.48, blue: 0.22)
    static let celticGold      = Color(red: 0.82, green: 0.70, blue: 0.38)
    static let celticParchment = Color(red: 0.88, green: 0.84, blue: 0.72)
    static let celticInk       = Color(red: 0.10, green: 0.07, blue: 0.03)
    static let celticRed       = Color(red: 0.62, green: 0.18, blue: 0.10)
}

// MARK: - Rounded corner helper (reused from other views)

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

private struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect,
                                byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
