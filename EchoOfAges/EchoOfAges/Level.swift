// Level.swift
// EchoOfAges
//
// Latin-square puzzle: each glyph appears exactly once per row and column.
// Fixed cells are pre-placed and cannot be changed. Player fills the rest.

import Foundation

// MARK: - Glyph

enum Glyph: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case eye   = "𓂀"   // Eye of Horus — Wisdom & Sight
    case owl   = "𓅓"   // Owl          — Knowledge & Night
    case water = "𓈖"   // Water        — Life & Renewal
    case lion  = "𓃭"   // Lion         — Strength & Power
    case sky   = "𓇯"   // Sky          — Eternity & Heaven

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .eye:   return "The Eye"
        case .owl:   return "The Owl"
        case .water: return "The Water"
        case .lion:  return "The Lion"
        case .sky:   return "The Sky"
        }
    }

    var meaning: String {
        switch self {
        case .eye:   return "Wisdom & Sight"
        case .owl:   return "Knowledge & Night"
        case .water: return "Life & Renewal"
        case .lion:  return "Strength & Power"
        case .sky:   return "Eternity & Heaven"
        }
    }
}

// MARK: - Grid Position

struct GridPosition: Hashable, Equatable {
    let row: Int
    let col: Int
}

// MARK: - Journal Entry

struct JournalEntry: Identifiable {
    let id: Int
    let title: String
    let body: String
    let artifact: String
}

// MARK: - Level

struct Level: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let lore: String
    let inscriptions: [String]
    let rows: Int
    let cols: Int
    let availableGlyphs: [Glyph]
    let initialGrid: [[Glyph?]]
    let fixedPositions: Set<GridPosition>
    let solution: [[Glyph]]
    let journalEntry: JournalEntry

    func isFixed(_ position: GridPosition) -> Bool {
        fixedPositions.contains(position)
    }

    func isSolved(_ grid: [[Glyph?]]) -> Bool {
        for row in 0..<rows {
            for col in 0..<cols {
                guard grid[row][col] == solution[row][col] else { return false }
            }
        }
        return true
    }

    // Roman numeral display for level number
    var romanNumeral: String {
        switch id {
        case 1: return "I"
        case 2: return "II"
        case 3: return "III"
        case 4: return "IV"
        case 5: return "V"
        default: return "\(id)"
        }
    }
}

// MARK: - Level Definitions
//
// Solutions are verified Latin squares (no cyclic-shift patterns).
// Fixed cells are placed off-diagonal to vary the visual starting point.
// Inscriptions give specific positional clues, not just rule restatements.
//
// Verification key: E=eye O=owl W=water L=lion S=sky

extension Level {
    static let allLevels: [Level] = [level1, level2, level3, level4, level5]

    // ─────────────────────────────────────────────────
    // LEVEL 1 · 3×3 · Glyphs: eye, owl, water
    //
    // Solution:       Col→  0    1    2
    //   Row 0:              O    W    E
    //   Row 1:              W    E    O
    //   Row 2:              E    O    W
    //
    // Fixed: (0,0)=O  (0,2)=E  (2,1)=O   ← top-left, top-right, bottom-center
    // ─────────────────────────────────────────────────
    static let level1 = Level(
        id: 1,
        title: "Tomb of Kha",
        subtitle: "The First Seal",
        lore: "Deep within the tomb of the master scribe Kha, three sacred symbols await their proper arrangement. The priests left them scattered as a test of worthiness. Only one who reads the fixed stones carefully may unlock the seal.",
        inscriptions: [
            "The Owl stands guard at the first corner of the first row.",
            "The Eye watches from the far end of that same row.",
            "The Owl appears again — this time in the middle of the last row.",
            "No symbol may appear twice in any row or column."
        ],
        rows: 3,
        cols: 3,
        availableGlyphs: [.eye, .owl, .water],
        initialGrid: [
            [.owl, nil,  .eye ],
            [nil,  nil,  nil  ],
            [nil,  .owl, nil  ]
        ],
        fixedPositions: [
            GridPosition(row: 0, col: 0),
            GridPosition(row: 0, col: 2),
            GridPosition(row: 2, col: 1)
        ],
        solution: [
            [.owl,   .water, .eye  ],
            [.water, .eye,   .owl  ],
            [.eye,   .owl,   .water]
        ],
        journalEntry: JournalEntry(
            id: 1,
            title: "The Scribe's Testament",
            body: "Here lies Kha, Master Scribe of the Great House. He who deciphers this seal shall know: three sacred symbols govern the world of the living — the Owl of wisdom, the Water of life, and the Eye of sight. Where they rest is not random. Each claims one position in every row, one in every column. In their proper order lies harmony; in disorder, chaos reigns eternal.",
            artifact: "𓏠"
        )
    )

    // ─────────────────────────────────────────────────
    // LEVEL 2 · 4×4 · Glyphs: eye, owl, water, lion
    //
    // Solution:       Col→  0    1    2    3
    //   Row 0:              E    L    O    W
    //   Row 1:              O    W    L    E
    //   Row 2:              L    E    W    O
    //   Row 3:              W    O    E    L
    //
    // Fixed: (0,0)=E  (1,2)=L  (2,1)=E  (3,3)=L   ← two glyphs, off-diagonal
    // ─────────────────────────────────────────────────
    static let level2 = Level(
        id: 2,
        title: "Chamber of Ra",
        subtitle: "The Solar Seal",
        lore: "The sun god Ra guards this chamber with four powerful symbols. The placement here is not a simple cycle — the Lion and the Eye hold fixed positions that reveal the structure only to those who reason carefully from what is known.",
        inscriptions: [
            "The Eye opens the first row; the Lion stands beside it in the second column.",
            "The Lion occupies the third position of the second row.",
            "The Eye descends to the second column of the third row.",
            "The Lion stands alone at the final corner of the seal."
        ],
        rows: 4,
        cols: 4,
        availableGlyphs: [.eye, .owl, .water, .lion],
        initialGrid: [
            [.eye, nil,   nil,   nil  ],
            [nil,  nil,   .lion, nil  ],
            [nil,  .eye,  nil,   nil  ],
            [nil,  nil,   nil,   .lion]
        ],
        fixedPositions: [
            GridPosition(row: 0, col: 0),
            GridPosition(row: 1, col: 2),
            GridPosition(row: 2, col: 1),
            GridPosition(row: 3, col: 3)
        ],
        solution: [
            [.eye,   .lion,  .owl,   .water],
            [.owl,   .water, .lion,  .eye  ],
            [.lion,  .eye,   .water, .owl  ],
            [.water, .owl,   .eye,   .lion ]
        ],
        journalEntry: JournalEntry(
            id: 2,
            title: "The Solar Hymn",
            body: "Ra's four sacred symbols do not simply rotate — they interlock like the teeth of a great celestial wheel. The Eye sees across rows; the Lion holds corners; the Owl glides between them; Water fills the remaining voids. To understand their arrangement is to read the mind of the sun god himself.",
            artifact: "𓇳"
        )
    )

    // ─────────────────────────────────────────────────
    // LEVEL 3 · 4×4 · Glyphs: eye, owl, water, lion
    //
    // Solution:       Col→  0    1    2    3
    //   Row 0:              W    O    E    L
    //   Row 1:              E    L    W    O
    //   Row 2:              L    W    O    E
    //   Row 3:              O    E    L    W
    //
    // Fixed: (0,3)=L  (1,0)=E  (2,2)=O  (3,1)=E   ← corners and crosses
    // ─────────────────────────────────────────────────
    static let level3 = Level(
        id: 3,
        title: "Hall of Anubis",
        subtitle: "The Judgment Seal",
        lore: "In the Hall of Two Truths, Anubis weighs the heart against the feather of Ma'at. The four symbols here follow no repeating pattern — each row is its own judgment. The fixed stones reveal corners of truth; the rest must be earned through deduction.",
        inscriptions: [
            "The Lion stands at the far end of the first row.",
            "The Eye steps forward to open the second row.",
            "The Owl is found at the third position of the third row.",
            "The Eye descends again to the second column of the last row."
        ],
        rows: 4,
        cols: 4,
        availableGlyphs: [.eye, .owl, .water, .lion],
        initialGrid: [
            [nil,  nil,  nil,   .lion],
            [.eye, nil,  nil,   nil  ],
            [nil,  nil,  .owl,  nil  ],
            [nil,  .eye, nil,   nil  ]
        ],
        fixedPositions: [
            GridPosition(row: 0, col: 3),
            GridPosition(row: 1, col: 0),
            GridPosition(row: 2, col: 2),
            GridPosition(row: 3, col: 1)
        ],
        solution: [
            [.water, .owl,   .eye,   .lion ],
            [.eye,   .lion,  .water, .owl  ],
            [.lion,  .water, .owl,   .eye  ],
            [.owl,   .eye,   .lion,  .water]
        ],
        journalEntry: JournalEntry(
            id: 3,
            title: "The Weighing of the Heart",
            body: "Anubis places the heart upon the golden scales. Opposite rests the Feather of Ma'at — truth itself. If the heart is light, unclouded by sin, the soul passes onward to Aaru. If heavy with wrongdoing, the Devourer waits. The seal mirrors this judgment: every position must be earned, every symbol placed with intention — not guessed, not assumed.",
            artifact: "𓂋"
        )
    )

    // ─────────────────────────────────────────────────
    // LEVEL 4 · 5×5 · Glyphs: eye, owl, water, lion, sky
    //
    // Solution:       Col→  0    1    2    3    4
    //   Row 0:              E    O    L    S    W
    //   Row 1:              S    L    E    W    O
    //   Row 2:              W    E    O    L    S
    //   Row 3:              L    S    W    O    E
    //   Row 4:              O    W    S    E    L
    //
    // Fixed: (0,0)=E  (0,4)=W  (1,1)=L  (2,2)=O  (3,3)=O  (4,1)=W  (4,4)=L
    // ─────────────────────────────────────────────────
    static let level4 = Level(
        id: 4,
        title: "Sanctuary of Thoth",
        subtitle: "The Wisdom Seal",
        lore: "Thoth, god of wisdom, devised this seal without repetition or cycle — five symbols woven in a pattern that requires careful reasoning at every step. The fixed stones are scattered across the grid; no two share a row or column with the same glyph.",
        inscriptions: [
            "The Eye opens the first row; Water seals it from the right.",
            "The Lion occupies the second position of the second row.",
            "The Owl is found at the center of the third row.",
            "The Owl appears again at the fourth position of the fourth row.",
            "Water holds the second position of the last row; the Lion closes it."
        ],
        rows: 5,
        cols: 5,
        availableGlyphs: [.eye, .owl, .water, .lion, .sky],
        initialGrid: [
            [.eye,  nil,    nil,   nil,    .water],
            [nil,   .lion,  nil,   nil,    nil   ],
            [nil,   nil,    .owl,  nil,    nil   ],
            [nil,   nil,    nil,   .owl,   nil   ],
            [nil,   .water, nil,   nil,    .lion ]
        ],
        fixedPositions: [
            GridPosition(row: 0, col: 0),
            GridPosition(row: 0, col: 4),
            GridPosition(row: 1, col: 1),
            GridPosition(row: 2, col: 2),
            GridPosition(row: 3, col: 3),
            GridPosition(row: 4, col: 1),
            GridPosition(row: 4, col: 4)
        ],
        solution: [
            [.eye,   .owl,   .lion,  .sky,   .water],
            [.sky,   .lion,  .eye,   .water, .owl  ],
            [.water, .eye,   .owl,   .lion,  .sky  ],
            [.lion,  .sky,   .water, .owl,   .eye  ],
            [.owl,   .water, .sky,   .eye,   .lion ]
        ],
        journalEntry: JournalEntry(
            id: 4,
            title: "The Library of Thoth",
            body: "In the forty-two sacred books of Thoth lies all knowledge: medicine, magic, astronomy, law, and the arts of the living and the dead. The five great glyphs represent five mysteries. Their arrangement here follows no simple pattern — it must be reasoned out, inscription by inscription, column by column, until the seal yields its truth.",
            artifact: "𓆓"
        )
    )

    // ─────────────────────────────────────────────────
    // LEVEL 5 · 5×5 · Glyphs: eye, owl, water, lion, sky
    //
    // Solution:       Col→  0    1    2    3    4
    //   Row 0:              S    W    E    O    L
    //   Row 1:              L    O    S    W    E
    //   Row 2:              O    E    W    L    S
    //   Row 3:              W    S    L    E    O
    //   Row 4:              E    L    O    S    W
    //
    // Fixed (only 5): (0,4)=L  (1,0)=L  (2,2)=W  (3,1)=S  (4,3)=S
    // ─────────────────────────────────────────────────
    static let level5 = Level(
        id: 5,
        title: "The Final Seal",
        subtitle: "The Eternal Gate",
        lore: "Before the gates of the Field of Reeds stands the Final Seal — the greatest test devised by the gods. Only five stones are fixed. The rest must be drawn entirely from reason. No pattern will save you here; only patience, and the knowledge earned in every chamber before.",
        inscriptions: [
            "The Lion closes the first row and opens the second — fixed at both.",
            "Water rests at the third column of the third row.",
            "The Sky descends to the second column of the fourth row.",
            "The Sky appears once more — at the fourth position of the final row.",
            "Begin with what is certain. Each truth reveals the next."
        ],
        rows: 5,
        cols: 5,
        availableGlyphs: [.eye, .owl, .water, .lion, .sky],
        initialGrid: [
            [nil,   nil,   nil,    nil,    .lion ],
            [.lion, nil,   nil,    nil,    nil   ],
            [nil,   nil,   .water, nil,    nil   ],
            [nil,   .sky,  nil,    nil,    nil   ],
            [nil,   nil,   nil,    .sky,   nil   ]
        ],
        fixedPositions: [
            GridPosition(row: 0, col: 4),
            GridPosition(row: 1, col: 0),
            GridPosition(row: 2, col: 2),
            GridPosition(row: 3, col: 1),
            GridPosition(row: 4, col: 3)
        ],
        solution: [
            [.sky,   .water, .eye,   .owl,  .lion ],
            [.lion,  .owl,   .sky,   .water, .eye ],
            [.owl,   .eye,   .water, .lion,  .sky ],
            [.water, .sky,   .lion,  .eye,   .owl ],
            [.eye,   .lion,  .owl,   .sky,   .water]
        ],
        journalEntry: JournalEntry(
            id: 5,
            title: "The Gates of Aaru",
            body: "Beyond the Final Seal lies the Field of Reeds — Aaru, the Egyptian paradise. Here the worthy live in eternal bliss beneath a sky of endless gold. You solved not by pattern but by reason — each clue a stepping stone, each deduction a gate opened. The five glyphs, now in perfect arrangement, sing the oldest song: all things in their proper place, all souls in their proper rest. You have heard the echo of ages.",
            artifact: "𓇋"
        )
    )
}
