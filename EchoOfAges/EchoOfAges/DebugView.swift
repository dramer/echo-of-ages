// DebugView.swift
// EchoOfAges
//
// Developer-only screen (compiled only in DEBUG builds).
// Accessible from Settings → Developer → Open Puzzle Debug Panel.
//
// Features:
//   • All civilizations in one scrollable list — each section expands / collapses
//   • Egyptian levels: Play + Solve buttons, filter bar
//   • Norse pathfinding and Sumerian cipher levels each get their own section
//   • "Play" — jump directly to that puzzle
//   • "Solve" — instantly mark the level complete and award the journal entry

import SwiftUI

#if DEBUG

struct DebugView: View {
    @EnvironmentObject var gameState: GameState
    @State private var filter: DebugFilter = .all
    @State private var confirmingSolve: Level? = nil
    @State private var collapsedSections: Set<String> = []

    enum DebugFilter: String, CaseIterable {
        case all      = "All"
        case unsolved = "Unsolved"
        case solved   = "Solved"
    }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.06, blue: 0.10).ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.08, green: 0.18, blue: 0.32).opacity(0.6), .clear],
                center: .topLeading, startRadius: 60, endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                filterBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.06, green: 0.09, blue: 0.15))

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        // Latin-square civs only (Norse, Sumerian, Maya, and Chinese have dedicated sections below)
                        ForEach(Civilization.all.filter { $0.id != .norse && $0.id != .sumerian && $0.id != .maya && $0.id != .chinese }) { civ in
                            civExpandableSection(civ)
                        }

                        // Norse pathfinding
                        norseExpandableSection

                        // Sumerian cipher
                        sumerianExpandableSection

                        // Maya calendar patterns
                        mayanExpandableSection

                        // Chinese wooden box puzzles
                        chineseExpandableSection

                        // Celtic Ogham ordering
                        celticExpandableSection

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
        }
        .alert(
            "Instantly Solve \"\(confirmingSolve?.title ?? "")\"?",
            isPresented: Binding(
                get: { confirmingSolve != nil },
                set: { if !$0 { confirmingSolve = nil } }
            )
        ) {
            Button("Solve It", role: .destructive) {
                if let level = confirmingSolve {
                    gameState.debugSolveLevel(level)
                }
                confirmingSolve = nil
            }
            Button("Cancel", role: .cancel) { confirmingSolve = nil }
        } message: {
            Text("This will fill the grid with the correct solution and trigger the level-complete sequence.")
        }
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { gameState.closeDebug() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(EgyptFont.body(17))
                }
                .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
            }

            Spacer()

            VStack(spacing: 1) {
                Text("DEBUG PANEL")
                    .font(EgyptFont.titleBold(16))
                    .tracking(3)
                    .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                Text("Puzzle Navigator")
                    .font(EgyptFont.body(12))
                    .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.6))
            }

            Spacer()

            Color.clear.frame(width: 60, height: 30)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Color(red: 0.06, green: 0.09, blue: 0.15)
                .overlay(
                    Rectangle()
                        .fill(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.25))
                        .frame(height: 0.8),
                    alignment: .bottom
                )
        )
    }

    // MARK: Filter Bar (applies to Latin-square levels)

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(DebugFilter.allCases, id: \.self) { f in
                Button(action: {
                    HapticFeedback.tap()
                    filter = f
                }) {
                    Text(f.rawValue)
                        .font(EgyptFont.body(14))
                        .foregroundStyle(filter == f
                            ? Color(red: 0.04, green: 0.06, blue: 0.10)
                            : Color(red: 0.45, green: 0.75, blue: 1.0))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(filter == f
                                    ? Color(red: 0.45, green: 0.75, blue: 1.0)
                                    : Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.35), lineWidth: 0.8))
                        )
                }
            }
            Spacer()

            let total  = Level.allLevels.count
            let solved = Level.allLevels.filter { gameState.unlockedJournalEntries.contains($0.journalEntry.id) }.count
            Text("\(solved)/\(total) solved")
                .font(EgyptFont.body(13))
                .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))
        }
    }

    // MARK: Expandable Civilization Section (Latin-square)

    @ViewBuilder
    private func civExpandableSection(_ civ: Civilization) -> some View {
        let key = civ.name
        let isExpanded = !collapsedSections.contains(key)
        let civLevels = Level.allLevels.filter { $0.civilization == civ.id }
        let filteredLevels = civLevels.filter { level in
            switch filter {
            case .all:      return true
            case .solved:   return  gameState.unlockedJournalEntries.contains(level.journalEntry.id)
            case .unsolved: return !gameState.unlockedJournalEntries.contains(level.journalEntry.id)
            }
        }

        if filteredLevels.isEmpty && filter != .all {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Tappable section header
                Button { toggleSection(key) } label: {
                    HStack(spacing: 10) {
                        Text(civ.emblem).font(.system(size: 22))
                        Text(civ.name.uppercased())
                            .font(EgyptFont.titleBold(15))
                            .tracking(2)
                            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                        if !civ.isUnlocked {
                            lockBadge
                        }
                        Spacer()
                        let nSolved = civLevels.filter { gameState.unlockedJournalEntries.contains($0.journalEntry.id) }.count
                        Text("\(nSolved)/\(civLevels.count)")
                            .font(EgyptFont.body(13))
                            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.6))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.22), lineWidth: 0.8))
                    )
                }
                .buttonStyle(.plain)

                // Collapsible puzzle rows
                if isExpanded {
                    VStack(spacing: 8) {
                        if civLevels.isEmpty {
                            HStack(spacing: 10) {
                                Image(systemName: "clock").font(.system(size: 13))
                                Text("No puzzles defined yet.")
                                    .font(EgyptFont.bodyItalic(14))
                            }
                            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.35))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.12), lineWidth: 0.7))
                            )
                        } else {
                            ForEach(filteredLevels) { level in
                                levelRow(level, civ: civ)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: isExpanded)
        }
    }

    // MARK: Expandable Norse Section

    private var norseExpandableSection: some View {
        let key = "norse_section"
        let isExpanded = !collapsedSections.contains(key)
        let allLevels = PathLevel.allLevels
        let nSolved = allLevels.filter { gameState.norseUnlockedLevels.contains($0.id) }.count

        return VStack(alignment: .leading, spacing: 0) {
            Button { toggleSection(key) } label: {
                HStack(spacing: 10) {
                    Text("ᚠ").font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("NORSE")
                            .font(EgyptFont.titleBold(15))
                            .tracking(2)
                            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                        Text("Pathfinding")
                            .font(EgyptFont.bodyItalic(12))
                            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.45))
                    }
                    Spacer()
                    Text("\(nSolved)/\(allLevels.count)")
                        .font(EgyptFont.body(13))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.22), lineWidth: 0.8))
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(allLevels) { level in
                        norsePathRow(level)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
    }

    // MARK: Expandable Sumerian Section

    private var sumerianExpandableSection: some View {
        let key = "sumerian_section"
        let isExpanded = !collapsedSections.contains(key)
        let allLevels = SumerianLevel.allLevels
        let nSolved = allLevels.filter { gameState.sumerianUnlockedLevels.contains($0.id) }.count

        return VStack(alignment: .leading, spacing: 0) {
            Button { toggleSection(key) } label: {
                HStack(spacing: 10) {
                    Text("𒀭").font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("SUMERIAN")
                            .font(EgyptFont.titleBold(15))
                            .tracking(2)
                            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                        Text("Substitution Cipher")
                            .font(EgyptFont.bodyItalic(12))
                            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.45))
                    }
                    Spacer()
                    Text("\(nSolved)/\(allLevels.count)")
                        .font(EgyptFont.body(13))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.22), lineWidth: 0.8))
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(allLevels) { level in
                        sumerianCipherRow(level)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
    }

    // MARK: Expandable Maya Section

    private var mayanExpandableSection: some View {
        let key = "mayan_section"
        let isExpanded = !collapsedSections.contains(key)
        let allLevels = MayanLevel.allLevels
        let nSolved = allLevels.filter { gameState.mayanUnlockedLevels.contains($0.id) }.count

        return VStack(alignment: .leading, spacing: 0) {
            Button { toggleSection(key) } label: {
                HStack(spacing: 10) {
                    Text("𝋡").font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("MAYA")
                            .font(EgyptFont.titleBold(15))
                            .tracking(2)
                            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                        Text("Calendar Patterns")
                            .font(EgyptFont.bodyItalic(12))
                            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.45))
                    }
                    Spacer()
                    Text("\(nSolved)/\(allLevels.count)")
                        .font(EgyptFont.body(13))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.22), lineWidth: 0.8))
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(allLevels) { level in
                        mayanLevelRow(level)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
    }

    // MARK: Maya Level Row

    private func mayanLevelRow(_ level: MayanLevel) -> some View {
        let isSolved  = gameState.mayanUnlockedLevels.contains(level.id)
        let isCurrent = gameState.mayanCurrentLevelIndex == (MayanLevel.allLevels.firstIndex(where: { $0.id == level.id }) ?? -1)
        let totalCells = level.cycles.count * level.sequenceLength
        let blankCount = level.cycles.reduce(0) { acc, cycle in
            acc + (0..<level.sequenceLength).filter { !cycle.isRevealed($0) }.count
        }

        return HStack(spacing: 14) {
            Text(level.romanNumeral)
                .font(EgyptFont.titleBold(18))
                .foregroundStyle(isSolved
                    ? Color(red: 0.30, green: 0.85, blue: 0.50)
                    : Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.7))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(level.title)
                        .font(EgyptFont.titleBold(15))
                        .foregroundStyle(.white)
                    if isCurrent { currentBadge }
                }
                HStack(spacing: 10) {
                    Label("\(level.cycles.count) cycles", systemImage: "arrow.clockwise")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))
                    Label("\(totalCells) cells", systemImage: "dot.circle")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))
                    goldBadge("\(blankCount) blanks")
                    if isSolved { solvedBadge }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    HapticFeedback.tap()
                    gameState.debugSolveMayanLevel(level)
                }) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(red: 0.30, green: 0.85, blue: 0.50).opacity(isSolved ? 0.35 : 0.85))
                }
                .disabled(isSolved)

                Button(action: {
                    HapticFeedback.tap()
                    gameState.debugJumpToMayanLevel(level)
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(levelBackground(solved: isSolved, current: isCurrent))
    }

    // MARK: Expandable Chinese Section

    private var chineseExpandableSection: some View {
        let key = "chinese_section"
        let isExpanded = !collapsedSections.contains(key)
        let allLevels = ChineseBoxLevel.allLevels
        let nSolved = allLevels.filter { gameState.chineseUnlockedLevels.contains($0.id) }.count

        return VStack(alignment: .leading, spacing: 0) {
            Button { toggleSection(key) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "hexagon.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(red: 0.86, green: 0.17, blue: 0.10))
                    Text("Chinese — Wooden Box Puzzles")
                        .font(EgyptFont.titleBold(16))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(nSolved)/\(allLevels.count)")
                        .font(EgyptFont.body(13))
                        .foregroundStyle(Color(red: 0.86, green: 0.17, blue: 0.10).opacity(0.8))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(allLevels) { level in
                        chineseLevelRow(level)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: Chinese Level Row

    private func chineseLevelRow(_ level: ChineseBoxLevel) -> some View {
        let isSolved  = gameState.chineseUnlockedLevels.contains(level.id)
        let isCurrent = gameState.chineseCurrentLevelIndex == (ChineseBoxLevel.allLevels.firstIndex(where: { $0.id == level.id }) ?? -1)
        let blankCount = level.pieces.count

        return HStack(spacing: 14) {
            Text(level.romanNumeral)
                .font(EgyptFont.titleBold(18))
                .foregroundStyle(isSolved
                    ? Color(red: 0.30, green: 0.85, blue: 0.50)
                    : Color(red: 0.86, green: 0.17, blue: 0.10).opacity(0.7))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(level.title)
                        .font(EgyptFont.titleBold(15))
                        .foregroundStyle(.white)
                    if isCurrent { currentBadge }
                }
                HStack(spacing: 10) {
                    Label("\(level.rows)×\(level.cols) tray", systemImage: "square.grid.2x2")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(Color(red: 0.86, green: 0.17, blue: 0.10).opacity(0.55))
                    goldBadge("\(blankCount) pieces")
                    if isSolved { solvedBadge }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    HapticFeedback.tap()
                    gameState.debugSolveChineseLevel(level)
                }) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(red: 0.30, green: 0.85, blue: 0.50).opacity(isSolved ? 0.35 : 0.85))
                }
                .disabled(isSolved)

                Button(action: {
                    HapticFeedback.tap()
                    gameState.debugJumpToChineseLevel(level)
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(red: 0.86, green: 0.17, blue: 0.10))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(levelBackground(solved: isSolved, current: isCurrent))
    }

    // MARK: Expandable Celtic Section

    private var celticExpandableSection: some View {
        let key = "celtic_section"
        let isExpanded = !collapsedSections.contains(key)
        let allDifficulties = CelticDifficulty.all
        let nSolved = allDifficulties.filter { gameState.celticUnlockedLevels.contains($0.id) }.count
        let accentColor = Color(red: 0.30, green: 0.55, blue: 0.22)

        return VStack(alignment: .leading, spacing: 0) {
            Button { toggleSection(key) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "tree.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(accentColor)
                    Text("Celtic — Ogham Ordering")
                        .font(EgyptFont.titleBold(16))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(nSolved)/\(allDifficulties.count)")
                        .font(EgyptFont.body(13))
                        .foregroundStyle(accentColor.opacity(0.8))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(allDifficulties) { difficulty in
                        celticLevelRow(difficulty)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func celticLevelRow(_ difficulty: CelticDifficulty) -> some View {
        let isSolved  = gameState.celticUnlockedLevels.contains(difficulty.id)
        let isCurrent = gameState.celticCurrentLevelIndex == difficulty.id - 1
        let accent    = Color(red: 0.30, green: 0.55, blue: 0.22)

        return HStack(spacing: 14) {
            Text(difficulty.romanNumeral)
                .font(EgyptFont.titleBold(18))
                .foregroundStyle(isSolved ? Color(red: 0.30, green: 0.85, blue: 0.50) : accent.opacity(0.7))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(difficulty.title)
                        .font(EgyptFont.titleBold(15))
                        .foregroundStyle(.white)
                    if isCurrent { currentBadge }
                }
                HStack(spacing: 10) {
                    Label("\(difficulty.rows)×\(difficulty.cols) grid", systemImage: "square.grid.3x3")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(accent.opacity(0.55))
                    goldBadge("~\(difficulty.targetBlanks) blanks")
                    if isSolved { solvedBadge }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    HapticFeedback.tap()
                    gameState.debugSolveCelticLevel(difficulty)
                }) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(red: 0.30, green: 0.85, blue: 0.50).opacity(isSolved ? 0.35 : 0.85))
                }
                .disabled(isSolved)

                Button(action: {
                    HapticFeedback.tap()
                    gameState.debugJumpToCelticLevel(difficulty)
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(accent)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(levelBackground(solved: isSolved, current: isCurrent))
    }

    // MARK: Toggle helper

    private func toggleSection(_ key: String) {
        HapticFeedback.tap()
        withAnimation(.easeInOut(duration: 0.22)) {
            if collapsedSections.contains(key) {
                collapsedSections.remove(key)
            } else {
                collapsedSections.insert(key)
            }
        }
    }

    // MARK: Lock Badge

    private var lockBadge: some View {
        Text("LOCKED")
            .font(EgyptFont.body(11))
            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.4))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.25), lineWidth: 0.7)
            )
    }

    // MARK: Norse Path Row

    private func norsePathRow(_ level: PathLevel) -> some View {
        let isSolved  = gameState.norseUnlockedLevels.contains(level.id)
        let isCurrent = gameState.norseCurrentLevelIndex == (PathLevel.allLevels.firstIndex(where: { $0.id == level.id }) ?? -1)

        return HStack(spacing: 14) {
            Text(level.romanNumeral)
                .font(EgyptFont.titleBold(18))
                .foregroundStyle(isSolved
                    ? Color(red: 0.30, green: 0.85, blue: 0.50)
                    : Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.7))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(level.title)
                        .font(EgyptFont.titleBold(15))
                        .foregroundStyle(.white)
                    if isCurrent {
                        currentBadge
                    }
                }
                HStack(spacing: 10) {
                    Label("\(level.rows)×\(level.cols)", systemImage: "grid")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))
                    Label("\(level.totalCells) cells", systemImage: "dot.circle")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))
                    goldBadge("\(level.waypoints.count) runes")
                    if isSolved { solvedBadge }
                }
            }

            Spacer()

            Button(action: {
                HapticFeedback.tap()
                gameState.debugJumpToNorseLevel(level)
            }) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(levelBackground(solved: isSolved, current: isCurrent))
    }

    // MARK: Egyptian Level Row

    private func levelRow(_ level: Level, civ: Civilization) -> some View {
        let isSolved  = gameState.unlockedJournalEntries.contains(level.journalEntry.id)
        let isCurrent = gameState.currentLevelIndex == (Level.allLevels.firstIndex(where: { $0.id == level.id }) ?? -1)

        return HStack(spacing: 14) {
            Text(level.romanNumeral)
                .font(EgyptFont.titleBold(18))
                .foregroundStyle(isSolved
                    ? Color(red: 0.30, green: 0.85, blue: 0.50)
                    : Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.7))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(level.title)
                        .font(EgyptFont.titleBold(15))
                        .foregroundStyle(.white)
                    if isCurrent { currentBadge }
                }
                HStack(spacing: 10) {
                    Label("\(level.rows)×\(level.cols)", systemImage: "grid")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))
                    variantBadge(level.variant)
                    if isSolved { solvedBadge }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    HapticFeedback.tap()
                    confirmingSolve = level
                }) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(red: 0.30, green: 0.85, blue: 0.50).opacity(isSolved ? 0.35 : 0.85))
                }
                .disabled(isSolved)

                Button(action: {
                    HapticFeedback.tap()
                    gameState.debugJumpToLevel(level)
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(levelBackground(solved: isSolved, current: isCurrent))
    }

    // MARK: Sumerian Cipher Row

    private func sumerianCipherRow(_ level: SumerianLevel) -> some View {
        let isSolved  = gameState.sumerianUnlockedLevels.contains(level.id)
        let isCurrent = gameState.sumerianCurrentLevelIndex == (SumerianLevel.allLevels.firstIndex(where: { $0.id == level.id }) ?? -1)

        return HStack(spacing: 14) {
            Text(level.romanNumeral)
                .font(EgyptFont.titleBold(18))
                .foregroundStyle(isSolved
                    ? Color(red: 0.30, green: 0.85, blue: 0.50)
                    : Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.7))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(level.title)
                        .font(EgyptFont.titleBold(15))
                        .foregroundStyle(.white)
                    if isCurrent { currentBadge }
                }
                HStack(spacing: 10) {
                    Label("\(level.symbols.count) symbols", systemImage: "character.cursor.ibeam")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))
                    Label("\(level.encodedSequence.count) signs", systemImage: "list.number")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))
                    goldBadge("\(level.revealedPositions.count) anchors")
                    if isSolved { solvedBadge }
                }
            }

            Spacer()

            Button(action: {
                HapticFeedback.tap()
                gameState.debugJumpToSumerianLevel(level)
            }) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(levelBackground(solved: isSolved, current: isCurrent))
    }

    // MARK: Shared badge / background helpers

    private var currentBadge: some View {
        Text("CURRENT")
            .font(EgyptFont.body(10))
            .tracking(1)
            .foregroundStyle(Color.goldBright)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color.goldDark.opacity(0.3)))
    }

    private var solvedBadge: some View {
        Label("Solved", systemImage: "checkmark.seal.fill")
            .font(EgyptFont.body(11))
            .foregroundStyle(Color(red: 0.30, green: 0.85, blue: 0.50))
    }

    private func goldBadge(_ text: String) -> some View {
        Text(text)
            .font(EgyptFont.body(11))
            .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.35).opacity(0.8))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 1.0, green: 0.80, blue: 0.35).opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(red: 1.0, green: 0.80, blue: 0.35).opacity(0.35), lineWidth: 0.7))
            )
    }

    private func variantBadge(_ variant: PuzzleVariant) -> some View {
        Text(variantLabel(variant))
            .font(EgyptFont.body(11))
            .foregroundStyle(variantColor(variant))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(variantColor(variant).opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(variantColor(variant).opacity(0.4), lineWidth: 0.7))
            )
    }

    private func levelBackground(solved: Bool, current: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(solved
                ? Color(red: 0.12, green: 0.22, blue: 0.14).opacity(0.6)
                : Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(current
                        ? Color.goldDark.opacity(0.6)
                        : Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.15),
                            lineWidth: current ? 1.2 : 0.7)
            )
    }

    // MARK: Variant helpers

    private func variantLabel(_ variant: PuzzleVariant) -> String {
        switch variant {
        case .standard:       return "Standard"
        case .noAdjacent:     return "No Adjacent"
        case .hiddenRegions:  return "Hidden Regions"
        case .pureDeduction:  return "Deduction"
        }
    }

    private func variantColor(_ variant: PuzzleVariant) -> Color {
        switch variant {
        case .standard:       return Color(red: 0.70, green: 0.60, blue: 1.00)
        case .noAdjacent:     return Color(red: 1.00, green: 0.70, blue: 0.30)
        case .hiddenRegions:  return Color(red: 0.30, green: 0.85, blue: 0.85)
        case .pureDeduction:  return Color(red: 1.00, green: 0.45, blue: 0.45)
        }
    }
}

// MARK: - Preview

#Preview {
    DebugView()
        .environmentObject({
            let gs = GameState()
            gs.unlockedJournalEntries = [1, 2]
            gs.discoveredGlyphs = [.eye, .owl, .water, .lion]
            return gs
        }())
}

#endif
