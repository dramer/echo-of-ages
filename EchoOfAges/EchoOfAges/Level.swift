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

extension Level {
    static let allLevels: [Level] = [level1, level2, level3, level4, level5]

    // ─────────────────────────────────────────────────
    // LEVEL 1 · 3×3 · Glyphs: eye, owl, water
    // Solution:
    //   E O W
    //   O W E
    //   W E O
    // ─────────────────────────────────────────────────
    static let level1 = Level(
        id: 1,
        title: "Tomb of Kha",
        subtitle: "The First Seal",
        lore: "Deep within the tomb of the master scribe Kha, three sacred symbols await their proper arrangement. The priests left them scattered as a test of worthiness. Only one who understands the ancient order may pass.",
        inscriptions: [
            "Each symbol appears exactly once in every row.",
            "Each symbol appears exactly once in every column.",
            "The Eye watches from the first corner — fixed and unyielding."
        ],
        rows: 3,
        cols: 3,
        availableGlyphs: [.eye, .owl, .water],
        initialGrid: [
            [.eye,  nil,    nil   ],
            [nil,   .water, nil   ],
            [nil,   nil,    .owl  ]
        ],
        fixedPositions: [
            GridPosition(row: 0, col: 0),
            GridPosition(row: 1, col: 1),
            GridPosition(row: 2, col: 2)
        ],
        solution: [
            [.eye,   .owl,   .water],
            [.owl,   .water, .eye  ],
            [.water, .eye,   .owl  ]
        ],
        journalEntry: JournalEntry(
            id: 1,
            title: "The Scribe's Testament",
            body: "Here lies Kha, Master Scribe of the Great House. He who deciphers this seal shall know: three sacred symbols govern the world of the living — the Eye of sight, the Owl of wisdom, and the Water of life. In their proper order lies harmony; in disorder, chaos reigns eternal.",
            artifact: "𓏠"
        )
    )

    // ─────────────────────────────────────────────────
    // LEVEL 2 · 4×4 · Glyphs: eye, owl, water, lion
    // Solution:
    //   E O W L
    //   O W L E
    //   W L E O
    //   L E O W
    // ─────────────────────────────────────────────────
    static let level2 = Level(
        id: 2,
        title: "Chamber of Ra",
        subtitle: "The Solar Seal",
        lore: "The sun god Ra guards this chamber with four powerful symbols. The Lion stands at corners opposite the Eye, the Water flows where the Owl cannot follow. Four symbols, four positions — the solar order must be maintained across all rows and columns.",
        inscriptions: [
            "The Eye and the Lion anchor opposite corners of the first row.",
            "No symbol repeats in any row or column.",
            "The Water flows in the corner where the Eye began — in the final row."
        ],
        rows: 4,
        cols: 4,
        availableGlyphs: [.eye, .owl, .water, .lion],
        initialGrid: [
            [.eye,  nil,    nil,   .lion ],
            [nil,   .water, nil,   nil   ],
            [nil,   nil,    .eye,  nil   ],
            [.lion, nil,    nil,   .water]
        ],
        fixedPositions: [
            GridPosition(row: 0, col: 0),
            GridPosition(row: 0, col: 3),
            GridPosition(row: 1, col: 1),
            GridPosition(row: 2, col: 2),
            GridPosition(row: 3, col: 0),
            GridPosition(row: 3, col: 3)
        ],
        solution: [
            [.eye,   .owl,   .water, .lion ],
            [.owl,   .water, .lion,  .eye  ],
            [.water, .lion,  .eye,   .owl  ],
            [.lion,  .eye,   .owl,   .water]
        ],
        journalEntry: JournalEntry(
            id: 2,
            title: "The Solar Hymn",
            body: "Ra rises as the Eye in the East, travels as the Owl through the sky, descends as Water into the Duat, and is reborn as the Lion of dawn. This cycle — repeated in the seal — mirrors the eternal journey of the sun. To know the cycle is to know eternity itself.",
            artifact: "𓇳"
        )
    )

    // ─────────────────────────────────────────────────
    // LEVEL 3 · 4×4 · Glyphs: eye, owl, water, lion
    // Solution:
    //   W L E O
    //   E O W L
    //   L W O E
    //   O E L W
    // ─────────────────────────────────────────────────
    static let level3 = Level(
        id: 3,
        title: "Hall of Anubis",
        subtitle: "The Judgment Seal",
        lore: "In the Hall of Two Truths, Anubis weighs the heart against the feather of Ma'at. Here, four symbols must be arranged with absolute precision — for Anubis tolerates no error in judgment. The dead cannot lie, and neither can the seal.",
        inscriptions: [
            "Water flows in the first corner of the first row.",
            "The Owl watches the diagonal — it rests in the second and third positions.",
            "Each row holds all four symbols exactly once, without exception."
        ],
        rows: 4,
        cols: 4,
        availableGlyphs: [.eye, .owl, .water, .lion],
        initialGrid: [
            [.water, nil,  nil,  nil   ],
            [nil,    .owl, nil,  nil   ],
            [nil,    nil,  .owl, nil   ],
            [nil,    nil,  nil,  .water]
        ],
        fixedPositions: [
            GridPosition(row: 0, col: 0),
            GridPosition(row: 1, col: 1),
            GridPosition(row: 2, col: 2),
            GridPosition(row: 3, col: 3)
        ],
        solution: [
            [.water, .lion, .eye,  .owl  ],
            [.eye,   .owl,  .water, .lion],
            [.lion,  .water, .owl, .eye  ],
            [.owl,   .eye,  .lion, .water]
        ],
        journalEntry: JournalEntry(
            id: 3,
            title: "The Weighing of the Heart",
            body: "Anubis places the heart upon the golden scales. Opposite rests the Feather of Ma'at — truth itself. If the heart is light, unclouded by sin, the soul passes onward to Aaru. If heavy with wrongdoing, the Devourer waits. The seal mirrors this judgment: every position must be earned, every symbol placed with intention.",
            artifact: "𓂋"
        )
    )

    // ─────────────────────────────────────────────────
    // LEVEL 4 · 5×5 · Glyphs: eye, owl, water, lion, sky
    // Solution (cyclic shift):
    //   E O W L S
    //   O W L S E
    //   W L S E O
    //   L S E O W
    //   S E O W L
    // ─────────────────────────────────────────────────
    static let level4 = Level(
        id: 4,
        title: "Sanctuary of Thoth",
        subtitle: "The Wisdom Seal",
        lore: "Thoth, god of wisdom and the keeper of sacred writing, devised this seal to guard his library of forty-two books. Five symbols flow in a perfect pattern — each row a single step forward in the sacred cycle. To read the pattern is to understand the mind of Thoth himself.",
        inscriptions: [
            "The Eye begins in the first corner.",
            "The Sky appears at the end of the first row and the start of the last.",
            "Each row shifts one step forward in the sacred order.",
            "Five symbols — five rows — five columns. The pattern is absolute."
        ],
        rows: 5,
        cols: 5,
        availableGlyphs: [.eye, .owl, .water, .lion, .sky],
        initialGrid: [
            [.eye,  nil,    nil,   nil,   .sky  ],
            [nil,   .water, nil,   nil,   nil   ],
            [nil,   nil,    .sky,  nil,   nil   ],
            [nil,   nil,    nil,   .owl,  nil   ],
            [.sky,  nil,    nil,   nil,   .lion ]
        ],
        fixedPositions: [
            GridPosition(row: 0, col: 0),
            GridPosition(row: 0, col: 4),
            GridPosition(row: 1, col: 1),
            GridPosition(row: 2, col: 2),
            GridPosition(row: 3, col: 3),
            GridPosition(row: 4, col: 0),
            GridPosition(row: 4, col: 4)
        ],
        solution: [
            [.eye,   .owl,   .water, .lion,  .sky  ],
            [.owl,   .water, .lion,  .sky,   .eye  ],
            [.water, .lion,  .sky,   .eye,   .owl  ],
            [.lion,  .sky,   .eye,   .owl,   .water],
            [.sky,   .eye,   .owl,   .water, .lion ]
        ],
        journalEntry: JournalEntry(
            id: 4,
            title: "The Library of Thoth",
            body: "In the forty-two sacred books of Thoth lies all knowledge: medicine, magic, astronomy, law, and the arts of the living and the dead. The five great glyphs represent five mysteries. Only by understanding their cyclic relationship — how each flows inevitably into the next — can one claim to have touched true wisdom.",
            artifact: "𓆓"
        )
    )

    // ─────────────────────────────────────────────────
    // LEVEL 5 · 5×5 · Glyphs: eye, owl, water, lion, sky
    // Solution:
    //   S W E O L
    //   O L S W E
    //   W E O L S
    //   L S W E O
    //   E O L S W
    // ─────────────────────────────────────────────────
    static let level5 = Level(
        id: 5,
        title: "The Final Seal",
        subtitle: "The Eternal Gate",
        lore: "Before the gates of the Field of Reeds stands the Final Seal — the greatest test devised by the gods themselves. Five symbols in perfect harmony, arranged by no simple cycle. Only one who has learned from all previous chambers will read the pattern hidden within.",
        inscriptions: [
            "The Sky opens the first gate — it holds the first position.",
            "In the second row, Water rests in the fourth place.",
            "The Eye observes from the second column of the third row.",
            "Patience reveals what force cannot — every symbol belongs somewhere."
        ],
        rows: 5,
        cols: 5,
        availableGlyphs: [.eye, .owl, .water, .lion, .sky],
        initialGrid: [
            [.sky,  nil,   nil,    nil,    nil  ],
            [nil,   nil,   nil,    .water, nil  ],
            [nil,   .eye,  nil,    nil,    nil  ],
            [nil,   nil,   nil,    nil,    .owl ],
            [nil,   nil,   nil,    nil,    .water]
        ],
        fixedPositions: [
            GridPosition(row: 0, col: 0),
            GridPosition(row: 1, col: 3),
            GridPosition(row: 2, col: 1),
            GridPosition(row: 3, col: 4),
            GridPosition(row: 4, col: 4)
        ],
        solution: [
            [.sky,   .water, .eye,   .owl,  .lion ],
            [.owl,   .lion,  .sky,   .water, .eye ],
            [.water, .eye,   .owl,   .lion,  .sky ],
            [.lion,  .sky,   .water, .eye,   .owl ],
            [.eye,   .owl,   .lion,  .sky,   .water]
        ],
        journalEntry: JournalEntry(
            id: 5,
            title: "The Gates of Aaru",
            body: "Beyond the Final Seal lies the Field of Reeds — Aaru, the Egyptian paradise. Here the worthy live in eternal bliss, farming fertile land that stretches beyond sight beneath a sky of endless gold. The five glyphs, now in perfect arrangement, sing the oldest song: all things in their proper place, all souls in their proper rest. You have heard the echo of ages.",
            artifact: "𓇋"
        )
    )
}
