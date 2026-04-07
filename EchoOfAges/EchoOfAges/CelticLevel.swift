// CelticLevel.swift
// EchoOfAges
//
// Ogham ordering puzzles for the Celtic / Druidic civilization.
//
// Mechanic: A carved stone inscription presents a grid of cells.
// The player fills blank cells with Ogham letters. The rule:
// every row (left → right) and every column (top → bottom)
// must be in non-decreasing Ogham alphabetical order.
//
// The five Ogham letters and their sacred tree associations:
//   ᚁ Beith (Birch)  — value 1
//   ᚂ Luis  (Rowan)  — value 2
//   ᚃ Fearn (Alder)  — value 3
//   ᚄ Sail  (Willow) — value 4
//   ᚅ Nion  (Ash)    — value 5
//
// Letters may repeat. Any filling that satisfies the non-decreasing
// constraint in every row and column is accepted as correct.
//
// Level progression:
//   L1 — 2×4,  4 blanks  (introduction — learn the ordering rule)
//   L2 — 3×3,  5 blanks  (rows + columns start to interact)
//   L3 — 3×4,  7 blanks  (more space, fewer anchors)
//   L4 — 4×4,  9 blanks  (four rows, deeper constraint chains)
//   L5 — 4×5, 12 blanks  (master — sparse anchors, full deduction)

import Foundation

// MARK: - OghamGlyph

enum OghamGlyph: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case beith = "ᚁ"   // Birch  — value 1
    case luis  = "ᚂ"   // Rowan  — value 2
    case fearn = "ᚃ"   // Alder  — value 3
    case sail  = "ᚄ"   // Willow — value 4
    case nion  = "ᚅ"   // Ash    — value 5

    var id: String { rawValue }

    /// Alphabetical position in the Beith-Luis-Nion sequence (1–5).
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
}

// MARK: - Cell Coordinate

struct CelticCellCoord: Hashable, Equatable {
    let row: Int
    let col: Int
}

// MARK: - Level

struct CelticLevel: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let lore: String
    let inscriptions: [String]
    let rows: Int
    let cols: Int
    /// The canonical solution — a valid fully-filled grid.
    let solution: [[OghamGlyph]]
    /// Cells pre-carved on the stone — these cannot be changed by the player.
    let fixedCells: Set<CelticCellCoord>
    let decodedMessage: String
    let artifactSymbol: String
    let journalTitle: String
    let journalBody: String

    var romanNumeral: String {
        ["I", "II", "III", "IV", "V"][min(id - 1, 4)]
    }

    // MARK: Grid helpers

    /// Returns the initial player grid with only the fixed cells filled.
    func initialGrid() -> [[OghamGlyph?]] {
        (0..<rows).map { r in
            (0..<cols).map { c in
                fixedCells.contains(CelticCellCoord(row: r, col: c))
                    ? solution[r][c]
                    : nil
            }
        }
    }

    // MARK: Validation

    /// True when every cell is filled AND every row and column is non-decreasing.
    func isSolved(_ grid: [[OghamGlyph?]]) -> Bool {
        guard grid.count == rows, grid.allSatisfy({ $0.count == cols }) else { return false }
        for r in 0..<rows {
            for c in 0..<cols {
                guard grid[r][c] != nil else { return false }
            }
        }
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
        return true
    }

    /// Returns cells that participate in any ordering violation (for the error-flash mechanic).
    func errorCells(in grid: [[OghamGlyph?]]) -> Set<CelticCellCoord> {
        var errors = Set<CelticCellCoord>()
        for r in 0..<rows {
            for c in 1..<cols {
                if let a = grid[r][c-1], let b = grid[r][c], a.value > b.value {
                    errors.insert(CelticCellCoord(row: r, col: c-1))
                    errors.insert(CelticCellCoord(row: r, col: c))
                }
            }
        }
        for c in 0..<cols {
            for r in 1..<rows {
                if let a = grid[r-1][c], let b = grid[r][c], a.value > b.value {
                    errors.insert(CelticCellCoord(row: r-1, col: c))
                    errors.insert(CelticCellCoord(row: r,   col: c))
                }
            }
        }
        return errors
    }
}

// MARK: - All Levels

extension CelticLevel {

    static let allLevels: [CelticLevel] = [level1, level2, level3, level4, level5]

    // ── LEVEL 1 ─────────────────────────────────────────────────────────────
    // 2×4 tray, 4 blanks — introduction to the ordering rule.
    //
    // Solution:
    //   ᚁ ᚁ ᚃ ᚄ    (1 1 3 4)
    //   ᚂ ᚃ ᚄ ᚅ    (2 3 4 5)
    //
    // Fixed (anchors): corners — (0,0)=ᚁ  (0,3)=ᚄ  (1,0)=ᚂ  (1,3)=ᚅ
    // Blanks: (0,1) (0,2) (1,1) (1,2)
    //
    // Row/col verification:
    //   Row 0: 1≤1≤3≤4 ✓   Row 1: 2≤3≤4≤5 ✓
    //   Col 0: 1≤2 ✓   Col 1: 1≤3 ✓   Col 2: 3≤4 ✓   Col 3: 4≤5 ✓
    static let level1 = CelticLevel(
        id: 1,
        title: "The First Inscription",
        subtitle: "Two rows on the standing stone",
        lore: "The apprentice Druid carved two lines into the stone. The master stopped the chisel: 'Every mark must follow the one before it. Beith before Luis, Luis before Fearn. The stone will teach you if you listen to its order.'",
        inscriptions: [
            "The top row begins with Beith and ends with Sail. Fill the two between.",
            "The bottom row begins with Luis and ends with Nion. Each column must also rise.",
            "Where rows and columns both rise — only one arrangement fits each blank."
        ],
        rows: 2, cols: 4,
        solution: [
            [.beith, .beith, .fearn, .sail],
            [.luis,  .fearn, .sail,  .nion]
        ],
        fixedCells: [
            CelticCellCoord(row: 0, col: 0), // ᚁ
            CelticCellCoord(row: 0, col: 3), // ᚄ
            CelticCellCoord(row: 1, col: 0), // ᚂ
            CelticCellCoord(row: 1, col: 3)  // ᚅ
        ],
        decodedMessage: "Beith rises before all others. Even the birch must learn what comes before it can grow.",
        artifactSymbol: "text.alignleft",
        journalTitle: "The Apprentice's Stone",
        journalBody: "A small standing stone found at the edge of a ring fort in County Clare. Two lines of Ogham, partially worn. The marks that remain tell you the rule. The marks that are gone ask you to remember it."
    )

    // ── LEVEL 2 ─────────────────────────────────────────────────────────────
    // 3×3 tray, 5 blanks — rows and columns begin to interact.
    //
    // Solution:
    //   ᚁ ᚂ ᚄ    (1 2 4)
    //   ᚂ ᚃ ᚅ    (2 3 5)
    //   ᚃ ᚄ ᚅ    (3 4 5)
    //
    // Fixed: (0,0)=ᚁ  (0,2)=ᚄ  (1,1)=ᚃ  (2,2)=ᚅ
    // Blanks: (0,1) (1,0) (1,2) (2,0) (2,1)
    //
    // Row/col verification:
    //   Row 0: 1≤2≤4 ✓   Row 1: 2≤3≤5 ✓   Row 2: 3≤4≤5 ✓
    //   Col 0: 1≤2≤3 ✓   Col 1: 2≤3≤4 ✓   Col 2: 4≤5≤5 ✓
    static let level2 = CelticLevel(
        id: 2,
        title: "The Grove Square",
        subtitle: "Three rows, three columns",
        lore: "The Druid grove was a square clearing in the forest. The master explained: the order you read across the stone must be the same order you read down it. Every mark agrees with every other. The grove has no beginning and no end — only the ordering.",
        inscriptions: [
            "Beith holds the top corner. Sail closes the first row. What lies between?",
            "Fearn anchors the center. It tells you what can come before it in its row, and what must follow below.",
            "Nion closes the stone. Everything must rise toward it."
        ],
        rows: 3, cols: 3,
        solution: [
            [.beith, .luis,  .sail],
            [.luis,  .fearn, .nion],
            [.fearn, .sail,  .nion]
        ],
        fixedCells: [
            CelticCellCoord(row: 0, col: 0), // ᚁ
            CelticCellCoord(row: 0, col: 2), // ᚄ
            CelticCellCoord(row: 1, col: 1), // ᚃ
            CelticCellCoord(row: 2, col: 2)  // ᚅ
        ],
        decodedMessage: "The rowan protects the grove. But only the ash, at the last corner, completes the boundary.",
        artifactSymbol: "square.grid.3x3",
        journalTitle: "The Grove Stone",
        journalBody: "Recovered from the center of a stone circle in County Galway. Nine marks arranged in a square. Four are legible. The pattern in the legible marks is the key to reading the worn ones."
    )

    // ── LEVEL 3 ─────────────────────────────────────────────────────────────
    // 3×4 tray, 7 blanks — more space, fewer anchors.
    //
    // Solution:
    //   ᚁ ᚁ ᚃ ᚄ    (1 1 3 4)
    //   ᚁ ᚂ ᚄ ᚄ    (1 2 4 4)
    //   ᚂ ᚃ ᚄ ᚅ    (2 3 4 5)
    //
    // Fixed: (0,0)=ᚁ  (0,3)=ᚄ  (1,1)=ᚂ  (2,0)=ᚂ  (2,3)=ᚅ
    // Blanks: (0,1)(0,2)(1,0)(1,2)(1,3)(2,1)(2,2)
    //
    // Row/col verification:
    //   Row 0: 1≤1≤3≤4 ✓   Row 1: 1≤2≤4≤4 ✓   Row 2: 2≤3≤4≤5 ✓
    //   Col 0: 1≤1≤2 ✓   Col 1: 1≤2≤3 ✓   Col 2: 3≤4≤4 ✓   Col 3: 4≤4≤5 ✓
    static let level3 = CelticLevel(
        id: 3,
        title: "The Long Stone",
        subtitle: "Three rows, four columns",
        lore: "The longer the inscription, the more constraints it carries. The Druids called the extended stone 'the memory stone' — because holding the order across four columns required more than cleverness. It required the kind of patience that only trees possess.",
        inscriptions: [
            "Beith begins the top row. Sail ends it. The two middle marks must agree with their columns below.",
            "Luis holds the second row's second position. Above it is Beith. Below it is Fearn. It is constrained from both sides.",
            "The bottom row anchors everything. Luis on the left, Nion on the right. What the middle holds, the other rows must have already prepared for."
        ],
        rows: 3, cols: 4,
        solution: [
            [.beith, .beith, .fearn, .sail],
            [.beith, .luis,  .sail,  .sail],
            [.luis,  .fearn, .sail,  .nion]
        ],
        fixedCells: [
            CelticCellCoord(row: 0, col: 0), // ᚁ
            CelticCellCoord(row: 0, col: 3), // ᚄ
            CelticCellCoord(row: 1, col: 1), // ᚂ
            CelticCellCoord(row: 2, col: 0), // ᚂ
            CelticCellCoord(row: 2, col: 3)  // ᚅ
        ],
        decodedMessage: "The alder grows beside the water. It does not ask what comes before it. It simply holds its place in the order, season after season.",
        artifactSymbol: "rectangle.split.3x1",
        journalTitle: "The Memory Stone",
        journalBody: "A long horizontal stone found half-buried at the edge of a bog in Connacht. The Druids buried stones intentionally — preservation, not concealment. The bog kept the Ogham crisp for two thousand years."
    )

    // ── LEVEL 4 ─────────────────────────────────────────────────────────────
    // 4×4 tray, 9 blanks — four rows, deeper constraint chains.
    //
    // Solution:
    //   ᚁ ᚁ ᚂ ᚄ    (1 1 2 4)
    //   ᚁ ᚂ ᚃ ᚅ    (1 2 3 5)
    //   ᚂ ᚃ ᚄ ᚅ    (2 3 4 5)
    //   ᚃ ᚄ ᚅ ᚅ    (3 4 5 5)
    //
    // Fixed: (0,0)=ᚁ  (0,3)=ᚄ  (1,2)=ᚃ  (2,0)=ᚂ  (2,3)=ᚅ  (3,0)=ᚃ  (3,3)=ᚅ
    // Blanks: (0,1)(0,2)(1,0)(1,1)(1,3)(2,1)(2,2)(3,1)(3,2)
    //
    // Row/col verification:
    //   Row 0: 1≤1≤2≤4 ✓   Row 1: 1≤2≤3≤5 ✓   Row 2: 2≤3≤4≤5 ✓   Row 3: 3≤4≤5≤5 ✓
    //   Col 0: 1≤1≤2≤3 ✓   Col 1: 1≤2≤3≤4 ✓   Col 2: 2≤3≤4≤5 ✓   Col 3: 4≤5≤5≤5 ✓
    static let level4 = CelticLevel(
        id: 4,
        title: "The Four Sacred Trees",
        subtitle: "Four rows, four columns",
        lore: "The Druidic year had four sacred turning points. At each, a tree was honored. The four-square inscription was the Druid's calendar in miniature: what grows in the first row constrains what can grow in the last. Past and future are written in the same stone.",
        inscriptions: [
            "Beith marks the top-left corner — new beginnings. Sail marks the top-right — flow and yielding.",
            "The second row's third mark is Fearn, the alder. It divides what can come before it in the row from what must follow.",
            "Luis holds the third row's left edge; Nion holds its right. The center two must honor both.",
            "The bottom row begins with Fearn and ends with Nion — twice. The end repeats, as seasons do."
        ],
        rows: 4, cols: 4,
        solution: [
            [.beith, .beith, .luis,  .sail],
            [.beith, .luis,  .fearn, .nion],
            [.luis,  .fearn, .sail,  .nion],
            [.fearn, .sail,  .nion,  .nion]
        ],
        fixedCells: [
            CelticCellCoord(row: 0, col: 0), // ᚁ
            CelticCellCoord(row: 0, col: 3), // ᚄ
            CelticCellCoord(row: 1, col: 2), // ᚃ
            CelticCellCoord(row: 2, col: 0), // ᚂ
            CelticCellCoord(row: 2, col: 3), // ᚅ
            CelticCellCoord(row: 3, col: 0), // ᚃ
            CelticCellCoord(row: 3, col: 3)  // ᚅ
        ],
        decodedMessage: "The willow bends without breaking. The ash stands without moving. Between them — the whole of what it means to endure.",
        artifactSymbol: "square.grid.4x3.fill",
        journalTitle: "The Calendar Stone",
        journalBody: "Found at the center of a Druidic ritual enclosure in Leinster. Four rows, four columns — sixteen marks total. Seven are legible. The Druids did not carve to record what they knew. They carved to test what the reader knew."
    )

    // ── LEVEL 5 ─────────────────────────────────────────────────────────────
    // 4×5 tray, 12 blanks — master inscription, sparse anchors.
    //
    // Solution:
    //   ᚁ ᚁ ᚂ ᚃ ᚄ    (1 1 2 3 4)
    //   ᚁ ᚂ ᚃ ᚄ ᚅ    (1 2 3 4 5)
    //   ᚂ ᚃ ᚄ ᚅ ᚅ    (2 3 4 5 5)
    //   ᚃ ᚄ ᚄ ᚅ ᚅ    (3 4 4 5 5)
    //
    // Fixed: (0,0)=ᚁ  (0,4)=ᚄ  (1,1)=ᚂ  (1,4)=ᚅ  (2,0)=ᚂ  (2,4)=ᚅ  (3,0)=ᚃ  (3,4)=ᚅ
    // Blanks: (0,1)(0,2)(0,3)(1,0)(1,2)(1,3)(2,1)(2,2)(2,3)(3,1)(3,2)(3,3)
    //
    // Row/col verification:
    //   Row 0: 1≤1≤2≤3≤4 ✓   Row 1: 1≤2≤3≤4≤5 ✓
    //   Row 2: 2≤3≤4≤5≤5 ✓   Row 3: 3≤4≤4≤5≤5 ✓
    //   Col 0: 1≤1≤2≤3 ✓   Col 1: 1≤2≤3≤4 ✓   Col 2: 2≤3≤4≤4 ✓
    //   Col 3: 3≤4≤5≤5 ✓   Col 4: 4≤5≤5≤5 ✓
    static let level5 = CelticLevel(
        id: 5,
        title: "The Master's Inscription",
        subtitle: "The complete Ogham sequence",
        lore: "The master Druid carved the final stone on the eve of the winter solstice. Twenty marks. Eight visible to the eye. Twelve hidden in the ordering itself — recoverable only by one who has learned to feel the sequence before they read it. The stone does not ask for cleverness. It asks for trust in the order.",
        inscriptions: [
            "Beith anchors the top-left corner; Sail anchors the top-right. Twelve cells stand between them.",
            "The second row's second mark is Luis. Its neighbors — above, below, left, right — all constrain it.",
            "Each edge column anchors the whole. The left edge climbs from Beith to Fearn. The right edge holds Sail and three Nions.",
            "What is true for every row is true for every column. The stone speaks the same language in both directions.",
            "When the last mark is placed, read the whole inscription. The order you feel will be the order of the grove."
        ],
        rows: 4, cols: 5,
        solution: [
            [.beith, .beith, .luis,  .fearn, .sail],
            [.beith, .luis,  .fearn, .sail,  .nion],
            [.luis,  .fearn, .sail,  .nion,  .nion],
            [.fearn, .sail,  .sail,  .nion,  .nion]
        ],
        fixedCells: [
            CelticCellCoord(row: 0, col: 0), // ᚁ
            CelticCellCoord(row: 0, col: 4), // ᚄ
            CelticCellCoord(row: 1, col: 1), // ᚂ
            CelticCellCoord(row: 1, col: 4), // ᚅ
            CelticCellCoord(row: 2, col: 0), // ᚂ
            CelticCellCoord(row: 2, col: 4), // ᚅ
            CelticCellCoord(row: 3, col: 0), // ᚃ
            CelticCellCoord(row: 3, col: 4)  // ᚅ
        ],
        decodedMessage: "Every tree named every other tree. Every voice in the grove spoke in the same sacred order. They did not know this was the word for 'remember.' They only knew it was the word for 'tree.'",
        artifactSymbol: "tree.fill",
        journalTitle: "The Master's Stone",
        journalBody: "The largest Ogham stone in the expedition's collection. Four rows, five columns — twenty marks carved in a deliberate sequence. The Druids who carved it left eight marks visible and twelve blank. Not vandalism. Not weather. Intention. The stone was carved to be completed by whoever came next."
    )
}
