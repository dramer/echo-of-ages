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

    /// The symmetric pairing partner for this glyph.
    /// KIN↔HAAB, IMIX↔IK. TZʼ maps to itself (not used in pairing puzzles).
    var pairingPartner: MayanGlyph {
        switch self {
        case .kin:   return .haab
        case .haab:  return .kin
        case .imix:  return .ik
        case .ik:    return .imix
        case .tzolk: return .tzolk
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
    /// True → both rings rotate in the same direction and stay in lock-step (Level 4 pairing puzzle).
    let usesSynchronizedRotation: Bool
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

    /// True when every non-anchor cell has been filled by the player (right or wrong).
    func isFullyFilled(_ playerGrid: [[MayanGlyph?]]) -> Bool {
        guard playerGrid.count == cycles.count else { return false }
        for (ci, cycle) in cycles.enumerated() {
            guard playerGrid[ci].count == sequenceLength else { return false }
            for pos in 0..<sequenceLength where !cycle.isRevealed(pos) {
                if playerGrid[ci][pos] == nil { return false }
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
        usesSynchronizedRotation: false,
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
        usesSynchronizedRotation: false,
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
    // Stubs used by allLevels for count/unlock tracking. GameState regenerates
    // these fresh each time the player loads puzzle 3 or 4.
    static let level3 = MayanLevel.generateLevel3()
    static let level4 = MayanLevel.generateLevel4()

    static let level5 = MayanLevel(
        id: 5,
        usesWheelMechanic: false,
        usesSynchronizedRotation: false,
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

// MARK: - Random Level Generation (Levels 3 & 4)

extension MayanLevel {

    // ─────────────────────────────────────────────────────────────────────
    // Pairing rule: KIN↔HAAB, IMIX↔IK (symmetric, both directions).
    // TZʼ is not used in pairing puzzles.
    //
    // Period (2, 3, or 4) is chosen at random each generation.
    // Outer symbols: random shuffle of `period` glyphs from the four.
    // Inner symbols: outer.map { $0.pairingPartner }  — always symmetric.
    // Sequence length: period × 2 (two full cycles visible).
    //
    // Reveal templates guarantee the pairing rule is discoverable:
    //   • P=2: 3 outer + 3 inner anchors → 2 blanks total
    //   • P=3: 4 outer + 4 inner anchors → 4 blanks total
    //   • P=4: 4 outer + 4 inner anchors → 8 blanks total
    //
    // Level 4 adds a random startOffset so the player must locate their
    // entry point in the cycle before applying the pairing rule.
    // ─────────────────────────────────────────────────────────────────────

    private static let pairingGlyphs: [MayanGlyph] = [.kin, .haab, .imix, .ik]

    /// Generates a random Level 3 (static grid, pairing discovery).
    static func generateLevel3() -> MayanLevel {
        let period        = [2, 3, 4].randomElement()!
        let outerSymbols  = Array(pairingGlyphs.shuffled().prefix(period))
        let innerSymbols  = outerSymbols.map { $0.pairingPartner }
        let seqLen        = period * 2

        let outerRev: Set<Int>
        let innerRev: Set<Int>
        switch period {
        case 2:
            // P=2, seqLen=4: show 3 outer anchors, 3 inner anchors → 2 blanks
            outerRev = [0, 1, 2]
            innerRev = [0, 1, 3]
        case 3:
            // P=3, seqLen=6: show first cycle outer + most of first inner → 4 blanks
            outerRev = [0, 1, 2, 3]
            innerRev = [0, 1, 3, 4]
        default:
            // P=4, seqLen=8: first cycle outer + first-cycle inner minus one → 8 blanks
            outerRev = [0, 1, 2, 3]
            innerRev = [0, 1, 2, 4]
        }

        return MayanLevel(
            id: 3,
            usesWheelMechanic: false,
            usesSynchronizedRotation: false,
            title: "Wheels That Answer Each Other",
            subtitle: "The Binding Rule",
            lore: "Two wheels, both still. But they are not independent. At every position, the outer mark and the inner mark are bound by a fixed pairing — and the pairing works both ways. The same symbol always finds the same partner, no matter which wheel it is on.",
            inscriptions: [
                "These two wheels do not turn separately. At each position, the outer mark and the inner mark belong together — a fixed pairing, always the same. The key: the rule is symmetric. If A pairs with B, then B pairs with A. The same symbol always finds the same partner.",
                "Find the positions where both wheels carry a mark. Those positions show you the pairings directly. Now look for a position where the same pair appears in the opposite order — outer becomes inner, inner becomes outer. That is not a coincidence. That is symmetry.",
                "Once you have the two pairings, fill any blank where its partner is visible. For positions where both wheels are blank, deduce the outer value from the outer wheel's own repeating cycle, then apply the pairing to find the inner.",
                "The Maya called this 'the binding of the wheels.' Each day carried a name in the Haab' solar year and a name in the Tzolk'in sacred round — two systems, always read in combination. No wheel turns alone."
            ],
            cycles: [
                MayanCycle(label: "Day Wheel",    symbols: outerSymbols, startOffset: 0, revealedPositions: outerRev),
                MayanCycle(label: "Sacred Wheel", symbols: innerSymbols, startOffset: 0, revealedPositions: innerRev)
            ],
            sequenceLength: seqLen,
            decodedMessage: "The third root reaches in two directions at once. KIN calls HAAB — and HAAB calls KIN. IMIX calls IK — and IK calls IMIX. The pairing is not one-way. It is not a hierarchy. It is a bond: equal, permanent, symmetric. The Tree does not breathe with one root pulling and another following. Both roots pull. Both roots answer. That is what holds the trunk upright.",
            newGlyphs: [],
            artifact: "asterisk.circle.fill",
            journalTitle: "The Binding Rule",
            journalBody: "I spent the first hour trying to solve each wheel separately. It didn't work. Then I looked at the positions where both wheels showed a mark. Same symbol on one wheel — its pair on the other. Then a position where the same pair appeared reversed. That was the moment I understood: the rule is symmetric. The same two symbols always find each other, no matter which wheel they're on. Find the partner, fill the blank."
        )
    }

    /// Generates a random Level 4 (rotating wheel, pairing in motion).
    /// Period and start offset are both randomised.
    static func generateLevel4() -> MayanLevel {
        let period        = [2, 3, 4].randomElement()!
        let outerSymbols  = Array(pairingGlyphs.shuffled().prefix(period))
        let innerSymbols  = outerSymbols.map { $0.pairingPartner }
        let seqLen        = period * 2
        let startOffset   = Int.random(in: 0..<period)

        // Both cycles share the same offset so inner[n] = pair(outer[n]) at every position.
        let outerRev: Set<Int>
        let innerRev: Set<Int>
        switch period {
        case 2:
            // P=2, seqLen=4: 2 outer + 2 inner anchors → 4 blanks
            outerRev = [0, 1]
            innerRev = [0, 2]
        case 3:
            // P=3, seqLen=6: 4 outer + 3 inner anchors → 5 blanks
            outerRev = [0, 1, 3, 4]
            innerRev = [1, 3, 5]
        default:
            // P=4, seqLen=8: 4 outer + 4 inner anchors → 8 blanks
            outerRev = [0, 1, 4, 5]
            innerRev = [1, 3, 5, 7]
        }

        return MayanLevel(
            id: 4,
            usesWheelMechanic: true,
            usesSynchronizedRotation: true,
            title: "The Pairing in Motion",
            subtitle: "Bound Wheels, Turning",
            lore: "The symmetric pairing rule holds even as the wheels rotate. You know the pairs from the previous tablet. Now the outer ring arrived mid-cycle. Watch what passes through 12 o'clock, identify where in the cycle you entered, then apply the binding rule to fill each blank.",
            inscriptions: [
                "The binding rule from the previous tablet still applies — and it is still symmetric. Each symbol always pairs with the same partner, no matter which ring it appears on. The new challenge is that the outer ring did not start at its first symbol.",
                "Watch the outer ring's first two anchor marks as they pass 12 o'clock. They tell you which two consecutive positions in the cycle you entered at. Once you know the entry point, every outer position is determined.",
                "When the ring pauses at a blank on the inner wheel and the outer shows an anchor, apply the pairing forward. When the outer is blank and the inner shows an anchor, apply the pairing in reverse — same rule, same symmetry.",
                "The Maya priest reading a running calendar did not start at the beginning. The wheels were already turning when he sat down. He identified which position he had entered, then read forward. That is the skill this tablet requires."
            ],
            cycles: [
                MayanCycle(label: "Day Wheel",    symbols: outerSymbols, startOffset: startOffset, revealedPositions: outerRev),
                MayanCycle(label: "Sacred Wheel", symbols: innerSymbols, startOffset: startOffset, revealedPositions: innerRev)
            ],
            sequenceLength: seqLen,
            decodedMessage: "The fourth root is the root in motion. The binding does not pause when the wheel turns — each symbol calls its partner whether still or spinning. Symmetry does not require stillness. The rule that holds at rest holds in motion. The Tree breathes the same whether you are watching or not.",
            newGlyphs: [],
            artifact: "wind",
            journalTitle: "The Pairing in Motion",
            journalBody: "Applying the pairing rule while the rings rotated was harder than I expected — not because the rule had changed, but because I had to find my entry point in the cycle before I could use it. Once I found the offset, the outer sequence was determined. And every time I placed a symbol, the inner ring confirmed it through the pairing. The binding held. The rule was the same rule. I just had to find my footing before I could use it."
        )
    }
}
