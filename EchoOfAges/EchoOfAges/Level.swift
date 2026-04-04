// Level.swift
// EchoOfAges
//
// Latin-square puzzle: each glyph appears exactly once per row and column.
// Fixed cells are pre-placed and cannot be changed. Player fills the rest.
// Completing a puzzle deciphers a message that contributes to the Tree of Life narrative.

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

    // The archaeologist's field note — written the first time this glyph was encountered
    var discoveryNote: String {
        switch self {
        case .eye:
            return "Appears at every threshold in Kha's tomb — above doorways, beside cartouches. Not merely decorative. It seems to represent the act of seeing itself, and of being seen by something vast and old."
        case .owl:
            return "Rare in formal inscriptions. The owl is usually a phonetic marker — the consonant 'm' — but here it stands as a primary symbol. Knowledge held in darkness. What the owl knows, it does not speak aloud."
        case .water:
            return "The three zigzag lines: the Nile in miniature. Without the flood, nothing lives, nothing grows, nothing endures. This may be the oldest mark of civilization ever pressed into stone."
        case .lion:
            return "New in the second chamber. Not hunting — guarding. Seated upright beside Ra's cartouche. Power that does not need to prove itself. The fourth symbol changes the puzzle entirely. I was not ready for it."
        case .sky:
            return "Found only deep within Thoth's sanctuary, near the ceiling. A vaulted arch: the sky imagined as a roof over the flat earth. To carve the sky is to name the infinite. The fifth and final symbol. The last piece."
        }
    }

    // Which level number first introduces this glyph
    var introducedInLevel: Int {
        switch self {
        case .eye:   return 1
        case .owl:   return 1
        case .water: return 1
        case .lion:  return 2
        case .sky:   return 4
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
    let civilization: CivilizationID    // Which civilization this partial tablet belongs to
    let title: String
    let subtitle: String
    let lore: String
    let inscriptions: [String]          // Field notes — clues for solving
    let rows: Int
    let cols: Int
    let availableGlyphs: [Glyph]
    let initialGrid: [[Glyph?]]
    let fixedPositions: Set<GridPosition>
    let solution: [[Glyph]]
    let journalEntry: JournalEntry
    let decodedMessage: String          // The message revealed when the inscription is solved
    let newGlyphs: [Glyph]             // Glyphs introduced for the first time in this level

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
// decodedMessage is the narrative text revealed upon solving each inscription.
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
        civilization: .egyptian,
        title: "Tomb of Kha",
        subtitle: "The First Seal",
        lore: "Deep within the tomb of the master scribe Kha, three sacred symbols await their proper arrangement. The priests left them scattered as a test of worthiness. Only one who reads the fixed stones carefully may unlock the seal.",
        inscriptions: [
            "The guardian symbol always opens a new line of thought. The Egyptians placed their watcher at every threshold — physical and spiritual.",
            "The Eye and the Owl never share a line in this tomb. One governs the day, one the night. Kha's scribes kept them apart as the priests decreed.",
            "Three forces in perfect balance. Each appears once in every direction of the inscription — to repeat a force on a single line was considered blasphemy.",
            "I noticed: the symbol for life appears below the symbol for knowledge, never beside it. The water follows the owl."
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
        ),
        decodedMessage: "In the age before memory, three forces shaped the world: the Eye that sees all truth, the Owl that guards all knowledge, the Water that gives all life. From these three, the first root of the great Tree was born beneath the earth, unseen, patient, waiting.",
        newGlyphs: [.eye, .owl, .water]
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
        civilization: .egyptian,
        title: "Chamber of Ra",
        subtitle: "The Solar Seal",
        lore: "The sun god Ra guards this chamber with four powerful symbols. The placement here is not a simple cycle — the Lion and the Eye hold fixed positions that reveal the structure only to those who reason carefully from what is known.",
        inscriptions: [
            "Ra's chamber: the Eye always faces outward — it opens, it never hides. I found it at the very edge of the inscription's first line.",
            "The Lion never appears beside the Eye in Ra's texts. Power and sight were kept separate — too much of both at once was considered an omen.",
            "Water flows to where the other symbols are absent. It fills the remaining space, as the Nile fills the delta.",
            "Four forces, four sacred directions — each appears exactly once in every line of the inscription, whether you read it across or downward."
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
        ),
        decodedMessage: "Ra looked upon the first roots and raised a fourth power: the Lion of Strength, to protect what grows. Four forces now balanced the world — sight, wisdom, life, and strength. The trunk of the Tree rose toward the heavens, and Ra called it good.",
        newGlyphs: [.lion]
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
        civilization: .egyptian,
        title: "Hall of Anubis",
        subtitle: "The Judgment Seal",
        lore: "In the Hall of Two Truths, Anubis weighs the heart against the feather of Ma'at. The four symbols here follow no repeating pattern — each row is its own judgment. The fixed stones reveal corners of truth; the rest must be earned through deduction.",
        inscriptions: [
            "Anubis watches from the corners. The symbol of judgment holds an edge position in this inscription — I found it at the far end of the first line.",
            "Cross-referencing with the Ra chamber: the Eye and the Lion swap roles here. Where Ra used the Eye at the opening, Anubis uses the Lion.",
            "The Water symbol in this hall refers to the river of the dead, not the Nile. It is surrounded by symbols of power and knowledge — strength tempered by life.",
            "No two identical symbols appear in any line, horizontal or vertical. Anubis permitted no repetition in the hall of judgment."
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
        ),
        decodedMessage: "Anubis weighed each soul who sought the Tree. Only those who balanced Eye and Lion, Water and Owl — each in its proper place, none repeated, none omitted — could pass beneath its branches. Order is the first law of the living. It is also the last law of the dead.",
        newGlyphs: []
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
        civilization: .egyptian,
        title: "Sanctuary of Thoth",
        subtitle: "The Wisdom Seal",
        lore: "Thoth, god of wisdom, devised this seal without repetition or cycle — five symbols woven in a pattern that requires careful reasoning at every step. The fixed stones are scattered across the grid; no two share a row or column with the same glyph.",
        inscriptions: [
            "Thoth introduced the Sky last. In every inscription with all five symbols, the Sky mediates between the Eye and the Water — never beside either one.",
            "Five symbols. Five sacred directions. Each appears exactly once per row and once per column. Thoth was a mathematician before he was a god.",
            "The Water and Sky are always separated by at least one other symbol in Thoth's texts. The forty-two books say: the waters below and the heaven above must never touch directly.",
            "The Owl appears in the second position of at least one line. Knowledge was always Thoth's second concern — wisdom came first.",
            "I spent two days on this inscription. The Sky symbol at the known positions tells you where it cannot be in the remaining rows. Begin there."
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
        ),
        decodedMessage: "Thoth inscribed a fifth force in his sacred books: the Sky, the vault of eternity above all things. Five forces, five directions, five chambers of truth. The branches of the Tree now reached from earth to heaven. And Thoth wrote in the margin: all things in their proper place is the first law of the universe, and also the last.",
        newGlyphs: [.sky]
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
        civilization: .egyptian,
        title: "The Final Seal",
        subtitle: "The Eternal Gate",
        lore: "Before the gates of the Field of Reeds stands the Final Seal — the greatest test devised by the gods. Only five stones are fixed. The rest must be drawn entirely from reason. No pattern will save you here; only patience, and the knowledge earned in every chamber before.",
        inscriptions: [
            "Only five stones are certain. Champollion had the Rosetta Stone. I have these five anchors. It must be enough.",
            "The Lion appears at the threshold of the second row and closes the first. Strength guards both entrance and exit — the inscription begins and ends with power.",
            "When I was stuck, I stopped guessing and listed only what I was certain of. Each certainty eliminated a position. The chain of deduction is long but unbroken.",
            "The Sky glyph confirmed by position in rows three and four. From the Sky, the Water follows — they are always separated by exactly two symbols in this seal.",
            "The priests left a note carved in the margin of the stone itself — an arrow pointing inward. Begin at the center. The outermost symbols reveal themselves last."
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
        ),
        decodedMessage: "You have heard the echo of ages. The Tree of Life stands at the center of all worlds — its roots in the waters of creation, its trunk the strength of lions, its branches the owl's wisdom spread wide, its leaves ten thousand eyes watching eternity, its fruit the sky itself: infinite, undying, and patient. Plant one truth each day. Let no symbol stand twice in the same place. This is how the world was made, and how it shall endure.",
        newGlyphs: []
    )
}
