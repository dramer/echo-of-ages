// CelticLevel.swift
// EchoOfAges
//
// Dynamic Ogham puzzles for the Celtic / Druidic civilization.
// Each level uses a different mechanic hinted at by its title:
//
//   L1  "The Climbing Stone"   — rows + columns non-decreasing (ascending)
//   L2  "The Sinking Stone"    — rows + columns non-increasing (descending)
//   L3  "The Braided Branches" — cells alternate odd / even in a checkerboard
//   L4  "The Scattered Grove"  — no two touching cells may share the same value
//   L5  "The Reflected Stone"  — each row is a palindrome (reads same both ways)
//
// All levels show row sums and column sums carved on the stone as targets.
// Puzzles are generated fresh each session — no two plays are identical.
//
// The five Ogham letters:
//   ᚁ Beith (Birch)  — value 1   (odd)
//   ᚂ Luis  (Rowan)  — value 2   (even)
//   ᚃ Fearn (Alder)  — value 3   (odd)
//   ᚄ Sail  (Willow) — value 4   (even)
//   ᚅ Nion  (Ash)    — value 5   (odd)

import Foundation

// MARK: - OghamGlyph

enum OghamGlyph: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case beith = "ᚁ"
    case luis  = "ᚂ"
    case fearn = "ᚃ"
    case sail  = "ᚄ"
    case nion  = "ᚅ"

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

// MARK: - CelticCellCoord

struct CelticCellCoord: Hashable, Equatable {
    let row: Int
    let col: Int
}

// MARK: - CelticMechanic

enum CelticMechanic: Equatable {
    case ascending   // L1
    case descending  // L2
    case braided     // L3
    case scattered   // L4
    case reflected   // L5

    /// One-line rule shown in the rule banner and help dialog.
    var ruleLabel: String {
        switch self {
        case .ascending:  return "Values climb — each row and column rises left→right, top→bottom"
        case .descending: return "Values sink — each row and column falls left→right, top→bottom"
        case .braided:    return "Marks weave — cells alternate odd (ᚁᚃᚅ) and even (ᚂᚄ) like a braid"
        case .scattered:  return "Marks scatter — no two touching cells may share the same value"
        case .reflected:  return "Marks mirror — each row reads the same forwards and backwards"
        }
    }
}

// MARK: - CelticPuzzle

struct CelticPuzzle {
    let rows: Int
    let cols: Int
    let mechanic: CelticMechanic
    let rowSums: [Int]
    let colSums: [Int]
    /// Cells pre-carved on the stone — cannot be changed by the player.
    let fixedCells: Set<CelticCellCoord>
    let fixedValues: [CelticCellCoord: Int]
    /// Complete solution grid (values 1–5).
    let solution: [[Int]]

    func initialGrid() -> [[OghamGlyph?]] {
        (0..<rows).map { r in
            (0..<cols).map { c in
                fixedValues[CelticCellCoord(row: r, col: c)].flatMap { OghamGlyph.from(value: $0) }
            }
        }
    }

    /// For the reflected mechanic the right half (col > cols/2) is auto-mirrored.
    /// Returns true when a cell is directly editable by the player.
    func isCanonical(col: Int) -> Bool {
        mechanic == .reflected ? col <= cols / 2 : true
    }

    // MARK: isSolved

    func isSolved(_ grid: [[OghamGlyph?]]) -> Bool {
        guard grid.count == rows, grid.allSatisfy({ $0.count == cols }) else { return false }
        for r in 0..<rows { for c in 0..<cols { guard grid[r][c] != nil else { return false } } }

        switch mechanic {
        case .ascending:
            for r in 0..<rows {
                for c in 1..<cols {
                    guard let a = grid[r][c-1], let b = grid[r][c], a.value <= b.value else { return false }
                }
            }
            for c in 0..<cols {
                for r in 1..<rows {
                    guard let a = grid[r-1][c], let b = grid[r][c], a.value <= b.value else { return false }
                }
            }

        case .descending:
            for r in 0..<rows {
                for c in 1..<cols {
                    guard let a = grid[r][c-1], let b = grid[r][c], a.value >= b.value else { return false }
                }
            }
            for c in 0..<cols {
                for r in 1..<rows {
                    guard let a = grid[r-1][c], let b = grid[r][c], a.value >= b.value else { return false }
                }
            }

        case .braided:
            for r in 0..<rows {
                for c in 0..<cols {
                    guard let g = grid[r][c] else { return false }
                    let mustOdd = (r + c) % 2 == 0
                    if mustOdd != (g.value % 2 == 1) { return false }
                }
            }

        case .scattered:
            for r in 0..<rows {
                for c in 0..<cols {
                    guard let v = grid[r][c]?.value else { return false }
                    if c + 1 < cols, grid[r][c+1]?.value == v { return false }
                    if r + 1 < rows, grid[r+1][c]?.value == v { return false }
                }
            }

        case .reflected:
            for r in 0..<rows {
                for c in 0..<cols {
                    guard let a = grid[r][c], let b = grid[r][cols-1-c], a == b else { return false }
                }
            }
        }

        for r in 0..<rows {
            let s = grid[r].compactMap { $0?.value }.reduce(0, +)
            if s != rowSums[r] { return false }
        }
        for c in 0..<cols {
            let s = (0..<rows).compactMap { grid[$0][c]?.value }.reduce(0, +)
            if s != colSums[c] { return false }
        }
        return true
    }

    // MARK: errorCells

    func errorCells(in grid: [[OghamGlyph?]]) -> Set<CelticCellCoord> {
        var errors = Set<CelticCellCoord>()

        switch mechanic {
        case .ascending:
            for r in 0..<rows {
                for c in 1..<cols {
                    if let a = grid[r][c-1], let b = grid[r][c], a.value > b.value {
                        errors.insert(.init(row: r, col: c-1)); errors.insert(.init(row: r, col: c))
                    }
                }
            }
            for c in 0..<cols {
                for r in 1..<rows {
                    if let a = grid[r-1][c], let b = grid[r][c], a.value > b.value {
                        errors.insert(.init(row: r-1, col: c)); errors.insert(.init(row: r, col: c))
                    }
                }
            }

        case .descending:
            for r in 0..<rows {
                for c in 1..<cols {
                    if let a = grid[r][c-1], let b = grid[r][c], a.value < b.value {
                        errors.insert(.init(row: r, col: c-1)); errors.insert(.init(row: r, col: c))
                    }
                }
            }
            for c in 0..<cols {
                for r in 1..<rows {
                    if let a = grid[r-1][c], let b = grid[r][c], a.value < b.value {
                        errors.insert(.init(row: r-1, col: c)); errors.insert(.init(row: r, col: c))
                    }
                }
            }

        case .braided:
            for r in 0..<rows {
                for c in 0..<cols {
                    guard let g = grid[r][c] else { continue }
                    let mustOdd = (r + c) % 2 == 0
                    if mustOdd != (g.value % 2 == 1) { errors.insert(.init(row: r, col: c)) }
                }
            }

        case .scattered:
            for r in 0..<rows {
                for c in 0..<cols {
                    guard let v = grid[r][c]?.value else { continue }
                    if c + 1 < cols, grid[r][c+1]?.value == v {
                        errors.insert(.init(row: r, col: c)); errors.insert(.init(row: r, col: c+1))
                    }
                    if r + 1 < rows, grid[r+1][c]?.value == v {
                        errors.insert(.init(row: r, col: c)); errors.insert(.init(row: r+1, col: c))
                    }
                }
            }

        case .reflected:
            for r in 0..<rows {
                for c in 0..<cols {
                    guard let a = grid[r][c], let b = grid[r][cols-1-c] else { continue }
                    if a != b {
                        errors.insert(.init(row: r, col: c))
                        errors.insert(.init(row: r, col: cols-1-c))
                    }
                }
            }
        }

        // Sum violations on fully-filled rows
        for r in 0..<rows {
            let vals = grid[r].compactMap { $0?.value }
            if vals.count == cols, vals.reduce(0, +) != rowSums[r] {
                for c in 0..<cols { errors.insert(.init(row: r, col: c)) }
            }
        }
        // Sum violations on fully-filled columns
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

struct CelticDifficulty: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let inscriptions: [String]
    let decodedMessage: String
    let rows: Int
    let cols: Int
    /// For .reflected this is the number of canonical (left-half + centre) cells to hide.
    /// For all other mechanics it is the total number of cells to hide.
    let targetBlanks: Int
    let mechanic: CelticMechanic

    var romanNumeral: String { ["I","II","III","IV","V"][min(id-1, 4)] }
}

extension CelticDifficulty {

    static let all: [CelticDifficulty] = [d1, d2, d3, d4, d5]

    // ─────────────────────────────────────────────────
    // L1 — ASCENDING  2×3
    // ─────────────────────────────────────────────────
    static let d1 = CelticDifficulty(
        id: 1,
        title: "The Climbing Stone",
        subtitle: "Two rows on the standing stone",
        inscriptions: [
            "Each row of marks must rise from left to right — no mark may be less than the one before it. Each column must rise from top to bottom by the same law. The carved sum beside each row and below each column tells you the target total. Only one arrangement satisfies both.",
            "Begin with the row or column whose carved sum allows the fewest rising combinations. Each mark you lock in removes choices from every other row and column it shares.",
            "Rising order and carved sums together leave only one answer on this stone."
        ],
        decodedMessage: "Beith rises before all others. Even the birch must learn what comes before it can grow.",
        rows: 2, cols: 3,
        targetBlanks: 4,
        mechanic: .ascending
    )

    // ─────────────────────────────────────────────────
    // L2 — DESCENDING  3×3
    // ─────────────────────────────────────────────────
    static let d2 = CelticDifficulty(
        id: 2,
        title: "The Sinking Stone",
        subtitle: "Three rows, three columns",
        inscriptions: [
            "Here the marks fall. Each row must sink from left to right — every mark no greater than the one before it. Each column must sink from top to bottom by the same law. The carved sums are your only other guide.",
            "Begin with the row or column whose sum leaves the fewest sinking combinations. A high sum means the marks start large and descend slowly — a low sum means they fall steeply.",
            "Falling order and carved sums together force a single arrangement. Work from the most constrained edge inward."
        ],
        decodedMessage: "The rowan holds its ground as the stream descends past it. To sink is not to be lost — it is to find where you belong.",
        rows: 3, cols: 3,
        targetBlanks: 7,
        mechanic: .descending
    )

    // ─────────────────────────────────────────────────
    // L3 — BRAIDED  3×4
    // ─────────────────────────────────────────────────
    static let d3 = CelticDifficulty(
        id: 3,
        title: "The Braided Branches",
        subtitle: "Three rows, four columns",
        inscriptions: [
            "The branches weave. At every position where the row number and column number add to an even number the mark must be odd — Beith (1), Fearn (3), or Nion (5). Where the sum is odd, the mark must be even — Luis (2) or Sail (4). This checkerboard holds across every cell.",
            "Apply the odd/even rule first — it eliminates most of the stone immediately, leaving only a handful of choices per cell. The carved row and column sums then tell you which odd and which even values belong.",
            "Parity and sums interlock. Once you see the weave, the stone reads itself."
        ],
        decodedMessage: "The alder grows where wet meets dry. It weaves between two worlds, belonging to neither, at home in both.",
        rows: 3, cols: 4,
        targetBlanks: 8,
        mechanic: .braided
    )

    // ─────────────────────────────────────────────────
    // L4 — SCATTERED  4×4
    // ─────────────────────────────────────────────────
    static let d4 = CelticDifficulty(
        id: 4,
        title: "The Scattered Grove",
        subtitle: "Four rows, four columns",
        inscriptions: [
            "No two trees of the same kind may stand side by side. Any two cells that touch — left, right, above, or below — must hold different marks. The carved sums tell you which values belong in each corner of the grove.",
            "A mark placed in one cell rules out that same mark from all four of its immediate neighbours. Work outward from the cell with the fewest legal choices — the most constrained position is always the best place to begin.",
            "Separation and sums together narrow the grove to a single arrangement. No mark clusters. Each stands apart."
        ],
        decodedMessage: "The willow does not crowd the oak. Each tree finds its ground and holds it. The grove is strong because none of them are alike.",
        rows: 4, cols: 4,
        targetBlanks: 13,
        mechanic: .scattered
    )

    // ─────────────────────────────────────────────────
    // L5 — REFLECTED  4×5
    // ─────────────────────────────────────────────────
    static let d5 = CelticDifficulty(
        id: 5,
        title: "The Reflected Stone",
        subtitle: "The complete Ogham sequence",
        inscriptions: [
            "This stone is carved to reflect itself. Every row reads the same from left to right as from right to left — the first mark matches the last, the second matches the second-to-last, and the centre stands alone. Fill only the left half of each row; the right half mirrors it automatically.",
            "Use the column sums to find the values for the left half of each row. Each column sum already accounts for the mirrored marks on the far side. Start with the column whose sum leaves the fewest choices.",
            "When the last canonical mark is placed and the stone reads true in every direction, the reflection is complete."
        ],
        decodedMessage: "Every tree named every other tree. Every voice in the grove spoke in the same sacred order. They did not know this was the word for 'remember.' They only knew it was the word for 'tree.'",
        rows: 4, cols: 5,
        targetBlanks: 9,   // canonical (left-half + centre) cells to hide
        mechanic: .reflected
    )
}

// MARK: - CelticGenerator

enum CelticGenerator {

    // MARK: Public entry point

    static func generate(difficulty: CelticDifficulty) -> CelticPuzzle {
        switch difficulty.mechanic {
        case .ascending:  return generateOrdered(difficulty: difficulty, ascending: true)
        case .descending: return generateOrdered(difficulty: difficulty, ascending: false)
        case .braided:    return generateBraided(difficulty: difficulty)
        case .scattered:  return generateScattered(difficulty: difficulty)
        case .reflected:  return generateReflected(difficulty: difficulty)
        }
    }

    // MARK: - Ascending / Descending

    private static func generateOrdered(difficulty: CelticDifficulty, ascending: Bool) -> CelticPuzzle {
        let rows = difficulty.rows; let cols = difficulty.cols
        for _ in 0..<40 {
            let tab = randomOrderedTableau(rows: rows, cols: cols, ascending: ascending)
            guard isOrderedInteresting(tab, rows: rows, cols: cols, ascending: ascending) else { continue }
            let rSums = rowSums(tab, rows: rows)
            let cSums = colSums(tab, rows: rows, cols: cols)
            let given = digHoles(
                rows: rows, cols: cols, rowSums: rSums, colSums: cSums,
                givenValues: allCells(tab, rows: rows, cols: cols),
                targetBlanks: difficulty.targetBlanks, mechanic: difficulty.mechanic
            )
            guard rows * cols - given.count >= max(1, difficulty.targetBlanks * 6 / 10) else { continue }
            return puzzle(from: tab, given: given, rSums: rSums, cSums: cSums, difficulty: difficulty)
        }
        let tab = randomOrderedTableau(rows: rows, cols: cols, ascending: ascending)
        return fullyRevealed(difficulty: difficulty, tableau: tab)
    }

    private static func randomOrderedTableau(rows: Int, cols: Int, ascending: Bool) -> [[Int]] {
        var g = Array(repeating: Array(repeating: 0, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                if ascending {
                    let lo = max(c > 0 ? g[r][c-1] : 1, r > 0 ? g[r-1][c] : 1)
                    g[r][c] = Int.random(in: lo...min(5, lo + 2))
                } else {
                    let hi = min(c > 0 ? g[r][c-1] : 5, r > 0 ? g[r-1][c] : 5)
                    g[r][c] = Int.random(in: max(1, hi - 2)...hi)
                }
            }
        }
        return g
    }

    private static func isOrderedInteresting(_ t: [[Int]], rows: Int, cols: Int, ascending: Bool) -> Bool {
        for r in 0..<rows { if Set(t[r]).count == 1 { return false } }
        for c in 0..<cols { if Set((0..<rows).map { t[$0][c] }).count == 1 { return false } }
        guard Set(t.flatMap { $0 }).count >= 3 else { return false }
        let extreme = ascending ? 5 : 1
        let count = t.flatMap { $0 }.filter { $0 == extreme }.count
        return count * 10 <= rows * cols * 3
    }

    // MARK: - Braided

    private static func generateBraided(difficulty: CelticDifficulty) -> CelticPuzzle {
        let rows = difficulty.rows; let cols = difficulty.cols
        for _ in 0..<40 {
            let tab = randomBraidedTableau(rows: rows, cols: cols)
            guard Set(tab.flatMap { $0 }).count >= 3 else { continue }
            let rSums = rowSums(tab, rows: rows)
            let cSums = colSums(tab, rows: rows, cols: cols)
            let given = digHoles(
                rows: rows, cols: cols, rowSums: rSums, colSums: cSums,
                givenValues: allCells(tab, rows: rows, cols: cols),
                targetBlanks: difficulty.targetBlanks, mechanic: difficulty.mechanic
            )
            guard rows * cols - given.count >= max(1, difficulty.targetBlanks * 6 / 10) else { continue }
            return puzzle(from: tab, given: given, rSums: rSums, cSums: cSums, difficulty: difficulty)
        }
        return fullyRevealed(difficulty: difficulty, tableau: randomBraidedTableau(rows: difficulty.rows, cols: difficulty.cols))
    }

    private static func randomBraidedTableau(rows: Int, cols: Int) -> [[Int]] {
        var g = Array(repeating: Array(repeating: 0, count: cols), count: rows)
        let odd = [1, 3, 5]; let even = [2, 4]
        for r in 0..<rows {
            for c in 0..<cols {
                g[r][c] = (r + c) % 2 == 0 ? odd.randomElement()! : even.randomElement()!
            }
        }
        return g
    }

    // MARK: - Scattered

    private static func generateScattered(difficulty: CelticDifficulty) -> CelticPuzzle {
        let rows = difficulty.rows; let cols = difficulty.cols
        for _ in 0..<40 {
            let tab = randomScatteredTableau(rows: rows, cols: cols)
            guard Set(tab.flatMap { $0 }).count >= 3 else { continue }
            let rSums = rowSums(tab, rows: rows)
            let cSums = colSums(tab, rows: rows, cols: cols)
            let given = digHoles(
                rows: rows, cols: cols, rowSums: rSums, colSums: cSums,
                givenValues: allCells(tab, rows: rows, cols: cols),
                targetBlanks: difficulty.targetBlanks, mechanic: difficulty.mechanic
            )
            guard rows * cols - given.count >= max(1, difficulty.targetBlanks * 6 / 10) else { continue }
            return puzzle(from: tab, given: given, rSums: rSums, cSums: cSums, difficulty: difficulty)
        }
        return fullyRevealed(difficulty: difficulty, tableau: randomScatteredTableau(rows: difficulty.rows, cols: difficulty.cols))
    }

    private static func randomScatteredTableau(rows: Int, cols: Int) -> [[Int]] {
        var g = Array(repeating: Array(repeating: 0, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                var forbidden = Set<Int>()
                if c > 0 { forbidden.insert(g[r][c-1]) }
                if r > 0 { forbidden.insert(g[r-1][c]) }
                let available = (1...5).filter { !forbidden.contains($0) }
                g[r][c] = available.randomElement() ?? 1
            }
        }
        return g
    }

    // MARK: - Reflected

    private static func generateReflected(difficulty: CelticDifficulty) -> CelticPuzzle {
        let rows = difficulty.rows; let cols = difficulty.cols
        for _ in 0..<40 {
            let tab = randomReflectedTableau(rows: rows, cols: cols)
            guard isReflectedInteresting(tab, rows: rows) else { continue }
            let rSums = rowSums(tab, rows: rows)
            let cSums = colSums(tab, rows: rows, cols: cols)
            let given = digHolesReflected(
                rows: rows, cols: cols, rowSums: rSums, colSums: cSums,
                givenValues: allCells(tab, rows: rows, cols: cols),
                targetCanonical: difficulty.targetBlanks
            )
            let canonicalTotal = rows * (cols / 2 + 1)
            let canonicalGiven = given.keys.filter { $0.col <= cols / 2 }.count
            guard canonicalTotal - canonicalGiven >= max(1, difficulty.targetBlanks * 6 / 10) else { continue }
            return puzzle(from: tab, given: given, rSums: rSums, cSums: cSums, difficulty: difficulty)
        }
        return fullyRevealed(difficulty: difficulty, tableau: randomReflectedTableau(rows: difficulty.rows, cols: difficulty.cols))
    }

    private static func randomReflectedTableau(rows: Int, cols: Int) -> [[Int]] {
        var g = Array(repeating: Array(repeating: 0, count: cols), count: rows)
        let half = (cols + 1) / 2
        for r in 0..<rows {
            for c in 0..<half { g[r][c] = Int.random(in: 1...5) }
            for c in half..<cols { g[r][c] = g[r][cols - 1 - c] }
        }
        return g
    }

    private static func isReflectedInteresting(_ t: [[Int]], rows: Int) -> Bool {
        for r in 0..<rows { if Set(t[r]).count < 2 { return false } }
        return Set(t.flatMap { $0 }).count >= 3
    }

    /// Dig holes in symmetric pairs (canonical + mirror). Only canonical cells are candidates.
    private static func digHolesReflected(
        rows: Int, cols: Int,
        rowSums: [Int], colSums: [Int],
        givenValues: [CelticCellCoord: Int],
        targetCanonical: Int
    ) -> [CelticCellCoord: Int] {
        var given = givenValues
        var removed = 0
        var canonical = (0..<rows).flatMap { r in (0...cols/2).map { c in CelticCellCoord(row: r, col: c) } }
        canonical.shuffle()

        for coord in canonical {
            guard removed < targetCanonical else { break }
            let mirrorCoord = CelticCellCoord(row: coord.row, col: cols - 1 - coord.col)
            let isCenter = coord.col == cols - 1 - coord.col

            let savedC = given.removeValue(forKey: coord)!
            var savedM: Int? = nil
            if !isCenter { savedM = given.removeValue(forKey: mirrorCoord) }

            if countSolutions(rows: rows, cols: cols, rowSums: rowSums, colSums: colSums,
                              givenValues: given, mechanic: .reflected) == 1 {
                removed += 1
            } else {
                given[coord] = savedC
                if let m = savedM { given[mirrorCoord] = m }
            }
        }
        return given
    }

    // MARK: - Shared Helpers

    private static func rowSums(_ t: [[Int]], rows: Int) -> [Int] {
        (0..<rows).map { t[$0].reduce(0, +) }
    }
    private static func colSums(_ t: [[Int]], rows: Int, cols: Int) -> [Int] {
        (0..<cols).map { c in (0..<rows).map { t[$0][c] }.reduce(0, +) }
    }
    private static func allCells(_ t: [[Int]], rows: Int, cols: Int) -> [CelticCellCoord: Int] {
        var d = [CelticCellCoord: Int]()
        for r in 0..<rows { for c in 0..<cols { d[CelticCellCoord(row: r, col: c)] = t[r][c] } }
        return d
    }
    private static func puzzle(from t: [[Int]], given: [CelticCellCoord: Int],
                               rSums: [Int], cSums: [Int],
                               difficulty: CelticDifficulty) -> CelticPuzzle {
        CelticPuzzle(rows: difficulty.rows, cols: difficulty.cols, mechanic: difficulty.mechanic,
                     rowSums: rSums, colSums: cSums,
                     fixedCells: Set(given.keys), fixedValues: given, solution: t)
    }
    private static func fullyRevealed(difficulty: CelticDifficulty, tableau: [[Int]]) -> CelticPuzzle {
        let rows = difficulty.rows; let cols = difficulty.cols
        let g = allCells(tableau, rows: rows, cols: cols)
        return CelticPuzzle(rows: rows, cols: cols, mechanic: difficulty.mechanic,
                            rowSums: rowSums(tableau, rows: rows),
                            colSums: colSums(tableau, rows: rows, cols: cols),
                            fixedCells: Set(g.keys), fixedValues: g, solution: tableau)
    }

    private static func digHoles(
        rows: Int, cols: Int, rowSums: [Int], colSums: [Int],
        givenValues: [CelticCellCoord: Int],
        targetBlanks: Int, mechanic: CelticMechanic
    ) -> [CelticCellCoord: Int] {
        var given = givenValues
        var removed = 0
        var coords = (0..<rows).flatMap { r in (0..<cols).map { c in CelticCellCoord(row: r, col: c) } }
        coords.shuffle()
        for coord in coords {
            guard removed < targetBlanks else { break }
            let saved = given.removeValue(forKey: coord)!
            if countSolutions(rows: rows, cols: cols, rowSums: rowSums, colSums: colSums,
                              givenValues: given, mechanic: mechanic) == 1 {
                removed += 1
            } else {
                given[coord] = saved
            }
        }
        return given
    }

    // MARK: - Backtracking Solver

    static func countSolutions(
        rows: Int, cols: Int,
        rowSums: [Int], colSums: [Int],
        givenValues: [CelticCellCoord: Int],
        mechanic: CelticMechanic
    ) -> Int {
        var grid = Array(repeating: Array(repeating: 0, count: cols), count: rows)
        // Place all given values
        for r in 0..<rows {
            for c in 0..<cols {
                if let v = givenValues[CelticCellCoord(row: r, col: c)] { grid[r][c] = v }
            }
        }
        // For reflected: propagate canonical → mirror
        if mechanic == .reflected {
            for r in 0..<rows {
                for c in 0...cols/2 {
                    let m = cols - 1 - c
                    if grid[r][c] > 0 && grid[r][m] == 0 { grid[r][m] = grid[r][c] }
                    else if grid[r][m] > 0 && grid[r][c] == 0 { grid[r][c] = grid[r][m] }
                }
            }
        }
        // Build blanks list — for reflected only canonical blanks
        var blanks = [(Int, Int)]()
        for r in 0..<rows {
            for c in 0..<cols {
                guard grid[r][c] == 0 else { continue }
                if mechanic == .reflected && c > cols / 2 { continue }
                blanks.append((r, c))
            }
        }
        var count = 0
        backtrack(&grid, blanks: blanks, index: 0,
                  rows: rows, cols: cols,
                  rowSums: rowSums, colSums: colSums,
                  mechanic: mechanic, count: &count)
        return count
    }

    private static func backtrack(
        _ grid: inout [[Int]],
        blanks: [(Int, Int)], index: Int,
        rows: Int, cols: Int,
        rowSums: [Int], colSums: [Int],
        mechanic: CelticMechanic,
        count: inout Int
    ) {
        guard count < 2 else { return }
        if index == blanks.count { count += 1; return }

        let (r, c) = blanks[index]
        for v in candidates(r: r, c: c, grid: grid, rows: rows, cols: cols, mechanic: mechanic) {
            grid[r][c] = v
            let mirrorC = cols - 1 - c
            let setMirror = mechanic == .reflected && mirrorC != c && grid[r][mirrorC] == 0
            if setMirror { grid[r][mirrorC] = v }

            if feasible(r: r, c: c, grid: grid, rows: rows, cols: cols,
                        rowSums: rowSums, colSums: colSums, mechanic: mechanic) {
                backtrack(&grid, blanks: blanks, index: index + 1,
                          rows: rows, cols: cols,
                          rowSums: rowSums, colSums: colSums,
                          mechanic: mechanic, count: &count)
            }

            guard count < 2 else {
                grid[r][c] = 0; if setMirror { grid[r][mirrorC] = 0 }; return
            }
            grid[r][c] = 0; if setMirror { grid[r][mirrorC] = 0 }
        }
    }

    private static func candidates(r: Int, c: Int, grid: [[Int]],
                                   rows: Int, cols: Int, mechanic: CelticMechanic) -> [Int] {
        switch mechanic {
        case .ascending:
            var lo = 1, hi = 5
            if c > 0 { lo = max(lo, grid[r][c-1]) }
            if r > 0 { lo = max(lo, grid[r-1][c]) }
            if c+1 < cols, grid[r][c+1] > 0 { hi = min(hi, grid[r][c+1]) }
            if r+1 < rows, grid[r+1][c] > 0  { hi = min(hi, grid[r+1][c]) }
            return lo <= hi ? Array(lo...hi) : []

        case .descending:
            var lo = 1, hi = 5
            if c > 0 { hi = min(hi, grid[r][c-1]) }
            if r > 0 { hi = min(hi, grid[r-1][c]) }
            if c+1 < cols, grid[r][c+1] > 0 { lo = max(lo, grid[r][c+1]) }
            if r+1 < rows, grid[r+1][c] > 0  { lo = max(lo, grid[r+1][c]) }
            return lo <= hi ? Array(lo...hi) : []

        case .braided:
            return (r + c) % 2 == 0 ? [1, 3, 5] : [2, 4]

        case .scattered:
            var forbidden = Set<Int>()
            if c > 0,    grid[r][c-1] > 0   { forbidden.insert(grid[r][c-1]) }
            if r > 0,    grid[r-1][c] > 0   { forbidden.insert(grid[r-1][c]) }
            if c+1 < cols, grid[r][c+1] > 0 { forbidden.insert(grid[r][c+1]) }
            if r+1 < rows, grid[r+1][c] > 0 { forbidden.insert(grid[r+1][c]) }
            return (1...5).filter { !forbidden.contains($0) }

        case .reflected:
            return Array(1...5)
        }
    }

    private static func feasible(r: Int, c: Int, grid: [[Int]],
                                 rows: Int, cols: Int,
                                 rowSums: [Int], colSums: [Int],
                                 mechanic: CelticMechanic) -> Bool {
        // Row check
        let rowCells = grid[r]
        let rFilled  = rowCells.filter { $0 > 0 }.reduce(0, +)
        let rBlanks  = rowCells.filter { $0 == 0 }.count
        let rNeeded  = rowSums[r] - rFilled
        if mechanic == .braided {
            var odd = 0, even = 0
            for cc in 0..<cols { if rowCells[cc] == 0 { if (r+cc)%2==0 { odd+=1 } else { even+=1 } } }
            if rNeeded < odd + even*2 || rNeeded > odd*5 + even*4 { return false }
        } else {
            if rNeeded < rBlanks || rNeeded > rBlanks * 5 { return false }
        }
        // Col check
        let colCells = (0..<rows).map { grid[$0][c] }
        let cFilled  = colCells.filter { $0 > 0 }.reduce(0, +)
        let cBlanks  = colCells.filter { $0 == 0 }.count
        let cNeeded  = colSums[c] - cFilled
        if mechanic == .braided {
            var odd = 0, even = 0
            for rr in 0..<rows { if colCells[rr] == 0 { if (rr+c)%2==0 { odd+=1 } else { even+=1 } } }
            if cNeeded < odd + even*2 || cNeeded > odd*5 + even*4 { return false }
        } else {
            if cNeeded < cBlanks || cNeeded > cBlanks * 5 { return false }
        }
        // For reflected also check the mirror column
        if mechanic == .reflected {
            let mc = cols - 1 - c
            if mc != c {
                let mcCells = (0..<rows).map { grid[$0][mc] }
                let mcFilled = mcCells.filter { $0 > 0 }.reduce(0, +)
                let mcBlanks = mcCells.filter { $0 == 0 }.count
                let mcNeeded = colSums[mc] - mcFilled
                if mcNeeded < mcBlanks || mcNeeded > mcBlanks * 5 { return false }
            }
        }
        return true
    }
}
