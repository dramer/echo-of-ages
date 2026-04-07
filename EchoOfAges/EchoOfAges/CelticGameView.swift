// CelticGameView.swift
// EchoOfAges
//
// Game view for the Celtic / Druidic civilization.
// Puzzle: fill a grid of Ogham letters so every row and
// column is in non-decreasing Beith-Luis-Nion order.

import SwiftUI

// MARK: - Main View

struct CelticGameView: View {
    @EnvironmentObject var gameState: GameState

    @State private var showComplete  = false
    @State private var messageRevealed = false
    @State private var showInscriptions = false

    private var level: CelticLevel { gameState.celticCurrentLevel }

    private var cellSize: CGFloat {
        let screenW = UIScreen.main.bounds.width
        let available = min(screenW - 40, 480.0)
        return min(74, available / CGFloat(level.cols))
    }

    var body: some View {
        ZStack {
            Color.celticForest.ignoresSafeArea()

            VStack(spacing: 0) {
                celticHeader
                ScrollView {
                    VStack(spacing: 20) {
                        subtitleText
                        gridView
                        inscriptionsSection
                        paletteView
                        actionButtons
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
            }

            if showComplete { levelCompleteCard }
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
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.celticGold)
                        .padding(.leading, 16)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(level.title)
                        .font(.custom("Cinzel-Regular", size: 15))
                        .foregroundStyle(Color.celticGold)
                    Text("Stone \(level.romanNumeral)  ·  Celtic / Druidic")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.celticParchment.opacity(0.6))
                }
                Spacer()
                // Level progress dots
                HStack(spacing: 5) {
                    ForEach(1...5, id: \.self) { i in
                        Circle()
                            .fill(gameState.celticUnlockedLevels.contains(i)
                                  ? Color.celticGold
                                  : (i == level.id ? Color.celticGold.opacity(0.5) : Color.celticParchment.opacity(0.2)))
                            .frame(width: 6, height: 6)
                    }
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
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.celticGold.opacity(0.8))
            Text(level.subtitle)
                .font(.custom("Cinzel-Regular", size: 13))
                .foregroundStyle(Color.celticParchment.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Grid

    private var gridView: some View {
        VStack(spacing: 3) {
            ForEach(0..<level.rows, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(0..<level.cols, id: \.self) { c in
                        celticCell(row: r, col: c)
                    }
                }
            }
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
    private func celticCell(row: Int, col: Int) -> some View {
        let coord   = CelticCellCoord(row: row, col: col)
        let isFixed = level.fixedCells.contains(coord)
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
        VStack(spacing: 8) {
            Text("Select a mark to place")
                .font(.system(size: 11))
                .foregroundStyle(Color.celticParchment.opacity(0.45))

            HStack(spacing: 10) {
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
            VStack(spacing: 4) {
                Text(glyph.rawValue)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(isArmed ? Color.celticGold : Color.celticInk)
                Text(glyph.treeMeaning)
                    .font(.system(size: 10))
                    .foregroundStyle(isArmed ? Color.celticGold.opacity(0.8) : Color.celticInk.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isArmed ? Color.celticGreen.opacity(0.35) : Color.celticStone.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
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
                        .font(.custom("Cinzel-Regular", size: 13))
                        .foregroundStyle(Color.celticGold.opacity(0.8))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }

            if showInscriptions {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(level.inscriptions.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: 8) {
                            Text("·")
                                .foregroundStyle(Color.celticGold.opacity(0.6))
                            Text(level.inscriptions[i])
                                .font(.system(size: 13, design: .serif))
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

    // MARK: - Level Complete Card

    private var levelCompleteCard: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Color.celticGreen.opacity(0.85)
                    VStack(spacing: 6) {
                        Text("ᚁ ᚂ ᚃ ᚄ ᚅ")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.celticGold)
                        Text("Stone Decoded")
                            .font(.custom("Cinzel-Regular", size: 20))
                            .foregroundStyle(Color.celticGold)
                        Text(level.title)
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(Color.celticParchment.opacity(0.75))
                    }
                    .padding(.vertical, 20)
                }
                .cornerRadius(14, corners: [.topLeft, .topRight])

                // Message
                VStack(spacing: 16) {
                    if messageRevealed {
                        Text(level.decodedMessage)
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(Color.celticParchment.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .transition(.opacity)
                    } else {
                        Text("Deciphering inscription…")
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(Color.celticParchment.opacity(0.4))
                            .italic()
                    }
                }
                .frame(minHeight: 80)
                .padding(.vertical, 20)
                .background(Color(red: 0.10, green: 0.17, blue: 0.08))

                // Buttons
                HStack(spacing: 0) {
                    Button {
                        gameState.advanceCelticToNextLevel()
                    } label: {
                        Text(level.id < 5 ? "Next Stone" : "Complete")
                            .font(.custom("Cinzel-Regular", size: 15))
                            .foregroundStyle(Color.celticGold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.celticGreen.opacity(0.6))
                    }
                    Divider().frame(width: 1).background(Color.celticGold.opacity(0.2))
                    Button {
                        gameState.advanceCelticToNextLevel()
                        gameState.currentScreen = .journal
                    } label: {
                        Text("Field Diary")
                            .font(.custom("Cinzel-Regular", size: 15))
                            .foregroundStyle(Color.celticParchment.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 0.10, green: 0.17, blue: 0.08))
                    }
                }
                .cornerRadius(14, corners: [.bottomLeft, .bottomRight])
            }
            .frame(maxWidth: 360)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.5), radius: 20)
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Celtic Color Palette

private extension Color {
    /// Dark forest green background
    static let celticForest  = Color(red: 0.07, green: 0.12, blue: 0.05)
    /// Stone grey for cells and borders
    static let celticStone   = Color(red: 0.68, green: 0.64, blue: 0.56)
    /// Celtic accent green (grove)
    static let celticGreen   = Color(red: 0.30, green: 0.48, blue: 0.22)
    /// Gold / bronze for title text and selected states
    static let celticGold    = Color(red: 0.82, green: 0.70, blue: 0.38)
    /// Cream/parchment for body text
    static let celticParchment = Color(red: 0.88, green: 0.84, blue: 0.72)
    /// Dark ink for glyphs on stone cells
    static let celticInk     = Color(red: 0.10, green: 0.07, blue: 0.03)
    /// Error red
    static let celticRed     = Color(red: 0.62, green: 0.18, blue: 0.10)
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
