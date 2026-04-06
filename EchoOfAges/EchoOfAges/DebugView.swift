// DebugView.swift
// EchoOfAges
//
// Developer-only screen (compiled only in DEBUG builds).
// Accessible from Settings → Developer → Open Puzzle Debug Panel.
//
// Features:
//   • All civilizations listed, unlocked or not
//   • All levels per civilization with solved status, variant badge, grid size
//   • Norse pathfinding levels shown separately with path progress
//   • "Play" — jump directly to that puzzle
//   • "Solve" — instantly mark the level complete and award the journal entry
//   • Filter bar to show All / Unsolved / Solved

import SwiftUI

#if DEBUG

struct DebugView: View {
    @EnvironmentObject var gameState: GameState
    @State private var filter: DebugFilter = .all
    @State private var confirmingSolve: Level? = nil
    @State private var selectedTab: DebugTab = .egyptian

    enum DebugFilter: String, CaseIterable {
        case all      = "All"
        case unsolved = "Unsolved"
        case solved   = "Solved"
    }

    enum DebugTab: String, CaseIterable {
        case egyptian = "Egyptian"
        case norse    = "Norse"
        case sumerian = "Sumerian"
    }

    var body: some View {
        ZStack {
            // Background — dark stone, slightly different tint so it reads as "dev"
            Color(red: 0.04, green: 0.06, blue: 0.10).ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.08, green: 0.18, blue: 0.32).opacity(0.6), .clear],
                center: .topLeading, startRadius: 60, endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                tabBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.06, green: 0.09, blue: 0.15))
                if selectedTab == .egyptian {
                    filterBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.06, green: 0.09, blue: 0.15))
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        switch selectedTab {
                        case .egyptian:
                            ForEach(Civilization.all) { civ in
                                civSection(civ)
                            }
                        case .norse:
                            norseSection
                        case .sumerian:
                            sumerianSection
                        }
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

            // Balance spacer matching "Back" button width
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

    // MARK: Tab Bar

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(DebugTab.allCases, id: \.self) { tab in
                Button(action: {
                    HapticFeedback.tap()
                    selectedTab = tab
                }) {
                    Text(tab.rawValue)
                        .font(EgyptFont.titleBold(14))
                        .tracking(1)
                        .foregroundStyle(selectedTab == tab
                            ? Color(red: 0.04, green: 0.06, blue: 0.10)
                            : Color(red: 0.45, green: 0.75, blue: 1.0))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab
                                    ? Color(red: 0.45, green: 0.75, blue: 1.0)
                                    : Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.35), lineWidth: 0.8))
                        )
                }
            }
            Spacer()
        }
    }

    // MARK: Filter Bar

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

            // Quick stats
            let total   = Level.allLevels.count
            let solved  = Level.allLevels.filter { gameState.unlockedJournalEntries.contains($0.journalEntry.id) }.count
            Text("\(solved)/\(total) solved")
                .font(EgyptFont.body(13))
                .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))
        }
    }

    // MARK: Norse Section

    private var norseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 10) {
                Text("ᚠ")
                    .font(.system(size: 22))
                Text("NORSE · PATHFINDING")
                    .font(EgyptFont.titleBold(15))
                    .tracking(2)
                    .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                Spacer()
                let nSolved = PathLevel.allLevels.filter { gameState.norseUnlockedLevels.contains($0.id) }.count
                Text("\(nSolved)/\(PathLevel.allLevels.count) solved")
                    .font(EgyptFont.body(13))
                    .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))
            }
            .padding(.horizontal, 4)

            Text("Hamiltonian path puzzles — trace a route that visits every stone exactly once, guided by rune waypoints.")
                .font(EgyptFont.bodyItalic(13))
                .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.5))
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(PathLevel.allLevels) { level in
                    norsePathRow(level)
                }
            }
        }
    }

    private func norsePathRow(_ level: PathLevel) -> some View {
        let isSolved  = gameState.norseUnlockedLevels.contains(level.id)
        let isCurrent = gameState.norseCurrentLevelIndex == (PathLevel.allLevels.firstIndex(where: { $0.id == level.id }) ?? -1)

        return HStack(spacing: 14) {

            // Roman numeral
            Text(level.romanNumeral)
                .font(EgyptFont.titleBold(18))
                .foregroundStyle(isSolved
                    ? Color(red: 0.30, green: 0.85, blue: 0.50)
                    : Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.7))
                .frame(width: 28)

            // Level info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(level.title)
                        .font(EgyptFont.titleBold(15))
                        .foregroundStyle(.white)
                    if isCurrent {
                        Text("CURRENT")
                            .font(EgyptFont.body(10))
                            .tracking(1)
                            .foregroundStyle(Color.goldBright)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Color.goldDark.opacity(0.3)))
                    }
                }
                HStack(spacing: 10) {
                    // Grid size
                    Label("\(level.rows)×\(level.cols)", systemImage: "grid")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))

                    // Cells
                    Label("\(level.totalCells) cells", systemImage: "dot.circle")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))

                    // Waypoints count
                    Text("\(level.waypoints.count) runes")
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

                    // Solved badge
                    if isSolved {
                        Label("Solved", systemImage: "checkmark.seal.fill")
                            .font(EgyptFont.body(11))
                            .foregroundStyle(Color(red: 0.30, green: 0.85, blue: 0.50))
                    }
                }
            }

            Spacer()

            // Play button
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
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSolved
                    ? Color(red: 0.12, green: 0.22, blue: 0.14).opacity(0.6)
                    : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isCurrent
                            ? Color.goldDark.opacity(0.6)
                            : Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.15),
                                lineWidth: isCurrent ? 1.2 : 0.7)
                )
        )
    }

    // MARK: Civilization Section

    @ViewBuilder
    private func civSection(_ civ: Civilization) -> some View {
        let civLevels = Level.allLevels.filter { $0.civilization == civ.id }
        let filteredLevels = civLevels.filter { level in
            switch filter {
            case .all:      return true
            case .solved:   return gameState.unlockedJournalEntries.contains(level.journalEntry.id)
            case .unsolved: return !gameState.unlockedJournalEntries.contains(level.journalEntry.id)
            }
        }

        // If filtering hides all levels of this civ, hide the whole section
        if filteredLevels.isEmpty && filter != .all { EmptyView() } else {
            VStack(alignment: .leading, spacing: 10) {

                // Civ header
                HStack(spacing: 10) {
                    Text(civ.emblem)
                        .font(.system(size: 22))
                    Text(civ.name.uppercased())
                        .font(EgyptFont.titleBold(15))
                        .tracking(2)
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                    if !civ.isUnlocked {
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
                    Spacer()
                    Text(civ.scriptName)
                        .font(EgyptFont.bodyItalic(12))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.4))
                }
                .padding(.horizontal, 4)

                if civLevels.isEmpty {
                    // No levels defined yet for this civ
                    HStack(spacing: 10) {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                        Text("No puzzles defined yet — coming in a future expedition phase.")
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
                    VStack(spacing: 8) {
                        ForEach(filteredLevels) { level in
                            levelRow(level, civ: civ)
                        }
                    }
                }
            }
        }
    }

    // MARK: Level Row

    private func levelRow(_ level: Level, civ: Civilization) -> some View {
        let isSolved = gameState.unlockedJournalEntries.contains(level.journalEntry.id)
        let isCurrent = gameState.currentLevelIndex == (Level.allLevels.firstIndex(where: { $0.id == level.id }) ?? -1)

        return HStack(spacing: 14) {

            // Roman numeral
            Text(level.romanNumeral)
                .font(EgyptFont.titleBold(18))
                .foregroundStyle(isSolved
                    ? Color(red: 0.30, green: 0.85, blue: 0.50)
                    : Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.7))
                .frame(width: 28)

            // Level info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(level.title)
                        .font(EgyptFont.titleBold(15))
                        .foregroundStyle(.white)
                    if isCurrent {
                        Text("CURRENT")
                            .font(EgyptFont.body(10))
                            .tracking(1)
                            .foregroundStyle(Color.goldBright)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Color.goldDark.opacity(0.3)))
                    }
                }
                HStack(spacing: 10) {
                    // Grid size
                    Label("\(level.rows)×\(level.cols)", systemImage: "grid")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))

                    // Variant badge
                    Text(variantLabel(level.variant))
                        .font(EgyptFont.body(11))
                        .foregroundStyle(variantColor(level.variant))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(variantColor(level.variant).opacity(0.15))
                                .overlay(RoundedRectangle(cornerRadius: 4)
                                    .stroke(variantColor(level.variant).opacity(0.4), lineWidth: 0.7))
                        )

                    // Solved badge
                    if isSolved {
                        Label("Solved", systemImage: "checkmark.seal.fill")
                            .font(EgyptFont.body(11))
                            .foregroundStyle(Color(red: 0.30, green: 0.85, blue: 0.50))
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                // Solve button
                Button(action: {
                    HapticFeedback.tap()
                    confirmingSolve = level
                }) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(red: 0.30, green: 0.85, blue: 0.50).opacity(isSolved ? 0.35 : 0.85))
                }
                .disabled(isSolved)

                // Play button
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
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSolved
                    ? Color(red: 0.12, green: 0.22, blue: 0.14).opacity(0.6)
                    : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isCurrent
                            ? Color.goldDark.opacity(0.6)
                            : Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.15),
                                lineWidth: isCurrent ? 1.2 : 0.7)
                )
        )
    }

    // MARK: Sumerian Section

    private var sumerianSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("𒀭")
                    .font(.system(size: 22))
                Text("SUMERIAN · CIPHER")
                    .font(EgyptFont.titleBold(15))
                    .tracking(2)
                    .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                Spacer()
                let nSolved = SumerianLevel.allLevels.filter { gameState.sumerianUnlockedLevels.contains($0.id) }.count
                Text("\(nSolved)/\(SumerianLevel.allLevels.count) solved")
                    .font(EgyptFont.body(13))
                    .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))
            }
            .padding(.horizontal, 4)

            Text("Substitution cipher puzzles — deduce the hidden bijection from anchor positions, then decode the full inscription.")
                .font(EgyptFont.bodyItalic(13))
                .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.5))
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(SumerianLevel.allLevels) { level in
                    sumerianCipherRow(level)
                }
            }
        }
    }

    private func sumerianCipherRow(_ level: SumerianLevel) -> some View {
        let isSolved  = gameState.sumerianUnlockedLevels.contains(level.id)
        let isCurrent = gameState.sumerianCurrentLevelIndex == (SumerianLevel.allLevels.firstIndex(where: { $0.id == level.id }) ?? -1)

        return HStack(spacing: 14) {

            // Roman numeral
            Text(level.romanNumeral)
                .font(EgyptFont.titleBold(18))
                .foregroundStyle(isSolved
                    ? Color(red: 0.30, green: 0.85, blue: 0.50)
                    : Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.7))
                .frame(width: 28)

            // Level info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(level.title)
                        .font(EgyptFont.titleBold(15))
                        .foregroundStyle(.white)
                    if isCurrent {
                        Text("CURRENT")
                            .font(EgyptFont.body(10))
                            .tracking(1)
                            .foregroundStyle(Color.goldBright)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Color.goldDark.opacity(0.3)))
                    }
                }
                HStack(spacing: 10) {
                    // Symbol count
                    Label("\(level.symbols.count) symbols", systemImage: "character.cursor.ibeam")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))

                    // Sequence length
                    Label("\(level.encodedSequence.count) signs", systemImage: "list.number")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55))

                    // Anchors badge
                    Text("\(level.revealedPositions.count) anchors")
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

                    if isSolved {
                        Label("Solved", systemImage: "checkmark.seal.fill")
                            .font(EgyptFont.body(11))
                            .foregroundStyle(Color(red: 0.30, green: 0.85, blue: 0.50))
                    }
                }
            }

            Spacer()

            // Play button
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
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSolved
                    ? Color(red: 0.12, green: 0.22, blue: 0.14).opacity(0.6)
                    : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isCurrent
                            ? Color.goldDark.opacity(0.6)
                            : Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.15),
                                lineWidth: isCurrent ? 1.2 : 0.7)
                )
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
