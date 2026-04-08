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
    case debug
    case norseGame
    case sumerianGame
    case mayanGame
    case chineseGame
    case celticGame
    case manduTablet
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

    // Archaeologist name — prompted once on first launch, editable in Settings
    @Published var playerName: String = ""

    /// True when the player hasn't entered their name yet.
    var needsPlayerName: Bool {
        playerName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // Set by the Table of Contents to jump to a specific diary page.
    @Published var journalTargetPage: Int? = nil

    // When true, JournalView jumps straight to the settings page on appear.
    @Published var journalOpeningToSettings: Bool = false

    // Tracks which civilization the player was last actively playing.
    // Used by Continue Journey to return to exactly where they left off.
    @Published var lastActiveCivilization: CivilizationID? = nil

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
        resetSumerianDecoded(for: SumerianLevel.allLevels[0])
        resetMayanGrid(for: MayanLevel.allLevels[0])
        resetChinesePieces(for: ChineseBoxLevel.allLevels[0])
        // Celtic puzzle is generated lazily when startCelticGame() is called
    }

    // MARK: Navigation

    /// Begin Journey — routes to the next unsolved puzzle in tier order across all civilizations.
    func startNewGame() {
        let done = civilizationsCompletedForMandu
        let unlocked = dynamicallyUnlockedCivIds

        // Tier 1: Egypt
        if unlocked.contains(.egyptian), !done.contains(.egyptian) {
            let next = min(unlockedJournalEntries.count, Level.allLevels.count - 1)
            loadLevel(next)
            lastActiveCivilization = .egyptian
            currentScreen = .game
            return
        }
        // Tier 2: Norse then Sumerian (play Norse first if both open and incomplete)
        if unlocked.contains(.norse), !done.contains(.norse) {
            lastActiveCivilization = .norse
            startNorseGame()
            return
        }
        if unlocked.contains(.sumerian), !done.contains(.sumerian) {
            lastActiveCivilization = .sumerian
            startSumerianGame()
            return
        }
        // Tier 3: Maya + Celtic
        if unlocked.contains(.maya), !done.contains(.maya) {
            lastActiveCivilization = .maya
            startMayanGame()
            return
        }
        if unlocked.contains(.celtic), !done.contains(.celtic) {
            lastActiveCivilization = .celtic
            startCelticGame()
            return
        }
        // Tier 4: Chinese
        if unlocked.contains(.chinese), !done.contains(.chinese) {
            lastActiveCivilization = .chinese
            startChineseGame()
            return
        }
        // All available civs complete
        if allSixCivsComplete { currentScreen = .manduTablet }
    }

    /// Continue Journey — returns to the last civilization the player was actively working on.
    func continueGame() {
        // If that civ is already fully completed, route to the next unsolved one instead.
        if let last = lastActiveCivilization, civilizationsCompletedForMandu.contains(last) {
            startNewGame()
            return
        }
        switch lastActiveCivilization {
        case .egyptian:
            let next = min(unlockedJournalEntries.count, Level.allLevels.count - 1)
            loadLevel(next)
            currentScreen = .game
        case .norse:
            startNorseGame()
        case .sumerian:
            startSumerianGame()
        case .maya:
            startMayanGame()
        case .celtic:
            startCelticGame()
        case .chinese:
            startChineseGame()
        default:
            startNewGame() // no last session — route to next unsolved
        }
    }

    /// Civilizations that newly become available when a player finishes level 5 of `civId`.
    /// The `done` set must already include `civId` (completion is recorded before showing the card).
    func newlyUnlockedCivs(completingLevel5Of civId: CivilizationID) -> [Civilization] {
        let done = civilizationsCompletedForMandu
        let implemented = Set(Civilization.all.filter(\.isUnlocked).map(\.id))
        var newIds = Set<CivilizationID>()
        switch civId {
        case .egyptian:
            for id: CivilizationID in [.norse, .sumerian] where implemented.contains(id) && !done.contains(id) {
                newIds.insert(id)
            }
        case .norse:
            if done.contains(.sumerian) {
                for id: CivilizationID in [.maya, .celtic] where implemented.contains(id) && !done.contains(id) { newIds.insert(id) }
            }
        case .sumerian:
            if done.contains(.norse) {
                for id: CivilizationID in [.maya, .celtic] where implemented.contains(id) && !done.contains(id) { newIds.insert(id) }
            }
        case .maya, .celtic:
            if implemented.contains(.chinese) && !done.contains(.chinese) { newIds.insert(.chinese) }
        case .chinese:
            break
        }
        return Civilization.all.filter { newIds.contains($0.id) }
    }

    /// Direct navigation to a specific civilization's next unsolved puzzle.
    /// Used by the civilization selector cards on the title screen.
    func navigateToCivilization(_ id: CivilizationID) {
        switch id {
        case .egyptian:
            let next = min(unlockedJournalEntries.count, Level.allLevels.count - 1)
            loadLevel(next)
            currentScreen = .game
        case .norse:
            startNorseGame()
        case .sumerian:
            startSumerianGame()
        case .maya:
            startMayanGame()
        case .celtic:
            startCelticGame()
        case .chinese:
            startChineseGame()
        default:
            break
        }
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
        // Open the journal and jump directly to the settings page (always last before debug).
        // JournalView watches journalTargetPage and scrolls to it on appear.
        journalOpeningToSettings = true
        previousScreen = currentScreen
        currentScreen = .journal
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
        lastActiveCivilization = .egyptian
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

        // Level 5 (the last Egyptian level) produces the Tree of Life key
        if currentLevelIndex == Level.allLevels.count - 1 {
            recordKey(for: .egyptian)
        }

        saveProgress()

        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            isAnimatingCompletion = false
            if currentLevelIndex < Level.allLevels.count - 1 {
                currentScreen = .levelComplete
            } else if allSixCivsComplete {
                currentScreen = .manduTablet
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
        lastActiveCivilization = .norse
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
                // Level 1 requires the correct mystery mark to complete
                if norseCurrentLevelIndex == 0 && needsKeyGate(for: .norse) {
                    if mysteryMarkIsCorrect(for: .norse) {
                        passKeyGate(for: .norse)
                        handleNorseLevelComplete()
                    } else {
                        // Correct path, wrong mark — flash and reset so player knows to check the diary
                        flashMysteryMarkWrong()
                        norseErrorCells = Set(norsePath)
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            norseErrorCells = []
                            norsePath = []
                        }
                    }
                } else {
                    handleNorseLevelComplete()
                }
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
        if norseCurrentLevelIndex == PathLevel.allLevels.count - 1 {
            recordKey(for: .norse)
        }
        saveProgress()
        // No auto-advance — player presses Continue or Open Diary in the completion card.
    }

    /// Advance to the next Norse level (or title if done). Called by the completion card button.
    func advanceNorseToNextLevel() {
        let next = norseCurrentLevelIndex + 1
        norseIsAnimatingCompletion = false
        norsePath = []
        norseErrorCells = []
        if next < PathLevel.allLevels.count {
            loadNorseLevel(next)
        } else {
            currentScreen = .title
        }
    }

    // MARK: Norse Debug

    func debugJumpToNorseLevel(_ level: PathLevel) {
        guard let idx = PathLevel.allLevels.firstIndex(where: { $0.id == level.id }) else { return }
        loadNorseLevel(idx)
        currentScreen = .norseGame
    }

    // MARK: Sumerian State

    @Published var sumerianCurrentLevelIndex: Int = 0
    @Published var playerSumerianDecoded: [CuneiformGlyph?] = []
    @Published var sumerianSelectedDecodedIndex: Int? = nil
    @Published var sumerianErrorPositions: Set<Int> = []
    @Published var sumerianUnlockedLevels: Set<Int> = []
    @Published var sumerianPendingComplete: Bool = false
    @Published var sumerianPendingDecodedMessage: String = ""

    // Maya
    @Published var mayanCurrentLevelIndex: Int = 0
    @Published var mayanUnlockedLevels: Set<Int> = []
    @Published var mayanPlayerGrid: [[MayanGlyph?]] = []
    @Published var mayanSelectedCell: MayanCellCoord? = nil
    @Published var mayanArmedGlyph: MayanGlyph? = nil
    @Published var mayanErrorCells: Set<MayanCellCoord> = []
    @Published var mayanPendingComplete: Bool = false

    var mayanCurrentLevel: MayanLevel { MayanLevel.allLevels[mayanCurrentLevelIndex] }

    // Chinese Box Puzzle
    @Published var chineseCurrentLevelIndex: Int = 0
    @Published var chineseUnlockedLevels: Set<Int> = []
    @Published var chinesePlacedPieces: [String: ChinesePiecePlacement] = [:]
    @Published var chineseSelectedPieceId: String? = nil
    @Published var chineseArmedRotation: Int = 0
    @Published var chinesePendingComplete: Bool = false

    var chineseCurrentLevel: ChineseBoxLevel { ChineseBoxLevel.allLevels[chineseCurrentLevelIndex] }

    // Celtic Ogham Ordering
    @Published var celticCurrentLevelIndex: Int = 0
    @Published var celticUnlockedLevels: Set<Int> = []
    @Published var celticPlayerGrid: [[OghamGlyph?]] = []
    @Published var celticArmedGlyph: OghamGlyph? = nil
    @Published var celticErrorCells: Set<CelticCellCoord> = []
    @Published var celticPendingComplete: Bool = false
    @Published var celticCurrentPuzzle: CelticPuzzle? = nil

    var celticCurrentDifficulty: CelticDifficulty {
        CelticDifficulty.all[min(celticCurrentLevelIndex, CelticDifficulty.all.count - 1)]
    }

    var sumerianCurrentLevel: SumerianLevel {
        SumerianLevel.allLevels[sumerianCurrentLevelIndex]
    }

    var sumerianHasProgress: Bool { !sumerianUnlockedLevels.isEmpty }

    /// All cipher mappings discoverable from current decoded positions
    /// (revealed anchors + player-filled cells combined).
    var sumerianKnownMappings: [CuneiformGlyph: CuneiformGlyph] {
        let level = sumerianCurrentLevel
        var mappings: [CuneiformGlyph: CuneiformGlyph] = [:]
        for (idx, encoded) in level.encodedSequence.enumerated() {
            guard idx < playerSumerianDecoded.count else { continue }
            if let decoded = playerSumerianDecoded[idx] {
                mappings[encoded] = decoded
            }
        }
        return mappings
    }

    // MARK: Sumerian Navigation

    func startSumerianGame() {
        lastActiveCivilization = .sumerian
        let next = min(sumerianUnlockedLevels.count, SumerianLevel.allLevels.count - 1)
        loadSumerianLevel(next)
        currentScreen = .sumerianGame
    }

    func closeSumerianGame() {
        sumerianPendingComplete = false
        currentScreen = allSixCivsComplete ? .manduTablet : .title
    }

    func loadSumerianLevel(_ index: Int) {
        sumerianCurrentLevelIndex = max(0, min(index, SumerianLevel.allLevels.count - 1))
        sumerianSelectedDecodedIndex = nil
        sumerianErrorPositions = []
        sumerianPendingComplete = false
        resetSumerianDecoded(for: SumerianLevel.allLevels[sumerianCurrentLevelIndex])
    }

    private func resetSumerianDecoded(for level: SumerianLevel) {
        playerSumerianDecoded = level.encodedSequence.indices.map { idx in
            level.isRevealed(idx) ? level.solution[idx] : nil
        }
        sumerianSelectedDecodedIndex = nil
    }

    // MARK: Sumerian Decoded Interaction

    /// Selects a blank decoded position (or deselects if already selected).
    func tapSumerianDecodedPosition(_ index: Int) {
        let level = sumerianCurrentLevel
        guard !level.isRevealed(index) else { HapticFeedback.error(); return }
        guard !sumerianPendingComplete else { return }
        if sumerianSelectedDecodedIndex == index {
            sumerianSelectedDecodedIndex = nil
        } else {
            sumerianSelectedDecodedIndex = index
            HapticFeedback.tap()
        }
    }

    /// Places a glyph at the currently selected decoded position.
    func placeSumerianGlyph(_ glyph: CuneiformGlyph) {
        guard let idx = sumerianSelectedDecodedIndex else { return }
        guard !sumerianPendingComplete else { return }
        guard idx < playerSumerianDecoded.count else { return }
        if playerSumerianDecoded[idx] == glyph {
            playerSumerianDecoded[idx] = nil
        } else {
            playerSumerianDecoded[idx] = glyph
        }
        sumerianSelectedDecodedIndex = nil
        HapticFeedback.tap()
        checkSumerianSolution()
    }

    func resetSumerianCurrentLevel() {
        loadSumerianLevel(sumerianCurrentLevelIndex)
    }

    // MARK: Sumerian Verify

    func verifySumerianPlacement() {
        let level = sumerianCurrentLevel
        var mistakes = Set<Int>()
        for (idx, glyph) in playerSumerianDecoded.enumerated() {
            if let placed = glyph, placed != level.solution[idx] {
                mistakes.insert(idx)
            }
        }
        if mistakes.isEmpty {
            // All cipher positions correct — still need the right mystery mark on Level 1
            if sumerianCurrentLevelIndex == 0 && needsKeyGate(for: .sumerian)
                && !mysteryMarkIsCorrect(for: .sumerian) {
                flashMysteryMarkWrong()
            } else {
                HapticFeedback.success()
            }
        } else {
            HapticFeedback.error()
            sumerianErrorPositions = mistakes
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                sumerianErrorPositions = []
            }
        }
    }

    // MARK: Sumerian Solution Check

    private func checkSumerianSolution() {
        guard playerSumerianDecoded.allSatisfy({ $0 != nil }) else { return }
        guard sumerianCurrentLevel.isSolved(playerSumerianDecoded) else { return }
        // Level 1 requires the correct mystery mark to complete
        if sumerianCurrentLevelIndex == 0 && needsKeyGate(for: .sumerian) {
            guard mysteryMarkIsCorrect(for: .sumerian) else { return }
            passKeyGate(for: .sumerian)
        }
        handleSumerianLevelComplete()
    }

    private func handleSumerianLevelComplete() {
        HapticFeedback.success()
        let level = sumerianCurrentLevel
        sumerianUnlockedLevels.insert(level.id)
        sumerianPendingDecodedMessage = level.decodedMessage
        if sumerianCurrentLevelIndex == SumerianLevel.allLevels.count - 1 {
            recordKey(for: .sumerian)
        }
        UserDefaults.standard.set(Array(sumerianUnlockedLevels), forKey: "EOA_sumerianUnlocked")
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            sumerianPendingComplete = true
        }
    }

    func advanceSumerianToNextLevel() {
        let next = sumerianCurrentLevelIndex + 1
        if next < SumerianLevel.allLevels.count {
            loadSumerianLevel(next)
        } else {
            closeSumerianGame()
        }
    }

    // MARK: Sumerian Debug

    func debugJumpToSumerianLevel(_ level: SumerianLevel) {
        guard let idx = SumerianLevel.allLevels.firstIndex(where: { $0.id == level.id }) else { return }
        loadSumerianLevel(idx)
        currentScreen = .sumerianGame
    }

    // MARK: Mandu Tablet State

    @Published var discoveredKeys: [CivilizationID: String] = [:]

    /// Civilizations whose key-identification gate the player has already passed.
    @Published var civKeyGateAnswered: Set<CivilizationID> = []

    // Mystery mark cycling — one index per civ (which candidate is currently shown)
    // China needs a second slot (it requires keys from both Maya and Celtic)
    @Published var mysteryMarkIndex: [CivilizationID: Int] = [:]
    @Published var chinaMysteryMarkIndex2: Int = 0

    // Set briefly when the player tries to complete Level 1 with the wrong mark
    @Published var mysteryMarkWrongFlash: Bool = false

    /// True if the player must still identify the foreign mark before Level 1 counts as solved.
    /// Egypt never requires this (it's the first civ).
    func needsKeyGate(for civ: CivilizationID) -> Bool {
        civ != .egyptian && !civKeyGateAnswered.contains(civ)
    }

    // MARK: Mystery Mark Helpers

    func mysteryMarkCurrent(for civ: CivilizationID) -> String {
        let choices = civ == .chinese ? TreeOfLifeKeys.chinaSlot1Choices : TreeOfLifeKeys.choices(for: civ)
        guard !choices.isEmpty else { return "" }
        return choices[(mysteryMarkIndex[civ, default: 0]) % choices.count]
    }

    var chinaMysteryMarkCurrent2: String {
        let c = TreeOfLifeKeys.chinaSlot2Choices
        return c[chinaMysteryMarkIndex2 % c.count]
    }

    func cycleMysteryMark(for civ: CivilizationID) {
        let choices = civ == .chinese ? TreeOfLifeKeys.chinaSlot1Choices : TreeOfLifeKeys.choices(for: civ)
        guard !choices.isEmpty else { return }
        mysteryMarkIndex[civ] = ((mysteryMarkIndex[civ, default: 0]) + 1) % choices.count
        HapticFeedback.tap()
    }

    func cycleChinaMysteryMark2() {
        chinaMysteryMarkIndex2 = (chinaMysteryMarkIndex2 + 1) % TreeOfLifeKeys.chinaSlot2Choices.count
        HapticFeedback.tap()
    }

    func mysteryMarkIsCorrect(for civ: CivilizationID) -> Bool {
        if civ == .chinese {
            return mysteryMarkCurrent(for: .chinese) == TreeOfLifeKeys.maya
                && chinaMysteryMarkCurrent2 == TreeOfLifeKeys.celtic
        }
        guard let required = TreeOfLifeKeys.required(by: civ) else { return true }
        return mysteryMarkCurrent(for: civ) == required
    }

    private func flashMysteryMarkWrong() {
        mysteryMarkWrongFlash = true
        HapticFeedback.error()
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            mysteryMarkWrongFlash = false
        }
    }

    /// Called when Level 1 is correctly solved AND mystery mark is correct.
    /// Marks the gate as passed. Navigation proceeds normally through the level-complete flow.
    func passKeyGate(for civ: CivilizationID) {
        civKeyGateAnswered.insert(civ)
        saveProgress()
    }

    func hasProducedKey(_ civ: CivilizationID) -> Bool {
        discoveredKeys[civ] != nil
    }

    func hasRequiredKey(for civ: CivilizationID) -> Bool {
        switch civ {
        case .egyptian: return true
        case .norse:    return discoveredKeys[.egyptian] != nil
        case .sumerian: return discoveredKeys[.egyptian] != nil
        case .maya:     return discoveredKeys[.norse] != nil
        case .celtic:   return discoveredKeys[.sumerian] != nil
        case .chinese:  return discoveredKeys[.maya] != nil && discoveredKeys[.celtic] != nil
        }
    }

    private func recordKey(for civ: CivilizationID) {
        guard let key = TreeOfLifeKeys.produced(by: civ) else { return }
        discoveredKeys[civ] = key
    }

    /// slot index 0-5 → CivilizationID.rawValue of the placed stone
    @Published var manduPlayerGrid: [Int: String] = [:]
    /// The civ token the player has picked up and is holding
    @Published var manduArmedCiv: CivilizationID? = nil

    /// All civilizations where the player has completed every puzzle.
    var civilizationsCompletedForMandu: Set<CivilizationID> {
        var done = Set<CivilizationID>()
        let egypt = Level.allLevels.filter { $0.civilization == .egyptian }
        if !egypt.isEmpty, egypt.allSatisfy({ unlockedJournalEntries.contains($0.journalEntry.id) }) {
            done.insert(.egyptian)
        }
        if !PathLevel.allLevels.isEmpty, PathLevel.allLevels.allSatisfy({ norseUnlockedLevels.contains($0.id) }) {
            done.insert(.norse)
        }
        if !SumerianLevel.allLevels.isEmpty, SumerianLevel.allLevels.allSatisfy({ sumerianUnlockedLevels.contains($0.id) }) {
            done.insert(.sumerian)
        }
        if !MayanLevel.allLevels.isEmpty, MayanLevel.allLevels.allSatisfy({ mayanUnlockedLevels.contains($0.id) }) {
            done.insert(.maya)
        }
        if !ChineseBoxLevel.allLevels.isEmpty, ChineseBoxLevel.allLevels.allSatisfy({ chineseUnlockedLevels.contains($0.id) }) {
            done.insert(.chinese)
        }
        if celticUnlockedLevels.count >= CelticDifficulty.all.count {
            done.insert(.celtic)
        }
        return done
    }

    /// True when at least one civilization is fully solved.
    /// Which civilizations the player has dynamically unlocked based on tier progression.
    /// Tier 1: Egyptian (always). Tier 2: Norse + Sumerian (after Egypt done).
    /// Tier 3: Maya + Celtic (after Norse AND Sumerian done). Tier 4: Chinese (after Maya OR Celtic done).
    var dynamicallyUnlockedCivIds: Set<CivilizationID> {
        let implemented = Set(Civilization.all.filter(\.isUnlocked).map(\.id))
        let done = civilizationsCompletedForMandu
        var unlocked = Set<CivilizationID>()
        if implemented.contains(.egyptian) { unlocked.insert(.egyptian) }
        if done.contains(.egyptian) {
            for id: CivilizationID in [.norse, .sumerian] where implemented.contains(id) { unlocked.insert(id) }
        }
        if done.contains(.norse) && done.contains(.sumerian) {
            for id: CivilizationID in [.maya, .celtic] where implemented.contains(id) { unlocked.insert(id) }
        }
        if done.contains(.maya) || done.contains(.celtic) {
            if implemented.contains(.chinese) { unlocked.insert(.chinese) }
        }
        return unlocked
    }

    /// True when all six implemented civilizations are fully solved — the tablet permanently holds symbols.
    var allSixCivsComplete: Bool {
        let ids = Civilization.all.filter(\.isUnlocked).map(\.id)
        guard ids.count == 6 else { return false }
        return ids.allSatisfy { civilizationsCompletedForMandu.contains($0) }
    }

    /// Legacy alias — kept for any call sites that used this name.
    var allUnlockedCivsComplete: Bool { allSixCivsComplete }

    /// True when every slot has the correct civilization stone in the correct tree-part position.
    var isManduComplete: Bool {
        TreeOfLifeKeys.tabletOrder.enumerated().allSatisfy { i, civ in
            manduPlayerGrid[i] == civ.rawValue
        }
    }

    /// Number of slots where the placed civ matches the correct tree-part order.
    var manduCorrectCount: Int {
        TreeOfLifeKeys.tabletOrder.enumerated().filter { i, civ in
            manduPlayerGrid[i] == civ.rawValue
        }.count
    }

    // MARK: Mandu Navigation

    func openManduTablet() {
        // Stones fall off every time the tablet is opened — they only hold when all six are done.
        if !allSixCivsComplete { manduPlayerGrid = [:] }
        manduArmedCiv = nil
        previousScreen = currentScreen
        currentScreen = .manduTablet
    }

    func closeManduTablet() {
        currentScreen = (previousScreen == .manduTablet) ? .title : previousScreen
    }

    // MARK: Mandu Interaction

    /// Arm or disarm a civilization token. Tapping an already-armed civ disarms it.
    func tapManduCiv(_ civ: CivilizationID) {
        if manduArmedCiv == civ {
            manduArmedCiv = nil
        } else {
            manduArmedCiv = civ
            HapticFeedback.tap()
        }
    }

    /// Place the armed civ into a slot, or pick up the civ already in a slot.
    func tapManduSlot(_ slotIndex: Int) {
        if let civ = manduArmedCiv {
            if manduPlayerGrid[slotIndex] == civ.rawValue {
                // Tap same civ in same slot → clear it
                manduPlayerGrid.removeValue(forKey: slotIndex)
            } else {
                // Remove this civ from any other slot first (each civ goes in exactly one slot)
                for key in manduPlayerGrid.keys where manduPlayerGrid[key] == civ.rawValue {
                    manduPlayerGrid.removeValue(forKey: key)
                }
                manduPlayerGrid[slotIndex] = civ.rawValue
                HapticFeedback.tap()
            }
            manduArmedCiv = nil
            if isManduComplete { HapticFeedback.success() }
        } else if let civRaw = manduPlayerGrid[slotIndex],
                  let civ = CivilizationID(rawValue: civRaw) {
            // No civ armed — pick up whatever is in this slot
            manduPlayerGrid.removeValue(forKey: slotIndex)
            manduArmedCiv = civ
            HapticFeedback.tap()
        }
    }

    func resetManduGrid() {
        manduPlayerGrid = [:]
        manduArmedCiv = nil
        HapticFeedback.heavy()
    }

    // MARK: Reset Civilization

    /// Number of solved levels for a given civilization. Used by Settings.
    func solvedLevelCount(for civId: CivilizationID) -> Int {
        switch civId {
        case .egyptian: return Level.allLevels.filter { unlockedJournalEntries.contains($0.journalEntry.id) }.count
        case .norse:    return norseUnlockedLevels.count
        case .sumerian: return sumerianUnlockedLevels.count
        case .maya:     return mayanUnlockedLevels.count
        case .celtic:   return celticUnlockedLevels.count
        case .chinese:  return chineseUnlockedLevels.count
        }
    }

    /// Total number of levels for a given civilization.
    func totalLevelCount(for civId: CivilizationID) -> Int {
        switch civId {
        case .egyptian: return Level.allLevels.count
        case .norse:    return PathLevel.allLevels.count
        case .sumerian: return SumerianLevel.allLevels.count
        case .maya:     return MayanLevel.allLevels.count
        case .celtic:   return CelticDifficulty.all.count
        case .chinese:  return ChineseBoxLevel.allLevels.count
        }
    }

    /// Wipes all solved levels, the mystery-mark gate, and the produced key for a civilization.
    /// The player can replay that civilization from scratch, including re-identifying the mark.
    func resetCivilization(_ civId: CivilizationID) {
        // ── Puzzle state per civ ─────────────────────────────────
        switch civId {
        case .egyptian:
            let civLevels = Level.allLevels.filter { $0.civilization == .egyptian }
            for level in civLevels {
                unlockedJournalEntries.remove(level.journalEntry.id)
                decodedMessages.removeValue(forKey: level.id)
            }
            let civGlyphs  = Set(civLevels.flatMap { $0.availableGlyphs })
            let otherGlyphs = Set(Level.allLevels
                .filter { $0.civilization != .egyptian }
                .flatMap { $0.availableGlyphs })
            discoveredGlyphs.removeAll { civGlyphs.subtracting(otherGlyphs).contains($0) }
            currentLevelIndex = 0
            resetGrid(for: Level.allLevels[0])

        case .norse:
            norseUnlockedLevels = []
            norseCurrentLevelIndex = 0
            norsePath = []
            norseErrorCells = []
            norseIsAnimatingCompletion = false
            norseActiveLevel = nil
            UserDefaults.standard.removeObject(forKey: "EOA_norseUnlocked")

        case .sumerian:
            sumerianUnlockedLevels = []
            sumerianCurrentLevelIndex = 0
            sumerianSelectedDecodedIndex = nil
            sumerianErrorPositions = []
            sumerianPendingComplete = false
            sumerianPendingDecodedMessage = ""
            resetSumerianDecoded(for: SumerianLevel.allLevels[0])
            UserDefaults.standard.removeObject(forKey: "EOA_sumerianUnlocked")

        case .maya:
            mayanUnlockedLevels = []
            mayanCurrentLevelIndex = 0
            mayanSelectedCell = nil
            mayanArmedGlyph = nil
            mayanErrorCells = []
            mayanPendingComplete = false
            resetMayanGrid(for: MayanLevel.allLevels[0])
            UserDefaults.standard.removeObject(forKey: "EOA_mayanUnlocked")

        case .celtic:
            celticUnlockedLevels = []
            celticCurrentLevelIndex = 0
            celticCurrentPuzzle = nil
            celticPlayerGrid = []
            celticArmedGlyph = nil
            celticErrorCells = []
            celticPendingComplete = false
            UserDefaults.standard.removeObject(forKey: "EOA_celticUnlocked")

        case .chinese:
            chineseUnlockedLevels = []
            chineseCurrentLevelIndex = 0
            chineseSelectedPieceId = nil
            chineseArmedRotation = 0
            chinesePendingComplete = false
            resetChinesePieces(for: ChineseBoxLevel.allLevels[0])
            UserDefaults.standard.removeObject(forKey: "EOA_chineseUnlocked")
        }

        // ── Key gate + produced key + mystery cycling position ────
        // Removing these lets the player re-identify the mystery mark on
        // Level 1 replay and re-earn the key by completing Level 5 again.
        civKeyGateAnswered.remove(civId)
        discoveredKeys.removeValue(forKey: civId)
        mysteryMarkIndex.removeValue(forKey: civId)
        if civId == .chinese { chinaMysteryMarkIndex2 = 0 }

        saveProgress()
        HapticFeedback.heavy()
    }

    // MARK: - Maya Game

    func startMayanGame() {
        lastActiveCivilization = .maya
        let idx = min(mayanUnlockedLevels.count, MayanLevel.allLevels.count - 1)
        loadMayanLevel(idx)
        previousScreen = currentScreen
        currentScreen = .mayanGame
    }

    func closeMayanGame() {
        mayanPendingComplete = false
        currentScreen = previousScreen == .mayanGame ? .title : previousScreen
    }

    func loadMayanLevel(_ index: Int) {
        mayanCurrentLevelIndex = index
        resetMayanGrid(for: MayanLevel.allLevels[index])
        mayanSelectedCell = nil
        mayanArmedGlyph = nil
        mayanErrorCells = []
        mayanPendingComplete = false
    }

    func resetMayanGrid(for level: MayanLevel) {
        mayanPlayerGrid = level.cycles.map { cycle in
            (0..<level.sequenceLength).map { pos in
                cycle.isRevealed(pos) ? cycle.symbol(at: pos) : nil
            }
        }
    }

    func resetMayanGrid() {
        resetMayanGrid(for: mayanCurrentLevel)
        mayanSelectedCell = nil
        mayanArmedGlyph = nil
        mayanErrorCells = []
    }

    func placeMayanGlyph(_ glyph: MayanGlyph, at coord: MayanCellCoord) {
        guard mayanPlayerGrid.indices.contains(coord.cycle),
              mayanPlayerGrid[coord.cycle].indices.contains(coord.position),
              !mayanCurrentLevel.cycles[coord.cycle].isRevealed(coord.position) else { return }
        mayanPlayerGrid[coord.cycle][coord.position] = glyph
        mayanErrorCells.remove(coord)
        // Check for solution after every placement
        if mayanCurrentLevel.isSolved(mayanPlayerGrid) {
            if mayanCurrentLevelIndex == 0 && needsKeyGate(for: .maya) {
                if mysteryMarkIsCorrect(for: .maya) {
                    passKeyGate(for: .maya)
                    completeMayanLevel()
                } else {
                    flashMysteryMarkWrong()
                }
            } else {
                completeMayanLevel()
            }
        }
    }

    func clearMayanCell(_ coord: MayanCellCoord) {
        guard mayanPlayerGrid.indices.contains(coord.cycle),
              mayanPlayerGrid[coord.cycle].indices.contains(coord.position),
              !mayanCurrentLevel.cycles[coord.cycle].isRevealed(coord.position) else { return }
        mayanPlayerGrid[coord.cycle][coord.position] = nil
        mayanErrorCells.remove(coord)
    }

    func verifyMayanPlacement() {
        let wrong = mayanCurrentLevel.incorrectCells(mayanPlayerGrid)
        if wrong.isEmpty && mayanCurrentLevelIndex == 0 && needsKeyGate(for: .maya)
            && !mysteryMarkIsCorrect(for: .maya) {
            flashMysteryMarkWrong()
            return
        }
        mayanErrorCells = wrong
        if !wrong.isEmpty {
            HapticFeedback.heavy()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.mayanErrorCells = []
            }
        }
    }

    func completeMayanLevel() {
        let level = mayanCurrentLevel
        mayanUnlockedLevels.insert(level.id)
        if mayanCurrentLevelIndex == MayanLevel.allLevels.count - 1 {
            recordKey(for: .maya)
        }
        saveProgress()
        HapticFeedback.heavy()
        mayanPendingComplete = true
        // Navigation handled by the completion card buttons — no auto-advance.
    }

    func advanceMayanToNextLevel() {
        let next = mayanCurrentLevelIndex + 1
        if next < MayanLevel.allLevels.count {
            loadMayanLevel(next)
            mayanPendingComplete = false
        } else {
            closeMayanGame()
        }
    }

    // MARK: Maya Debug

    func debugJumpToMayanLevel(_ level: MayanLevel) {
        guard let idx = MayanLevel.allLevels.firstIndex(where: { $0.id == level.id }) else { return }
        loadMayanLevel(idx)
        currentScreen = .mayanGame
    }

    func debugSolveMayanLevel(_ level: MayanLevel) {
        guard let idx = MayanLevel.allLevels.firstIndex(where: { $0.id == level.id }) else { return }
        loadMayanLevel(idx)
        let l = MayanLevel.allLevels[idx]
        mayanPlayerGrid = l.cycles.enumerated().map { (_, cycle) in
            (0..<l.sequenceLength).map { pos in cycle.symbol(at: pos) }
        }
        completeMayanLevel()
    }

    // MARK: - Chinese Box Puzzle

    func startChineseGame() {
        lastActiveCivilization = .chinese
        let idx = min(chineseUnlockedLevels.count, ChineseBoxLevel.allLevels.count - 1)
        loadChineseLevel(idx)
        previousScreen = currentScreen
        currentScreen = .chineseGame
    }

    func closeChineseGame() {
        chinesePendingComplete = false
        currentScreen = previousScreen == .chineseGame ? .title : previousScreen
    }

    func loadChineseLevel(_ index: Int) {
        chineseCurrentLevelIndex = index
        resetChinesePieces(for: ChineseBoxLevel.allLevels[index])
        chineseSelectedPieceId = nil
        chineseArmedRotation = 0
        chinesePendingComplete = false
    }

    func resetChinesePieces(for level: ChineseBoxLevel) {
        chinesePlacedPieces = [:]
    }

    func resetChinesePieces() {
        resetChinesePieces(for: chineseCurrentLevel)
        chineseSelectedPieceId = nil
        chineseArmedRotation = 0
        HapticFeedback.heavy()
    }

    /// Select a piece from the palette. If already selected, rotate it instead.
    func selectChinesePiece(id: String) {
        if chineseSelectedPieceId == id {
            chineseArmedRotation = (chineseArmedRotation + 1) % 4
            HapticFeedback.tap()
        } else {
            chineseSelectedPieceId = id
            chineseArmedRotation = 0
            HapticFeedback.tap()
        }
    }

    func rotateSelectedChinesePiece() {
        guard chineseSelectedPieceId != nil else { return }
        chineseArmedRotation = (chineseArmedRotation + 1) % 4
        HapticFeedback.tap()
    }

    /// Place the selected piece with its top-left anchor at (row, col).
    func placeChinesePiece(id: String, row: Int, col: Int) {
        let level = chineseCurrentLevel
        guard let piece = level.pieces.first(where: { $0.id == id }) else { return }
        let proposed = ChinesePiecePlacement(row: row, col: col, rotation: chineseArmedRotation)
        guard level.isValidPlacement(piece: piece, proposed: proposed, existing: chinesePlacedPieces) else {
            HapticFeedback.error()
            return
        }
        chinesePlacedPieces[id] = proposed
        chineseSelectedPieceId = nil
        chineseArmedRotation = 0
        HapticFeedback.tap()
        if level.isSolved(chinesePlacedPieces) {
            if chineseCurrentLevelIndex == 0 && needsKeyGate(for: .chinese) {
                if mysteryMarkIsCorrect(for: .chinese) {
                    passKeyGate(for: .chinese)
                    completeChineseLevel()
                } else {
                    flashMysteryMarkWrong()
                }
            } else {
                completeChineseLevel()
            }
        }
    }

    func removeChinesePiece(id: String) {
        chinesePlacedPieces.removeValue(forKey: id)
        HapticFeedback.tap()
    }

    func completeChineseLevel() {
        let level = chineseCurrentLevel
        chineseUnlockedLevels.insert(level.id)
        if chineseCurrentLevelIndex == ChineseBoxLevel.allLevels.count - 1 {
            recordKey(for: .chinese)
        }
        saveProgress()
        HapticFeedback.heavy()
        chinesePendingComplete = true
        // Navigation handled by the completion card buttons — no auto-advance.
    }

    func advanceChineseToNextLevel() {
        let next = chineseCurrentLevelIndex + 1
        if next < ChineseBoxLevel.allLevels.count {
            loadChineseLevel(next)
            chinesePendingComplete = false
        } else {
            closeChineseGame()
        }
    }

    // MARK: Chinese Debug

    func debugJumpToChineseLevel(_ level: ChineseBoxLevel) {
        guard let idx = ChineseBoxLevel.allLevels.firstIndex(where: { $0.id == level.id }) else { return }
        loadChineseLevel(idx)
        currentScreen = .chineseGame
    }

    func debugSolveChineseLevel(_ level: ChineseBoxLevel) {
        guard let idx = ChineseBoxLevel.allLevels.firstIndex(where: { $0.id == level.id }) else { return }
        loadChineseLevel(idx)
        chinesePlacedPieces = ChineseBoxLevel.allLevels[idx].solutionPlacements
        completeChineseLevel()
    }

    // MARK: - Celtic Ogham Ordering

    func startCelticGame() {
        lastActiveCivilization = .celtic
        let idx = min(celticUnlockedLevels.count, CelticDifficulty.all.count - 1)
        loadCelticLevel(idx)
        previousScreen = currentScreen
        currentScreen = .celticGame
    }

    func closeCelticGame() {
        celticPendingComplete = false
        currentScreen = previousScreen == .celticGame ? .title : previousScreen
    }

    func loadCelticLevel(_ index: Int) {
        let safeIndex = max(0, min(index, CelticDifficulty.all.count - 1))
        celticCurrentLevelIndex = safeIndex
        let difficulty = CelticDifficulty.all[safeIndex]
        celticCurrentPuzzle = CelticGenerator.generate(difficulty: difficulty)
        celticPlayerGrid = celticCurrentPuzzle?.initialGrid() ?? []
        celticArmedGlyph = nil
        celticErrorCells = []
        celticPendingComplete = false
    }

    func armCelticGlyph(_ glyph: OghamGlyph) {
        celticArmedGlyph = (celticArmedGlyph == glyph) ? nil : glyph
        HapticFeedback.tap()
    }

    func tapCelticCell(row: Int, col: Int) {
        guard let puzzle = celticCurrentPuzzle else { return }
        let coord = CelticCellCoord(row: row, col: col)
        guard !puzzle.fixedCells.contains(coord) else { return }
        guard celticPlayerGrid.indices.contains(row),
              celticPlayerGrid[row].indices.contains(col) else { return }

        if let armed = celticArmedGlyph {
            if celticPlayerGrid[row][col] == armed {
                celticPlayerGrid[row][col] = nil
            } else {
                celticPlayerGrid[row][col] = armed
            }
        } else {
            // No palette selection — cycle through glyphs
            let current = celticPlayerGrid[row][col]
            let all = OghamGlyph.allCases
            if let c = current, let idx = all.firstIndex(of: c) {
                celticPlayerGrid[row][col] = (idx + 1 < all.count) ? all[idx + 1] : nil
            } else {
                celticPlayerGrid[row][col] = all.first
            }
        }

        celticErrorCells.remove(coord)
        HapticFeedback.tap()

        if puzzle.isSolved(celticPlayerGrid) {
            if celticCurrentLevelIndex == 0 && needsKeyGate(for: .celtic) {
                if mysteryMarkIsCorrect(for: .celtic) {
                    passKeyGate(for: .celtic)
                    completeCelticLevel()
                } else {
                    flashMysteryMarkWrong()
                }
            } else {
                completeCelticLevel()
            }
        }
    }

    func clearCelticCell(row: Int, col: Int) {
        guard let puzzle = celticCurrentPuzzle else { return }
        let coord = CelticCellCoord(row: row, col: col)
        guard !puzzle.fixedCells.contains(coord),
              celticPlayerGrid.indices.contains(row),
              celticPlayerGrid[row].indices.contains(col) else { return }
        celticPlayerGrid[row][col] = nil
        celticErrorCells.remove(coord)
        HapticFeedback.tap()
    }

    func resetCelticGrid() {
        celticPlayerGrid = celticCurrentPuzzle?.initialGrid() ?? []
        celticArmedGlyph = nil
        celticErrorCells = []
        HapticFeedback.heavy()
    }

    func verifyCelticPlacement() {
        guard let puzzle = celticCurrentPuzzle else { return }
        let errors = puzzle.errorCells(in: celticPlayerGrid)
        if errors.isEmpty && celticCurrentLevelIndex == 0 && needsKeyGate(for: .celtic)
            && !mysteryMarkIsCorrect(for: .celtic) {
            flashMysteryMarkWrong()
            return
        }
        celticErrorCells = errors
        if !errors.isEmpty {
            HapticFeedback.heavy()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.celticErrorCells = []
            }
        }
    }

    func completeCelticLevel() {
        let levelId = celticCurrentLevelIndex + 1   // IDs are 1-based
        celticUnlockedLevels.insert(levelId)
        if celticCurrentLevelIndex == CelticDifficulty.all.count - 1 {
            recordKey(for: .celtic)
        }
        saveProgress()
        HapticFeedback.heavy()
        celticPendingComplete = true
        // Navigation handled by the completion card buttons — no auto-advance.
    }

    func advanceCelticToNextLevel() {
        let next = celticCurrentLevelIndex + 1
        if next < CelticDifficulty.all.count {
            loadCelticLevel(next)
            celticPendingComplete = false
        } else {
            closeCelticGame()
        }
    }

    // MARK: Celtic Debug

    func debugJumpToCelticLevel(_ difficulty: CelticDifficulty) {
        guard let idx = CelticDifficulty.all.firstIndex(where: { $0.id == difficulty.id }) else { return }
        loadCelticLevel(idx)
        currentScreen = .celticGame
    }

    func debugSolveCelticLevel(_ difficulty: CelticDifficulty) {
        guard let idx = CelticDifficulty.all.firstIndex(where: { $0.id == difficulty.id }) else { return }
        loadCelticLevel(idx)
        guard let puzzle = celticCurrentPuzzle else { return }
        celticPlayerGrid = (0..<puzzle.rows).map { r in
            (0..<puzzle.cols).map { c in OghamGlyph.from(value: puzzle.solution[r][c]) }
        }
        completeCelticLevel()
    }

    // MARK: Progress Persistence

    private func saveProgress() {
        UserDefaults.standard.set(Array(unlockedJournalEntries), forKey: "EOA_unlockedEntries")
        UserDefaults.standard.set(discoveredGlyphs.map(\.rawValue), forKey: "EOA_codex")
        let messagesDict = decodedMessages.reduce(into: [String: String]()) { $0["\($1.key)"] = $1.value }
        UserDefaults.standard.set(messagesDict, forKey: "EOA_chronicle")
        UserDefaults.standard.set(showIntroOnLaunch, forKey: "EOA_showIntro")
        UserDefaults.standard.set(playerName, forKey: "EOA_playerName")
        UserDefaults.standard.set(Array(norseUnlockedLevels), forKey: "EOA_norseUnlocked")
        UserDefaults.standard.set(Array(mayanUnlockedLevels), forKey: "EOA_mayanUnlocked")
        UserDefaults.standard.set(Array(chineseUnlockedLevels), forKey: "EOA_chineseUnlocked")
        UserDefaults.standard.set(Array(celticUnlockedLevels),  forKey: "EOA_celticUnlocked")
        UserDefaults.standard.set(lastActiveCivilization?.rawValue, forKey: "EOA_lastCiv")
        let keysDict = discoveredKeys.reduce(into: [String: String]()) { $0[$1.key.rawValue] = $1.value }
        UserDefaults.standard.set(keysDict, forKey: "EOA_discoveredKeys")
        UserDefaults.standard.set(civKeyGateAnswered.map(\.rawValue), forKey: "EOA_keyGateAnswered")
        // Only persist the Mandu grid when all six civilizations are complete.
        // Until then symbols fall off — clearing here ensures a fresh slate on next open.
        if allSixCivsComplete {
            let manduDict = manduPlayerGrid.reduce(into: [String: String]()) { $0["\($1.key)"] = $1.value }
            UserDefaults.standard.set(manduDict, forKey: "EOA_manduGrid")
        } else {
            UserDefaults.standard.removeObject(forKey: "EOA_manduGrid")
        }
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
        if let rawCiv = UserDefaults.standard.string(forKey: "EOA_lastCiv") {
            lastActiveCivilization = CivilizationID(rawValue: rawCiv)
        }

        let sumerianIds = UserDefaults.standard.array(forKey: "EOA_sumerianUnlocked") as? [Int] ?? []
        sumerianUnlockedLevels = Set(sumerianIds)

        mayanUnlockedLevels = Set(UserDefaults.standard.array(forKey: "EOA_mayanUnlocked") as? [Int] ?? [])
        mayanCurrentLevelIndex = min(mayanUnlockedLevels.count, MayanLevel.allLevels.count - 1)

        chineseUnlockedLevels = Set(UserDefaults.standard.array(forKey: "EOA_chineseUnlocked") as? [Int] ?? [])
        chineseCurrentLevelIndex = min(chineseUnlockedLevels.count, ChineseBoxLevel.allLevels.count - 1)

        celticUnlockedLevels = Set(UserDefaults.standard.array(forKey: "EOA_celticUnlocked") as? [Int] ?? [])
        celticCurrentLevelIndex = min(celticUnlockedLevels.count, CelticDifficulty.all.count - 1)

        let rawKeys = UserDefaults.standard.dictionary(forKey: "EOA_discoveredKeys") as? [String: String] ?? [:]
        discoveredKeys = rawKeys.reduce(into: [CivilizationID: String]()) {
            if let civ = CivilizationID(rawValue: $1.key) { $0[civ] = $1.value }
        }
        let rawGate = UserDefaults.standard.array(forKey: "EOA_keyGateAnswered") as? [String] ?? []
        civKeyGateAnswered = Set(rawGate.compactMap { CivilizationID(rawValue: $0) })

        let rawMandu = UserDefaults.standard.dictionary(forKey: "EOA_manduGrid") as? [String: String] ?? [:]
        manduPlayerGrid = rawMandu.reduce(into: [Int: String]()) {
            if let id = Int($1.key) { $0[id] = $1.value }
        }

        // Default showIntroOnLaunch to true only on first ever run
        if UserDefaults.standard.object(forKey: "EOA_showIntro") == nil {
            showIntroOnLaunch = true
        } else {
            showIntroOnLaunch = UserDefaults.standard.bool(forKey: "EOA_showIntro")
        }

        playerName = UserDefaults.standard.string(forKey: "EOA_playerName") ?? ""
    }

    var hasProgress: Bool {
        lastActiveCivilization != nil
    }

    func saveSettings() {
        UserDefaults.standard.set(showIntroOnLaunch, forKey: "EOA_showIntro")
        UserDefaults.standard.set(playerName, forKey: "EOA_playerName")
    }

    /// Persist the player's name immediately (called from the name-entry sheet).
    func savePlayerName(_ name: String) {
        playerName = name.trimmingCharacters(in: .whitespaces)
        UserDefaults.standard.set(playerName, forKey: "EOA_playerName")
    }

    // MARK: - Master Reset

    /// Wipes every piece of game state and returns the player to the title screen,
    /// exactly as if the app had never been launched before.
    func masterReset() {
        // ── Egyptian puzzle ──────────────────────────────────────
        currentLevelIndex = 0
        selectedGlyph = nil
        errorCells = []
        isAnimatingCompletion = false
        unlockedJournalEntries = []
        discoveredGlyphs = []
        decodedMessages = [:]
        pendingDecodedMessage = ""
        spotlightJournalId = nil
        resetGrid(for: Level.allLevels[0])

        // ── Norse ─────────────────────────────────────────────────
        norseCurrentLevelIndex = 0
        norsePath = []
        norseErrorCells = []
        norseIsAnimatingCompletion = false
        norseUnlockedLevels = []
        norseActiveLevel = nil

        // ── Sumerian ──────────────────────────────────────────────
        sumerianCurrentLevelIndex = 0
        sumerianSelectedDecodedIndex = nil
        sumerianErrorPositions = []
        sumerianUnlockedLevels = []
        sumerianPendingComplete = false
        sumerianPendingDecodedMessage = ""
        resetSumerianDecoded(for: SumerianLevel.allLevels[0])

        // ── Maya ──────────────────────────────────────────────────
        mayanCurrentLevelIndex = 0
        mayanUnlockedLevels = []
        mayanSelectedCell = nil
        mayanArmedGlyph = nil
        mayanErrorCells = []
        mayanPendingComplete = false
        resetMayanGrid(for: MayanLevel.allLevels[0])

        // ── Chinese ───────────────────────────────────────────────
        chineseCurrentLevelIndex = 0
        chineseUnlockedLevels = []
        chineseSelectedPieceId = nil
        chineseArmedRotation = 0
        chinesePendingComplete = false
        resetChinesePieces(for: ChineseBoxLevel.allLevels[0])

        // ── Celtic ────────────────────────────────────────────────
        celticCurrentLevelIndex = 0
        celticUnlockedLevels = []
        celticPlayerGrid = []
        celticArmedGlyph = nil
        celticErrorCells = []
        celticPendingComplete = false
        celticCurrentPuzzle = nil

        // ── Tree of Life / Mandu Tablet ───────────────────────────
        discoveredKeys = [:]
        civKeyGateAnswered = []
        mysteryMarkIndex = [:]
        chinaMysteryMarkIndex2 = 0
        mysteryMarkWrongFlash = false
        manduPlayerGrid = [:]
        manduArmedCiv = nil

        // ── Navigation / session ──────────────────────────────────
        lastActiveCivilization = nil
        journalTargetPage = nil
        previousScreen = .title

        // ── UserDefaults ──────────────────────────────────────────
        let keysToErase = [
            "EOA_unlockedEntries", "EOA_codex", "EOA_chronicle",
            "EOA_norseUnlocked", "EOA_sumerianUnlocked", "EOA_mayanUnlocked",
            "EOA_chineseUnlocked", "EOA_celticUnlocked", "EOA_lastCiv",
            "EOA_discoveredKeys", "EOA_keyGateAnswered", "EOA_manduGrid",
            "EOA_hasSeenIntro"
        ]
        keysToErase.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        // Keep showIntroOnLaunch and playerName — the player set those deliberately.

        HapticFeedback.heavy()
        currentScreen = .title
    }
}
