// GameState.swift
// EchoOfAges

import SwiftUI
import Combine

// MARK: - Screen

enum GameScreen: Equatable {
    case intro
    case title
    case game
    case journal
    case levelComplete
    case gameComplete
    case settings
    case debug
    case norseGame
}

// MARK: - GameState

@MainActor
final class GameState: ObservableObject {

    // Navigation
    @Published var currentScreen: GameScreen = .title
    private var previousScreen: GameScreen = .title

    // Puzzle state
    @Published var currentLevelIndex: Int = 0
    @Published var playerGrid: [[Glyph?]] = []
    @Published var selectedGlyph: Glyph? = nil
    @Published var errorCells: Set<GridPosition> = []
    @Published var isAnimatingCompletion: Bool = false

    // Progress
    @Published var unlockedJournalEntries: Set<Int> = []

    // The journal entry to highlight (set when completing a level)
    @Published var spotlightJournalId: Int? = nil

    // Archaeologist's Codex — glyphs discovered so far, in encounter order
    @Published var discoveredGlyphs: [Glyph] = []

    // Decoded messages from completed inscriptions, keyed by level id
    @Published var decodedMessages: [Int: String] = [:]

    // The message shown on the level-complete screen
    @Published var pendingDecodedMessage: String = ""

    // Settings
    @Published var showIntroOnLaunch: Bool = true

    var currentLevel: Level { Level.allLevels[currentLevelIndex] }

    // Ordered list of discovered glyphs (respects Glyph.allCases canonical order)
    var codexGlyphs: [Glyph] {
        Glyph.allCases.filter { discoveredGlyphs.contains($0) }
    }

    // All 5 chronicle entries in narrative order
    var chronicleMessages: [(level: Level, message: String?)] {
        Level.allLevels.map { level in
            (level: level, message: decodedMessages[level.id])
        }
    }

    // Which civilizations have all their partial tablets fully deciphered
    var completedCivilizations: Set<CivilizationID> {
        var completed = Set<CivilizationID>()
        for civ in Civilization.all where civ.isUnlocked {
            let civLevels = Level.allLevels.filter { $0.civilization == civ.id }
            let allSolved = civLevels.allSatisfy { unlockedJournalEntries.contains($0.journalEntry.id) }
            if allSolved && !civLevels.isEmpty { completed.insert(civ.id) }
        }
        return completed
    }

    // Tablet slots decoded so far (civilization must be complete)
    var decodedTabletSlots: Set<Int> {
        let done = completedCivilizations
        return Set(TabletSlot.all.filter { done.contains($0.civilization) }.map(\.id))
    }

    // Whether all 6 civilizations are complete — the tablet is fully decoded
    var isTabletFullyDecoded: Bool {
        Civilization.all.filter(\.isUnlocked).allSatisfy { completedCivilizations.contains($0.id) }
    }

    // Whether the intro has ever been completed
    var hasSeenIntro: Bool {
        UserDefaults.standard.bool(forKey: "EOA_hasSeenIntro")
    }

    // MARK: Init

    init() {
        loadProgress()
        resetGrid(for: Level.allLevels[0])

        // Show intro on first ever launch, or if the player has it turned on
        if !hasSeenIntro || showIntroOnLaunch {
            currentScreen = .intro
        }
    }

    // MARK: Navigation

    func startNewGame() {
        loadLevel(0)
        currentScreen = .game
    }

    func continueGame() {
        let next = min(unlockedJournalEntries.count, Level.allLevels.count - 1)
        loadLevel(next)
        currentScreen = .game
    }

    func goToTitle() {
        currentScreen = .title
    }

    func openJournal() {
        previousScreen = currentScreen
        currentScreen = .journal
    }

    func closeJournal() {
        currentScreen = previousScreen
    }

    func openSettings() {
        previousScreen = currentScreen
        currentScreen = .settings
    }

    func closeSettings() {
        currentScreen = previousScreen
    }

    func openDebug() {
        previousScreen = currentScreen
        currentScreen = .debug
    }

    func closeDebug() {
        currentScreen = previousScreen
    }

    /// Jump directly to any level, bypassing unlock requirements. Debug only.
    func debugJumpToLevel(_ level: Level) {
        guard let idx = Level.allLevels.firstIndex(where: { $0.id == level.id }) else { return }
        loadLevel(idx)
        currentScreen = .game
    }

    /// Mark a level solved instantly. Debug only.
    func debugSolveLevel(_ level: Level) {
        guard let idx = Level.allLevels.firstIndex(where: { $0.id == level.id }) else { return }
        loadLevel(idx)
        // Fill the grid with the solution then trigger completion
        playerGrid = level.solution.map { $0.map { Optional($0) } }
        checkSolutionPublic()
    }

    /// Public wrapper so DebugView can trigger a solution check.
    func checkSolutionPublic() {
        let level = currentLevel
        for row in 0..<level.rows {
            for col in 0..<level.cols {
                if playerGrid[row][col] == nil { return }
            }
        }
        if level.isSolved(playerGrid) {
            handleLevelComplete()
        }
    }

    func playIntro() {
        previousScreen = currentScreen
        currentScreen = .intro
    }

    func finishIntro() {
        markIntroSeen()
        currentScreen = .title
    }

    func markIntroSeen() {
        UserDefaults.standard.set(true, forKey: "EOA_hasSeenIntro")
    }

    func advanceToNextLevel() {
        let next = currentLevelIndex + 1
        if next < Level.allLevels.count {
            loadLevel(next)
            currentScreen = .game
        } else {
            currentScreen = .title
        }
    }

    // MARK: Level Management

    func loadLevel(_ index: Int) {
        currentLevelIndex = index
        selectedGlyph = nil
        errorCells = []
        resetGrid(for: Level.allLevels[index])
    }

    func resetCurrentLevel() {
        HapticFeedback.heavy()
        loadLevel(currentLevelIndex)
    }

    private func resetGrid(for level: Level) {
        playerGrid = level.initialGrid.map { $0.map { $0 } }
    }

    // MARK: Glyph Palette

    func selectGlyph(_ glyph: Glyph) {
        if selectedGlyph == glyph {
            selectedGlyph = nil
        } else {
            selectedGlyph = glyph
            HapticFeedback.tap()
        }
    }

    // MARK: Cell Interaction

    func tapCell(at position: GridPosition) {
        let level = currentLevel
        guard !level.isFixed(position) else {
            HapticFeedback.error()
            return
        }

        if let picked = selectedGlyph {
            if playerGrid[position.row][position.col] == picked {
                playerGrid[position.row][position.col] = nil
            } else {
                playerGrid[position.row][position.col] = picked
            }
        } else {
            let glyphs = level.availableGlyphs
            let current = playerGrid[position.row][position.col]
            if let current, let idx = glyphs.firstIndex(of: current) {
                let next = idx + 1
                playerGrid[position.row][position.col] = next < glyphs.count ? glyphs[next] : nil
            } else {
                playerGrid[position.row][position.col] = glyphs.first
            }
        }

        HapticFeedback.tap()
        checkSolution()
    }

    func clearCell(at position: GridPosition) {
        guard !currentLevel.isFixed(position) else { return }
        playerGrid[position.row][position.col] = nil
        HapticFeedback.tap()
    }

    // MARK: Verify (highlights mistakes temporarily)

    func verifyPlacement() {
        let level = currentLevel
        var mistakes = Set<GridPosition>()
        for row in 0..<level.rows {
            for col in 0..<level.cols {
                if let placed = playerGrid[row][col], placed != level.solution[row][col] {
                    mistakes.insert(GridPosition(row: row, col: col))
                }
            }
        }
        if mistakes.isEmpty {
            HapticFeedback.success()
        } else {
            HapticFeedback.error()
            errorCells = mistakes
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                errorCells = []
            }
        }
    }

    // MARK: Solution Check

    private func checkSolution() {
        let level = currentLevel
        for row in 0..<level.rows {
            for col in 0..<level.cols {
                if playerGrid[row][col] == nil { return }
            }
        }
        if level.isSolved(playerGrid) {
            handleLevelComplete()
        }
    }

    private func handleLevelComplete() {
        isAnimatingCompletion = true
        HapticFeedback.success()

        let level = currentLevel

        // Unlock journal entry
        let entryId = level.journalEntry.id
        unlockedJournalEntries.insert(entryId)
        spotlightJournalId = entryId

        // Record decoded message for the chronicle
        decodedMessages[level.id] = level.decodedMessage
        pendingDecodedMessage = level.decodedMessage

        // Add new glyphs to the codex (in encounter order)
        for glyph in level.availableGlyphs where !discoveredGlyphs.contains(glyph) {
            discoveredGlyphs.append(glyph)
        }

        saveProgress()

        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            isAnimatingCompletion = false
            if currentLevelIndex < Level.allLevels.count - 1 {
                currentScreen = .levelComplete
            } else {
                currentScreen = .gameComplete
            }
        }
    }

    // MARK: Norse Pathfinding State

    @Published var norseCurrentLevelIndex: Int = 0
    @Published var norsePath: [GridPosition] = []
    @Published var norseErrorCells: Set<GridPosition> = []
    @Published var norseIsAnimatingCompletion: Bool = false
    @Published var norseUnlockedLevels: Set<Int> = []

    /// The active variant of the current level — randomised path + runes.
    /// Replaced every time loadNorseLevel() or resetNorsePath() is called.
    private var norseActiveLevel: PathLevel?

    /// Returns the live (generated) variant; falls back to the static template
    /// if generation hasn't run yet (e.g. during unit tests or first init).
    var norseCurrentLevel: PathLevel {
        norseActiveLevel ?? PathLevel.allLevels[norseCurrentLevelIndex]
    }

    var norseHasProgress: Bool { !norseUnlockedLevels.isEmpty }

    // MARK: Norse Navigation

    func startNorseGame() {
        let next = min(norseUnlockedLevels.count, PathLevel.allLevels.count - 1)
        loadNorseLevel(next)
        currentScreen = .norseGame
    }

    func closeNorseGame() {
        currentScreen = .title
    }

    func loadNorseLevel(_ index: Int) {
        norseCurrentLevelIndex = max(0, min(index, PathLevel.allLevels.count - 1))
        norsePath = []
        norseErrorCells = []
        norseActiveLevel = generateNorseVariant(at: norseCurrentLevelIndex)
    }

    func resetNorsePath() {
        norsePath = []
        norseErrorCells = []
        // Generate a fresh path layout — every reset gives a new puzzle
        norseActiveLevel = generateNorseVariant(at: norseCurrentLevelIndex)
        HapticFeedback.heavy()
    }

    /// Generates a randomised variant of the level at `index`.
    /// Keeps the same grid dimensions, blocked cells, title and lore — only
    /// the Hamiltonian path and rune assignments change.
    private func generateNorseVariant(at index: Int) -> PathLevel {
        let template = PathLevel.allLevels[index]
        guard let path = PathGenerator.generatePath(
            rows: template.rows,
            cols: template.cols,
            blockedCells: template.blockedCells
        ) else {
            return template  // Fallback: use the static hand-crafted path
        }
        let waypoints = PathGenerator.placeWaypoints(
            on: path,
            count: template.waypoints.count
        )
        return template.withGeneratedPath(solution: path, waypoints: waypoints)
    }

    // MARK: Norse Cell Interaction

    func tapNorseCell(at position: GridPosition) {
        let level = norseCurrentLevel
        guard !norseIsAnimatingCompletion else { return }

        // Can't tap while errors are flashing
        guard norseErrorCells.isEmpty else { return }

        // Can't tap impassable/blocked stones
        guard !level.isBlocked(position) else {
            HapticFeedback.error()
            return
        }

        if norsePath.isEmpty {
            // First tap must be the start cell
            guard position == level.startPosition else {
                HapticFeedback.error()
                return
            }
            norsePath.append(position)
            HapticFeedback.tap()
            return
        }

        let pathEnd = norsePath.last!

        // Tapping the current end backtracks one step
        if position == pathEnd {
            norsePath.removeLast()
            HapticFeedback.tap()
            return
        }

        // Must be adjacent to the current path end
        guard norseIsAdjacent(position, pathEnd) else {
            HapticFeedback.error()
            return
        }

        // Can't revisit a cell already in the path
        guard !norsePath.contains(position) else {
            HapticFeedback.error()
            return
        }

        norsePath.append(position)
        HapticFeedback.tap()

        // Auto-verify once the path covers every cell
        if norsePath.count == level.totalCells {
            if level.isSolved(norsePath) {
                handleNorseLevelComplete()
            } else {
                // Wrong path — flash all cells red then reset
                norseErrorCells = Set(norsePath)
                HapticFeedback.error()
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    norseErrorCells = []
                    norsePath = []
                }
            }
        }
    }

    private func norseIsAdjacent(_ a: GridPosition, _ b: GridPosition) -> Bool {
        let dr = abs(a.row - b.row)
        let dc = abs(a.col - b.col)
        return (dr == 1 && dc == 0) || (dr == 0 && dc == 1)
    }

    // MARK: Norse Completion

    private func handleNorseLevelComplete() {
        norseIsAnimatingCompletion = true
        HapticFeedback.success()
        norseUnlockedLevels.insert(norseCurrentLevel.id)
        saveProgress()

        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            norseIsAnimatingCompletion = false
            let next = norseCurrentLevelIndex + 1
            if next < PathLevel.allLevels.count {
                loadNorseLevel(next)
            } else {
                currentScreen = .title
            }
        }
    }

    // MARK: Norse Debug

    func debugJumpToNorseLevel(_ level: PathLevel) {
        guard let idx = PathLevel.allLevels.firstIndex(where: { $0.id == level.id }) else { return }
        loadNorseLevel(idx)
        currentScreen = .norseGame
    }

    // MARK: Reset Civilization

    /// Wipes all solved levels and discovered glyphs for a given civilization.
    func resetCivilization(_ civId: CivilizationID) {
        let civLevels = Level.allLevels.filter { $0.civilization == civId }

        for level in civLevels {
            unlockedJournalEntries.remove(level.journalEntry.id)
            decodedMessages.removeValue(forKey: level.id)
        }

        // Remove glyphs that were introduced exclusively by this civilization's levels
        let civGlyphs = Set(civLevels.flatMap { $0.availableGlyphs })
        let otherGlyphs = Set(Level.allLevels
            .filter { $0.civilization != civId }
            .flatMap { $0.availableGlyphs })
        let exclusiveGlyphs = civGlyphs.subtracting(otherGlyphs)
        discoveredGlyphs.removeAll { exclusiveGlyphs.contains($0) }

        saveProgress()
        HapticFeedback.heavy()
    }

    // MARK: Progress Persistence

    private func saveProgress() {
        UserDefaults.standard.set(Array(unlockedJournalEntries), forKey: "EOA_unlockedEntries")
        UserDefaults.standard.set(discoveredGlyphs.map(\.rawValue), forKey: "EOA_codex")
        let messagesDict = decodedMessages.reduce(into: [String: String]()) { $0["\($1.key)"] = $1.value }
        UserDefaults.standard.set(messagesDict, forKey: "EOA_chronicle")
        UserDefaults.standard.set(showIntroOnLaunch, forKey: "EOA_showIntro")
        UserDefaults.standard.set(Array(norseUnlockedLevels), forKey: "EOA_norseUnlocked")
    }

    private func loadProgress() {
        let ids = UserDefaults.standard.array(forKey: "EOA_unlockedEntries") as? [Int] ?? []
        unlockedJournalEntries = Set(ids)

        let rawValues = UserDefaults.standard.array(forKey: "EOA_codex") as? [String] ?? []
        discoveredGlyphs = rawValues.compactMap { Glyph(rawValue: $0) }

        let messagesDict = UserDefaults.standard.dictionary(forKey: "EOA_chronicle") as? [String: String] ?? [:]
        decodedMessages = messagesDict.reduce(into: [Int: String]()) {
            if let id = Int($1.key) { $0[id] = $1.value }
        }

        let norseIds = UserDefaults.standard.array(forKey: "EOA_norseUnlocked") as? [Int] ?? []
        norseUnlockedLevels = Set(norseIds)

        // Default showIntroOnLaunch to true only on first ever run
        if UserDefaults.standard.object(forKey: "EOA_showIntro") == nil {
            showIntroOnLaunch = true
        } else {
            showIntroOnLaunch = UserDefaults.standard.bool(forKey: "EOA_showIntro")
        }
    }

    var hasProgress: Bool {
        !unlockedJournalEntries.isEmpty
    }

    func saveSettings() {
        UserDefaults.standard.set(showIntroOnLaunch, forKey: "EOA_showIntro")
    }
}
