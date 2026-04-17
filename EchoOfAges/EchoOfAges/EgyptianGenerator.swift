// EgyptianGenerator.swift
// EchoOfAges
//
// Generates fresh Latin-square puzzles for each Egyptian level every session.
// All narrative content (titles, lore, inscriptions, journal entries, decoded
// messages, newGlyphs, variant) is preserved exactly from the static Level
// templates in Level.swift. Only the solution grid and fixed-cell positions
// are randomised.
//
// Variants handled:
//   .standard       — random Latin square, N fixed cells
//   .noAdjacent     — same (any Latin square satisfies no-adjacent trivially)
//   .hiddenRegions  — Sudoku-valid Latin square (each 2×2 quadrant unique)
//   .pureDeduction  — minimal fixed cells (target: 5 for a 5×5 grid)

import Foundation

enum EgyptianGenerator {

    // MARK: - Public API

    /// Returns a freshly generated version of `template`, preserving all narrative
    /// but replacing the solution and fixed positions with newly generated ones.
    /// Falls back to the original static template if generation fails repeatedly.
    static func refresh(_ template: Level) -> Level {
        for _ in 0..<80 {
            if let generated = attempt(template) { return generated }
        }
        return template
    }

    // MARK: - Generation Attempt

    private static func attempt(_ template: Level) -> Level? {
        let glyphs = template.availableGlyphs
        let rows   = template.rows
        let cols   = template.cols

        // 1. Generate a valid Latin square solution
        let solution: [[Glyph]]
        if case .hiddenRegions = template.variant {
            solution = randomSudokuLatinSquare(glyphs: glyphs)
        } else {
            guard let s = randomLatinSquare(glyphs: glyphs, rows: rows, cols: cols) else { return nil }
            solution = s
        }

        // 2. Dig holes until the target fixed-cell count is reached
        let target = fixedCellTarget(for: template)
        guard let fixed = digHoles(solution: solution, glyphs: glyphs,
                                   rows: rows, cols: cols,
                                   targetFixed: target,
                                   variant: template.variant) else { return nil }

        // 3. Build a new Level with the original template's narrative
        return Level(
            id:              template.id,
            civilization:    template.civilization,
            title:           template.title,
            subtitle:        template.subtitle,
            lore:            template.lore,
            inscriptions:    template.inscriptions,
            rows:            rows,
            cols:            cols,
            availableGlyphs: glyphs,
            initialGrid:     makeInitialGrid(solution: solution, fixed: fixed,
                                             rows: rows, cols: cols),
            fixedPositions:  Set(fixed.keys),
            solution:        solution,
            journalEntry:    template.journalEntry,
            decodedMessage:  template.decodedMessage,
            newGlyphs:       template.newGlyphs,
            variant:         template.variant
        )
    }

    // MARK: - Fixed-Cell Target

    private static func fixedCellTarget(for level: Level) -> Int {
        switch level.id {
        case 1: return 3   // 3×3  — 3 anchor cells
        case 2: return 4   // 4×4  — 4 anchors
        case 3: return 4   // 4×4  — 4 anchors (Sudoku variant)
        case 4: return 7   // 5×5  — 7 anchors
        case 5: return 5   // 5×5  — only 5 anchors (pure deduction)
        default: return 4
        }
    }

    // MARK: - Latin Square Generation
    //
    // Generates a random n×n Latin square by starting from the canonical cyclic
    // square and applying three independent random permutations:
    //   (a) permute rows
    //   (b) permute columns
    //   (c) permute glyph labels
    // Any composition of these produces a valid Latin square.

    private static func randomLatinSquare(glyphs: [Glyph], rows: Int, cols: Int) -> [[Glyph]]? {
        let n = glyphs.count
        guard rows == n, cols == n else { return nil }

        // Cyclic base: cell (r, c) = (r + c) % n
        var indices = (0..<n).map { r in (0..<n).map { c in (r + c) % n } }

        // (a) Permute rows
        let rowPerm = Array(0..<n).shuffled()
        indices = rowPerm.map { indices[$0] }

        // (b) Permute columns
        let colPerm = Array(0..<n).shuffled()
        indices = indices.map { row in colPerm.map { row[$0] } }

        // (c) Permute glyph labels
        let glyphPerm = glyphs.shuffled()
        return indices.map { row in row.map { glyphPerm[$0] } }
    }

    // Generates a random 4×4 Sudoku-valid Latin square — every row, column, and
    // 2×2 quadrant contains all four glyphs exactly once. Used for Level 3.
    //
    // Transformations that preserve the Sudoku property:
    //   • Swap rows within the same horizontal band (rows 0–1 or rows 2–3)
    //   • Swap the two bands
    //   • Swap columns within the same vertical stack (cols 0–1 or cols 2–3)
    //   • Swap the two stacks
    //   • Permute glyph labels

    private static func randomSudokuLatinSquare(glyphs: [Glyph]) -> [[Glyph]] {
        // Valid 4×4 Sudoku base (verified: each row, col, and 2×2 quadrant is {0,1,2,3})
        var g = [
            [0, 1, 2, 3],
            [2, 3, 0, 1],
            [1, 0, 3, 2],
            [3, 2, 1, 0]
        ]

        // Shuffle rows within top band
        if Bool.random() { g.swapAt(0, 1) }
        // Shuffle rows within bottom band
        if Bool.random() { g.swapAt(2, 3) }
        // Swap bands
        if Bool.random() { g = [g[2], g[3], g[0], g[1]] }

        // Shuffle columns within left stack
        if Bool.random() { for r in 0..<4 { g[r].swapAt(0, 1) } }
        // Shuffle columns within right stack
        if Bool.random() { for r in 0..<4 { g[r].swapAt(2, 3) } }
        // Swap stacks
        if Bool.random() { for r in 0..<4 { g[r] = [g[r][2], g[r][3], g[r][0], g[r][1]] } }

        // Permute glyph labels
        let glyphPerm = glyphs.shuffled()
        return g.map { row in row.map { glyphPerm[$0] } }
    }

    // MARK: - Hole Digging
    //
    // Starts with every cell given and iteratively removes cells in random order.
    // After each removal, the uniqueness solver checks whether exactly one solution
    // remains. If removing a cell breaks uniqueness, it is restored. Stops when
    // the given-cell count reaches `targetFixed` (or within 1 of it).

    private static func digHoles(
        solution: [[Glyph]], glyphs: [Glyph],
        rows: Int, cols: Int,
        targetFixed: Int,
        variant: PuzzleVariant
    ) -> [GridPosition: Glyph]? {
        var given = [GridPosition: Glyph]()
        for r in 0..<rows {
            for c in 0..<cols {
                given[GridPosition(row: r, col: c)] = solution[r][c]
            }
        }

        let positions = given.keys.shuffled()
        for pos in positions {
            guard given.count > targetFixed else { break }
            let saved = given.removeValue(forKey: pos)!
            if countSolutions(given: given, glyphs: glyphs,
                              rows: rows, cols: cols, variant: variant) != 1 {
                given[pos] = saved
            }
        }

        // Accept if within 1 cell of the target (digging may get stuck before target)
        return given.count <= targetFixed + 1 ? given : nil
    }

    // MARK: - Initial Grid

    private static func makeInitialGrid(
        solution: [[Glyph]], fixed: [GridPosition: Glyph],
        rows: Int, cols: Int
    ) -> [[Glyph?]] {
        (0..<rows).map { r in
            (0..<cols).map { c in fixed[GridPosition(row: r, col: c)] }
        }
    }

    // MARK: - Uniqueness Solver
    //
    // Backtracking solver that counts the number of valid completions of a
    // partial grid. Stops as soon as count reaches `maxCount` (default 2) to
    // avoid unnecessary work. Returns 1 iff the puzzle has a unique solution.

    static func countSolutions(
        given: [GridPosition: Glyph], glyphs: [Glyph],
        rows: Int, cols: Int, variant: PuzzleVariant,
        maxCount: Int = 2
    ) -> Int {
        var grid: [[Glyph?]] = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        for (pos, glyph) in given { grid[pos.row][pos.col] = glyph }
        var count = 0
        solve(grid: &grid, glyphs: glyphs, rows: rows, cols: cols,
              variant: variant, count: &count, maxCount: maxCount)
        return count
    }

    private static func solve(
        grid: inout [[Glyph?]], glyphs: [Glyph],
        rows: Int, cols: Int, variant: PuzzleVariant,
        count: inout Int, maxCount: Int
    ) {
        guard count < maxCount else { return }

        // Find the first empty cell
        for r in 0..<rows {
            for c in 0..<cols {
                guard grid[r][c] == nil else { continue }
                for glyph in glyphs {
                    if isValid(glyph, row: r, col: c, grid: grid,
                               rows: rows, cols: cols, variant: variant) {
                        grid[r][c] = glyph
                        solve(grid: &grid, glyphs: glyphs, rows: rows, cols: cols,
                              variant: variant, count: &count, maxCount: maxCount)
                        grid[r][c] = nil
                        guard count < maxCount else { return }
                    }
                }
                return  // no valid glyph for this cell — backtrack
            }
        }
        count += 1  // every cell filled validly
    }

    private static func isValid(
        _ glyph: Glyph, row: Int, col: Int, grid: [[Glyph?]],
        rows: Int, cols: Int, variant: PuzzleVariant
    ) -> Bool {
        // Row uniqueness
        for c in 0..<cols {
            if grid[row][c] == glyph { return false }
        }
        // Column uniqueness
        for r in 0..<rows {
            if grid[r][col] == glyph { return false }
        }
        // Region uniqueness (hiddenRegions only)
        if case .hiddenRegions(let regions) = variant {
            let pos = GridPosition(row: row, col: col)
            if let myRegion = regions.first(where: { $0.contains(pos) }) {
                for regionPos in myRegion {
                    if grid[regionPos.row][regionPos.col] == glyph { return false }
                }
            }
        }
        return true
    }
}
