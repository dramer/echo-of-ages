// ChineseGameView.swift
// EchoOfAges
//
// Wooden box puzzle screen for the Ancient Chinese civilization.
//
// Mechanic: Fit all wooden pieces into the rectangular tray.
// Each piece can be rotated in 90° increments. The puzzle is solved
// when every cell of the tray is occupied by exactly one piece.
//
// Layout:
//   • Header bar — back (Journal), Chinese title, level numeral
//   • Level title / subtitle / lore
//   • Wooden tray board — adaptive cell size, tap to place/remove
//   • Piece palette — horizontal scroll of mini piece shapes
//   • Rotate button — shown when a piece is selected
//   • Verify / Reset buttons
//   • Collapsible field inscriptions
//   • Level-complete overlay card

import SwiftUI

struct ChineseGameView: View {
    @EnvironmentObject var gameState: GameState

    @State private var showComplete        = false
    @State private var messageRevealed     = false
    @State private var inscriptionsExpanded = false
    @State private var errorCell: (Int, Int)? = nil
    @State private var showVerifyError: Bool  = false

    private var level: ChineseBoxLevel { gameState.chineseCurrentLevel }

    // MARK: - Colors

    private var lacquerBlack: Color { Color(red: 0.06, green: 0.04, blue: 0.02) }
    private var trayFrame:    Color { Color(hex: "4A2810") ?? Color(red: 0.29, green: 0.16, blue: 0.06) }
    private var emptyCell:    Color { (Color(hex: "D4A96A") ?? Color(red: 0.83, green: 0.66, blue: 0.42)).opacity(0.25) }
    private var cellBorder:   Color { (Color(hex: "5C3520") ?? Color(red: 0.36, green: 0.21, blue: 0.13)).opacity(0.60) }
    private var warmGold:     Color { Color(red: 0.85, green: 0.68, blue: 0.28) }
    private var vermillion:   Color { Color(red: 0.78, green: 0.16, blue: 0.09) }
    private var inkGrey:      Color { Color(red: 0.55, green: 0.50, blue: 0.44) }

    // MARK: - Body

    var body: some View {
        ZStack {
            lacquerBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        levelHeader

                        GeometryReader { geo in
                            boardSectionGeometry(geo: geo)
                        }
                        .frame(height: boardHeightEstimate)

                        piecesPalette
                        actionRow
                        inscriptionsSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }

            if showComplete {
                Color.black.opacity(0.60).ignoresSafeArea()
                    .transition(.opacity).zIndex(9)
                levelCompleteCard
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .onChange(of: gameState.chinesePendingComplete) { _, newVal in
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

    // MARK: - Computed Board Height Estimate

    /// Conservative estimate for the GeometryReader outer frame height.
    /// The inner boardSection adjusts to the measured width at render time.
    private var boardHeightEstimate: CGFloat {
        // Use a generous per-row estimate; the actual computed height may be
        // smaller on wide screens (fewer rows) or larger on narrow screens.
        let approxCellSize: CGFloat = 58
        return CGFloat(level.rows) * approxCellSize + 32
    }

    /// Wraps boardSection inside a GeometryReader callback, computing a precise height.
    @ViewBuilder
    private func boardSectionGeometry(geo: GeometryProxy) -> some View {
        let sw = geo.size.width + 36  // compensate for parent's horizontal padding
        let cs = cellSize(screenWidth: sw)
        let h  = CGFloat(level.rows) * cs + 16
        boardSection(screenWidth: sw)
            .frame(height: h)
    }

    // MARK: - Cell Size

    private func cellSize(screenWidth: CGFloat) -> CGFloat {
        let available = min(screenWidth - 48, 500.0)
        return max(44, available / CGFloat(level.cols))
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Button(action: { gameState.closeChineseGame() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Journal")
                        .font(EgyptFont.body(17))
                }
                .foregroundStyle(vermillion)
            }
            Spacer()
            VStack(spacing: 1) {
                Text("木工")
                    .font(EgyptFont.titleBold(18))
                    .foregroundStyle(vermillion)
                Text("Wooden Puzzle")
                    .font(EgyptFont.body(11))
                    .foregroundStyle(vermillion.opacity(0.60))
            }
            Spacer()
            Text(level.romanNumeral)
                .font(EgyptFont.titleBold(22))
                .foregroundStyle(warmGold)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            lacquerBlack
                .overlay(
                    Rectangle()
                        .fill(vermillion.opacity(0.40))
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
                .foregroundStyle(warmGold)
            Text(level.subtitle)
                .font(EgyptFont.bodyItalic(14))
                .foregroundStyle(warmGold.opacity(0.65))
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
                .fill(Color(red: 0.09, green: 0.06, blue: 0.03).opacity(0.90))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(vermillion.opacity(0.22), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Board Section

    private func boardSection(screenWidth: CGFloat) -> some View {
        let cs = cellSize(screenWidth: screenWidth)
        let trayWidth  = CGFloat(level.cols) * cs
        let trayHeight = CGFloat(level.rows) * cs
        let board = level.board(from: gameState.chinesePlacedPieces)

        return VStack(alignment: .center, spacing: 0) {
            ZStack(alignment: .topLeading) {
                // Tray frame background
                RoundedRectangle(cornerRadius: 10)
                    .fill(trayFrame)
                    .frame(width: trayWidth + 16, height: trayHeight + 16)
                    .shadow(color: .black.opacity(0.50), radius: 8, x: 0, y: 4)

                // Cell grid
                VStack(spacing: 0) {
                    ForEach(0 ..< level.rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0 ..< level.cols, id: \.self) { col in
                                boardCell(row: row, col: col,
                                          board: board, cellSize: cs)
                            }
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Board Cell

    @ViewBuilder
    private func boardCell(row: Int, col: Int,
                            board: [[String?]], cellSize cs: CGFloat) -> some View {
        let occupantId = board.indices.contains(row)
            ? (board[row].indices.contains(col) ? board[row][col] : nil)
            : nil
        let isError = errorCell.map { $0.0 == row && $0.1 == col } ?? false

        ZStack {
            if let pieceId = occupantId,
               let piece = level.pieces.first(where: { $0.id == pieceId }) {
                // Occupied cell — piece color
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: piece.colorHex) ?? warmGold)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black.opacity(0.20), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                    .padding(1)

                // Piece name character (small, centered)
                Text(piece.name)
                    .font(.system(size: cs * 0.28, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.35))
            } else {
                // Empty cell — also highlight red on verify error
                let emptyIsError = isError || showVerifyError
                RoundedRectangle(cornerRadius: 4)
                    .fill(emptyIsError
                          ? Color.red.opacity(0.35)
                          : emptyCell)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(emptyIsError
                                    ? Color.red.opacity(0.70)
                                    : cellBorder,
                                    lineWidth: 1)
                    )
                    .padding(1)
            }
        }
        .frame(width: cs, height: cs)
        .contentShape(Rectangle())
        .onTapGesture {
            handleBoardTap(row: row, col: col, board: board)
        }
    }

    // MARK: - Board Tap Handling

    private func handleBoardTap(row: Int, col: Int, board: [[String?]]) {
        if let selectedId = gameState.chineseSelectedPieceId {
            // Attempt to place the selected piece anchored at this cell
            let placement = ChinesePiecePlacement(
                row: row, col: col,
                rotation: gameState.chineseArmedRotation
            )
            let piece = level.pieces.first(where: { $0.id == selectedId })
            let valid = piece.map {
                level.isValidPlacement(piece: $0,
                                       proposed: placement,
                                       existing: gameState.chinesePlacedPieces)
            } ?? false

            if valid {
                HapticFeedback.tap()
                gameState.placeChinesePiece(id: selectedId, row: row, col: col)
            } else {
                // Flash error
                HapticFeedback.error()
                errorCell = (row, col)
                Task {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    errorCell = nil
                }
            }
        } else {
            // No piece selected — tap on occupied cell removes it
            let occupantId = board.indices.contains(row)
                ? (board[row].indices.contains(col) ? board[row][col] : nil)
                : nil
            if let pieceId = occupantId {
                HapticFeedback.tap()
                gameState.removeChinesePiece(id: pieceId)
            }
        }
    }

    // MARK: - Pieces Palette

    private var piecesPalette: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PIECES")
                .font(EgyptFont.title(11))
                .foregroundStyle(warmGold.opacity(0.55))
                .tracking(2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(level.pieces) { piece in
                        palettePieceButton(piece: piece)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }

            // Rotate button — only when a piece is selected
            if gameState.chineseSelectedPieceId != nil {
                HStack {
                    Spacer()
                    Button(action: {
                        HapticFeedback.tap()
                        gameState.rotateSelectedChinesePiece()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "rotate.right")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Rotate")
                                .font(EgyptFont.title(14))
                        }
                        .foregroundStyle(warmGold)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(warmGold.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(warmGold.opacity(0.45), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.05, blue: 0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(vermillion.opacity(0.18), lineWidth: 0.8)
                )
        )
        .animation(.easeInOut(duration: 0.20), value: gameState.chineseSelectedPieceId)
    }

    // MARK: - Palette Piece Button

    @ViewBuilder
    private func palettePieceButton(piece: ChineseBoxPiece) -> some View {
        let isPlaced    = gameState.chinesePlacedPieces[piece.id] != nil
        let isSelected  = gameState.chineseSelectedPieceId == piece.id
        let rotation    = isSelected ? gameState.chineseArmedRotation : 0

        Button(action: {
            HapticFeedback.tap()
            gameState.selectChinesePiece(id: piece.id)
        }) {
            VStack(spacing: 6) {
                ZStack {
                    pieceShape(piece: piece, rotation: rotation, cellSize: 14)
                        .opacity(isPlaced ? 0.35 : 1.0)

                    if isPlaced {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(warmGold.opacity(0.80))
                    }
                }
                .frame(width: 60, height: 60, alignment: .center)

                Text(piece.name)
                    .font(.system(size: 16))
                    .foregroundStyle(isPlaced
                                     ? inkGrey.opacity(0.50)
                                     : warmGold.opacity(0.85))

                Text(piece.meaning)
                    .font(EgyptFont.body(10))
                    .foregroundStyle(isPlaced
                                     ? inkGrey.opacity(0.40)
                                     : inkGrey.opacity(0.70))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                          ? warmGold.opacity(0.12)
                          : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? warmGold : Color.clear,
                                    lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Piece Shape Mini-renderer

    @ViewBuilder
    private func pieceShape(piece: ChineseBoxPiece,
                             rotation: Int,
                             cellSize cs: CGFloat) -> some View {
        let cells = piece.cells(rotation: rotation)
        let maxRow = (cells.map { $0.0 }.max() ?? 0) + 1
        let maxCol = (cells.map { $0.1 }.max() ?? 0) + 1
        let pieceColor = Color(hex: piece.colorHex) ?? warmGold

        ZStack(alignment: .topLeading) {
            // Invisible bounding box to anchor the ZStack
            Color.clear
                .frame(width: CGFloat(maxCol) * cs,
                       height: CGFloat(maxRow) * cs)

            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                RoundedRectangle(cornerRadius: 2)
                    .fill(pieceColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.black.opacity(0.25), lineWidth: 0.5)
                    )
                    .frame(width: cs - 1, height: cs - 1)
                    .offset(x: CGFloat(cell.1) * cs + 0.5,
                            y: CGFloat(cell.0) * cs + 0.5)
            }
        }
        .frame(width: CGFloat(maxCol) * cs, height: CGFloat(maxRow) * cs)
    }

    // MARK: - Action Row

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button(action: {
                HapticFeedback.tap()
                verifyPlacement()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                    Text("Verify")
                        .font(EgyptFont.title(15))
                }
                .foregroundStyle(warmGold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(warmGold.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(warmGold.opacity(0.45), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Button(action: {
                HapticFeedback.tap()
                gameState.resetChinesePieces()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15))
                    Text("Reset")
                        .font(EgyptFont.title(15))
                }
                .foregroundStyle(inkGrey)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(inkGrey.opacity(0.30), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Verify Placement

    private func verifyPlacement() {
        let unplacedCount = level.pieces.filter {
            gameState.chinesePlacedPieces[$0.id] == nil
        }.count

        if unplacedCount > 0 || !level.isSolved(gameState.chinesePlacedPieces) {
            HapticFeedback.error()
            // Flash all empty cells briefly via showVerifyError
            withAnimation(.easeInOut(duration: 0.15)) {
                showVerifyError = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation { showVerifyError = false }
            }
        } else {
            HapticFeedback.heavy()
            // Already solved — GameState detects completion on piece placement,
            // but Verify acts as a secondary trigger for player confidence.
        }
    }

    // MARK: - Collapsible Inscriptions

    private var inscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                HapticFeedback.tap()
                withAnimation(.easeInOut(duration: 0.25)) {
                    inscriptionsExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: inscriptionsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                    Text("Field Inscriptions")
                        .font(EgyptFont.title(13))
                        .tracking(1)
                    Spacer()
                    Text("\(level.inscriptions.count) entries")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(warmGold.opacity(0.50))
                }
                .foregroundStyle(warmGold.opacity(0.70))
                .padding(14)
            }
            .buttonStyle(.plain)

            if inscriptionsExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(level.inscriptions.enumerated()), id: \.offset) { _, note in
                        HStack(alignment: .top, spacing: 10) {
                            Text("–")
                                .font(EgyptFont.body(13))
                                .foregroundStyle(warmGold.opacity(0.40))
                            Text(note)
                                .font(EgyptFont.bodyItalic(14))
                                .foregroundStyle(Color.papyrus.opacity(0.75))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.05, blue: 0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(vermillion.opacity(0.18), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Level Complete Card

    private var levelCompleteCard: some View {
        VStack(spacing: 20) {
            Image(systemName: level.artifactSymbol)
                .font(.system(size: 64))
                .foregroundStyle(warmGold)
                .shadow(color: warmGold.opacity(0.55), radius: 14, x: 0, y: 0)

            VStack(spacing: 8) {
                Text("Box Complete")
                    .font(EgyptFont.titleBold(26))
                    .foregroundStyle(warmGold)
                    .tracking(2)
                Text(level.journalTitle)
                    .font(EgyptFont.bodyItalic(17))
                    .foregroundStyle(warmGold.opacity(0.75))
            }

            if messageRevealed {
                Text(level.decodedMessage)
                    .font(EgyptFont.bodyItalic(15))
                    .foregroundStyle(Color.papyrus.opacity(0.85))
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .transition(.opacity)
            }

            VStack(spacing: 10) {
                Button(action: {
                    HapticFeedback.tap()
                    gameState.advanceChineseToNextLevel()
                }) {
                    StoneButton(title: "Next Chamber", icon: "arrow.right", style: .gold)
                }
                .buttonStyle(.plain)

                Button(action: {
                    HapticFeedback.tap()
                    gameState.closeChineseGame()
                    gameState.openJournal()
                }) {
                    StoneButton(title: "Open Field Diary", icon: "book.fill", style: .muted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(lacquerBlack)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(warmGold.opacity(0.50), lineWidth: 1.2)
                )
        )
        .shadow(color: .black.opacity(0.55), radius: 22, x: 0, y: 8)
        .padding(.horizontal, 28)
    }

    // MARK: - Background

    private var lacquerBackground: some View {
        ZStack {
            lacquerBlack
            RadialGradient(
                colors: [
                    Color(red: 0.20, green: 0.10, blue: 0.02).opacity(0.50),
                    .clear
                ],
                center: .topLeading,
                startRadius: 60,
                endRadius: 440
            )
        }
    }
}
