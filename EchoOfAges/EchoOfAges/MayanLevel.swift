// MayanLevel.swift
// EchoOfAges
//
// Calendar pattern puzzles for the Maya civilization.
//
// Mechanic: Each puzzle shows one or more independent symbol cycles (rows).
// Each cycle is a repeating sequence of Maya glyphs. Some positions in each
// row are pre-revealed as anchors; the player fills in the blanks by
// identifying the underlying repeating rhythm.
//
// Level progression:
//   L1 — 1 cycle, period 5, 2 blanks   (pure pattern recognition)
//   L2 — 2 cycles, periods 3+2, 6 blanks (two independent rhythms)
//   L3 — 2 cycles, periods 4+3, 8 blanks (longer periods, interleaved reveals)
//   L4 — 2 cycles, offset starts, 7 blanks (arrive mid-cycle, deduce offset)
//   L5 — 3 cycles, periods 3+4+5, 11 blanks (the full Calendar Round)

import Foundation

// MARK: - MayanGlyph

enum MayanGlyph: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case kin   = "𝋡"   // Sun / Day
    case haab  = "𝋢"   // Year
    case tzolk = "𝋣"   // Sacred Round
    case imix  = "𝋠"   // Earth / Crocodile
    case ik    = "𝋤"   // Wind / Breath

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kin:   return "KIN"
        case .haab:  return "HAAB"
        case .tzolk: return "TZʼ"
        case .imix:  return "IMIX"
        case .ik:    return "IK"
        }
    }

    var meaning: String {
        switch self {
        case .kin:   return "Sun · Day"
        case .haab:  return "Year"
        case .tzolk: return "Sacred Round"
        case .imix:  return "Earth · Crocodile"
        case .ik:    return "Wind · Breath"
        }
    }

    /// SF Symbol name used to render this glyph in the wheel cells and palette.
    /// The Mayan Numeral Unicode block (U+1D2E0–) is not in the iOS system font.
    var sfSymbol: String {
        switch self {
        case .kin:   return "sun.max.fill"
        case .haab:  return "calendar.circle.fill"
        case .tzolk: return "asterisk.circle.fill"
        case .imix:  return "globe.americas.fill"
        case .ik:    return "wind"
        }
    }

    var discoveryNote: String {
        switch self {
        case .kin:
            return "KIN — the sun, the basic unit of Maya time. A single day. The Maya tracked the sun with extraordinary precision across centuries of patient sky-watching, without telescopes, without instruments beyond their own eyes and memory."
        case .haab:
            return "HAAB — the solar year, 365 days divided into 18 months of 20 days each, plus 5 nameless days at the end. The Wayeb' — the five unnamed days — were considered dangerous. Time held its breath."
        case .tzolk:
            return "TZʼOLKIN — the 260-day sacred calendar. 13 numbers cycling through 20 day-names simultaneously. No one knows with certainty why 260 days. Some say it matches the human gestation period. Some say it tracks the appearance of Venus. The Maya said: this is how the world breathes."
        case .imix:
            return "IMIX — the earth, the crocodile, the first day of the sacred round. In Maya cosmology the earth itself floats on the back of a great crocodile in the primordial sea. Every calendar begins with IMIX. Every world begins with earth."
        case .ik:
            return "IK — wind, breath, the second day of the sacred round. The Maya World Tree — Wakah-Chan — was said to breathe. IK is that breath. It is both the wind that moves the world and the breath inside the chest of every living thing."
        }
    }
}

// MARK: - MayanCycle

struct MayanCycle {
    /// Human-readable label shown at the start of the row (e.g. "First Wheel")
    let label: String
    /// The repeating symbol sequence for this cycle
    let symbols: [MayanGlyph]
    /// How far into the cycle position 0 begins (for mid-cycle puzzles)
    let startOffset: Int
    /// Positions pre-revealed to the player as anchor points
    let revealedPositions: Set<Int>

    /// The correct glyph for a given sequence position
    func symbol(at position: Int) -> MayanGlyph {
        symbols[(position + startOffset) % symbols.count]
    }

    func isRevealed(_ position: Int) -> Bool {
        revealedPositions.contains(position)
    }
}

// MARK: - MayanCellCoord

struct MayanCellCoord: Hashable {
    let cycle: Int
    let position: Int
}

// MARK: - MayanLevel

struct MayanLevel: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let lore: String
    let inscriptions: [String]
    let cycles: [MayanCycle]
    let sequenceLength: Int
    let decodedMessage: String
    let newGlyphs: [MayanGlyph]
    let artifact: String
    let journalTitle: String
    let journalBody: String

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

    /// Check whether the player's grid is fully and correctly filled.
    /// playerGrid[cycleIndex][position] — nil means blank/unfilled.
    func isSolved(_ playerGrid: [[MayanGlyph?]]) -> Bool {
        guard playerGrid.count == cycles.count else { return false }
        for (ci, cycle) in cycles.enumerated() {
            guard playerGrid[ci].count == sequenceLength else { return false }
            for pos in 0..<sequenceLength where !cycle.isRevealed(pos) {
                guard playerGrid[ci][pos] == cycle.symbol(at: pos) else { return false }
            }
        }
        return true
    }

    /// Returns the set of incorrectly filled (non-empty, non-anchor) cells.
    func incorrectCells(_ playerGrid: [[MayanGlyph?]]) -> Set<MayanCellCoord> {
        var wrong = Set<MayanCellCoord>()
        guard playerGrid.count == cycles.count else { return wrong }
        for (ci, cycle) in cycles.enumerated() {
            for pos in 0..<sequenceLength where !cycle.isRevealed(pos) {
                if let placed = playerGrid[ci][pos], placed != cycle.symbol(at: pos) {
                    wrong.insert(MayanCellCoord(cycle: ci, position: pos))
                }
            }
        }
        return wrong
    }
}

// MARK: - Level Definitions

extension MayanLevel {
    static let allLevels: [MayanLevel] = [level1, level2, level3, level4, level5]

    // ─────────────────────────────────────────────────────────────────────
    // LEVEL 1 · 1 cycle · period 5 · 2 blanks
    //
    // Cycle A: [KIN, IMIX, IK, TZʼ, HAAB]  offset=0
    // Sequence (length 10):
    //   0:KIN  1:IMIX  2:IK  3:TZʼ  4:HAAB  5:KIN  6:IMIX  7:IK  8:TZʼ  9:HAAB
    // Revealed: {0,1,2,3,4,5,7,8}  Blanks: {6→IMIX, 9→HAAB}
    // ─────────────────────────────────────────────────────────────────────
    static let level1 = MayanLevel(
        id: 1,
        title: "Tablet of the First Sunrise",
        subtitle: "The Wheel Begins",
        lore: "The first Maya calendar tablet. A single cycle of five sacred glyphs — KIN the sun, IMIX the earth, IK the wind, TZʼ the sacred round, HAAB the year — repeating without end. The first full cycle is shown to you. Continue it.",
        inscriptions: [
            "Wheels, not rivers — the Maya did not think of time as a river flowing from past to future. They thought of it as a wheel turning. Five signs repeat in fixed order: KIN, IMIX, IK, TZʼ, HAAB. The first full cycle is already shown. Continue it.",
            "The sequence is already familiar by position five. You have seen KIN, IMIX, IK, TZʼ, HAAB. Now the wheel turns again. What comes after KIN the second time? The same thing that came after KIN the first time.",
            "Fill the two blank positions. Look at where each blank sits in the cycle. Count from the beginning — what position are they? The cycle has five steps. A blank at position six is the same as position one.",
            "I recognised the rhythm before I found the blanks. That is how the Maya intended it. Feel the pattern first. The blanks fill themselves."
        ],
        cycles: [
            MayanCycle(
                label: "Day Wheel",
                symbols: [.kin, .imix, .ik, .tzolk, .haab],
                startOffset: 0,
                revealedPositions: [0,1,2,3,4,5,7,8]
            )
        ],
        sequenceLength: 10,
        decodedMessage: "The World Tree — Wakah-Chan — rises from the turtle shell of creation. It has always been turning. The first root reaches toward the sun. This is the root of KIN, the root of the repeating day, the root that measures breath.",
        newGlyphs: [.kin, .imix, .ik, .tzolk, .haab],
        artifact: "sun.max.fill",
        journalTitle: "The First Sunrise",
        journalBody: "The tablet was pristine. Cleaner than anything we'd found in the Egyptian chamber — as if it had been sealed the same morning it was carved. The five glyphs ran in a perfect line, then repeated, with two positions left deliberately blank. A test, the priest's notes said. They gave students this tablet first. If you could not complete a single cycle, you were not ready to learn time."
    )

    // ─────────────────────────────────────────────────────────────────────
    // LEVEL 2 · 2 cycles · periods 3+2 · 7 blanks  (rotating wheel mechanic)
    //
    // Cycle A: [KIN, HAAB, TZʼ]  offset=0  length=6
    //   0:KIN  1:HAAB  2:TZʼ  3:KIN  4:HAAB  5:TZʼ
    //   Revealed: {0,1,2}  — first full cycle is all anchors (teaching pass)
    //   Blanks: {3→KIN, 4→HAAB, 5→TZʼ}
    //
    // Cycle B: [IMIX, IK]  offset=0  length=6
    //   0:IMIX  1:IK  2:IMIX  3:IK  4:IMIX  5:IK
    //   Revealed: {0,1}  — first full cycle is all anchors (teaching pass)
    //   Blanks: {2→IMIX, 3→IK, 4→IMIX, 5→IK}
    // ─────────────────────────────────────────────────────────────────────
    static let level2 = MayanLevel(
        id: 2,
        title: "The Two Wheels Turn",
        subtitle: "Independent Rhythms",
        lore: "Two cycles now run simultaneously — the Solar Wheel above and the Earth Wheel below. Each turns independently. What happens in one row has no effect on the other. Solve each wheel on its own.",
        inscriptions: [
            "Above and below: two wheels, two independent rhythms. The Solar Wheel in the top row turns every three steps. The Earth Wheel below turns every two. They share the same sequence of positions but follow entirely separate cycles — solve each row alone.",
            "Solve the top row first. Ignore the bottom row completely. Three symbols repeat. You have two anchors — from them you can reconstruct the full cycle.",
            "Now solve the bottom row. Ignore the top. Two symbols alternate. You have three anchors — the pattern is immediate.",
            "The Maya tracked six separate calendar cycles running simultaneously. Some cycles were 260 days. Some were 365. Some were 584. Each turned on its own wheel. The priest's job was to know where every wheel was at any given moment."
        ],
        cycles: [
            MayanCycle(
                label: "Solar Wheel",
                symbols: [.kin, .haab, .tzolk],
                startOffset: 0,
                revealedPositions: [0,1,2]
            ),
            MayanCycle(
                label: "Earth Wheel",
                symbols: [.imix, .ik],
                startOffset: 0,
                revealedPositions: [0,1]
            )
        ],
        sequenceLength: 6,
        decodedMessage: "Two roots grow from the same trunk. The root of KIN grows toward the sun and turns in a cycle of three. The root of IMIX grows into the dark water and turns in a cycle of two. They never align — and that is the point. The Tree breathes in both directions at once.",
        newGlyphs: [],
        artifact: "calendar.circle.fill",
        journalTitle: "The Two Wheels",
        journalBody: "The second tablet was mounted beside the first on the chamber wall, but carved by a different hand — lighter strokes, more confident. Two rows instead of one. I didn't understand at first. I kept trying to find a relationship between the rows, some hidden correspondence. There was none. They were simply two independent clocks, running at different speeds, recorded side by side because that is how you read time: all the wheels together, each one on its own terms."
    )

    // ─────────────────────────────────────────────────────────────────────
    // LEVEL 3 · 2 cycles · periods 4+3 · 8 blanks
    //
    // Cycle A: [KIN, IMIX, IK, HAAB]  offset=0  length=8
    //   0:KIN  1:IMIX  2:IK  3:HAAB  4:KIN  5:IMIX  6:IK  7:HAAB
    //   Revealed: {0,2,5,7}  Blanks: {1→IMIX, 3→HAAB, 4→KIN, 6→IK}
    //
    // Cycle B: [TZʼ, KIN, IMIX]  offset=0  length=8
    //   0:TZʼ  1:KIN  2:IMIX  3:TZʼ  4:KIN  5:IMIX  6:TZʼ  7:KIN
    //   Revealed: {0,1,4,6}  Blanks: {2→IMIX, 3→TZʼ, 5→IMIX, 7→KIN}
    // ─────────────────────────────────────────────────────────────────────
    static let level3 = MayanLevel(
        id: 3,
        title: "The Interlocking Wheels",
        subtitle: "LCM of Four and Three",
        lore: "The wheels are longer now. The Day Wheel turns every four steps; the Sacred Wheel turns every three. Their combined pattern does not repeat for twelve steps. But you only need to see eight — enough to feel both rhythms and fill the gaps.",
        inscriptions: [
            "Two wheels of different lengths now turn together — four symbols in one row, three in another. Their combined pattern takes twelve positions to repeat, but eight are shown. Identify the period of each cycle from the anchors; once the period is clear, every blank follows directly.",
            "The Day Wheel has four symbols. You see KIN at position 0, IK at position 2. That tells you positions 0 and 2 in a four-step cycle. Position 1 and 3 are forced — only one symbol fits each gap without repeating within the period.",
            "The Sacred Wheel has three symbols. TZʼ appears at positions 0 and 6. KIN at 1 and 4. That is a period-3 cycle confirming itself. The blanks in the Sacred Wheel row write themselves.",
            "I drew the two cycles as wheels on paper beside the tablet — a small wheel of three and a larger wheel of four, both turning. The blank positions were where I needed to look up at the wheels and read off the next position. The pattern was precise and inevitable."
        ],
        cycles: [
            MayanCycle(
                label: "Day Wheel",
                symbols: [.kin, .imix, .ik, .haab],
                startOffset: 0,
                revealedPositions: [0,2,5,7]
            ),
            MayanCycle(
                label: "Sacred Wheel",
                symbols: [.tzolk, .kin, .imix],
                startOffset: 0,
                revealedPositions: [0,1,4,6]
            )
        ],
        sequenceLength: 8,
        decodedMessage: "The third root is the root of the sacred round. TZʼOLKIN: 260 days, two wheels inside each other — 13 numbers and 20 day-names cycling simultaneously. It takes 260 days before the same combination appears again. The Maya tracked this without paper, without instruments, in their heads. The Tree remembers every turn.",
        newGlyphs: [],
        artifact: "asterisk.circle.fill",
        journalTitle: "The Interlocking Wheels",
        journalBody: "Two wheels, different sizes. I kept making errors until I stopped trying to solve both at once and started treating each row as its own private problem. Once I found the period of each cycle from the anchors, the blanks took less than a minute. The Maya students must have learned this the same way — first confusion, then the moment the period becomes visible, and then the whole inscription snaps into focus at once."
    )

    // ─────────────────────────────────────────────────────────────────────
    // LEVEL 4 · 2 cycles · offset starts · 7 blanks
    //
    // Cycle A: [KIN, IMIX, TZʼ, HAAB]  offset=1  length=8
    //   symbol(pos) = symbols[(pos+1)%4]
    //   0:IMIX  1:TZʼ  2:HAAB  3:KIN  4:IMIX  5:TZʼ  6:HAAB  7:KIN
    //   Revealed: {0,1,3,5,7}  Blanks: {2→HAAB, 4→IMIX, 6→HAAB}
    //
    // Cycle B: [IK, KIN, HAAB]  offset=2  length=8
    //   symbol(pos) = symbols[(pos+2)%3]
    //   0:HAAB  1:IK  2:KIN  3:HAAB  4:IK  5:KIN  6:HAAB  7:IK
    //   Revealed: {0,2,4,6}  Blanks: {1→IK, 3→HAAB, 5→KIN, 7→IK}
    // ─────────────────────────────────────────────────────────────────────
    static let level4 = MayanLevel(
        id: 4,
        title: "The Haab' Speaks",
        subtitle: "Arriving Mid-Cycle",
        lore: "The inscription does not begin at the start of either cycle. Both wheels were already turning when this tablet was carved. You must deduce where in each cycle the sequence begins — then extend it forward and backward to fill the blanks.",
        inscriptions: [
            "Each wheel on this tablet was already mid-cycle when the inscription was carved. The Day Wheel does not open at its first symbol. Read the anchors and ask: which step in the four-symbol cycle does the first revealed position occupy? That offset determines every other position in the row.",
            "For the Day Wheel: you see IMIX at position 0. In the cycle [KIN, IMIX, TZʼ, HAAB], IMIX is index 1. So the offset is 1 — the sequence entered at the second symbol of the wheel. From there, all other positions are determined.",
            "The Wind Wheel has period 3 and opened at HAAB, which is index 2 in [IK, KIN, HAAB]. So offset is 2. The blanks are the positions not yet shown — use the formula: symbol = cycle[(position + offset) % period].",
            "Maya scribes sometimes began an inscription in the middle of a sacred cycle — a deliberate choice, to show the student that the calendar had no beginning and no end. The wheel was already turning before the first human was born. It will be turning after the last one closes their eyes."
        ],
        cycles: [
            MayanCycle(
                label: "Day Wheel",
                symbols: [.kin, .imix, .tzolk, .haab],
                startOffset: 1,
                revealedPositions: [0,1,3,5,7]
            ),
            MayanCycle(
                label: "Wind Wheel",
                symbols: [.ik, .kin, .haab],
                startOffset: 2,
                revealedPositions: [0,2,4,6]
            )
        ],
        sequenceLength: 8,
        decodedMessage: "The fourth root is the root of IK — wind, breath, the invisible force that moves all visible things. Wakah-Chan does not grow into the sky. The sky grows around it. Every breath a human takes is the sky acknowledging what stands at the centre of the world. IK is the proof.",
        newGlyphs: [],
        artifact: "wind",
        journalTitle: "Arriving Mid-Cycle",
        journalBody: "This tablet confused me for nearly an hour. The symbols were familiar but the sequence felt wrong — as if the inscription was out of order, or damaged. It wasn't damaged. It simply began in the middle. The Maya carved time wherever time happened to be. There was no ceremony about starting at the beginning, because the wheel has no beginning. I finally drew a small chart: four symbols in a loop for the top row, three for the bottom. Then I slid a finger around each loop until the revealed anchors lined up. The offset snapped into place. The rest was arithmetic."
    )

    // ─────────────────────────────────────────────────────────────────────
    // LEVEL 5 · 3 cycles · periods 3+4+5 · 11 blanks
    //
    // Cycle A: [KIN, IMIX, IK]  offset=0  length=9
    //   0:KIN  1:IMIX  2:IK  3:KIN  4:IMIX  5:IK  6:KIN  7:IMIX  8:IK
    //   Revealed: {0,1,4,6,8}  Blanks: {2→IK, 3→KIN, 5→IK, 7→IMIX}
    //
    // Cycle B: [HAAB, TZʼ, KIN, IMIX]  offset=0  length=9
    //   0:HAAB  1:TZʼ  2:KIN  3:IMIX  4:HAAB  5:TZʼ  6:KIN  7:IMIX  8:HAAB
    //   Revealed: {0,1,4,5,8}  Blanks: {2→KIN, 3→IMIX, 6→KIN, 7→IMIX}
    //
    // Cycle C: [IK, KIN, HAAB, TZʼ, IMIX]  offset=0  length=9
    //   0:IK  1:KIN  2:HAAB  3:TZʼ  4:IMIX  5:IK  6:KIN  7:HAAB  8:TZʼ
    //   Revealed: {0,1,2,5,6,7}  Blanks: {3→TZʼ, 4→IMIX, 8→TZʼ}
    // ─────────────────────────────────────────────────────────────────────
    static let level5 = MayanLevel(
        id: 5,
        title: "The Calendar Round",
        subtitle: "Three Wheels, One Machine",
        lore: "Three cycles turning simultaneously — period 3, period 4, period 5. Together they will not repeat for sixty steps. This inscription shows nine. Each row is independent. Solve each on its own terms. When all three wheels are filled, the inscription of the Calendar Round is complete.",
        inscriptions: [
            "Running at once: three wheels with independent periods of three, four, and five. Together they do not repeat for sixty positions — you see nine. Solve each row entirely on its own terms: find the period, locate the revealed anchors within it, and fill the blanks.",
            "The Sun Wheel is period 3: KIN, IMIX, IK repeating. Five positions are revealed — more than enough to confirm the rhythm. The two blanks in the middle and the two near the end follow directly from the pattern.",
            "The Year Wheel is period 4: HAAB, TZʼ, KIN, IMIX repeating. Five positions revealed. The four blanks all fall in positions not yet shown — use the period to locate each one in the cycle.",
            "The Long Wheel is period 5, all five glyphs in order. Six positions revealed across nine total. The three blanks are at positions 3, 4, and 8 — all uniquely determined. When all three rows are filled, you have decoded the Calendar Round: the great machine that the Maya used to measure the breath of the world."
        ],
        cycles: [
            MayanCycle(
                label: "Sun Wheel",
                symbols: [.kin, .imix, .ik],
                startOffset: 0,
                revealedPositions: [0,1,4,6,8]
            ),
            MayanCycle(
                label: "Year Wheel",
                symbols: [.haab, .tzolk, .kin, .imix],
                startOffset: 0,
                revealedPositions: [0,1,4,5,8]
            ),
            MayanCycle(
                label: "Long Wheel",
                symbols: [.ik, .kin, .haab, .tzolk, .imix],
                startOffset: 0,
                revealedPositions: [0,1,2,5,6,7]
            )
        ],
        sequenceLength: 9,
        decodedMessage: "Wakah-Chan does not grow — it turns. The World Tree is the axle of the world, and the world is the wheel. Every ending is the beginning of the same cycle wearing a different name. KIN returns. HAAB returns. The Calendar Round returns every fifty-two years. Wakah-Chan has been turning since before the first human opened their eyes. It will be turning after the last one closes theirs. Stand at the centre. Feel it turn.",
        newGlyphs: [],
        artifact: "globe.americas.fill",
        journalTitle: "The Calendar Round",
        journalBody: "The fifth tablet was the largest — three rows, nine positions across, with only eleven blanks among twenty-seven cells. By this point the rhythm was in my hands. I filled the Sun Wheel in under a minute. The Year Wheel took two. The Long Wheel required me to count carefully from the anchors, but the logic was identical. Three independent cycles, each solvable alone. What made it magnificent was not the difficulty but the completeness — three wheels, all at once, the full machine running. The Maya called this the Calendar Round: the moment all three great cycles realigned. It happened once every fifty-two years. When it did, they lit a new fire and began the world again."
    )
}
