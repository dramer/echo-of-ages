// PathGameView.swift
// EchoOfAges
//
// Norse pathfinding puzzle screen.
// The player traces a Hamiltonian path through a runestone grid guided by
// visible rune waypoints. Tap to extend the path; tap the last cell to backtrack.
// The path auto-verifies when every cell has been visited.

import SwiftUI

// MARK: - PathGameView

struct PathGameView: View {
    @EnvironmentObject var gameState: GameState

    // Toast
    @State private var toastMessage:     String = ""
    @State private var toastVisible:     Bool   = false
    @State private var toastDismissTask: Task<Void, Never>? = nil

    // Help
    @State private var showHelp: Bool = false

    // Inscription panel
    @State private var showRuneInscriptions: Bool = false

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                norseBackground

                if geo.size.width > geo.size.height {
                    landscapeLayout(geo: geo)
                } else {
                    portraitLayout(geo: geo)
                }

                // Completion overlay
                if gameState.norseIsAnimatingCompletion {
                    completionOverlay
                        .transition(.opacity)
                        .zIndex(8)
                }

                // Inscription panel overlay
                if showRuneInscriptions {
                    runeInscriptionPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(7)
                }

                // Help overlay
                if showHelp {
                    Color.black.opacity(0.55).ignoresSafeArea()
                        .onTapGesture { withAnimation { showHelp = false } }
                        .transition(.opacity).zIndex(9)
                    norseHelpDialog
                        .transition(.scale(scale: 0.93).combined(with: .opacity))
                        .zIndex(10)
                }

                // Toast overlay
                if toastVisible {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(9)
                    ToastView(message: toastMessage)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.88).combined(with: .opacity),
                            removal: .opacity))
                        .zIndex(10)
                }
            }
        }
        .background(norseBackground)
        .onChange(of: gameState.norsePenaltyMessage) { _, message in
            guard let message else { return }
            showToast(message, duration: 6.0)
        }
    }

    // MARK: Portrait Layout

    @ViewBuilder
    private func portraitLayout(geo: GeometryProxy) -> some View {
        let barH:       CGFloat = 48
        let titleH:     CGFloat = 76
        let runeBarH:   CGFloat = 64
        let actionBarH: CGFloat = 48
        let spacing:    CGFloat = 8 * 4
        let safeBottom: CGFloat = 16
        let reserved    = barH + titleH + runeBarH + actionBarH + spacing + safeBottom
        let gridAvailH  = geo.size.height - reserved
        let gridAvailW  = geo.size.width - 32

        VStack(spacing: 0) {
            norseHeaderBar

            Spacer(minLength: 8)
            levelTitle.padding(.horizontal, 16)
            Spacer(minLength: 8)

            pathGrid(availableWidth: gridAvailW, availableHeight: max(gridAvailH, 100))
                .padding(.horizontal, 16)

            Spacer(minLength: 10)
            waypointBar.padding(.horizontal, 16)
            Spacer(minLength: 8)
            norseActionRow.padding(.horizontal, 16)
            Spacer(minLength: safeBottom)
        }
    }

    // MARK: Landscape Layout

    @ViewBuilder
    private func landscapeLayout(geo: GeometryProxy) -> some View {
        let leftW      = geo.size.width * 0.60
        let rightW     = geo.size.width - leftW
        let barH:  CGFloat = 48
        let gridAvailW = leftW - 28
        let gridAvailH = geo.size.height - barH - 28

        VStack(spacing: 0) {
            norseHeaderBar

            HStack(spacing: 0) {
                VStack(spacing: 6) {
                    pathGrid(availableWidth: gridAvailW, availableHeight: max(gridAvailH, 80))
                        .padding(.horizontal, 14)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                .frame(width: leftW)

                Rectangle()
                    .fill(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.18))
                    .frame(width: 1)
                    .padding(.vertical, 16)

                VStack(spacing: 0) {
                    levelTitle
                    Spacer(minLength: 10)
                    waypointBar
                    Spacer(minLength: 8)
                    norseActionRow
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(width: rightW)
            }
        }
    }

    // MARK: Standard Header Bar (Norse)

    private var norseHeaderBar: some View {
        let norsBlue = Color(red: 0.45, green: 0.75, blue: 1.0)
        return HStack {
            Button {
                HapticFeedback.tap()
                gameState.closeNorseGame()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Return")
                        .font(EgyptFont.titleBold(15))
                }
                .foregroundStyle(norsBlue)
            }
            .frame(minWidth: 80, alignment: .leading)

            Spacer()

            Text("ᚱ  Norse")
                .font(EgyptFont.titleBold(16))
                .foregroundStyle(norsBlue)
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            HStack(spacing: 10) {
                Text(gameState.norseCurrentLevel.romanNumeral)
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(norsBlue.opacity(0.75))
                Button { withAnimation { showHelp = true } } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(norsBlue)
                }
            }
            .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(red: 0.08, green: 0.12, blue: 0.20)
                .overlay(
                    Rectangle()
                        .fill(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.3))
                        .frame(height: 0.8),
                    alignment: .bottom
                )
        )
    }

    // MARK: Norse Action Row (Reset + Runes + Journal) — below waypoints

    private var norseActionRow: some View {
        let norsBlue = Color(red: 0.45, green: 0.75, blue: 1.0)
        let resetsLeft  = max(0, 2 - gameState.norseResetCount)
        let willDrawNew = gameState.norseResetCount >= 2
        let dots = (0..<2).map { $0 < resetsLeft ? "●" : "○" }.joined(separator: " ")

        return HStack(spacing: 10) {
            // Reset / New puzzle
            Button {
                HapticFeedback.tap()
                gameState.resetNorsePath()
            } label: {
                VStack(spacing: 2) {
                    Label(willDrawNew ? "New" : "Reset",
                          systemImage: willDrawNew ? "shuffle" : "arrow.counterclockwise")
                        .font(EgyptFont.titleBold(13))
                    Text(dots)
                        .font(.system(size: 9))
                        .foregroundStyle(willDrawNew
                            ? Color(red: 0.85, green: 0.45, blue: 0.35)
                            : norsBlue.opacity(0.7))
                }
                .foregroundStyle(norsBlue.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(norsBlue.opacity(0.25), lineWidth: 0.8))
                )
            }

            // Runes toggle
            Button {
                HapticFeedback.tap()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    showRuneInscriptions.toggle()
                }
            } label: {
                Label("Runes", systemImage: showRuneInscriptions ? "scroll.fill" : "scroll")
                    .font(EgyptFont.titleBold(13))
                    .foregroundStyle(showRuneInscriptions ? norsBlue : norsBlue.opacity(0.65))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(showRuneInscriptions
                                  ? norsBlue.opacity(0.12)
                                  : Color.white.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(norsBlue.opacity(0.25), lineWidth: 0.8))
                    )
            }

            // Journal
            Button {
                HapticFeedback.tap()
                gameState.openJournal()
            } label: {
                Label("Journal", systemImage: "book.fill")
                    .font(EgyptFont.titleBold(13))
                    .foregroundStyle(norsBlue.opacity(0.65))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(norsBlue.opacity(0.25), lineWidth: 0.8))
                    )
            }
        }
    }

    // MARK: Level Title

    private var levelTitle: some View {
        VStack(spacing: 3) {
            Text("· \(gameState.norseCurrentLevel.romanNumeral) · \(gameState.norseCurrentLevel.title.uppercased())")
                .font(EgyptFont.titleBold(17))
                .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 1.0))
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(gameState.norseCurrentLevel.subtitle)
                .font(EgyptFont.bodyItalic(14))
                .foregroundStyle(Color(red: 0.75, green: 0.90, blue: 1.0).opacity(0.7))
                .lineLimit(1)
            // Path progress
            let total   = gameState.norseCurrentLevel.totalCells
            let placed  = gameState.norsePath.count
            Text("\(placed) of \(total) stones traced")
                .font(EgyptFont.body(12))
                .foregroundStyle(placed == 0
                    ? Color(red: 0.45, green: 0.65, blue: 0.85).opacity(0.6)
                    : Color(red: 0.45, green: 0.85, blue: 0.65))
                .padding(.top, 1)
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 2)
    }

    // MARK: Waypoint Bar (shows rune sequence at bottom)

    private var waypointBar: some View {
        let level    = gameState.norseCurrentLevel
        let path     = gameState.norsePath
        // On Level 1, the start waypoint rune is the player-selected mystery mark symbol.
        let keyGateActive = gameState.norseCurrentLevelIndex == 0
                         && gameState.needsKeyGate(for: .norse)

        return VStack(spacing: 6) {
            Text("Waypoints — visit in order")
                .font(EgyptFont.body(12))
                .foregroundStyle(Color(red: 0.55, green: 0.75, blue: 0.95).opacity(0.7))

            HStack(spacing: 6) {
                ForEach(level.waypoints.sorted(by: { $0.pathIndex < $1.pathIndex })) { wp in
                    let reached = path.count > wp.pathIndex && path[wp.pathIndex] == wp.position
                    // Use the live mystery mark for the start waypoint while the key gate is open
                    let rawRune = (wp.isStart && keyGateActive)
                        ? gameState.mysteryMarkCurrent(for: .norse)
                        : wp.rune
                    let displayRune = (wp.isStart && keyGateActive && rawRune.isEmpty) ? "?" : rawRune
                    let isUnknown   = wp.isStart && keyGateActive && rawRune.isEmpty
                    VStack(spacing: 2) {
                        Text(displayRune)
                            .contentTransition(.numericText())
                            .font(.system(size: 20))
                            .foregroundStyle(isUnknown
                                ? Color(red: 0.90, green: 0.72, blue: 0.25).opacity(0.85)
                                : (reached
                                    ? Color(red: 0.30, green: 0.90, blue: 0.55)
                                    : (wp.isStart ? Color(red: 0.55, green: 0.95, blue: 0.65)
                                                 : Color(red: 0.85, green: 0.72, blue: 0.40))))
                        Text(wp.isStart ? "Start" : wp.isEnd ? "End" : wp.runeName)
                            .font(EgyptFont.body(9))
                            .foregroundStyle(Color(red: 0.65, green: 0.80, blue: 0.95).opacity(0.65))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(reached
                                ? Color(red: 0.10, green: 0.30, blue: 0.20).opacity(0.8)
                                : Color(red: 0.08, green: 0.14, blue: 0.22))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(reached
                                    ? Color(red: 0.30, green: 0.90, blue: 0.55).opacity(0.7)
                                    : Color(red: 0.45, green: 0.65, blue: 0.85).opacity(0.25),
                                        lineWidth: 0.8))
                    )
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: Path Grid

    private func pathGrid(availableWidth: CGFloat, availableHeight: CGFloat) -> some View {
        let level   = gameState.norseCurrentLevel
        let spacing = gridSpacing
        let pad     = gridPadding
        let cs      = cellSize(cols: level.cols, rows: level.rows,
                               availableWidth: availableWidth, availableHeight: availableHeight)
        let gridW   = CGFloat(level.cols) * cs + CGFloat(level.cols - 1) * spacing + 2 * pad
        let gridH   = CGFloat(level.rows) * cs + CGFloat(level.rows - 1) * spacing + 2 * pad

        return ZStack {
            // Grid cells
            VStack(spacing: spacing) {
                ForEach(0..<level.rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<level.cols, id: \.self) { col in
                            let pos = GridPosition(row: row, col: col)
                            let isKeyGateStart = pos == level.startPosition
                                && gameState.norseCurrentLevelIndex == 0
                                && gameState.needsKeyGate(for: .norse)
                            PathCellView(
                                position: pos,
                                level: level,
                                path: gameState.norsePath,
                                errorCells: gameState.norseErrorCells,
                                isAnimatingCompletion: gameState.norseIsAnimatingCompletion,
                                size: cs,
                                mysteryMarkSymbol: isKeyGateStart
                                    ? gameState.mysteryMarkCurrent(for: .norse)
                                    : nil
                            ) {
                                gameState.tapNorseCell(at: pos)
                            }
                        }
                    }
                }
            }
            .padding(pad)

            // Path connection lines drawn on top
            Canvas { ctx, _ in
                drawPathLines(ctx: ctx, path: gameState.norsePath,
                              cellSize: cs, spacing: spacing, padding: pad,
                              errorCells: gameState.norseErrorCells)
            }
            .allowsHitTesting(false)
            .frame(width: gridW, height: gridH)
        }
        .frame(width: gridW, height: gridH)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.05, green: 0.09, blue: 0.16).opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.3), lineWidth: 1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.45, green: 0.85, blue: 0.65), lineWidth: 2.5)
                .opacity(gameState.norseIsAnimatingCompletion ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).repeatCount(4, autoreverses: true),
                           value: gameState.norseIsAnimatingCompletion)
        )
    }

    // MARK: Grid Metrics

    private let gridSpacing: CGFloat = 5
    private let gridPadding: CGFloat = 10

    private func cellSize(cols: Int, rows: Int,
                          availableWidth: CGFloat, availableHeight: CGFloat) -> CGFloat {
        let hs  = CGFloat(cols - 1) * gridSpacing
        let vs  = CGFloat(rows - 1) * gridSpacing
        let byW = (availableWidth  - hs - 2 * gridPadding) / CGFloat(cols)
        let byH = (availableHeight - vs - 2 * gridPadding) / CGFloat(rows)
        return min(byW, byH, 80)
    }

    // MARK: Path Line Drawing (Canvas)

    private func drawPathLines(ctx: GraphicsContext, path: [GridPosition],
                               cellSize cs: CGFloat, spacing sp: CGFloat,
                               padding pad: CGFloat, errorCells: Set<GridPosition>) {
        guard path.count > 1 else { return }

        func center(_ pos: GridPosition) -> CGPoint {
            CGPoint(
                x: pad + CGFloat(pos.col) * (cs + sp) + cs / 2,
                y: pad + CGFloat(pos.row) * (cs + sp) + cs / 2
            )
        }

        let isError = !errorCells.isEmpty
        let lineColor = isError
            ? Color(red: 0.85, green: 0.20, blue: 0.20).opacity(0.75)
            : Color(red: 0.55, green: 0.85, blue: 1.00).opacity(0.65)

        var linePath = Path()
        linePath.move(to: center(path[0]))
        for i in 1..<path.count {
            linePath.addLine(to: center(path[i]))
        }
        ctx.stroke(linePath, with: .color(lineColor),
                   style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
    }

    // MARK: Completion Overlay

    private var completionOverlay: some View {
        let isLastLevel = gameState.norseCurrentLevelIndex == PathLevel.allLevels.count - 1
        let newCivs     = isLastLevel ? gameState.newlyUnlockedCivs(completingLevel5Of: .norse) : []
        let accentBlue  = Color(red: 0.45, green: 0.85, blue: 1.0)
        let accentGreen = Color(red: 0.45, green: 0.85, blue: 0.65)

        return ZStack {
            Color.black.opacity(0.60).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 30)

                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 10) {
                            Text("ᚠ")
                                .font(.system(size: 64))
                                .foregroundStyle(accentGreen)
                                .shadow(color: accentGreen.opacity(0.7), radius: 10, x: 0, y: 0)

                            Text("Path Complete")
                                .font(EgyptFont.titleBold(28))
                                .foregroundStyle(accentGreen)
                                .tracking(3)

                            Text(gameState.norseCurrentLevel.title)
                                .font(EgyptFont.bodyItalic(17))
                                .foregroundStyle(accentBlue.opacity(0.8))
                        }

                        // Winner image
                        WinnerScene(imageName: "norse_final",
                                    completedLevelIndex: gameState.norseCurrentLevelIndex)

                        // Decoded message
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Rune Message", systemImage: "scroll")
                                .font(EgyptFont.title(11))
                                .foregroundStyle(accentBlue.opacity(0.65))
                                .tracking(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(gameState.norseCurrentLevel.decodedMessage)
                                .font(EgyptFont.bodyItalic(15))
                                .foregroundStyle(Color(red: 0.85, green: 0.92, blue: 1.0).opacity(0.80))
                                .lineSpacing(5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.06, green: 0.12, blue: 0.22).opacity(0.80))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(accentBlue.opacity(0.30), lineWidth: 1))
                        )

                        // Journal nudge
                        HStack(spacing: 8) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(accentBlue.opacity(0.65))
                            Text("A new entry has been written in your Field Diary.")
                                .font(EgyptFont.bodyItalic(13))
                                .foregroundStyle(accentBlue.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Level 5 — key earned + newly unlocked civs
                        if isLastLevel {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.goldMid)
                                    Text("The Norse key has been carved in your Field Diary.")
                                        .font(EgyptFont.bodyItalic(13))
                                        .foregroundStyle(Color.goldMid)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                if !newCivs.isEmpty {
                                    Text("NEW PATHS OPEN")
                                        .font(EgyptFont.title(11))
                                        .foregroundStyle(accentBlue.opacity(0.55))
                                        .tracking(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    ForEach(newCivs) { civ in
                                        HStack(spacing: 12) {
                                            Text(civ.emblem).font(.system(size: 24))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(civ.name)
                                                    .font(EgyptFont.titleBold(14))
                                                    .foregroundStyle(civ.accentColor)
                                                Text(civ.era)
                                                    .font(EgyptFont.bodyItalic(12))
                                                    .foregroundStyle(Color(red: 0.80, green: 0.90, blue: 1.0).opacity(0.55))
                                            }
                                            Spacer()
                                            Image(systemName: "lock.open.fill")
                                                .font(.system(size: 13))
                                                .foregroundStyle(Color.goldMid)
                                        }
                                        .padding(10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(red: 0.06, green: 0.12, blue: 0.22).opacity(0.6))
                                                .overlay(RoundedRectangle(cornerRadius: 8)
                                                    .stroke(civ.accentColor.opacity(0.35), lineWidth: 1))
                                        )
                                    }
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(red: 0.05, green: 0.10, blue: 0.18).opacity(0.75))
                                    .overlay(RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.goldMid.opacity(0.35), lineWidth: 1))
                            )
                        }

                        // Buttons
                        VStack(spacing: 10) {
                            if isLastLevel && gameState.allSixCivsComplete {
                                Button {
                                    HapticFeedback.heavy()
                                    gameState.norseIsAnimatingCompletion = false
                                    withAnimation(.easeInOut(duration: 0.4)) { gameState.openManduTablet() }
                                } label: {
                                    StoneButton(title: "Open the Mandu Tablet", icon: "seal.fill", style: .gold)
                                }
                            } else {
                                Button {
                                    HapticFeedback.tap()
                                    gameState.advanceNorseToNextLevel()
                                } label: {
                                    StoneButton(title: isLastLevel ? "Return to Title" : "Next Runestone",
                                                icon: isLastLevel ? "house.fill" : "arrow.right",
                                                style: .gold)
                                }
                            }

                            Button {
                                HapticFeedback.tap()
                                gameState.norseIsAnimatingCompletion = false
                                gameState.openJournal()
                            } label: {
                                StoneButton(title: "Open Field Diary", icon: "book.fill", style: .muted)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 0.04, green: 0.08, blue: 0.16))
                            .overlay(RoundedRectangle(cornerRadius: 20)
                                .stroke(accentGreen.opacity(0.55), lineWidth: 1.5))
                    )
                    .padding(.horizontal, 22)
                    .shadow(color: accentGreen.opacity(0.25), radius: 20, x: 0, y: 0)

                    Spacer(minLength: 30)
                }
            }
        }
    }

    // MARK: Toast

    private func showToast(_ message: String, duration: Double = 5.0) {
        toastDismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.45)) {
            toastMessage = message
            toastVisible = true
        }
        toastDismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            withAnimation(.easeIn(duration: 0.55)) { toastVisible = false }
        }
    }

    // MARK: Help Dialog

    private var norseHelpDialog: some View {
        let accent = Color(red: 0.55, green: 0.85, blue: 1.0)
        let bg     = Color(red: 0.08, green: 0.12, blue: 0.20)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ᚠ  How to Play")
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

            norseHelpRow(number: "1", title: "Start at the marked rune",
                         body: "Tap the highlighted starting stone to begin your path. You cannot start from any other cell.")
            norseHelpRow(number: "2", title: "Visit every stone exactly once",
                         body: "Tap any stone adjacent (up, down, left, right) to the current end of your path to extend it. Every valid stone must be visited — no stone can be skipped or revisited.")
            norseHelpRow(number: "3", title: "Backtrack by tapping the last stone",
                         body: "Tapping the stone at the tip of your path removes it, letting you try a different route. Tap Clear to start over.")
            norseHelpRow(number: "4", title: "Blocked stones",
                         body: "Dark stones marked with an X are impassable — route around them. They don't need to be visited.")

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

    private func norseHelpRow(number: String, title: String, body: String) -> some View {
        let accent = Color(red: 0.55, green: 0.85, blue: 1.0)
        return HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(EgyptFont.titleBold(16))
                .foregroundStyle(accent)
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

    // MARK: Rune Inscription Panel

    private var runeInscriptionPanel: some View {
        let level    = gameState.norseCurrentLevel
        let acrostic = TreeOfLifeKeys.acrosticLetter(for: .norse,
                                                     levelIndex: gameState.norseCurrentLevelIndex)
        return VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                // Handle / title bar
                HStack {
                    Text("RUNESTONE INSCRIPTION")
                        .font(EgyptFont.title(12))
                        .tracking(2)
                        .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 1.0))
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                            showRuneInscriptions = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.white.opacity(0.38))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 10)

                Divider()
                    .background(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.20))

                // Inscriptions with acrostic underline on the first note
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(level.inscriptions.enumerated()), id: \.offset) { i, note in
                            Group {
                                if i == 0 {
                                    Text(acrosticUnderlined(note, letter: acrostic))
                                } else {
                                    Text(note)
                                }
                            }
                            .font(EgyptFont.bodyItalic(15))
                            .foregroundStyle(Color(red: 0.85, green: 0.92, blue: 1.0).opacity(0.80))
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if i < level.inscriptions.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.08))
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
                .frame(maxHeight: 220)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.05, green: 0.10, blue: 0.18).opacity(0.97))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.22), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.55), radius: 14, x: 0, y: -5)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: Background

    private var norseBackground: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.13).ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.10, green: 0.22, blue: 0.38).opacity(0.55), .clear],
                center: .center, startRadius: 100, endRadius: 500
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Path Cell View

private struct PathCellView: View {
    let position: GridPosition
    let level: PathLevel
    let path: [GridPosition]
    let errorCells: Set<GridPosition>
    let isAnimatingCompletion: Bool
    let size: CGFloat
    let mysteryMarkSymbol: String?   // non-nil on the start cell when key gate is active
    let onTap: () -> Void

    private var isBlocked: Bool { level.isBlocked(position) }
    private var pathIndex: Int? { path.firstIndex(of: position) }
    private var isInPath:  Bool { pathIndex != nil }
    private var isPathEnd: Bool { path.last == position }
    private var isError:   Bool { errorCells.contains(position) }
    private var waypoint:  Waypoint? { level.waypoint(at: position) }
    private var isStart:   Bool { position == level.startPosition }
    private var isEnd:     Bool { position == level.endPosition }
    // True when this cell is the start cell with the key-gate mystery mark active (not yet locked into path)
    private var isMysteryCell: Bool { mysteryMarkSymbol != nil && isStart && !isInPath }
    // True when isMysteryCell but no symbol has been selected yet — show a "?" prompt
    private var isMysteryUnselected: Bool { isMysteryCell && (mysteryMarkSymbol ?? "").isEmpty }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                cellBackground
                cellContent
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .disabled(isBlocked)
    }

    @ViewBuilder
    private var cellBackground: some View {
        if isMysteryCell {
            // Mystery mark start cell — glowing amber, inviting interaction
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.28, green: 0.20, blue: 0.06))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(red: 0.90, green: 0.72, blue: 0.25).opacity(0.85), lineWidth: 2))
        } else if isBlocked {
            // Impassable stone — dark, earthy, clearly inert
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.09, green: 0.08, blue: 0.07))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(red: 0.22, green: 0.18, blue: 0.14).opacity(0.7), lineWidth: 1))
        } else if isError {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.55, green: 0.08, blue: 0.08))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.red.opacity(0.8), lineWidth: 1.5))
        } else if isAnimatingCompletion && isInPath {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.10, green: 0.35, blue: 0.22))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(red: 0.40, green: 0.90, blue: 0.60).opacity(0.9), lineWidth: 1.5))
        } else if isPathEnd {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.12, green: 0.30, blue: 0.55))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(red: 0.55, green: 0.85, blue: 1.0), lineWidth: 2))
        } else if isInPath {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.08, green: 0.20, blue: 0.38))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(red: 0.35, green: 0.65, blue: 0.90).opacity(0.5), lineWidth: 1))
        } else if let wp = waypoint {
            RoundedRectangle(cornerRadius: 6)
                .fill(wp.isStart
                    ? Color(red: 0.10, green: 0.28, blue: 0.15)
                    : wp.isEnd
                        ? Color(red: 0.25, green: 0.15, blue: 0.06)
                        : Color(red: 0.22, green: 0.18, blue: 0.06))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(wp.isStart
                        ? Color(red: 0.35, green: 0.85, blue: 0.50).opacity(0.8)
                        : Color(red: 0.80, green: 0.65, blue: 0.25).opacity(0.75),
                            lineWidth: 1.5))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.10, green: 0.14, blue: 0.22))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(red: 0.30, green: 0.45, blue: 0.65).opacity(0.25), lineWidth: 0.8))
        }
    }

    @ViewBuilder
    private var cellContent: some View {
        if isMysteryCell {
            // Mystery mark — cycling Egyptian hieroglyph on the start stone
            VStack(spacing: 1) {
                if isMysteryUnselected {
                    // Not yet selected — prompt the player with a glowing "?"
                    Text("?")
                        .font(.system(size: size * 0.44, weight: .bold))
                        .foregroundStyle(Color(red: 0.95, green: 0.82, blue: 0.40).opacity(0.90))
                        .contentTransition(.numericText())
                } else {
                    Text(mysteryMarkSymbol ?? "")
                        .font(.system(size: size * 0.44))
                        .foregroundStyle(Color(red: 0.95, green: 0.82, blue: 0.40))
                        .contentTransition(.numericText())
                }
                if size > 44 {
                    Image(systemName: "arrow.2.circlepath")
                        .font(.system(size: size * 0.15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.90, green: 0.72, blue: 0.25).opacity(0.70))
                }
            }
        } else if isBlocked {
            // Cracked/impassable stone — subtle crossed lines
            ZStack {
                // Diagonal crack lines
                Canvas { ctx, size in
                    let s = size.width
                    var p1 = Path()
                    p1.move(to: CGPoint(x: s * 0.22, y: s * 0.22))
                    p1.addLine(to: CGPoint(x: s * 0.78, y: s * 0.78))
                    var p2 = Path()
                    p2.move(to: CGPoint(x: s * 0.78, y: s * 0.22))
                    p2.addLine(to: CGPoint(x: s * 0.22, y: s * 0.78))
                    ctx.stroke(p1, with: .color(Color(red: 0.30, green: 0.24, blue: 0.18).opacity(0.6)),
                               style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                    ctx.stroke(p2, with: .color(Color(red: 0.30, green: 0.24, blue: 0.18).opacity(0.6)),
                               style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                }
                .frame(width: size, height: size)
            }
        } else if isError {
            // Red X for wrong path
            Image(systemName: "xmark")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(Color.red.opacity(0.9))
        } else if let wp = waypoint {
            // Waypoint — show rune symbol + small label
            let reached = isInPath
            // Keep showing the mystery mark symbol after the start cell is placed in the path
            let displayRune = (mysteryMarkSymbol != nil && wp.isStart) ? (mysteryMarkSymbol ?? wp.rune) : wp.rune
            VStack(spacing: 1) {
                Text(displayRune)
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(reached
                        ? Color(red: 0.40, green: 0.95, blue: 0.65)
                        : wp.isStart
                            ? Color(red: 0.45, green: 0.95, blue: 0.60)
                            : Color(red: 0.90, green: 0.75, blue: 0.30))
                if size > 44 {
                    Text(wp.runeName)
                        .font(EgyptFont.body(size > 64 ? 9 : 8))
                        .foregroundStyle(Color(red: 0.70, green: 0.80, blue: 0.95).opacity(0.65))
                        .lineLimit(1)
                }
            }
        } else if isInPath, let idx = pathIndex {
            // Path cell — show sequence number
            Text("\(idx + 1)")
                .font(.system(size: size * 0.30, weight: .semibold, design: .rounded))
                .foregroundStyle(isPathEnd
                    ? Color(red: 0.75, green: 0.95, blue: 1.0)
                    : Color(red: 0.50, green: 0.75, blue: 0.95).opacity(0.8))
        } else {
            // Empty, unvisited cell — subtle dot
            Circle()
                .fill(Color(red: 0.30, green: 0.45, blue: 0.65).opacity(0.25))
                .frame(width: size * 0.18, height: size * 0.18)
        }
    }
}

// MARK: - Preview

#Preview {
    PathGameView()
        .environmentObject(GameState())
}
