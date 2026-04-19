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
//   L1 — 3×4 tray, 3 pieces   (strip + two hooks, two rotations)
//   L2 — 3×5 tray, 4 pieces   (four different shapes including short strip)
//   L3 — 4×4 tray, 4 pieces   (four nails — same T-shape, four rotations)
//   L4 — 4×5 tray, 5 pieces   (five distinct shapes)
//   L5 — 4×6 tray, 6 pieces   (master: two pillars + four nails)

import Foundation

// MARK: - Piece Placement

struct ChinesePiecePlacement: Equatable, Hashable, Codable {
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
    /// Index into baseCells whose cell carries a gate mark (nil = no mark).
    /// The mark is physically carved into the wood — it moves with the piece as it rotates.
    let gateMarkCellIndex: Int?
    /// The Unicode symbol carved on the gate-marked cell (nil = no mark).
    let gateMarkSymbol: String?

    init(id: String, name: String, meaning: String, colorHex: String,
         baseCells: [(Int, Int)],
         gateMarkCellIndex: Int? = nil, gateMarkSymbol: String? = nil) {
        self.id = id
        self.name = name
        self.meaning = meaning
        self.colorHex = colorHex
        self.baseCells = baseCells
        self.gateMarkCellIndex = gateMarkCellIndex
        self.gateMarkSymbol = gateMarkSymbol
    }

    /// Returns the gate mark's absolute board position (and symbol) given a current placement,
    /// or nil if this piece has no gate mark.
    func gateMarkBoardCell(at placement: ChinesePiecePlacement) -> (row: Int, col: Int, symbol: String)? {
        guard let idx = gateMarkCellIndex, let symbol = gateMarkSymbol else { return nil }
        let rotated = cells(rotation: placement.rotation)
        guard idx < rotated.count else { return nil }
        let (dr, dc) = rotated[idx]
        return (row: dr + placement.row, col: dc + placement.col, symbol: symbol)
    }

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
    // 3×4 tray, 3 pieces — I-4 strip + two L-hooks (same shape, two rotations)
    //
    // TWO valid tray packings exist:
    //   Packing 1 (correct) — strip at top:     Packing 2 (wrong) — strip at bottom:
    //     A A A A                                  B B B C
    //     B B B C                                  B C C C
    //     B C C C                                  A A A A
    //
    // Gate mark design — marks must land ADJACENT for the gate to pass:
    //   A (strip): gate mark at baseCells[2]=(0,2).
    //     Packing 1 — A@(0,0)rot0: mark → board (0,2)
    //     Packing 2 — A@(2,0)rot0: mark → board (2,2)
    //
    //   B (hook):  gate mark at baseCells[0]=(0,0).
    //     Packing 1 — B@(1,0)rot1: baseCells[0]→rot1[0]=(0,2) → board (1,2)
    //     Packing 2 — B@(0,0)rot1: baseCells[0]→rot1[0]=(0,2) → board (0,2)
    //
    //   Packing 1: A mark=(0,2), B mark=(1,2) → vertically adjacent ✓  GATE PASSES
    //   Packing 2: A mark=(2,2), B mark=(0,2) → two rows apart        ✗  GATE FAILS, board resets
    //
    // Rotation verification (L rot1 from baseCells [(0,0),(1,0),(2,0),(2,1)]):
    //   apply (r,c)→(c,-r): (0,0)→(0,0) (1,0)→(0,-1) (2,0)→(0,-2) (2,1)→(1,-2)
    //   normalize (+2 col):  (0,2)(0,1)(0,0)(1,0)
    //
    // L rot3: (1,0)(1,1)(1,2)(0,2)
    //
    // Solution placements (Packing 1):
    //   A@(0,0)rot0 → (0,0)(0,1)(0,2)(0,3)
    //   B@(1,0)rot1 → (1,0)(1,1)(1,2)(2,0)
    //   C@(1,1)rot3 → (1,3)(2,1)(2,2)(2,3)
    //
    // Verified cell map (all 12 cells):
    //   (0,0)=A (0,1)=A (0,2)=A✦ (0,3)=A
    //   (1,0)=B (1,1)=B (1,2)=B✦ (1,3)=C
    //   (2,0)=B (2,1)=C (2,2)=C  (2,3)=C  ✓  marks at (0,2)↕(1,2) — adjacent
    static let level1 = ChineseBoxLevel(
        id: 1,
        title: "The Turning Pieces",
        subtitle: "One shape, two facings",
        lore: "The master sets a long plank above the tray and two hook-pieces beside it. They are the same hook — one faces dawn, one faces dusk. Only by turning do they reveal their place.",
        inscriptions: [
            "Study what the long strip leaves behind. It spans the top row entirely — whatever it covers is settled. What remains below shapes the two hook-pieces, which are identical in form but cannot face the same direction. Find what the strip cannot touch, and the hooks place themselves.",
            "Two hooks, one shape — yet they cannot face the same direction.",
            "Turn the hook until the corner it seeks becomes clear."
        ],
        rows: 3, cols: 4,
        pieces: [
            // Gate mark: baseCells[2]=(0,2) → rot0=(0,2) → board(0,2). Celtic ᚅ carved on the strip.
            ChineseBoxPiece(id: "A", name: "條", meaning: "Strip",
                            colorHex: "B5813A",
                            baseCells: [(0,0),(0,1),(0,2),(0,3)],
                            gateMarkCellIndex: 2, gateMarkSymbol: "ᚅ"),
            // Gate mark: baseCells[0]=(0,0) → rot1[0]=(0,2) → board(1,2). Maya ᛚ carved here.
            ChineseBoxPiece(id: "B", name: "鉤", meaning: "Hook",
                            colorHex: "9A6B2E",
                            baseCells: [(0,0),(1,0),(2,0),(2,1)],
                            gateMarkCellIndex: 0, gateMarkSymbol: "ᛚ"),
            // No gate mark on piece C.
            ChineseBoxPiece(id: "C", name: "鉤", meaning: "Hook",
                            colorHex: "C4924A",
                            baseCells: [(0,0),(1,0),(2,0),(2,1)])
        ],
        // A@(0,0)rot0 → (0,0)(0,1)(0,2)(0,3)
        // B@(1,0)rot1 → (1,0)(1,1)(1,2)(2,0)
        // C@(1,1)rot3 → (1,3)(2,1)(2,2)(2,3)
        solutionPlacements: [
            "A": ChinesePiecePlacement(row: 0, col: 0, rotation: 0),
            "B": ChinesePiecePlacement(row: 1, col: 0, rotation: 1),
            "C": ChinesePiecePlacement(row: 1, col: 1, rotation: 3)
        ],
        decodedMessage: "Turning reveals what standing still conceals. The hook finds its home only when it faces the right direction.",
        artifactSymbol: "rotate.right",
        journalTitle: "The Hook Pieces",
        journalBody: "Two carved elm pieces, identical in every measurement. The tray accepts them only when they face opposite corners. The workshop inscription: 'Same wood, same shape — yet each has only one true place.'"
    )

    // ── LEVEL 2 ─────────────────────────────────────────────────────────────
    // 3×5 tray, 4 pieces — I-4 + T-4 + L-4 + I-3 (four different shapes)
    //
    //   A A A A B
    //   C C C B B
    //   C D D D B
    //
    // Pieces:
    //   A = I-4  baseCells [(0,0),(0,1),(0,2),(0,3)]
    //   B = T-4  baseCells [(0,0),(0,1),(0,2),(1,1)]  — placed at rot1
    //   C = L-4  baseCells [(0,0),(1,0),(2,0),(2,1)]  — placed at rot1
    //   D = I-3  baseCells [(0,0),(0,1),(0,2)]        — placed at rot0
    //
    // Rotation verification:
    //   T rot1 = [(0,1),(1,0),(1,1),(2,1)]
    //   L rot1 = [(0,0),(0,1),(0,2),(1,0)]
    //
    // Solution placements:
    //   A@(0,0)rot0 → (0,0)(0,1)(0,2)(0,3)
    //   B@(0,3)rot1 → (0,4)(1,3)(1,4)(2,4)
    //   C@(1,0)rot1 → (1,0)(1,1)(1,2)(2,0)
    //   D@(2,1)rot0 → (2,1)(2,2)(2,3)
    //
    // Verified cell map (all 15 cells):
    //   (0,0)=A (0,1)=A (0,2)=A (0,3)=A (0,4)=B
    //   (1,0)=C (1,1)=C (1,2)=C (1,3)=B (1,4)=B
    //   (2,0)=C (2,1)=D (2,2)=D (2,3)=D (2,4)=B  ✓
    static let level2 = ChineseBoxLevel(
        id: 2,
        title: "The Four Shapes",
        subtitle: "No two pieces alike",
        lore: "Four distinct pieces of wood rest beside the tray. Each has a different name, a different length, a different turning. The tray accepts all four — but only in one arrangement.",
        inscriptions: [
            "One shape claims the top row completely. Below it, the nail-piece descends from the right, the hook sweeps the second row, and the short strip fills the final gap. Let each piece find its own fixed corner before placing the next.",
            "The hook sweeps the second row. The small strip fills what remains.",
            "Four shapes, one tray. Each piece knows one corner it cannot reach without the others."
        ],
        rows: 3, cols: 5,
        pieces: [
            ChineseBoxPiece(id: "A", name: "條", meaning: "Strip",
                            colorHex: "B5813A",
                            baseCells: [(0,0),(0,1),(0,2),(0,3)]),
            ChineseBoxPiece(id: "B", name: "丁", meaning: "Nail",
                            colorHex: "6B3D25",
                            baseCells: [(0,0),(0,1),(0,2),(1,1)]),
            ChineseBoxPiece(id: "C", name: "鉤", meaning: "Hook",
                            colorHex: "9A6B2E",
                            baseCells: [(0,0),(1,0),(2,0),(2,1)]),
            ChineseBoxPiece(id: "D", name: "短", meaning: "Short",
                            colorHex: "C4924A",
                            baseCells: [(0,0),(0,1),(0,2)])
        ],
        // A@(0,0)rot0 → (0,0)(0,1)(0,2)(0,3)
        // B@(0,3)rot1 → (0,4)(1,3)(1,4)(2,4)
        // C@(1,0)rot1 → (1,0)(1,1)(1,2)(2,0)
        // D@(2,1)rot0 → (2,1)(2,2)(2,3)
        solutionPlacements: [
            "A": ChinesePiecePlacement(row: 0, col: 0, rotation: 0),
            "B": ChinesePiecePlacement(row: 0, col: 3, rotation: 1),
            "C": ChinesePiecePlacement(row: 1, col: 0, rotation: 1),
            "D": ChinesePiecePlacement(row: 2, col: 1, rotation: 0)
        ],
        decodedMessage: "Four shapes, one harmony. Difference does not prevent unity — it enables it.",
        artifactSymbol: "square.grid.2x2",
        journalTitle: "The Mixed Tray",
        journalBody: "A craftsman's teaching tray from the Warring States period. Four different pieces of wood — cedar, elm, pine, and oak — each a different size. The note accompanying them: 'Unlike things may still complete one another.'"
    )

    // ── LEVEL 3 ─────────────────────────────────────────────────────────────
    // 4×4 tray, 4 pieces — four T-tetrominoes (same shape, all four rotations)
    //
    //   A A A B
    //   C A B B
    //   C C B D
    //   C D D D
    //
    // T rot0=[(0,0),(0,1),(0,2),(1,1)]  rot1=[(0,1),(1,0),(1,1),(2,1)]
    // T rot2=[(0,1),(1,0),(1,1),(1,2)]  rot3=[(0,0),(1,0),(1,1),(2,0)]
    //
    // Solution placements:
    //   A@(0,0)rot0 → (0,0)(0,1)(0,2)(1,1)
    //   B@(0,2)rot1 → (0,3)(1,2)(1,3)(2,3)
    //   C@(1,0)rot3 → (1,0)(2,0)(2,1)(3,0)
    //   D@(2,1)rot2 → (2,2)(3,1)(3,2)(3,3)
    //
    // Verified cell map (all 16 cells):
    //   (0,0)=A (0,1)=A (0,2)=A (0,3)=B
    //   (1,0)=C (1,1)=A (1,2)=B (1,3)=B
    //   (2,0)=C (2,1)=C (2,2)=D (2,3)=B
    //   (3,0)=C (3,1)=D (3,2)=D (3,3)=D  ✓
    static let level3 = ChineseBoxLevel(
        id: 3,
        title: "The Four Nails",
        subtitle: "Four T-shapes, four directions",
        lore: "The nail piece is named for the character 丁 — a head and a stem. It can point toward any of the four walls. When each nail faces a different wall, they lock together and the tray is filled.",
        inscriptions: [
            "Like the character 丁 — a head above a stem — each nail-piece can point toward any of the four walls. No two may face the same direction. One points down, one points right, one points left, one points up. Together they share the centre of the tray.",
            "A second nail descends from the right. A third rises from the left.",
            "The fourth nail points upward from below, its stem buried in the corner.",
            "No two nails face the same wall. Together they share the center."
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
        // A@(0,0)rot0 → (0,0)(0,1)(0,2)(1,1)
        // B@(0,2)rot1 → (0,3)(1,2)(1,3)(2,3)
        // C@(1,0)rot3 → (1,0)(2,0)(2,1)(3,0)
        // D@(2,1)rot2 → (2,2)(3,1)(3,2)(3,3)
        solutionPlacements: [
            "A": ChinesePiecePlacement(row: 0, col: 0, rotation: 0),
            "B": ChinesePiecePlacement(row: 0, col: 2, rotation: 1),
            "C": ChinesePiecePlacement(row: 1, col: 0, rotation: 3),
            "D": ChinesePiecePlacement(row: 2, col: 1, rotation: 2)
        ],
        decodedMessage: "What points in all directions loses nothing and gains everything. The four nails hold the box together from within.",
        artifactSymbol: "arrow.up.arrow.down.circle",
        journalTitle: "The Scholar's Lock",
        journalBody: "A puzzle box from the Song dynasty. Four identical pieces of hardwood — the challenge is not identifying the shapes, but discovering which direction each one must face."
    )

    // ── LEVEL 4 ─────────────────────────────────────────────────────────────
    // 4×5 tray, 5 pieces — I-4 + J + L + L + J (five distinct instances)
    //
    //   A A A A B
    //   C D D D B
    //   C D E B B
    //   C C E E E
    //
    // Pieces:
    //   A = I-4  baseCells [(0,0),(0,1),(0,2),(0,3)]
    //   B = J    baseCells [(0,1),(1,1),(2,0),(2,1)]  — placed at rot0
    //   C = L    baseCells [(0,0),(1,0),(2,0),(2,1)]  — placed at rot0
    //   D = L    baseCells [(0,0),(1,0),(2,0),(2,1)]  — placed at rot1
    //   E = J    baseCells [(0,1),(1,1),(2,0),(2,1)]  — placed at rot1
    //
    // Rotation verification:
    //   J rot0 = [(0,1),(1,1),(2,0),(2,1)]
    //   L rot0 = [(0,0),(1,0),(2,0),(2,1)]
    //   L rot1 = [(0,0),(0,1),(0,2),(1,0)]
    //   J rot1 = [(0,0),(1,0),(1,1),(1,2)]
    //
    // Solution placements:
    //   A@(0,0)rot0 → (0,0)(0,1)(0,2)(0,3)
    //   B@(0,3)rot0 → (0,4)(1,4)(2,3)(2,4)
    //   C@(1,0)rot0 → (1,0)(2,0)(3,0)(3,1)
    //   D@(1,1)rot1 → (1,1)(1,2)(1,3)(2,1)
    //   E@(2,2)rot1 → (2,2)(3,2)(3,3)(3,4)
    //
    // Verified cell map (all 20 cells):
    //   (0,0)=A (0,1)=A (0,2)=A (0,3)=A (0,4)=B
    //   (1,0)=C (1,1)=D (1,2)=D (1,3)=D (1,4)=B
    //   (2,0)=C (2,1)=D (2,2)=E (2,3)=B (2,4)=B
    //   (3,0)=C (3,1)=C (3,2)=E (3,3)=E (3,4)=E  ✓
    static let level4 = ChineseBoxLevel(
        id: 4,
        title: "The Five Wood Spirits",
        subtitle: "Five shapes seek their home",
        lore: "Five pieces of ancient wood, each carved by a different hand in a different dynasty. The long strip remembers the river's straightness. The two bends remember the willow's curve. Only together can they fill the carpenter's tray.",
        inscriptions: [
            "Across the top row, only the long strip fits without interruption. Below it, a bend descends from the right while a hook grows down the left. Between them, a broader piece sweeps three cells in the second row. The final bend curls from the centre toward the far corner.",
            "A bend descends from the right, folding inward at the base.",
            "The left hook grows downward, its foot extending right.",
            "The broad piece sweeps three cells across the second row, anchored at the left.",
            "The final bend curls from the center downward, claiming the far corner."
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
        // A@(0,0)rot0 → (0,0)(0,1)(0,2)(0,3)
        // B@(0,3)rot0 → (0,4)(1,4)(2,3)(2,4)
        // C@(1,0)rot0 → (1,0)(2,0)(3,0)(3,1)
        // D@(1,1)rot1 → (1,1)(1,2)(1,3)(2,1)
        // E@(2,2)rot1 → (2,2)(3,2)(3,3)(3,4)
        solutionPlacements: [
            "A": ChinesePiecePlacement(row: 0, col: 0, rotation: 0),
            "B": ChinesePiecePlacement(row: 0, col: 3, rotation: 0),
            "C": ChinesePiecePlacement(row: 1, col: 0, rotation: 0),
            "D": ChinesePiecePlacement(row: 1, col: 1, rotation: 1),
            "E": ChinesePiecePlacement(row: 2, col: 2, rotation: 1)
        ],
        decodedMessage: "Five pieces, five woods, five dynasties — yet the tray holds them all. What is different may still be complete.",
        artifactSymbol: "puzzlepiece.fill",
        journalTitle: "The Five-Piece Tray",
        journalBody: "Recovered from a Tang dynasty chest: five puzzle pieces, each a different wood — pine, cedar, elm, oak, and sandalwood. The lid inscription reads: 'Only together do they remember the shape of the tree.'"
    )

    // ── LEVEL 5 ─────────────────────────────────────────────────────────────
    // 4×6 tray, 6 pieces — I-4 (vert) × 2 + T-4 × 4
    //
    //   A C C C D B
    //   A E C D D B
    //   A E E F D B
    //   A E F F F B
    //
    // Pieces:
    //   A = I-4  baseCells [(0,0),(0,1),(0,2),(0,3)]  — placed vertical (rot1)
    //   B = I-4  baseCells [(0,0),(0,1),(0,2),(0,3)]  — placed vertical (rot1)
    //   C = T-4  baseCells [(0,0),(0,1),(0,2),(1,1)]  — placed at rot0
    //   D = T-4  baseCells [(0,0),(0,1),(0,2),(1,1)]  — placed at rot1
    //   E = T-4  baseCells [(0,0),(0,1),(0,2),(1,1)]  — placed at rot3
    //   F = T-4  baseCells [(0,0),(0,1),(0,2),(1,1)]  — placed at rot2
    //
    // Rotation verification:
    //   I-4 rot1 = [(0,0),(1,0),(2,0),(3,0)]  (vertical pillar)
    //   T   rot0 = [(0,0),(0,1),(0,2),(1,1)]  (T pointing down)
    //   T   rot1 = [(0,1),(1,0),(1,1),(2,1)]  (T pointing right)
    //   T   rot2 = [(0,1),(1,0),(1,1),(1,2)]  (T pointing up)
    //   T   rot3 = [(0,0),(1,0),(1,1),(2,0)]  (T pointing left)
    //
    // Solution placements:
    //   A@(0,0)rot1 → (0,0)(1,0)(2,0)(3,0)
    //   B@(0,5)rot1 → (0,5)(1,5)(2,5)(3,5)
    //   C@(0,1)rot0 → (0,1)(0,2)(0,3)(1,2)
    //   D@(0,3)rot1 → (0,4)(1,3)(1,4)(2,4)
    //   E@(1,1)rot3 → (1,1)(2,1)(2,2)(3,1)
    //   F@(2,2)rot2 → (2,3)(3,2)(3,3)(3,4)
    //
    // Verified cell map (all 24 cells):
    //   (0,0)=A (0,1)=C (0,2)=C (0,3)=C (0,4)=D (0,5)=B
    //   (1,0)=A (1,1)=E (1,2)=C (1,3)=D (1,4)=D (1,5)=B
    //   (2,0)=A (2,1)=E (2,2)=E (2,3)=F (2,4)=D (2,5)=B
    //   (3,0)=A (3,1)=E (3,2)=F (3,3)=F (3,4)=F (3,5)=B  ✓
    static let level5 = ChineseBoxLevel(
        id: 5,
        title: "The Master's Creation",
        subtitle: "Two pillars, four nails",
        lore: "The master craftsman's final tray is the widest. Two long pillars stand at the edges. Between them, four nail-pieces interlock in a pattern that took the master thirty years to discover. No shortcut exists. The wood will only speak to those who have learned to listen.",
        inscriptions: [
            "Rest the two pillars at the left and right edges first — they are the tallest pieces and the only ones that span the full height of the tray. Between them, four nail-pieces must interlock, each one facing a different direction than the others.",
            "A nail-piece crowns the top, its head spanning three columns.",
            "A second nail descends from the upper right, its stem at the far edge.",
            "A third nail rises from the left of center, its foot touching the second row.",
            "The fourth nail points upward from below, its head in the final row.",
            "When all six pieces are placed, the tray is silent. The work is complete."
        ],
        rows: 4, cols: 6,
        pieces: [
            ChineseBoxPiece(id: "A", name: "柱", meaning: "Pillar",
                            colorHex: "4A2C1A",
                            baseCells: [(0,0),(0,1),(0,2),(0,3)]),
            ChineseBoxPiece(id: "B", name: "柱", meaning: "Pillar",
                            colorHex: "6B3D25",
                            baseCells: [(0,0),(0,1),(0,2),(0,3)]),
            ChineseBoxPiece(id: "C", name: "丁", meaning: "Nail",
                            colorHex: "B5813A",
                            baseCells: [(0,0),(0,1),(0,2),(1,1)]),
            ChineseBoxPiece(id: "D", name: "丁", meaning: "Nail",
                            colorHex: "9A6B2E",
                            baseCells: [(0,0),(0,1),(0,2),(1,1)]),
            ChineseBoxPiece(id: "E", name: "丁", meaning: "Nail",
                            colorHex: "C4924A",
                            baseCells: [(0,0),(0,1),(0,2),(1,1)]),
            ChineseBoxPiece(id: "F", name: "丁", meaning: "Nail",
                            colorHex: "A07030",
                            baseCells: [(0,0),(0,1),(0,2),(1,1)])
        ],
        // A@(0,0)rot1 → (0,0)(1,0)(2,0)(3,0)
        // B@(0,5)rot1 → (0,5)(1,5)(2,5)(3,5)
        // C@(0,1)rot0 → (0,1)(0,2)(0,3)(1,2)
        // D@(0,3)rot1 → (0,4)(1,3)(1,4)(2,4)
        // E@(1,1)rot3 → (1,1)(2,1)(2,2)(3,1)
        // F@(2,2)rot2 → (2,3)(3,2)(3,3)(3,4)
        solutionPlacements: [
            "A": ChinesePiecePlacement(row: 0, col: 0, rotation: 1),
            "B": ChinesePiecePlacement(row: 0, col: 5, rotation: 1),
            "C": ChinesePiecePlacement(row: 0, col: 1, rotation: 0),
            "D": ChinesePiecePlacement(row: 0, col: 3, rotation: 1),
            "E": ChinesePiecePlacement(row: 1, col: 1, rotation: 3),
            "F": ChinesePiecePlacement(row: 2, col: 2, rotation: 2)
        ],
        decodedMessage: "The Tao that can be named is not the eternal Tao. Yet here, in wood and silence, you have touched its shape.",
        artifactSymbol: "seal.fill",
        journalTitle: "The Master's Final Tray",
        journalBody: "Found locked in a sealed chamber beneath the workshop. Six pieces of the darkest hardwood, worn smooth by decades of handling. The inscription on the tray's underside: 'Thirty years I sought this arrangement. Now it is yours to find in an afternoon — or a lifetime.'"
    )
}
