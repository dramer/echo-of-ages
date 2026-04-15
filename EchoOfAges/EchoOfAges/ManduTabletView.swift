// ManduTabletView.swift
// EchoOfAges
//
// The Tablet of Mandu — the final mastermind puzzle of Echo of Ages.
//
// Seven symbols. Six rows. Six slots per row.
// Six of the seven belong in the tablet — one does not.
// The player must find the correct six AND their correct order.
// The Ramer mark ᚱ is always the symbol left over.
//
// Each row is one attempt. After all six symbols are placed, submit to
// see how many are in the right position (●) and how many are the right
// symbol but in the wrong position (○). Six chances to solve it.
// If the sixth row is submitted without a solution, the board resets.

import SwiftUI

// MARK: - Peg state

private enum Peg { case exact, near, empty }

// MARK: - ManduTabletView

struct ManduTabletView: View {
    @EnvironmentObject var gameState: GameState

    @State private var showReveal   = false
    @State private var treeProgress: CGFloat = 0
    @State private var revealStep   = 0
    @State private var showFullMsg  = false
    @State private var isAnimating  = false

    private var currentRowIndex: Int { gameState.masterMindGuessHistory.count }
    private var allSlotsFilled: Bool { !gameState.masterMindPlayerSlots.contains(nil) }
    private var gameOver: Bool { gameState.masterMindIsDefeated || gameState.masterMindIsComplete }

    var body: some View {
        ZStack {
            sandBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        titleBlock
                        gameBoard
                        paletteSection
                        if let armed = gameState.masterMindArmedSymbol {
                            armedBanner(symbol: armed)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        if allSlotsFilled && !gameOver {
                            checkButton
                                .transition(.scale.combined(with: .opacity))
                        }
                        loreNote
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 60)
                }
            }

            if showReveal {
                Color.black.opacity(0.90).ignoresSafeArea()
                    .transition(.opacity).zIndex(9)
                revealOverlay.zIndex(10)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.80), value: gameState.masterMindArmedSymbol)
        .animation(.spring(response: 0.4), value: allSlotsFilled)
        .animation(.easeInOut(duration: 0.3), value: currentRowIndex)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button { HapticFeedback.tap(); gameState.closeManduTablet() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(paper)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("TABLET OF MANDU")
                    .font(EgyptFont.titleBold(20))
                    .tracking(3)
                    .foregroundStyle(paper)
                Text("The Tree of Life")
                    .font(EgyptFont.bodyItalic(15))
                    .foregroundStyle(paper.opacity(0.70))
            }
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .frame(height: 60)
        .background(ink.opacity(0.88))
    }

    // MARK: - Title Block

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text("Seven marks. Six chances.")
                .font(EgyptFont.bodyItalic(24))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
            Text("● right position  ·  ○ right mark, wrong position")
                .font(EgyptFont.body(15))
                .foregroundStyle(ink.opacity(0.75))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Game Board (grows with each attempt)

    private var gameBoard: some View {
        let history      = gameState.masterMindGuessHistory
        let maxAttempts  = gameState.masterMindMaxAttempts
        let attemptsLeft = maxAttempts - history.count

        return VStack(spacing: 5) {
            // Past rows — locked, results shown
            ForEach(Array(history.enumerated()), id: \.offset) { _, guess in
                boardRow(
                    symbols:      guess.symbols.map { $0.isEmpty ? nil : $0 },
                    isActive:     false,
                    exactMatches: guess.exactMatches,
                    nearMatches:  guess.nearMatches,
                    isWin:        guess.exactMatches == 6
                )
            }

            // Active row — player fills this one now
            if !gameState.masterMindIsComplete {
                boardRow(
                    symbols:      gameState.masterMindPlayerSlots,
                    isActive:     true,
                    exactMatches: nil,
                    nearMatches:  nil,
                    isWin:        false
                )
            }

            // Attempts remaining indicator
            if !gameState.masterMindIsComplete && attemptsLeft > 0 {
                HStack(spacing: 6) {
                    ForEach(0..<attemptsLeft, id: \.self) { _ in
                        Circle()
                            .fill(paper.opacity(0.25))
                            .overlay(Circle().stroke(paper.opacity(0.30), lineWidth: 1))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(slab.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(gold.opacity(0.30), lineWidth: 1.5)
                )
        )
        .animation(.easeOut(duration: 0.35), value: history.count)
    }

    private func boardRow(
        symbols: [String?],
        isActive: Bool,
        exactMatches: Int?,
        nearMatches: Int?,
        isWin: Bool
    ) -> some View {
        HStack(spacing: 8) {
            // Six symbol cells
            HStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { i in
                    boardCell(sym: symbols[i], index: i, isActive: isActive)
                }
            }

            // Peg result grid — 3 columns × 2 rows
            pegGrid(
                exact:   exactMatches ?? 0,
                near:    nearMatches  ?? 0,
                show:    exactMatches != nil,
                isWin:   isWin
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            Group {
                if isWin {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(gold.opacity(0.18))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(gold.opacity(0.70), lineWidth: 1.5))
                } else if isActive {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(gold.opacity(0.60), lineWidth: 1.5))
                } else {
                    Color.clear
                }
            }
        )
    }

    private func boardCell(sym: String?, index: Int, isActive: Bool) -> some View {
        let armed    = gameState.masterMindArmedSymbol
        let isTarget = armed != nil && isActive

        return Button {
            guard isActive else { return }
            gameState.tapMasterMindSlot(index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(sym != nil ? cell : slot)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(sym != nil
                                    ? ink.opacity(0.40)
                                    : (isTarget ? gold : gold.opacity(isActive ? 0.35 : 0.15)),
                                    lineWidth: isTarget && sym == nil ? 2.0 : 1.2)
                    )

                if let s = sym {
                    Text(s)
                        .font(.system(size: 24))
                        .foregroundStyle(ink)
                } else if isActive {
                    Text("·")
                        .font(.system(size: 20))
                        .foregroundStyle(isTarget ? gold.opacity(0.80) : paper.opacity(0.30))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.plain)
        .disabled(!isActive)
        .animation(.easeInOut(duration: 0.12), value: sym)
    }

    // Peg grid: 3 columns × 2 rows, ordered exact → near → empty
    private func pegGrid(exact: Int, near: Int, show: Bool, isWin: Bool) -> some View {
        let pegs: [Peg] = show
            ? (Array(repeating: Peg.exact, count: exact)
               + Array(repeating: Peg.near,  count: near)
               + Array(repeating: Peg.empty, count: 6 - exact - near))
            : Array(repeating: Peg.empty, count: 6)

        return LazyVGrid(
            columns: [GridItem(.fixed(11)), GridItem(.fixed(11)), GridItem(.fixed(11))],
            spacing: 4
        ) {
            ForEach(0..<6, id: \.self) { i in
                switch pegs[i] {
                case .exact:
                    Circle()
                        .fill(isWin ? gold : gold.opacity(0.90))
                        .frame(width: 10, height: 10)
                case .near:
                    Circle()
                        .fill(Color.clear)
                        .overlay(Circle().stroke(gold.opacity(0.72), lineWidth: 1.5))
                        .frame(width: 10, height: 10)
                case .empty:
                    Circle()
                        .fill(Color.clear)
                        .overlay(Circle().stroke(paper.opacity(show ? 0.35 : 0.18), lineWidth: 1.0))
                        .frame(width: 10, height: 10)
                }
            }
        }
        .frame(width: 37)
    }

    // MARK: - Symbol Palette

    private var paletteSection: some View {
        VStack(spacing: 10) {
            Text("YOUR MARKS")
                .font(EgyptFont.title(14))
                .tracking(2)
                .foregroundStyle(paper)

            HStack(spacing: 3) {
                ForEach(CivilizationID.allCases, id: \.self) { civ in
                    paletteToken(for: civ)
                }
                ramerPaletteToken
            }

            Text("One of these seven does not belong. Place only the six that do.")
                .font(EgyptFont.bodyItalic(14))
                .foregroundStyle(paper.opacity(0.70))
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(slab.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(gold.opacity(0.30), lineWidth: 1.2)
                )
        )
        .disabled(gameOver)
        .opacity(gameOver ? 0.45 : 1.0)
    }

    private func paletteToken(for civ: CivilizationID) -> some View {
        let symbol   = TreeOfLifeKeys.treePartSymbol(for: civ)
        let earned   = gameState.masterMindSymbolsEarned.contains(symbol)
        let isArmed  = gameState.masterMindArmedSymbol == symbol
        let isPlaced = gameState.masterMindPlayerSlots.contains(symbol)
        let accent   = Civilization.all.first(where: { $0.id == civ })?.accentColor ?? gold

        return Button {
            if earned && !gameOver { gameState.tapMasterMindSymbol(symbol) }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isArmed  ? accent.opacity(0.30)
                              : (earned ? slot : slab.opacity(0.60)))
                        .overlay(
                            Circle()
                                .stroke(isArmed ? accent
                                        : (earned ? (isPlaced ? paper.opacity(0.25) : paper.opacity(0.50)) : paper.opacity(0.15)),
                                        lineWidth: isArmed ? 2.5 : 1.5)
                        )
                        .frame(width: 44, height: 44)

                    if earned {
                        Text(symbol)
                            .font(.system(size: 22))
                            .foregroundStyle(isArmed ? accent
                                             : (isPlaced ? paper.opacity(0.40) : paper))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(paper.opacity(0.22))
                    }
                }
                Text(civShortName(civ))
                    .font(EgyptFont.body(11))
                    .foregroundStyle(earned
                                     ? (isArmed ? accent.opacity(0.95) : (isPlaced ? paper.opacity(0.40) : paper.opacity(0.80)))
                                     : paper.opacity(0.28))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!earned || gameOver)
        .animation(.easeInOut(duration: 0.15), value: isArmed)
        .animation(.easeInOut(duration: 0.15), value: isPlaced)
    }

    private var ramerPaletteToken: some View {
        let symbol   = TreeOfLifeKeys.ramerMark
        let isArmed  = gameState.masterMindArmedSymbol == symbol
        let isPlaced = gameState.masterMindPlayerSlots.contains(symbol)

        return Button {
            if !gameOver { gameState.tapMasterMindSymbol(symbol) }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isArmed ? inkRed.opacity(0.30) : slot)
                        .overlay(
                            Circle()
                                .stroke(isArmed ? inkRed
                                        : (isPlaced ? inkRed.opacity(0.30) : inkRed.opacity(0.75)),
                                        lineWidth: isArmed ? 2.5 : 1.5)
                        )
                        .frame(width: 44, height: 44)

                    Text(symbol)
                        .font(.system(size: 22))
                        .foregroundStyle(isArmed ? inkRed
                                         : (isPlaced ? inkRed.opacity(0.40) : Color(red: 0.90, green: 0.55, blue: 0.50)))
                }
                Text("?")
                    .font(EgyptFont.body(11))
                    .foregroundStyle(isArmed ? inkRed.opacity(0.90) : Color(red: 0.85, green: 0.45, blue: 0.40).opacity(0.80))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(gameOver)
        .animation(.easeInOut(duration: 0.15), value: isArmed)
        .animation(.easeInOut(duration: 0.15), value: isPlaced)
    }

    private func civShortName(_ civ: CivilizationID) -> String {
        switch civ {
        case .egyptian: return "Egypt"
        case .norse:    return "Norse"
        case .sumerian: return "Sumer"
        case .maya:     return "Maya"
        case .celtic:   return "Celtic"
        case .chinese:  return "China"
        }
    }

    // MARK: - Armed Banner

    private func armedBanner(symbol: String) -> some View {
        HStack(spacing: 12) {
            Text(symbol)
                .font(.system(size: 28))
                .foregroundStyle(symbol == TreeOfLifeKeys.ramerMark ? inkRed.opacity(0.88) : ink.opacity(0.90))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Mark selected")
                    .font(EgyptFont.title(14))
                    .tracking(1)
                    .foregroundStyle(ink.opacity(0.88))
                Text("Tap an empty slot on the active row to place it")
                    .font(EgyptFont.bodyItalic(14))
                    .foregroundStyle(ink.opacity(0.65))
            }
            Spacer()
            Button { gameState.tapMasterMindSymbol(symbol) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(ink.opacity(0.30))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(gold.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(gold.opacity(0.35), lineWidth: 1))
        )
    }

    // MARK: - Check Button

    private var checkButton: some View {
        Button { handleSubmit() } label: {
            Label("Check Arrangement", systemImage: "checkmark.seal")
                .font(EgyptFont.titleBold(17))
                .foregroundStyle(Color(red: 0.10, green: 0.08, blue: 0.02))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(gold)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(gold.opacity(0.50), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Submit Logic

    private func handleSubmit() {
        let guess = gameState.submitMasterMindGuess()
        if guess.exactMatches == 6 {
            // Win
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { startReveal() }
        } else if gameState.masterMindIsDefeated {
            // All 6 rows used, no win — clear the board silently after a beat
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    gameState.resetMasterMind()
                }
            }
        } else {
            // Wrong, still have attempts — clear slots so the new active row is fresh
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                gameState.resetMasterMindSlots()
            }
        }
    }

    // MARK: - Lore Note

    private var loreNote: some View {
        Text("Six civilizations. Seven marks. One belongs to none of them.")
            .font(EgyptFont.bodyItalic(20))
            .foregroundStyle(ink)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    // MARK: - Reveal Overlay

    private var revealOverlay: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                OakTreeView(progress: treeProgress)
                    .frame(maxWidth: 360)
                    .frame(height: 290)
                    .padding(.horizontal, 8)

                if revealStep > 0 || showFullMsg {
                    VStack(spacing: 8) {
                        Text("THE WORD IS")
                            .font(EgyptFont.titleBold(20))
                            .tracking(6)
                            .foregroundStyle(gold.opacity(0.70))
                        Text("REMEMBER")
                            .font(EgyptFont.titleBold(36))
                            .tracking(8)
                            .foregroundStyle(gold)
                            .shadow(color: gold.opacity(0.60), radius: 14)
                    }
                    .transition(.opacity)

                    goldRule

                    VStack(spacing: 12) {
                        ForEach(Array(Civilization.all.enumerated()), id: \.offset) { i, civ in
                            if revealStep > i {
                                civRevealCard(civ)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                    .animation(.easeOut(duration: 0.5), value: revealStep)

                    if showFullMsg {
                        VStack(spacing: 16) {
                            goldRule
                            Text(TabletSlot.fullMessage)
                                .font(EgyptFont.bodyItalic(20))
                                .foregroundStyle(paper)
                                .multilineTextAlignment(.center)
                                .lineSpacing(9)
                                .padding(.horizontal, 8)
                            goldRule
                        }
                        .transition(.opacity)
                        .animation(.easeOut(duration: 0.8), value: showFullMsg)
                    }
                }

                Spacer(minLength: 20)

                Button {
                    withAnimation(.easeInOut(duration: 0.4)) { showReveal = false }
                } label: {
                    StoneButton(title: "Close the Stone", icon: "xmark", style: .muted)
                }

                Spacer(minLength: 50)
            }
            .padding(.horizontal, 22)
            .animation(.easeOut(duration: 0.6), value: revealStep > 0)
        }
    }

    private func civRevealCard(_ civ: Civilization) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(civ.emblem)
                    .font(.system(size: 18))
                    .foregroundStyle(civ.accentColor)
                Text(civ.name.uppercased())
                    .font(EgyptFont.title(13))
                    .tracking(2)
                    .foregroundStyle(civ.accentColor.opacity(0.80))
                Spacer()
                Text(TreeOfLifeKeys.treePartSymbol(for: civ.id))
                    .font(.system(size: 20))
                    .foregroundStyle(civ.accentColor.opacity(0.70))
            }
            Text(civ.tabletLine)
                .font(EgyptFont.bodyItalic(17))
                .foregroundStyle(paper.opacity(0.90))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(civ.accentColor.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(civ.accentColor.opacity(0.30), lineWidth: 1)
                )
        )
    }

    // MARK: - Reveal Sequencing

    private func startReveal() {
        guard !isAnimating else { return }
        isAnimating  = true
        revealStep   = 0
        showFullMsg  = false
        treeProgress = 0
        withAnimation(.easeIn(duration: 0.55)) { showReveal = true }
        Task {
            try? await Task.sleep(nanoseconds: 550_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 3.8)) { treeProgress = 1.0 }
            }
            try? await Task.sleep(nanoseconds: 3_900_000_000)
            for step in 1...Civilization.all.count {
                try? await Task.sleep(nanoseconds: 700_000_000)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.5)) { revealStep = step }
                }
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.8)) { showFullMsg = true }
            }
            isAnimating = false
        }
    }

    // MARK: - Colors & Helpers

    private var sandBackground: some View {
        ZStack {
            Color(red: 0.93, green: 0.87, blue: 0.73)
            RadialGradient(colors: [.clear, ink.opacity(0.12)],
                           center: .center, startRadius: 220, endRadius: 650)
        }
    }

    private var gold:    Color { Color(red: 0.92, green: 0.75, blue: 0.35) }
    private var ink:     Color { Color(red: 0.16, green: 0.10, blue: 0.04) }
    private var paper:   Color { Color(red: 0.93, green: 0.87, blue: 0.73) }
    private var inkRed:  Color { Color(red: 0.72, green: 0.18, blue: 0.12) }
    /// Dark stone slab — the board and palette containers sit on this
    private var slab:    Color { Color(red: 0.20, green: 0.14, blue: 0.07) }
    /// Carved empty slot inside the board
    private var slot:    Color { Color(red: 0.28, green: 0.20, blue: 0.10) }
    /// Filled cell — warm parchment so the symbol pops against dark slab
    private var cell:    Color { Color(red: 0.91, green: 0.82, blue: 0.58) }

    private var goldRule: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, gold, .clear],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(height: 0.8)
            .padding(.horizontal, 20)
    }
}

// MARK: - Preview

#Preview {
    ManduTabletView()
        .environmentObject(GameState())
}
