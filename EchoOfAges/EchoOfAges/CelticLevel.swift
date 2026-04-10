// CelticLevel.swift
// EchoOfAges
//
// Dynamic Ogham ordering puzzles for the Celtic / Druidic civilization.
//
// Mechanic: The player fills a grid of Ogham letters so that every row
// (left → right) and every column (top → bottom) is non-decreasing.
// Row sums and column sums are carved on the stone as additional targets —
// together they usually force a unique solution.
//
// Puzzles are generated fresh each session so no two plays are identical.
//
// The five Ogham letters:
//   ᚁ Beith (Birch)  — value 1
//   ᚂ Luis  (Rowan)  — value 2
//   ᚃ Fearn (Alder)  — value 3
//   ᚄ Sail  (Willow) — value 4
//   ᚅ Nion  (Ash)    — value 5

import Foundation

// MARK: - OghamGlyph

enum OghamGlyph: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case beith = "ᚁ"   // Birch  — value 1
    case luis  = "ᚂ"   // Rowan  — value 2
    case fearn = "ᚃ"   // Alder  — value 3
    case sail  = "ᚄ"   // Willow — value 4
    case nion  = "ᚅ"   // Ash    — value 5

    var id: String { rawValue }

    var value: Int {
        switch self {
        case .beith: return 1
        case .luis:  return 2
        case .fearn: return 3
        case .sail:  return 4
        case .nion:  return 5
        }
    }

    var treeName: String {
        switch self {
        case .beith: return "Beith"
        case .luis:  return "Luis"
        case .fearn: return "Fearn"
        case .sail:  return "Sail"
        case .nion:  return "Nion"
        }
    }

    var treeMeaning: String {
        switch self {
        case .beith: return "Birch"
        case .luis:  return "Rowan"
        case .fearn: return "Alder"
        case .sail:  return "Willow"
        case .nion:  return "Ash"
        }
    }

    static func from(value: Int) -> OghamGlyph? {
        allCases.first { $0.value == value }
    }
}

// MARK: - Cell Coordinate

struct CelticCellCoord: Hashable, Equatable {
    let row: Int
    let col: Int
}

// MARK: - CelticPuzzle
//
// A single generated puzzle instance. Created by CelticGenerator each time
// a level is loaded. Carries the full solution so debug-solve can fill it in.

struct CelticPuzzle {
    let rows: Int
    let cols: Int
    let rowSums: [Int]
    let colSums: [Int]
    /// Cells pre-carved on the stone — cannot be changed by the player.
    let fixedCells: Set<CelticCellCoord>
    /// Values (1–5) for every fixed cell.
    let fixedValues: [CelticCellCoord: Int]
    /// Complete solution grid (values 1–5) used only for debug-solve.
    let solution: [[Int]]

    // MARK: Grid Helpers

    func initialGrid() -> [[OghamGlyph?]] {
        (0..<rows).map { r in
            (0..<cols).map { c in
                let coord = CelticCellCoord(row: r, col: c)
                return fixedValues[coord].flatMap { OghamGlyph.from(value: $0) }
            }
        }
    }

    // MARK: Validation

    /// True when every cell is filled, every row/column is non-decreasing,
    /// and every row sum and column sum matches the carved targets.
    func isSolved(_ grid: [[OghamGlyph?]]) -> Bool {
        guard grid.count == rows, grid.allSatisfy({ $0.count == cols }) else { return false }

        // All cells filled
        for r in 0..<rows {
            for c in 0..<cols {
                guard grid[r][c] != nil else { return false }
            }
        }

        // Row ordering
        for r in 0..<rows {
            for c in 1..<cols {
                guard let a = grid[r][c-1], let b = grid[r][c], a.value <= b.value else { return false }
            }
        }

        // Column ordering
        for c in 0..<cols {
            for r in 1..<rows {
                guard let a = grid[r-1][c], let b = grid[r][c], a.value <= b.value else { return false }
            }
        }

        // Row sums
        for r in 0..<rows {
            let s = grid[r].compactMap { $0?.value }.reduce(0, +)
            if s != rowSums[r] { return false }
        }

        // Column sums
        for c in 0..<cols {
            let s = (0..<rows).compactMap { grid[$0][c]?.value }.reduce(0, +)
            if s != colSums[c] { return false }
        }

        return true
    }

    /// Returns cells that participate in any ordering violation or
    /// belong to a fully-filled row/column whose sum is wrong.
    func errorCells(in grid: [[OghamGlyph?]]) -> Set<CelticCellCoord> {
        var errors = Set<CelticCellCoord>()

        // Ordering violations
        for r in 0..<rows {
            for c in 1..<cols {
                if let a = grid[r][c-1], let b = grid[r][c], a.value > b.value {
                    errors.insert(.init(row: r, col: c-1))
                    errors.insert(.init(row: r, col: c))
                }
            }
        }
        for c in 0..<cols {
            for r in 1..<rows {
                if let a = grid[r-1][c], let b = grid[r][c], a.value > b.value {
                    errors.insert(.init(row: r-1, col: c))
                    errors.insert(.init(row: r,   col: c))
                }
            }
        }

        // Sum violations on complete rows
        for r in 0..<rows {
            let vals = grid[r].compactMap { $0?.value }
            if vals.count == cols, vals.reduce(0, +) != rowSums[r] {
                for c in 0..<cols { errors.insert(.init(row: r, col: c)) }
            }
        }

        // Sum violations on complete columns
        for c in 0..<cols {
            let vals = (0..<rows).compactMap { grid[$0][c]?.value }
            if vals.count == rows, vals.reduce(0, +) != colSums[c] {
                for r in 0..<rows { errors.insert(.init(row: r, col: c)) }
            }
        }

        return errors
    }
}

// MARK: - CelticDifficulty
//
// Static display content for each of the five difficulty tiers.
// CelticGenerator uses these to know the grid size and target blank count.

struct CelticDifficulty: Identifiable {
    let id: Int                      // 1–5
    let title: String
    let subtitle: String
    let inscriptions: [String]
    let decodedMessage: String
    let rows: Int
    let cols: Int
    let targetBlanks: Int

    var romanNumeral: String {
        ["I", "II", "III", "IV", "V"][min(id - 1, 4)]
    }
}

extension CelticDifficulty {

    static let all: [CelticDifficulty] = [d1, d2, d3, d4, d5]

    static let d1 = CelticDifficulty(
        id: 1,
        title: "The First Inscription",
        subtitle: "Two rows on the standing stone",
        inscriptions: [
            "From left to right, each row must rise — no mark may be smaller than the one before it. The same law holds from top to bottom in every column. Together with the sum carved beside each row and below each column, these constraints leave only one arrangement.",
            "The numbers carved beside each row and below each column reveal their totals.",
            "A single arrangement satisfies both the ordering and the sums."
        ],
        decodedMessage: "Beith rises before all others. Even the birch must learn what comes before it can grow.",
        rows: 2, cols: 3,
        targetBlanks: 3
    )

    static let d2 = CelticDifficulty(
        id: 2,
        title: "The Grove Square",
        subtitle: "Three rows, three columns",
        inscriptions: [
            "Rows and columns both rise, and the sums on this stone are tighter than the first. Start with the row or column whose sum allows the fewest combinations of Ogham values. Each narrowed choice removes possibilities from every cell that shares its row or column.",
            "Each carved sum fixes the total for its row and column — use them to narrow your choices.",
            "Where ordering and sums both apply, very few arrangements remain."
        ],
        decodedMessage: "The rowan protects the grove. But only the ash, at the last corner, completes the boundary.",
        rows: 3, cols: 3,
        targetBlanks: 5
    )

    static let d3 = CelticDifficulty(
        id: 3,
        title: "The Long Stone",
        subtitle: "Three rows, four columns",
        inscriptions: [
            "Only by reading row sums and column sums together does this longer stone yield. More columns means a longer ordering chain — a wrong mark at the left end will break a sum at the far right. Let the most constrained row or column guide the very first placement.",
            "A row sum that leaves little room forces you to place higher marks earlier.",
            "The sum on each column ties the rows together. Work both directions."
        ],
        decodedMessage: "The alder grows beside the water. It holds its place in the order, season after season.",
        rows: 3, cols: 4,
        targetBlanks: 7
    )

    static let d4 = CelticDifficulty(
        id: 4,
        title: "The Four Sacred Trees",
        subtitle: "Four rows, four columns",
        inscriptions: [
            "No mark here stands alone. Every cell touches a row and a column — a wrong value ripples outward and breaks a sum somewhere else on the stone. The sums are tight: a single error in one row will violate a column sum elsewhere. Read the grid as a whole.",
            "The sums are tight. A wrong choice in one row will violate a column sum elsewhere.",
            "Every mark constrains its neighbors in all four directions. Read the stone as a whole."
        ],
        decodedMessage: "The willow bends without breaking. The ash stands without moving. Between them — the whole of what it means to endure.",
        rows: 4, cols: 4,
        targetBlanks: 10
    )

    static let d5 = CelticDifficulty(
        id: 5,
        title: "The Master's Inscription",
        subtitle: "The complete Ogham sequence",
        inscriptions: [
            "Deeper than any stone before it — twenty marks, most hidden. Work from the most constrained rows first: where the sum leaves the fewest possible combinations of Ogham values, those cells are nearest to forced. Let the stone guide you to certainty before guesswork.",
            "Work from the most constrained rows and columns first — the ones whose sums allow the fewest combinations.",
            "When you place the last mark and the stone reads true in every direction, the inscription is complete."
        ],
        decodedMessage: "Every tree named every other tree. Every voice in the grove spoke in the same sacred order. They did not know this was the word for 'remember.' They only knew it was the word for 'tree.'",
        rows: 4, cols: 5,
        targetBlanks: 14
    )
}

// MARK: - CelticGenerator
//
// Generates a fresh CelticPuzzle for a given difficulty tier each call.
//
// Algorithm:
//   1. Fill a random valid Young Tableau (non-decreasing rows + columns).
//   2. Compute row sums and column sums from the tableau.
//   3. Dig holes: remove cells one by one while the puzzle retains a
//      unique solution (verified by a backtracking solver that stops at 2).

enum CelticGenerator {

    // MARK: Public

    static func generate(difficulty: CelticDifficulty) -> CelticPuzzle {
        for _ in 0..<40 {
            if let p = attempt(difficulty: difficulty) { return p }
        }
        // Fallback: return fully-revealed puzzle (very rare)
        return fullyRevealedPuzzle(difficulty: difficulty)
    }

    // MARK: Private — Generation

    private static func attempt(difficulty: CelticDifficulty) -> CelticPuzzle? {
        let rows = difficulty.rows
        let cols = difficulty.cols
        let tableau = randomTableau(rows: rows, cols: cols)
        let rowSums = (0..<rows).map { r in tableau[r].reduce(0, +) }
        let colSums = (0..<cols).map { c in (0..<rows).map { tableau[$0][c] }.reduce(0, +) }

        // Build a complete givenValues map (all cells fixed)
        var givenValues = [CelticCellCoord: Int]()
        for r in 0..<rows {
            for c in 0..<cols {
                givenValues[CelticCellCoord(row: r, col: c)] = tableau[r][c]
            }
        }

        // Dig holes until we reach targetBlanks (or can't go further)
        let finalGiven = digHoles(
            rows: rows, cols: cols,
            rowSums: rowSums, colSums: colSums,
            givenValues: givenValues,
            targetBlanks: difficulty.targetBlanks
        )

        let blanksAchieved = rows * cols - finalGiven.count
        // Require at least 60 % of target blanks to avoid trivially easy puzzles
        guard blanksAchieved >= max(1, difficulty.targetBlanks * 6 / 10) else { return nil }

        return CelticPuzzle(
            rows: rows, cols: cols,
            rowSums: rowSums, colSums: colSums,
            fixedCells: Set(finalGiven.keys),
            fixedValues: finalGiven,
            solution: tableau
        )
    }

    private static func randomTableau(rows: Int, cols: Int) -> [[Int]] {
        var grid = Array(repeating: Array(repeating: 0, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                let lo = max(c > 0 ? grid[r][c-1] : 1,
                             r > 0 ? grid[r-1][c] : 1)
                grid[r][c] = Int.random(in: lo...5)
            }
        }
        return grid
    }

    private static func digHoles(
        rows: Int, cols: Int,
        rowSums: [Int], colSums: [Int],
        givenValues: [CelticCellCoord: Int],
        targetBlanks: Int
    ) -> [CelticCellCoord: Int] {
        var given = givenValues
        var removed = 0

        // Shuffle all coords so we dig in a random order each generation
        var coords = (0..<rows).flatMap { r in (0..<cols).map { c in CelticCellCoord(row: r, col: c) } }
        coords.shuffle()

        for coord in coords {
            guard removed < targetBlanks else { break }

            let saved = given.removeValue(forKey: coord)!

            if countSolutions(rows: rows, cols: cols,
                               rowSums: rowSums, colSums: colSums,
                               givenValues: given) == 1 {
                removed += 1
            } else {
                given[coord] = saved   // restore — removal breaks uniqueness
            }
        }

        return given
    }

    // MARK: Private — Backtracking Solver
    //
    // Returns the number of valid solutions, stopping as soon as count reaches 2.
    // Uses ordering constraints (lo from left/above, hi from right/below given cells)
    // plus sum-feasibility pruning (remaining blanks can still reach the target sum).

    static func countSolutions(
        rows: Int, cols: Int,
        rowSums: [Int], colSums: [Int],
        givenValues: [CelticCellCoord: Int]
    ) -> Int {
        // Build integer grid: given cells are non-zero, blanks are 0
        var grid = Array(repeating: Array(repeating: 0, count: cols), count: rows)
        var blanks = [(Int, Int)]()

        for r in 0..<rows {
            for c in 0..<cols {
                let coord = CelticCellCoord(row: r, col: c)
                if let v = givenValues[coord] {
                    grid[r][c] = v
                } else {
                    blanks.append((r, c))
                }
            }
        }

        var count = 0
        backtrack(grid: &grid, blanks: blanks, index: 0,
                  rows: rows, cols: cols,
                  rowSums: rowSums, colSums: colSums,
                  count: &count)
        return count
    }

    private static func backtrack(
        grid: inout [[Int]],
        blanks: [(Int, Int)],
        index: Int,
        rows: Int, cols: Int,
        rowSums: [Int], colSums: [Int],
        count: inout Int
    ) {
        guard count < 2 else { return }

        if index == blanks.count {
            count += 1
            return
        }

        let (r, c) = blanks[index]

        // Lower bound: must be ≥ left neighbor and ≥ upper neighbor (already placed)
        var lo = 1
        if c > 0 { lo = max(lo, grid[r][c-1]) }
        if r > 0 { lo = max(lo, grid[r-1][c]) }

        // Upper bound: must be ≤ next known value in the same row (right)
        // or the same column (below), when that cell is already filled.
        // In row-major order, right-neighbor in the same row is only filled if it's a given cell.
        // Below-neighbor is never filled yet (we haven't reached row r+1).
        var hi = 5
        if c + 1 < cols, grid[r][c+1] > 0 { hi = min(hi, grid[r][c+1]) }
        if r + 1 < rows, grid[r+1][c] > 0  { hi = min(hi, grid[r+1][c])  }

        guard lo <= hi else { return }

        for v in lo...hi {
            grid[r][c] = v

            // Sum-feasibility for row r
            var rowFilled = 0; var rowBlanksLeft = 0
            for cc in 0..<cols {
                if grid[r][cc] > 0 { rowFilled += grid[r][cc] } else { rowBlanksLeft += 1 }
            }
            let rowNeeded = rowSums[r] - rowFilled
            guard rowNeeded >= rowBlanksLeft && rowNeeded <= rowBlanksLeft * 5 else {
                continue
            }

            // Sum-feasibility for col c
            var colFilled = 0; var colBlanksLeft = 0
            for rr in 0..<rows {
                if grid[rr][c] > 0 { colFilled += grid[rr][c] } else { colBlanksLeft += 1 }
            }
            let colNeeded = colSums[c] - colFilled
            guard colNeeded >= colBlanksLeft && colNeeded <= colBlanksLeft * 5 else {
                continue
            }

            backtrack(grid: &grid, blanks: blanks, index: index + 1,
                      rows: rows, cols: cols,
                      rowSums: rowSums, colSums: colSums,
                      count: &count)

            guard count < 2 else { grid[r][c] = 0; return }
        }

        grid[r][c] = 0
    }

    // MARK: Private — Fallback

    private static func fullyRevealedPuzzle(difficulty: CelticDifficulty) -> CelticPuzzle {
        let rows = difficulty.rows
        let cols = difficulty.cols
        let tableau = randomTableau(rows: rows, cols: cols)
        let rowSums = (0..<rows).map { r in tableau[r].reduce(0, +) }
        let colSums = (0..<cols).map { c in (0..<rows).map { tableau[$0][c] }.reduce(0, +) }
        var givenValues = [CelticCellCoord: Int]()
        for r in 0..<rows {
            for c in 0..<cols { givenValues[CelticCellCoord(row: r, col: c)] = tableau[r][c] }
        }
        return CelticPuzzle(rows: rows, cols: cols,
                            rowSums: rowSums, colSums: colSums,
                            fixedCells: Set(givenValues.keys),
                            fixedValues: givenValues,
                            solution: tableau)
    }
}
