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
    case sumerianGame
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
        // Tier 3+: Maya, Celtic, Chinese (not yet implemented — fall through)
        // All available civs complete
        if allSixCivsComplete { currentScreen = .manduTablet }
    }

    /// Continue Journey — returns to the last civilization the player was actively working on.
    func continueGame() {
        switch lastActiveCivilization {
        case .egyptian:
            let next = min(unlockedJournalEntries.count, Level.allLevels.count - 1)
            loadLevel(next)
            currentScreen = .game
        case .norse:
            startNorseGame()
        case .sumerian:
            startSumerianGame()
        default:
            startNewGame() // no last session — route to next unsolved
        }
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

    // MARK: Sumerian State

    @Published var sumerianCurrentLevelIndex: Int = 0
    @Published var playerSumerianDecoded: [CuneiformGlyph?] = []
    @Published var sumerianSelectedDecodedIndex: Int? = nil
    @Published var sumerianErrorPositions: Set<Int> = []
    @Published var sumerianUnlockedLevels: Set<Int> = []
    @Published var sumerianPendingComplete: Bool = false
    @Published var sumerianPendingDecodedMessage: String = ""

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
            HapticFeedback.success()
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
        if sumerianCurrentLevel.isSolved(playerSumerianDecoded) {
            handleSumerianLevelComplete()
        }
    }

    private func handleSumerianLevelComplete() {
        HapticFeedback.success()
        let level = sumerianCurrentLevel
        sumerianUnlockedLevels.insert(level.id)
        sumerianPendingDecodedMessage = level.decodedMessage
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

    @Published var manduPlayerGrid: [Int: String] = [:]
    @Published var manduSelectedSlotId: Int? = nil

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

    /// True when every slot in the tablet has the correct symbol placed.
    var isManduComplete: Bool {
        TabletSlot.all.allSatisfy { manduPlayerGrid[$0.id] == $0.character }
    }

    var manduCorrectCount: Int {
        TabletSlot.all.filter { manduPlayerGrid[$0.id] == $0.character }.count
    }

    // MARK: Mandu Navigation

    func openManduTablet() {
        // Symbols fall off every time the tablet is opened — they only hold when all six are done.
        if !allSixCivsComplete { manduPlayerGrid = [:] }
        previousScreen = currentScreen
        currentScreen = .manduTablet
    }

    func closeManduTablet() {
        currentScreen = (previousScreen == .manduTablet) ? .title : previousScreen
    }

    // MARK: Mandu Interaction

    func tapManduSlot(_ slotId: Int) {
        if manduSelectedSlotId == slotId {
            manduSelectedSlotId = nil
        } else {
            manduSelectedSlotId = slotId
            HapticFeedback.tap()
        }
    }

    func placeManduSymbol(_ character: String) {
        guard let slotId = manduSelectedSlotId else { return }
        if manduPlayerGrid[slotId] == character {
            manduPlayerGrid.removeValue(forKey: slotId)
        } else {
            manduPlayerGrid[slotId] = character
            HapticFeedback.tap()
        }
        manduSelectedSlotId = nil
        if isManduComplete { HapticFeedback.success() }
    }

    func resetManduGrid() {
        manduPlayerGrid = [:]
        manduSelectedSlotId = nil
        HapticFeedback.heavy()
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
        UserDefaults.standard.set(lastActiveCivilization?.rawValue, forKey: "EOA_lastCiv")
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
    }

    var hasProgress: Bool {
        lastActiveCivilization != nil
    }

    func saveSettings() {
        UserDefaults.standard.set(showIntroOnLaunch, forKey: "EOA_showIntro")
    }
}
