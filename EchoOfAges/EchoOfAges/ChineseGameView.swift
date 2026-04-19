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
    @State private var showHelp:          Bool = false

    // Drag-to-place state
    @State private var draggedPieceId: String?           = nil
    @State private var ghostAnchor: (row: Int, col: Int)? = nil
    @State private var cellGridOrigin: CGPoint            = .zero

    // Gate mark reveal glow — briefly highlights the two adjacent marked cells on L1 solve
    @State private var glowGateCells: Bool = false

    private var level: ChineseBoxLevel { gameState.chineseCurrentLevel }

    // MARK: - Colors

    private var trayFrame:  Color { Color(hex: "4A2810") ?? Color(red: 0.29, green: 0.16, blue: 0.06) }
    private var emptyCell:  Color { (Color(hex: "D4A96A") ?? Color(red: 0.83, green: 0.66, blue: 0.42)).opacity(0.35) }
    private var cellBorder: Color { (Color(hex: "5C3520") ?? Color(red: 0.36, green: 0.21, blue: 0.13)).opacity(0.50) }
    private var warmGold:   Color { Color.goldDark }
    private var vermillion: Color { Color(red: 0.78, green: 0.16, blue: 0.09) }
    private var inkGrey:    Color { Color.stoneLight }

    // MARK: - Body

    // Cell size computed from screen width — avoids GeometryReader height estimation bugs.
    private var computedCellSize: CGFloat {
        let screenW = UIScreen.main.bounds.width
        let available = min(screenW - 36, 560.0)
        return max(44, available / CGFloat(level.cols))
    }

    var body: some View {
        ZStack {
            Color.papyrus.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        levelHeader
                        boardSection(cellSize: computedCellSize)
                        // Palette + action buttons in a shared card
                        VStack(spacing: 12) {
                            piecesPalette
                            actionRow
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.stoneMid.opacity(0.20))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(vermillion.opacity(0.30), lineWidth: 1))
                        )
                        inscriptionsSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }

            if showHelp {
                Color.black.opacity(0.55).ignoresSafeArea()
                    .onTapGesture { withAnimation { showHelp = false } }
                    .transition(.opacity).zIndex(9)
                chineseHelpDialog
                    .transition(.scale(scale: 0.93).combined(with: .opacity))
                    .zIndex(10)
            }

            if showComplete {
                Color.black.opacity(0.60).ignoresSafeArea()
                    .transition(.opacity).zIndex(11)
                levelCompleteCard
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .zIndex(12)
            }
        }
        .onChange(of: gameState.chinesePendingComplete) { _, newVal in
            if newVal {
                if gameState.chineseCurrentLevelIndex == 0 {
                    // Level 1: let the player see the solved board and the two gate marks
                    // glowing side by side for 5 seconds before the completion card appears.
                    Task {
                        // Glow on immediately
                        withAnimation(.easeInOut(duration: 0.35)) { glowGateCells = true }
                        // Hold glow for ~3 s, then fade — card arrives at 5 s
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        withAnimation(.easeOut(duration: 0.5)) { glowGateCells = false }
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                            showComplete = true
                        }
                        try? await Task.sleep(nanoseconds: 700_000_000)
                        withAnimation(.easeOut(duration: 0.6)) { messageRevealed = true }
                    }
                } else {
                    // All other levels: show completion card immediately
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                        showComplete = true
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 700_000_000)
                        withAnimation(.easeOut(duration: 0.6)) { messageRevealed = true }
                    }
                }
            } else {
                glowGateCells = false
                withAnimation(.easeOut(duration: 0.25)) {
                    showComplete = false
                    messageRevealed = false
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
            Button {
                HapticFeedback.tap()
                gameState.closeChineseGame()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Return")
                        .font(EgyptFont.titleBold(15))
                }
                .foregroundStyle(vermillion)
            }
            .frame(minWidth: 80, alignment: .leading)

            Spacer()

            Text("木工  Chinese")
                .font(EgyptFont.titleBold(16))
                .foregroundStyle(vermillion)
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            HStack(spacing: 10) {
                Text(level.romanNumeral)
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(warmGold.opacity(0.85))
                Button { withAnimation { showHelp = true } } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(warmGold)
                }
                .buttonStyle(.plain)
            }
            .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.stoneDark
                .overlay(
                    Rectangle()
                        .fill(vermillion.opacity(0.50))
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
                .foregroundStyle(Color.stoneDark)
            Text(level.subtitle)
                .font(EgyptFont.bodyItalic(14))
                .foregroundStyle(Color.stoneLight)
            Text(level.lore)
                .font(EgyptFont.body(13))
                .foregroundStyle(Color.stoneDark.opacity(0.75))
                .lineSpacing(3)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.stoneMid.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.stoneMid.opacity(0.40), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Board Section

    private func boardSection(cellSize cs: CGFloat) -> some View {
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
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                cellGridOrigin = geo.frame(in: .global).origin
                            }
                            .onChange(of: geo.frame(in: .global).origin) { _, newOrigin in
                                cellGridOrigin = newOrigin
                            }
                    }
                )
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
                let placement = gameState.chinesePlacedPieces[pieceId]
                let gateMark  = placement.flatMap { piece.gateMarkBoardCell(at: $0) }
                let isMarkCell = gateMark.map { $0.row == row && $0.col == col } ?? false
                let glowing   = isMarkCell && glowGateCells

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: piece.colorHex) ?? warmGold)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black.opacity(0.20), lineWidth: 0.5)
                    )
                    .shadow(color: glowing
                            ? Color.white.opacity(0.90)
                            : Color.black.opacity(0.25),
                            radius: glowing ? 10 : 2, x: 0, y: 1)
                    .padding(1)

                if isMarkCell, let symbol = gateMark?.symbol {
                    // Gate mark carved into the wood — larger than piece name
                    Text(symbol)
                        .font(.system(size: cs * 0.46))
                        .foregroundStyle(Color.black.opacity(glowing ? 0.90 : 0.55))
                        .shadow(color: glowing ? Color.white.opacity(0.80) : .clear,
                                radius: 6, x: 0, y: 0)
                } else {
                    // Piece name character (small, centered)
                    Text(piece.name)
                        .font(.system(size: cs * 0.28, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.35))
                }
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

            // Ghost overlay — shown while dragging a piece from the palette
            if let dId = draggedPieceId,
               let anchor = ghostAnchor,
               let piece = level.pieces.first(where: { $0.id == dId }),
               occupantId == nil {
                let rotation = gameState.chineseArmedRotation
                let pieceCells = piece.cells(rotation: rotation)
                let isGhostCell = pieceCells.contains(where: {
                    anchor.row + $0.0 == row && anchor.col + $0.1 == col
                })
                if isGhostCell {
                    let proposed = ChinesePiecePlacement(
                        row: anchor.row, col: anchor.col, rotation: rotation)
                    let valid = level.isValidPlacement(
                        piece: piece, proposed: proposed,
                        existing: gameState.chinesePlacedPieces)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(valid
                              ? Color.green.opacity(0.50)
                              : Color.red.opacity(0.50))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(valid
                                        ? Color.green.opacity(0.80)
                                        : Color.red.opacity(0.80),
                                        lineWidth: 1.5)
                        )
                        .padding(1)
                }
            }
        }
        .frame(width: cs, height: cs)
        .contentShape(Rectangle())
        .onTapGesture {
            handleBoardTap(row: row, col: col, board: board)
        }
    }

    // MARK: - Board Tap Handling

    /// Converts a global drag coordinate to a board (row, col) and stores it in ghostAnchor.
    /// Sets ghostAnchor to nil when the finger is outside the board.
    private func updateGhostAnchor(at globalPoint: CGPoint, cellSize cs: CGFloat) {
        let x = globalPoint.x - cellGridOrigin.x
        let y = globalPoint.y - cellGridOrigin.y
        let col = Int(x / cs)
        let row = Int(y / cs)
        if row >= 0 && row < level.rows && col >= 0 && col < level.cols {
            ghostAnchor = (row: row, col: col)
        } else {
            ghostAnchor = nil
        }
    }

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
                .foregroundStyle(Color.stoneLight)
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
                .fill(Color.stoneMid.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.stoneMid.opacity(0.35), lineWidth: 0.8)
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
        .simultaneousGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .onChanged { value in
                    if draggedPieceId == nil {
                        draggedPieceId = piece.id
                        // Only call selectChinesePiece when this piece isn't already armed.
                        // selectChinesePiece rotates when the same ID is passed in, which
                        // would clobber the rotation the user just set.
                        if gameState.chineseSelectedPieceId != piece.id {
                            gameState.selectChinesePiece(id: piece.id)
                        }
                    }
                    updateGhostAnchor(at: value.location, cellSize: computedCellSize)
                }
                .onEnded { value in
                    defer {
                        draggedPieceId = nil
                        ghostAnchor   = nil
                    }
                    guard let anchor = ghostAnchor,
                          let pid    = draggedPieceId,
                          !isPlaced,
                          let p = level.pieces.first(where: { $0.id == pid }) else { return }
                    let rotation = gameState.chineseArmedRotation
                    let proposed = ChinesePiecePlacement(
                        row: anchor.row, col: anchor.col, rotation: rotation)
                    if level.isValidPlacement(piece: p, proposed: proposed,
                                              existing: gameState.chinesePlacedPieces) {
                        HapticFeedback.tap()
                        gameState.placeChinesePiece(id: pid, row: anchor.row, col: anchor.col)
                    } else {
                        HapticFeedback.error()
                    }
                }
        )
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
        // Which local cell index carries the gate mark at this rotation?
        let markLocalCell: (Int, Int)? = piece.gateMarkCellIndex.map { cells[$0] }

        ZStack(alignment: .topLeading) {
            // Invisible bounding box to anchor the ZStack
            Color.clear
                .frame(width: CGFloat(maxCol) * cs,
                       height: CGFloat(maxRow) * cs)

            ForEach(Array(cells.enumerated()), id: \.offset) { idx, cell in
                let isMarkCell = markLocalCell.map { $0.0 == cell.0 && $0.1 == cell.1 } ?? false
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(pieceColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.black.opacity(0.25), lineWidth: 0.5)
                        )
                        .frame(width: cs - 1, height: cs - 1)

                    if isMarkCell, let symbol = piece.gateMarkSymbol {
                        Text(symbol)
                            .font(.system(size: cs * 0.55))
                            .foregroundStyle(Color.black.opacity(0.60))
                    }
                }
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
                gameState.resetChinesePieces()
            }) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(Color.stoneLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.stoneMid.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(Color.stoneMid.opacity(0.40), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Button(action: {
                HapticFeedback.tap()
                verifyPlacement()
            }) {
                Label("Decipher", systemImage: "checkmark.seal")
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(Color.stoneDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(warmGold)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(warmGold.opacity(0.6), lineWidth: 1)
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
                let acrostic = TreeOfLifeKeys.acrosticLetter(for: .chinese, levelIndex: gameState.chineseCurrentLevelIndex)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(level.inscriptions.enumerated()), id: \.offset) { _, note in
                        HStack(alignment: .top, spacing: 10) {
                            Text("–")
                                .font(EgyptFont.body(13))
                                .foregroundStyle(warmGold.opacity(0.40))
                            Text(acrosticUnderlined(note, letter: acrostic))
                                .font(EgyptFont.bodyItalic(14))
                                .foregroundStyle(Color.stoneDark.opacity(0.75))
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
                .fill(Color.stoneMid.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.stoneMid.opacity(0.35), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Help Dialog

    private var chineseHelpDialog: some View {
        let accent = warmGold
        let bg     = Color(red: 0.08, green: 0.05, blue: 0.02)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("木  How to Play")
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

            chineseHelpRow(number: "1", title: "Select a piece from the tray",
                           body: "Tap any wooden piece at the bottom to select it. The selected piece is highlighted. Some pieces carry a foreign mark carved into the wood — pay attention to where they land.")
            chineseHelpRow(number: "2", title: "Rotate before placing",
                           body: "Tap the Rotate button to turn the selected piece 90° clockwise. Pieces can be rotated up to three times.")
            chineseHelpRow(number: "3", title: "Drag the piece onto the board",
                           body: "Drag the selected piece from the palette and drop it onto the board. A green ghost shows where it will land — red means it won't fit. You can also tap an empty board cell to place it.")
            chineseHelpRow(number: "4", title: "Fill the board completely",
                           body: "All pieces must fit on the board without overlapping. The puzzle solves automatically once every cell is covered.")

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

    private func chineseHelpRow(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(EgyptFont.titleBold(16))
                .foregroundStyle(warmGold)
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

    // MARK: - Level Complete Card

    private var levelCompleteCard: some View {
        let isLastLevel   = gameState.chineseCurrentLevelIndex == ChineseBoxLevel.allLevels.count - 1
        let allComplete   = gameState.allSixCivsComplete
        let newCivs       = isLastLevel ? gameState.newlyUnlockedCivs(completingLevel5Of: .chinese) : []

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer(minLength: 20)

                Image(systemName: level.artifactSymbol)
                    .font(.system(size: 60))
                    .foregroundStyle(warmGold)
                    .shadow(color: warmGold.opacity(0.55), radius: 14, x: 0, y: 0)

                VStack(spacing: 8) {
                    Text(isLastLevel && allComplete ? "All Six Keys Gathered" : "Box Complete")
                        .font(EgyptFont.titleBold(26))
                        .foregroundStyle(warmGold)
                        .tracking(2)
                    Text(level.journalTitle)
                        .font(EgyptFont.bodyItalic(17))
                        .foregroundStyle(warmGold.opacity(0.75))
                }

                WinnerScene(imageName: "chinese_final",
                            completedLevelIndex: gameState.chineseCurrentLevelIndex)

                if messageRevealed {
                    Text(level.decodedMessage)
                        .font(EgyptFont.bodyItalic(15))
                        .foregroundStyle(Color.papyrus.opacity(0.85))
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .transition(.opacity)

                    // Journal nudge
                    HStack(spacing: 8) {
                        Image(systemName: "book.fill").font(.system(size: 11))
                            .foregroundStyle(warmGold.opacity(0.60))
                        Text("A new entry has been written in your Field Diary.")
                            .font(EgyptFont.bodyItalic(13))
                            .foregroundStyle(warmGold.opacity(0.60))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .transition(.opacity)

                    // Level 5 — key earned + Mandu call-to-action
                    if isLastLevel {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "key.fill").font(.system(size: 12))
                                    .foregroundStyle(warmGold)
                                Text("The Chinese key has been carved in your Field Diary.")
                                    .font(EgyptFont.bodyItalic(13))
                                    .foregroundStyle(warmGold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if allComplete {
                                Rectangle()
                                    .fill(warmGold.opacity(0.25))
                                    .frame(height: 0.8)
                                    .padding(.vertical, 4)

                                HStack(spacing: 10) {
                                    Image(systemName: "seal.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(warmGold)
                                    Text("Six peoples. Six keys.\nThe Mandu Tablet awaits.")
                                        .font(EgyptFont.bodyItalic(14))
                                        .foregroundStyle(Color.papyrus)
                                        .lineSpacing(4)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else if !newCivs.isEmpty {
                                Text("NEW PATHS OPEN")
                                    .font(EgyptFont.title(11))
                                    .foregroundStyle(warmGold.opacity(0.55))
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
                                            .foregroundStyle(warmGold)
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.stoneMid.opacity(0.18))
                                            .overlay(RoundedRectangle(cornerRadius: 8)
                                                .stroke(civ.accentColor.opacity(0.35), lineWidth: 1))
                                    )
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.stoneMid.opacity(0.20))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(warmGold.opacity(0.30), lineWidth: 1))
                        )
                        .transition(.opacity)
                    }
                }

                VStack(spacing: 10) {
                    if isLastLevel && allComplete {
                        Button {
                            HapticFeedback.heavy()
                            gameState.chinesePendingComplete = false
                            withAnimation(.easeInOut(duration: 0.4)) { gameState.openManduTablet() }
                        } label: {
                            StoneButton(title: "Open the Mandu Tablet", icon: "seal.fill", style: .gold)
                        }
                        .buttonStyle(.plain)
                    } else if isLastLevel {
                        Button {
                            HapticFeedback.heavy()
                            gameState.chinesePendingComplete = false
                            withAnimation(.easeInOut(duration: 0.4)) { gameState.startNewGame() }
                        } label: {
                            StoneButton(title: "Continue Expedition", icon: "arrow.right", style: .gold)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            HapticFeedback.tap()
                            gameState.advanceChineseToNextLevel()
                        } label: {
                            StoneButton(title: "Next Chamber", icon: "arrow.right", style: .gold)
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
                        .stroke(warmGold.opacity(0.50), lineWidth: 1.2)
                )
        )
        .shadow(color: .black.opacity(0.55), radius: 22, x: 0, y: 8)
        .padding(.horizontal, 24)
        .frame(maxHeight: UIScreen.main.bounds.height * 0.82)
    }

}
