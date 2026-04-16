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
    /// True → rotating wheel mechanic (MayanWheelView). False → static grid.
    let usesWheelMechanic: Bool
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
        usesWheelMechanic: false,
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
        usesWheelMechanic: true,
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
    // LEVEL 3 · 2 cycles · period 4 + period 4 · 8 blanks  (static grid)
    //
    // SYMMETRIC PAIRING RULE — the same symbol always finds the same partner,
    // no matter which ring it appears on:
    //   KIN  ↔ HAAB   (sun and year — both solar, always together)
    //   IMIX ↔ IK     (earth and wind — always together)
    //
    // Day Wheel (outer): [KIN, IMIX, IK, HAAB]  offset=0
    //   0:KIN  1:IMIX  2:IK  3:HAAB  4:KIN  5:IMIX  6:IK  7:HAAB
    //   Revealed: {0,1,2,3}  Blanks: {4→KIN, 5→IMIX, 6→IK, 7→HAAB}
    //
    // Sacred Wheel (inner): [HAAB, IK, IMIX, KIN]  offset=0
    //   (derived: inner[n] = symmetric_pair(outer[n]))
    //   0:HAAB  1:IK  2:IMIX  3:KIN  4:HAAB  5:IK  6:IMIX  7:KIN
    //   Revealed: {0,1,2,4}  Blanks: {3→KIN, 5→IK, 6→IMIX, 7→KIN}
    //
    // Solving order — the symmetry "aha" happens at positions 1 and 2:
    //   Pos 0 (KIN/HAAB):   learn KIN↔HAAB
    //   Pos 1 (IMIX/IK):    learn IMIX↔IK (forward)
    //   Pos 2 (IK/IMIX):    same pair, reversed → symmetry revealed!
    //   Pos 3 (HAAB/blank): reverse KIN↔HAAB → inner=KIN
    //   Pos 4 (blank/HAAB): outer from cycle; HAAB confirms outer=KIN
    //   Pos 5 (blank/blank): outer=IMIX from cycle; inner=IK from pair
    //   Pos 6 (blank/blank): outer=IK from cycle; inner=IMIX from pair
    //   Pos 7 (blank/blank): outer=HAAB from cycle; inner=KIN from pair
    // ─────────────────────────────────────────────────────────────────────
    static let level3 = MayanLevel(
        id: 3,
        usesWheelMechanic: false,
        title: "Wheels That Answer Each Other",
        subtitle: "The Binding Rule",
        lore: "Two wheels, both still. But they are not independent. At every position, the outer mark and the inner mark are bound by a fixed pairing — and the pairing works both ways. If you see KIN on the outer, HAAB will be on the inner. If you see HAAB on the outer, KIN will be on the inner. The same symbol always finds the same partner, no matter which wheel it is on.",
        inscriptions: [
            "These two wheels do not turn separately. At each of the eight positions, the outer mark and the inner mark belong together — a fixed pairing, always the same. The key: the rule is symmetric. If A pairs with B, then B pairs with A. The same symbol always finds the same partner.",
            "Find the positions where both wheels carry a mark. Look at positions 0, 1, and 2 — three pairings are shown directly. Now look at positions 1 and 2 again. The outer symbol at position 1 is the same as the inner symbol at position 2, and vice versa. That is not a coincidence. That is symmetry.",
            "Once you have the two pairings, fill any blank where its partner is visible. For positions where both wheels are blank, deduce the outer value from the outer wheel's own four-symbol repeating cycle, then apply the pairing to find the inner.",
            "The Maya called this 'the binding of the wheels.' Each day carried a name in the Haab' solar year and a name in the Tzolk'in sacred round — two systems, always read in combination. The sun and the year. The earth and the wind. No wheel turns alone."
        ],
        cycles: [
            MayanCycle(
                label: "Day Wheel",
                symbols: [.kin, .imix, .ik, .haab],
                startOffset: 0,
                revealedPositions: [0,1,2,3]
            ),
            MayanCycle(
                label: "Sacred Wheel",
                symbols: [.haab, .ik, .imix, .kin],
                startOffset: 0,
                revealedPositions: [0,1,2,4]
            )
        ],
        sequenceLength: 8,
        decodedMessage: "The third root reaches in two directions at once. KIN calls HAAB — and HAAB calls KIN. IMIX calls IK — and IK calls IMIX. The pairing is not one-way. It is not a hierarchy. It is a bond: equal, permanent, symmetric. The Tree does not breathe with one root pulling and another following. Both roots pull. Both roots answer. That is what holds the trunk upright.",
        newGlyphs: [],
        artifact: "asterisk.circle.fill",
        journalTitle: "The Binding Rule",
        journalBody: "I spent the first hour trying to solve each wheel separately. It didn't work. Then I looked at positions 1 and 2 together — IMIX with IK at position 1, IK with IMIX at position 2. The same pair, twice, from both sides. That was the moment I understood: the rule is symmetric. KIN always pairs with HAAB. IMIX always pairs with IK. It doesn't matter which wheel the symbol appears on. Find its partner, fill the blank. The tablet solved itself in minutes after that."
    )

    // ─────────────────────────────────────────────────────────────────────
    // LEVEL 4 · 2 cycles · period 4 + period 4 · 8 blanks  (rotating wheel)
    //
    // Same symmetric pairing rule as Level 3.
    // Outer cycle starts mid-sequence (offset=2): player sees IK first,
    // must deduce the cycle entered 2 steps in.
    //
    // Day Wheel (outer): [KIN, IMIX, IK, HAAB]  offset=2
    //   symbol(pos) = [KIN,IMIX,IK,HAAB][(pos+2)%4]
    //   0:IK  1:HAAB  2:KIN  3:IMIX  4:IK  5:HAAB  6:KIN  7:IMIX
    //   Revealed: {0,1,4,5}  Blanks: {2→KIN, 3→IMIX, 6→KIN, 7→IMIX}
    //
    // Sacred Wheel (inner): [IMIX, KIN, HAAB, IK]  offset=0
    //   (derived: inner[n] = symmetric_pair(outer[n]))
    //   IK↔IMIX, HAAB↔KIN, KIN↔HAAB, IMIX↔IK (all symmetric ✓)
    //   0:IMIX  1:KIN  2:HAAB  3:IK  4:IMIX  5:KIN  6:HAAB  7:IK
    //   Revealed: {1,3,5,7}  Blanks: {0→IMIX, 2→HAAB, 4→IMIX, 6→HAAB}
    //
    // Pairing at each position (all symmetric):
    //   Pos 0: IK(r)/IMIX(blank)  → IK↔IMIX → fill inner=IMIX
    //   Pos 1: HAAB(r)/KIN(r)     → HAAB↔KIN confirmed ✓
    //   Pos 2: KIN(blank)/HAAB(blank) → cycle→KIN; pair→HAAB
    //   Pos 3: IMIX(blank)/IK(r)  → IK↔IMIX → fill outer=IMIX (+ cycle)
    //   Pos 4: IK(r)/IMIX(blank)  → repeat pos 0
    //   Pos 5: HAAB(r)/KIN(r)     → repeat pos 1
    //   Pos 6: KIN(blank)/HAAB(blank) → repeat pos 2
    //   Pos 7: IMIX(blank)/IK(r)  → repeat pos 3
    // ─────────────────────────────────────────────────────────────────────
    static let level4 = MayanLevel(
        id: 4,
        usesWheelMechanic: true,
        title: "The Pairing in Motion",
        subtitle: "Bound Wheels, Turning",
        lore: "The symmetric pairing rule holds even as the wheels rotate. You know the pairs from the previous tablet — KIN with HAAB, IMIX with IK, always both ways. Now the outer ring arrived mid-cycle. Watch what passes through 12 o'clock, identify where in the four-symbol cycle you entered, then apply the binding rule to fill each blank.",
        inscriptions: [
            "The binding rule from the previous tablet still applies — and it is still symmetric. KIN pairs with HAAB no matter which ring it appears on. IMIX pairs with IK no matter which ring. The new challenge is that the outer ring did not start at its first symbol.",
            "Watch the outer ring's first two marks as they pass. They tell you which two consecutive positions in the four-symbol cycle you entered at. Once you know the entry point, every outer position is determined. The inner ring confirms each answer.",
            "When the ring pauses at a blank on the inner wheel and the outer shows an anchor, apply the pairing forward. When the outer is blank and the inner shows an anchor, apply the pairing in reverse — same rule, same symmetry.",
            "The Maya priest reading a running calendar did not start at the beginning. The wheels were already turning when he sat down. He identified which position he had entered, then read forward. That is the skill this tablet requires."
        ],
        cycles: [
            MayanCycle(
                label: "Day Wheel",
                symbols: [.kin, .imix, .ik, .haab],
                startOffset: 2,
                revealedPositions: [0,1,4,5]
            ),
            MayanCycle(
                label: "Sacred Wheel",
                symbols: [.imix, .kin, .haab, .ik],
                startOffset: 0,
                revealedPositions: [1,3,5,7]
            )
        ],
        sequenceLength: 8,
        decodedMessage: "The fourth root is the root in motion. The binding does not pause when the wheel turns — KIN calls HAAB whether still or spinning, IMIX calls IK whether the stone moves or not. Symmetry does not require stillness. The rule that holds at rest holds in motion. The Tree breathes the same whether you are watching or not.",
        newGlyphs: [],
        artifact: "wind",
        journalTitle: "The Pairing in Motion",
        journalBody: "Applying the pairing rule while the rings rotated was harder than I expected — not because the rule had changed, but because I had to find my entry point in the cycle before I could use it. IK first, then HAAB: two steps into the four-symbol cycle. Once I knew the offset, the outer sequence was determined. And every time I placed a symbol, the inner ring confirmed it through the pairing. The binding held. The rule was the same rule. I just had to find my footing before I could use it."
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
        usesWheelMechanic: false,
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
