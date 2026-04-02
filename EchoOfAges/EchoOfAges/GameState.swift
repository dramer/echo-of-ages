// GameState.swift
// EchoOfAges

import SwiftUI
import Combine

// MARK: - Screen

enum GameScreen: Equatable {
    case title
    case game
    case journal
    case levelComplete
    case gameComplete
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

    var currentLevel: Level { Level.allLevels[currentLevelIndex] }

    // MARK: Init

    init() {
        loadProgress()
        resetGrid(for: Level.allLevels[0])
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
        // Deep-copy the initial grid so mutations don't affect the static
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
            // Place or toggle-off the selected glyph
            if playerGrid[position.row][position.col] == picked {
                playerGrid[position.row][position.col] = nil
            } else {
                playerGrid[position.row][position.col] = picked
            }
        } else {
            // No palette selection — cycle through available glyphs
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
        // Must have all cells filled before checking
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

        let entryId = currentLevel.journalEntry.id
        unlockedJournalEntries.insert(entryId)
        spotlightJournalId = entryId
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

    // MARK: Progress Persistence

    private func saveProgress() {
        let ids = Array(unlockedJournalEntries)
        UserDefaults.standard.set(ids, forKey: "EOA_unlockedEntries")
    }

    private func loadProgress() {
        let ids = UserDefaults.standard.array(forKey: "EOA_unlockedEntries") as? [Int] ?? []
        unlockedJournalEntries = Set(ids)
    }

    var hasProgress: Bool {
        !unlockedJournalEntries.isEmpty
    }
}
