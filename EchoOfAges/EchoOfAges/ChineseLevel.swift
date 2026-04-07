// ChineseLevel.swift
// EchoOfAges
//
// Wooden box puzzle for the Ancient Chinese civilization.
//
// Mechanic: Fit all wooden pieces into the rectangular tray.
// Each piece can be rotated in 90° increments. The puzzle is solved
// when every cell of the tray is occupied by exactly one piece.
//
// Piece rotation: 90° clockwise transform (r,c) → (c,−r), then
// normalize so top-left = (0,0).
//
// Level progression:
//   L1 — 2×4 tray, 2 pieces   (tutorial: two squares)
//   L2 — 3×4 tray, 3 pieces   (strip + two squares)
//   L3 — 3×4 tray, 4 pieces   (four corners — same L-shape, four rotations)
//   L4 — 4×4 tray, 4 pieces   (four nails — same T-shape, four rotations)
//   L5 — 4×5 tray, 5 pieces   (master: five distinct shapes)

import Foundation

// MARK: - Piece Placement

struct ChinesePiecePlacement: Equatable, Hashable {
    let row: Int
    let col: Int
    let rotation: Int   // 0=0°, 1=90° CW, 2=180°, 3=270° CW
}

// MARK: - Box Piece

struct ChineseBoxPiece: Identifiable {
    let id: String
    let name: String        // Chinese character name
    let meaning: String     // English meaning
    let colorHex: String    // warm wood tone
    /// Cell offsets from top-left anchor at rotation 0, as (row, col).
    let baseCells: [(Int, Int)]

    /// Returns the piece's cells after `rotation` 90°-CW turns,
    /// normalized so the minimum row and column are both 0.
    func cells(rotation: Int) -> [(Int, Int)] {
        var r = baseCells
        for _ in 0 ..< (rotation & 3) {
            r = r.map { (row, col) in (col, -row) }
            let minR = r.map { $0.0 }.min() ?? 0
            let minC = r.map { $0.1 }.min() ?? 0
            r = r.map { (row, col) in (row - minR, col - minC) }
        }
        return r
    }

    /// How many visually distinct rotations this piece has (1, 2, or 4).
    var rotationCount: Int {
        var seen: [Set<String>] = []
        for i in 0 ..< 4 {
            let key = Set(cells(rotation: i).map { "\($0.0),\($0.1)" })
            if !seen.contains(key) { seen.append(key) }
        }
        return seen.count
    }
}

// MARK: - Level

struct ChineseBoxLevel: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let lore: String
    let inscriptions: [String]
    let rows: Int
    let cols: Int
    let pieces: [ChineseBoxPiece]
    /// A known valid solution used by debug-solve. Maps piece.id → placement.
    let solutionPlacements: [String: ChinesePiecePlacement]
    let decodedMessage: String
    let artifactSymbol: String   // SF Symbol name
    let journalTitle: String
    let journalBody: String

    var romanNumeral: String {
        ["I", "II", "III", "IV", "V"][min(id - 1, 4)]
    }

    // MARK: Board

    /// Returns a rows×cols grid; each cell holds the occupying piece's id or nil.
    func board(from placements: [String: ChinesePiecePlacement]) -> [[String?]] {
        var grid: [[String?]] = Array(
            repeating: Array(repeating: nil, count: cols),
            count: rows
        )
        for piece in pieces {
            guard let p = placements[piece.id] else { continue }
            for (r, c) in absoluteCells(for: piece, placement: p) {
                if r >= 0, r < rows, c >= 0, c < cols {
                    grid[r][c] = piece.id
                }
            }
        }
        return grid
    }

    /// Absolute cell positions for a piece at a given placement.
    func absoluteCells(for piece: ChineseBoxPiece,
                       placement: ChinesePiecePlacement) -> [(Int, Int)] {
        piece.cells(rotation: placement.rotation)
            .map { (r, c) in (r + placement.row, c + placement.col) }
    }

    // MARK: Validation

    /// Whether placing `piece` at `proposed` is legal given `existing` placements.
    func isValidPlacement(piece: ChineseBoxPiece,
                          proposed: ChinesePiecePlacement,
                          existing: [String: ChinesePiecePlacement]) -> Bool {
        let newCells = absoluteCells(for: piece, placement: proposed)
        for (r, c) in newCells {
            guard r >= 0, r < rows, c >= 0, c < cols else { return false }
        }
        var occupied = Set<String>()
        for (otherId, otherP) in existing where otherId != piece.id {
            if let other = pieces.first(where: { $0.id == otherId }) {
                for (r, c) in absoluteCells(for: other, placement: otherP) {
                    occupied.insert("\(r),\(c)")
                }
            }
        }
        return newCells.allSatisfy { (r, c) in !occupied.contains("\(r),\(c)") }
    }

    /// True when all pieces are placed and every tray cell is covered exactly once.
    func isSolved(_ placements: [String: ChinesePiecePlacement]) -> Bool {
        guard placements.count == pieces.count else { return false }
        var board = Array(repeating: Array(repeating: false, count: cols), count: rows)
        for piece in pieces {
            guard let p = placements[piece.id] else { return false }
            for (r, c) in absoluteCells(for: piece, placement: p) {
                guard r >= 0, r < rows, c >= 0, c < cols, !board[r][c]
                else { return false }
                board[r][c] = true
            }
        }
        return board.allSatisfy { $0.allSatisfy { $0 } }
    }
}

// MARK: - All Levels

extension ChineseBoxLevel {

    static let allLevels: [ChineseBoxLevel] = [level1, level2, level3, level4, level5]

    // ── LEVEL 1 ─────────────────────────────────────────────────────────────
    // 2×4 tray, 2 pieces — two 2×2 squares
    //   A A B B
    //   A A B B
    static let level1 = ChineseBoxLevel(
        id: 1,
        title: "The Apprentice's Tray",
        subtitle: "Two squares fill the box",
        lore: "The first lesson of the master craftsman: every shape has its place. Begin with the simplest fit.",
        inscriptions: [
            "Two squares, one tray — the first lesson needs no words.",
            "Find where each piece rests and the wood speaks for itself."
        ],
        rows: 2, cols: 4,
        pieces: [
            ChineseBoxPiece(id: "A", name: "方", meaning: "Square",
                            colorHex: "9A6B2E",
                            baseCells: [(0,0),(0,1),(1,0),(1,1)]),
            ChineseBoxPiece(id: "B", name: "方", meaning: "Square",
                            colorHex: "C4924A",
                            baseCells: [(0,0),(0,1),(1,0),(1,1)])
        ],
        solutionPlacements: [
            "A": ChinesePiecePlacement(row: 0, col: 0, rotation: 0),
            "B": ChinesePiecePlacement(row: 0, col: 2, rotation: 0)
        ],
        decodedMessage: "The sun rises. Order begins with the simplest form.",
        artifactSymbol: "square.split.2x2",
        journalTitle: "The Wooden Tray",
        journalBody: "Found among the ruins of a Han dynasty workshop — a child's puzzle tray. The simplest lessons endure the longest."
    )

    // ── LEVEL 2 ─────────────────────────────────────────────────────────────
    // 3×4 tray, 3 pieces — I-strip + two 2×2 squares
    //   A A A A
    //   B B C C
    //   B B C C
    static let level2 = ChineseBoxLevel(
        id: 2,
        title: "The Craftsman's Test",
        subtitle: "Strip and squares",
        lore: "The long plank anchors the top. Two equal squares fill what remains. Study the edge before the center.",
        inscriptions: [
            "Lay the long piece first — it commands the row above all.",
            "What the strip cannot reach, the squares will complete."
        ],
        rows: 3, cols: 4,
        pieces: [
            ChineseBoxPiece(id: "A", name: "條", meaning: "Strip",
                            colorHex: "B5813A",
                            baseCells: [(0,0),(0,1),(0,2),(0,3)]),
            ChineseBoxPiece(id: "B", name: "方", meaning: "Square",
                            colorHex: "9A6B2E",
                            baseCells: [(0,0),(0,1),(1,0),(1,1)]),
            ChineseBoxPiece(id: "C", name: "方", meaning: "Square",
                            colorHex: "C4924A",
                            baseCells: [(0,0),(0,1),(1,0),(1,1)])
        ],
        // A@(0,0)rot0 → (0,0)(0,1)(0,2)(0,3)
        // B@(1,0)rot0 → (1,0)(1,1)(2,0)(2,1)
        // C@(1,2)rot0 → (1,2)(1,3)(2,2)(2,3)
        solutionPlacements: [
            "A": ChinesePiecePlacement(row: 0, col: 0, rotation: 0),
            "B": ChinesePiecePlacement(row: 1, col: 0, rotation: 0),
            "C": ChinesePiecePlacement(row: 1, col: 2, rotation: 0)
        ],
        decodedMessage: "The moon follows. What is long guides what is equal.",
        artifactSymbol: "rectangle.split.3x1",
        journalTitle: "The Scholar's Desk",
        journalBody: "Ivory and sandalwood pieces recovered from a Confucian academy. The long piece is always placed first — so wrote the master to his student."
    )

    // ── LEVEL 3 ─────────────────────────────────────────────────────────────
    // 3×4 tray, 4 pieces — four L-trominoes (same shape, four rotations)
    //   A A B B
    //   A C B D
    //   C C D D
    //
    // L3 rot0 = [(0,0),(0,1),(1,0)]   rot2 = [(0,1),(1,0),(1,1)]
    static let level3 = ChineseBoxLevel(
        id: 3,
        title: "The Four Corners",
        subtitle: "Four corners fill the box",
        lore: "Each corner piece is identical — only its facing changes. The box has four corners; the piece has four rotations. This is not coincidence.",
        inscriptions: [
            "One shape, four turnings. The tray asks which way each corner faces.",
            "Two pieces crown the top. Two pieces anchor the base. Mirror one side to find the other."
        ],
        rows: 3, cols: 4,
        pieces: [
            ChineseBoxPiece(id: "A", name: "角", meaning: "Corner",
                            colorHex: "B5813A",
                            baseCells: [(0,0),(0,1),(1,0)]),
            ChineseBoxPiece(id: "B", name: "角", meaning: "Corner",
                            colorHex: "9A6B2E",
                            baseCells: [(0,0),(0,1),(1,0)]),
            ChineseBoxPiece(id: "C", name: "角", meaning: "Corner",
                            colorHex: "C4924A",
                            baseCells: [(0,0),(0,1),(1,0)]),
            ChineseBoxPiece(id: "D", name: "角", meaning: "Corner",
                            colorHex: "A07030",
                            baseCells: [(0,0),(0,1),(1,0)])
        ],
        // A@(0,0)rot0 → (0,0)(0,1)(1,0)
        // B@(0,2)rot0 → (0,2)(0,3)(1,2)
        // C@(1,0)rot2: rot2=[(0,1),(1,0),(1,1)] → @(1,0): (1,1)(2,0)(2,1)
        // D@(1,2)rot2: rot2=[(0,1),(1,0),(1,1)] → @(1,2): (1,3)(2,2)(2,3)
        solutionPlacements: [
            "A": ChinesePiecePlacement(row: 0, col: 0, rotation: 0),
            "B": ChinesePiecePlacement(row: 0, col: 2, rotation: 0),
            "C": ChinesePiecePlacement(row: 1, col: 0, rotation: 2),
            "D": ChinesePiecePlacement(row: 1, col: 2, rotation: 2)
        ],
        decodedMessage: "Water finds the lowest place. Four turnings, one truth.",
        artifactSymbol: "rotate.right",
        journalTitle: "The Corner Pieces",
        journalBody: "Four identical pieces of polished elm. The inscription on the tray reads: 'One shape becomes four when you learn to see what it faces.'"
    )

    // ── LEVEL 4 ─────────────────────────────────────────────────────────────
    // 4×4 tray, 4 pieces — four T-tetrominoes (same shape, all four rotations)
    //   A A A B
    //   C A B B
    //   C C B D   (B is T-rot1 pointing right; D is T-rot2 pointing up)
    //   C D D D
    //
    // T rot0=[(0,0),(0,1),(0,2),(1,1)]  rot1=[(0,1),(1,0),(1,1),(2,1)]
    // T rot2=[(0,1),(1,0),(1,1),(1,2)]  rot3=[(0,0),(1,0),(1,1),(2,0)]
    //
    // Verified cell map:
    //   (0,0)=A (0,1)=A (0,2)=A (0,3)=B
    //   (1,0)=C (1,1)=A (1,2)=B (1,3)=B
    //   (2,0)=C (2,1)=C (2,2)=D (2,3)=B
    //   (3,0)=C (3,1)=D (3,2)=D (3,3)=D
    static let level4 = ChineseBoxLevel(
        id: 4,
        title: "The Four Nails",
        subtitle: "Four T-shapes, four directions",
        lore: "The nail piece points in four directions. Each nail must face a different wall of the box. When all four directions are honoured, the tray is complete.",
        inscriptions: [
            "The T-piece points down, right, left, and up — one for each wall of the tray.",
            "Each nail interlocks with the others. Find where one points and the next will follow.",
            "The center of the tray is always shared. No nail owns it alone."
        ],
        rows: 4, cols: 4,
        pieces: [
            ChineseBoxPiece(id: "A", name: "丁", meaning: "Nail",
                            colorHex: "B5813A",
                            baseCells: [(0,0),(0,1),(0,2),(1,1)]),
            ChineseBoxPiece(id: "B", name: "丁", meaning: "Nail",
                            colorHex: "9A6B2E",
                            baseCells: [(0,0),(0,1),(0,2),(1,1)]),
            ChineseBoxPiece(id: "C", name: "丁", meaning: "Nail",
                            colorHex: "C4924A",
                            baseCells: [(0,0),(0,1),(0,2),(1,1)]),
            ChineseBoxPiece(id: "D", name: "丁", meaning: "Nail",
                            colorHex: "A07030",
                            baseCells: [(0,0),(0,1),(0,2),(1,1)])
        ],
        // A@(0,0)rot0: [(0,0),(0,1),(0,2),(1,1)] → (0,0)(0,1)(0,2)(1,1)
        // B@(0,2)rot1: [(0,1),(1,0),(1,1),(2,1)] → (0,3)(1,2)(1,3)(2,3)
        // C@(1,0)rot3: [(0,0),(1,0),(1,1),(2,0)] → (1,0)(2,0)(2,1)(3,0)
        // D@(2,1)rot2: [(0,1),(1,0),(1,1),(1,2)] → (2,2)(3,1)(3,2)(3,3)
        solutionPlacements: [
            "A": ChinesePiecePlacement(row: 0, col: 0, rotation: 0),
            "B": ChinesePiecePlacement(row: 0, col: 2, rotation: 1),
            "C": ChinesePiecePlacement(row: 1, col: 0, rotation: 3),
            "D": ChinesePiecePlacement(row: 2, col: 1, rotation: 2)
        ],
        decodedMessage: "Fire transforms. What points in all directions consumes nothing and loses nothing.",
        artifactSymbol: "arrow.up.arrow.down.circle",
        journalTitle: "The Scholar's Lock",
        journalBody: "A puzzle box from the Song dynasty. Four identical pieces of hardwood — the challenge is not identifying the shapes, but discovering which direction each one must face."
    )

    // ── LEVEL 5 ─────────────────────────────────────────────────────────────
    // 4×5 tray, 5 pieces — five distinct tetromino shapes
    //
    //   A A A A B
    //   C D D D B
    //   C D E B B
    //   C C E E E
    //
    // Pieces:
    //   A = I-tetromino  baseCells [(0,0),(0,1),(0,2),(0,3)]
    //   B = J-tetromino  baseCells [(0,1),(1,1),(2,0),(2,1)]
    //   C = L-tetromino  baseCells [(0,0),(1,0),(2,0),(2,1)]
    //   D = L-tetromino (different instance, placed at rot1)
    //   E = J-tetromino (different instance, placed at rot1)
    //
    // Solution placements:
    //   A@(0,0)rot0 → (0,0)(0,1)(0,2)(0,3)
    //   B@(0,3)rot0: [(0,1),(1,1),(2,0),(2,1)] → (0,4)(1,4)(2,3)(2,4)
    //   C@(1,0)rot0: [(0,0),(1,0),(2,0),(2,1)] → (1,0)(2,0)(3,0)(3,1)
    //   D@(1,1)rot1: L rot1=[(0,0),(0,1),(0,2),(1,0)] → (1,1)(1,2)(1,3)(2,1)
    //   E@(2,2)rot1: J rot1=[(0,0),(1,0),(1,1),(1,2)] → (2,2)(3,2)(3,3)(3,4)
    //
    // Verified cell map:
    //   (0,0)=A (0,1)=A (0,2)=A (0,3)=A (0,4)=B
    //   (1,0)=C (1,1)=D (1,2)=D (1,3)=D (1,4)=B
    //   (2,0)=C (2,1)=D (2,2)=E (2,3)=B (2,4)=B
    //   (3,0)=C (3,1)=C (3,2)=E (3,3)=E (3,4)=E  ✓ all 20 cells
    static let level5 = ChineseBoxLevel(
        id: 5,
        title: "The Master's Tray",
        subtitle: "Five shapes, one tray",
        lore: "Five different pieces of wood. No two are the same. Yet together they fill the tray without a gap. The master saw this and said: difference is not disorder.",
        inscriptions: [
            "The long strip claims the top. What remains is shaped by what surrounds it.",
            "The hook on the left grows downward. The hook on the right folds inward.",
            "The center piece bridges what the outer pieces cannot reach alone.",
            "When the last piece drops into place, no corner is left empty."
        ],
        rows: 4, cols: 5,
        pieces: [
            ChineseBoxPiece(id: "A", name: "條", meaning: "Strip",
                            colorHex: "B5813A",
                            baseCells: [(0,0),(0,1),(0,2),(0,3)]),
            ChineseBoxPiece(id: "B", name: "曲", meaning: "Bend",
                            colorHex: "9A6B2E",
                            baseCells: [(0,1),(1,1),(2,0),(2,1)]),
            ChineseBoxPiece(id: "C", name: "鉤", meaning: "Hook",
                            colorHex: "C4924A",
                            baseCells: [(0,0),(1,0),(2,0),(2,1)]),
            ChineseBoxPiece(id: "D", name: "鉤", meaning: "Hook",
                            colorHex: "A07030",
                            baseCells: [(0,0),(1,0),(2,0),(2,1)]),
            ChineseBoxPiece(id: "E", name: "曲", meaning: "Bend",
                            colorHex: "8C6228",
                            baseCells: [(0,1),(1,1),(2,0),(2,1)])
        ],
        solutionPlacements: [
            "A": ChinesePiecePlacement(row: 0, col: 0, rotation: 0),
            "B": ChinesePiecePlacement(row: 0, col: 3, rotation: 0),
            "C": ChinesePiecePlacement(row: 1, col: 0, rotation: 0),
            "D": ChinesePiecePlacement(row: 1, col: 1, rotation: 1),
            "E": ChinesePiecePlacement(row: 2, col: 2, rotation: 1)
        ],
        decodedMessage: "Wood remembers every ring of every year. Five pieces, one truth: difference is not disorder — it is completion.",
        artifactSymbol: "puzzlepiece.fill",
        journalTitle: "The Master Craftsman's Box",
        journalBody: "Found sealed inside a lacquered chest from the Tang dynasty. Five puzzle pieces, each a different wood: pine, cedar, elm, oak, and sandalwood. The inscription on the lid: 'Only together do they remember the shape of the tree.'"
    )
}
