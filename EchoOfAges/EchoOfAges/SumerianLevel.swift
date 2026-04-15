// SumerianLevel.swift
// EchoOfAges
//
// Substitution cipher puzzles for the Sumerian / Cuneiform civilization.
//
// Mechanic: A clay tablet shows a row of ENCODED cuneiform symbols.
// Beneath it the player fills in the DECODED symbols.
// Some decoded positions are pre-revealed as anchor points.
// From those anchors the player deduces the hidden cipher key
// (a one-to-one mapping of symbols), then applies it to every blank.
//
// Difficulty progression:
//   L1 — 3 symbols, 2 anchors, 4 blanks  (cyclic key, easy pattern)
//   L2 — 4 symbols, 3 anchors, 5 blanks
//   L3 — 4 symbols, 3 anchors, 5 blanks  (different permutation)
//   L4 — 5 symbols, 4 anchors, 6 blanks
//   L5 — 5 symbols, 4 anchors, 8 blanks  (long sequence, full deduction)

import Foundation

// MARK: - CuneiformGlyph

enum CuneiformGlyph: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case an  = "𒀭"   // Heaven / God
    case ki  = "𒆳"   // Earth / Land
    case a   = "𒀀"   // Water
    case ud  = "𒌓"   // Sun / Day
    case gal = "𒃲"   // Great / Large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .an:  return "AN"
        case .ki:  return "KI"
        case .a:   return "A"
        case .ud:  return "UD"
        case .gal: return "GAL"
        }
    }

    var meaning: String {
        switch self {
        case .an:  return "Heaven · God"
        case .ki:  return "Earth · Land"
        case .a:   return "Water"
        case .ud:  return "Sun · Day"
        case .gal: return "Great · Large"
        }
    }

    var discoveryNote: String {
        switch self {
        case .an:
            return "AN — the sky god. The very first written sign for divinity: a star pressed into clay. Every god in Sumer wore this mark as a crown above their name."
        case .ki:
            return "KI — earth, the great below. Where AN ends, KI begins. In the beginning they were one; Enlil forced them apart and the world came into being between them."
        case .a:
            return "A — water, the source of all things. Eridu, the first city, was built beside the primordial waters. Without A, there is no life, no grain, no city, no god."
        case .ud:
            return "The sun disc rising. UD measures time itself — the Sumerians were the first people to divide the day into hours, the year into months. To carve UD is to tame eternity."
        case .gal:
            return "GAL — great, vast, supreme. The sky is AN-GAL. The earth is KI-GAL. Even death has a name here: EREŠ-KI-GAL, Lady of the Great Below. The fifth and final sign."
        }
    }
}

// MARK: - SumerianLevel

struct SumerianLevel: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let lore: String
    let inscriptions: [String]

    /// The subset of glyphs used in this level's cipher (3, 4, or 5 symbols).
    let symbols: [CuneiformGlyph]

    /// The encoded sequence shown to the player on the tablet (fixed, never changes).
    let encodedSequence: [CuneiformGlyph]

    /// The hidden one-to-one mapping: encoded symbol → decoded symbol.
    let cipherKey: [CuneiformGlyph: CuneiformGlyph]

    /// Indices in the sequence where the decoded symbol is pre-revealed as an anchor.
    let revealedPositions: Set<Int>

    let decodedMessage: String
    let newGlyphs: [CuneiformGlyph]
    let artifact: String
    let journalTitle: String
    let journalBody: String

    /// The full decoded sequence (solution).
    var solution: [CuneiformGlyph] {
        encodedSequence.map { cipherKey[$0]! }
    }

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

    func isRevealed(_ index: Int) -> Bool {
        revealedPositions.contains(index)
    }

    func isSolved(_ decoded: [CuneiformGlyph?]) -> Bool {
        guard decoded.count == solution.count else { return false }
        return decoded.enumerated().allSatisfy { idx, glyph in glyph == solution[idx] }
    }
}

// MARK: - Level Definitions
//
// Key notation:  AN KI A UD GAL
// Each level's cipherKey is a bijection (one-to-one) over the level's symbol set.
// Solvability guarantee: the revealed anchors expose enough distinct encoded→decoded
// pairs that the remaining mapping is uniquely determined by elimination.

extension SumerianLevel {
    static let allLevels: [SumerianLevel] = [level1, level2, level3, level4, level5]

    // ─────────────────────────────────────────────────
    // LEVEL 1 · 3 symbols · 2 anchors · 4 blanks
    //
    // Key:   AN→KI   KI→A   A→AN       (cyclic shift +1)
    // Seq:   AN  KI  A   AN  KI  A
    // Sol:   KI  A   AN  KI  A   AN
    // Rev:   {0, 1}  →  AN→KI, KI→A revealed
    // Deduction: A→AN by elimination (only output left)
    // ─────────────────────────────────────────────────
    static let level1 = SumerianLevel(
        id: 1,
        title: "Tablet of Ur-Namma",
        subtitle: "The Hidden Impression",
        lore: "King Ur-Namma's scribes concealed their messages using a simple substitution — each sign replaced by the next sign in the sacred cycle. Two anchor stones are pre-revealed. From them, deduce what the third sign becomes, then decode the rest of the inscription.",
        inscriptions: [
            "Beneath every sign pressed into this clay lies a different sign — the true meaning hidden by substitution. Two anchor positions are already revealed, showing you where the key begins. Name the two known pairings; only one sign remains unmatched.",
            "AN above becomes KI — heaven becomes earth. KI becomes A — earth becomes water. What does water become? There is only one sign left.",
            "Once you know all three substitutions, apply them in order to every blank position. The pattern repeats across the inscription.",
            "I solved it by writing the key beside the tablet: AN→KI, KI→A, A→? The third substitution was forced — only one symbol remained unused."
        ],
        symbols: [.an, .ki, .a],
        encodedSequence: [.an, .ki, .a, .an, .ki, .a],
        cipherKey: [.an: .ki, .ki: .a, .a: .an],
        revealedPositions: [0, 1],
        decodedMessage: "In the great above, AN was fixed and named. Something pressed downward through the clay, seeking the dark waters below the world. Heaven was made real the moment it was written.",
        newGlyphs: [.an, .ki, .a],
        artifact: "𒀭",
        journalTitle: "The First Law",
        journalBody: "Ur-Namma's code did not begin with punishment. It began with substitution. AN became KI, KI became A, A became AN — an endless cycle carved into the clay. The priest explained: before we could write law, we had to write the world in secret. The substitution cipher was the first act of both secrecy and trust."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 2 · 4 symbols · 3 anchors · 5 blanks
    //
    // Key:   AN→KI   KI→UD   UD→A   A→AN
    // Seq:   AN  A   UD  KI  AN  KI  A   UD
    // Sol:   KI  AN  A   UD  KI  UD  AN  A
    // Rev:   {0, 2, 3}  →  AN→KI, UD→A, KI→UD revealed
    // Deduction: A→AN by elimination
    // ─────────────────────────────────────────────────
    static let level2 = SumerianLevel(
        id: 2,
        title: "Temple of Nanna",
        subtitle: "The Moon's Cipher",
        lore: "The Moon god Nanna's priests encoded their temple records with a four-sign cycle. Three anchor stones are revealed. Each one exposes a different substitution. Together they leave only one possible mapping for the fourth sign — find it, and the inscription opens.",
        inscriptions: [
            "Of the four substitutions in this cipher, three are shown in the anchor positions. Study each anchor pair: which sign appears as an input without a paired output? Which output is unclaimed? The missing pair is the only one that satisfies both gaps.",
            "Look at the three anchors: which signs appear as inputs? Which signs appear as outputs? The sign that appears as neither an input nor an output in the key panel is the missing output.",
            "When you know all four substitutions, apply each encoded sign to its decoded partner. The tablet's message will surface like the moon from cloud.",
            "Nanna divided the month into four phases. His scribes divided the cipher into four steps. I found the missing step by asking: which output is not yet claimed?"
        ],
        symbols: [.an, .ki, .a, .ud],
        encodedSequence: [.an, .a, .ud, .ki, .an, .ki, .a, .ud],
        cipherKey: [.an: .ki, .ki: .ud, .ud: .a, .a: .an],
        revealedPositions: [0, 2, 3],
        decodedMessage: "In the great below, KI was planted and known. The Moon measured its depths and found: what grows in the dark grows as surely as what grows in the light. Time, it seems, has roots that go very deep.",
        newGlyphs: [.ud],
        artifact: "𒌓",
        journalTitle: "The Moon's Record",
        journalBody: "Nanna's temple kept the first calendar. The scribes encoded UD — the sun — into their records using the moon's cipher, as if to say: the sun belongs to us too, hidden in our sequence. Four signs, four substitutions, one endless cycle. The moon and sun taking turns, each becoming the other."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 3 · 4 symbols · 3 anchors · 5 blanks
    //
    // Key:   AN→A   KI→AN   A→UD   UD→KI       (different cycle)
    // Seq:   KI  AN  UD  A   KI  A   AN  UD
    // Sol:   AN  A   KI  UD  AN  UD  A   KI
    // Rev:   {1, 3, 4}  →  AN→A, A→UD, KI→AN revealed
    // Deduction: UD→KI by elimination
    // ─────────────────────────────────────────────────
    static let level3 = SumerianLevel(
        id: 3,
        title: "Sacred Precinct of Nippur",
        subtitle: "The Invisible Key",
        lore: "Nippur's priests changed the cipher rotation. The same four signs, but a different cycle — AN no longer becomes KI. Three anchors are given. This time pay attention to which sign is conspicuously absent from the revealed substitutions: that absence is the clue.",
        inscriptions: [
            "Unlike the Moon Temple's cipher, this one does not shift heaven into earth. The same four signs, but a different cycle — read the three anchor pairs without assuming the previous pattern applies. The fourth substitution writes itself from what remains.",
            "Three substitutions are revealed. Name the four inputs. Name the four outputs. Which input is not yet paired with an output? Which output is not yet claimed? They belong to each other.",
            "In Nippur, the priests deliberately chose a cipher where the sign for heaven does not become the sign for earth. They said: heaven and earth are opposites. They should not follow each other in the key.",
            "I drew a small chart beside the tablet: the four signs in a column on the left, their mapped partners on the right. Three lines were given. The fourth drew itself."
        ],
        symbols: [.an, .ki, .a, .ud],
        encodedSequence: [.ki, .an, .ud, .a, .ki, .a, .an, .ud],
        cipherKey: [.an: .a, .ki: .an, .a: .ud, .ud: .ki],
        revealedPositions: [1, 3, 4],
        decodedMessage: "What reaches upward also reaches downward. As AN is above, KI is below. As the branch grows outward, the root grows inward. The priests of Nippur knew: the world is divided into invisible chambers, and all of them are full.",
        newGlyphs: [],
        artifact: "𒆳",
        journalTitle: "The Invisible Boundaries",
        journalBody: "The Nippur archives were protected not by physical walls but by a substitution cipher that changed with each archive season. No two seasons used the same key. The priests memorized the annual cycle. An outsider who cracked one tablet could not read the next — they would have to start the deduction again."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 4 · 5 symbols · 4 anchors · 6 blanks
    //
    // Key:   AN→GAL   KI→AN   A→KI   UD→A   GAL→UD
    // Seq:   AN  KI  A   UD  GAL  AN  A   KI  GAL  UD
    // Sol:   GAL AN  KI  A   UD   GAL KI  AN  UD   A
    // Rev:   {0, 2, 3, 4}  →  AN→GAL, A→KI, UD→A, GAL→UD revealed
    // Deduction: KI→AN by elimination
    // ─────────────────────────────────────────────────
    static let level4 = SumerianLevel(
        id: 4,
        title: "Ziggurat of Eridu",
        subtitle: "The Five-Step Descent",
        lore: "Eridu's ziggurat had seven levels, but its cipher used only five steps — one for each sacred sign. Four anchors are given across the first five positions. The fifth substitution hides behind elimination alone. Find it, and the full inscription of the Great Descent will open.",
        inscriptions: [
            "Going level by level through the ziggurat, heaven becomes great, great becomes sun — the key descends in steps through all five signs. Four of the five substitutions are visible in the anchor stones. Name every input and output already shown; the fifth pair is the one not yet claimed.",
            "Four of the five substitutions are directly shown. Name the four known inputs. Name the four known outputs. Which input is paired with no output yet? Which output is unclaimed? Those two belong together.",
            "Once you have all five substitutions, work across the ten positions of the inscription. Each encoded sign has exactly one decoded partner.",
            "The ziggurat was a key made of stone — seven levels, each transforming the level above it. The priests called their cipher 'the stone key'. It worked the same way: each sign transforms into the next."
        ],
        symbols: [.an, .ki, .a, .ud, .gal],
        encodedSequence: [.an, .ki, .a, .ud, .gal, .an, .a, .ki, .gal, .ud],
        cipherKey: [.an: .gal, .ki: .an, .a: .ki, .ud: .a, .gal: .ud],
        revealedPositions: [0, 2, 3, 4],
        decodedMessage: "What grows toward AN-GAL — the great heaven — also grows toward KI-GAL — the great earth. The ziggurat reaches in both directions at once — seven levels descending into the earth, seven levels ascending into heaven, the middle level the world where people live. All growth has two directions. All things reach both ways.",
        newGlyphs: [.gal],
        artifact: "𒃲",
        journalTitle: "The First City's Secret",
        journalBody: "Eridu's priests claimed their city was built before the flood, before the other cities, before time itself. The five-sign cipher was their oldest secret — older than cuneiform, they said, carved in the mind before the stylus existed. AN became GAL and descended through UD and A and KI until it returned to itself. The city and the cipher were both circles."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 5 · 5 symbols · 4 anchors · 8 blanks
    //
    // Key:   AN→UD   KI→GAL   A→AN   UD→KI   GAL→A
    // Seq:   AN  KI  A   UD  GAL  AN  KI  GAL  A   UD  KI  AN
    // Sol:   UD  GAL AN  KI  A    UD  GAL A    AN  KI  GAL UD
    // Rev:   {0, 2, 4, 6}  →  AN→UD, A→AN, GAL→A, KI→GAL revealed
    // Deduction: UD→KI by elimination
    // ─────────────────────────────────────────────────
    static let level5 = SumerianLevel(
        id: 5,
        title: "The Great Descent",
        subtitle: "Inanna's Final Cipher",
        lore: "Inanna descended through seven gates. At each gate she surrendered one truth — until at the bottom she held nothing and understood everything. This inscription is her final cipher: twelve encoded signs, four anchors, one hidden substitution deducible only by elimination. Decode it as she decoded the underworld: by giving up assumption and following only what is certain.",
        inscriptions: [
            "Held within these twelve signs is a cipher of five substitutions — four visible in the four anchor positions. Name every input that appears in the anchors; name every output. The one remaining pair writes itself. With the complete key, each encoded sign has exactly one decoded partner.",
            "Look at the four anchors. Name every input that appears in them. Name every output. Five inputs must pair with five outputs. Four pairings are shown — the fifth pair writes itself.",
            "Inanna surrendered her crown, her robe, her lapis beads, her breastplate, her ring. At each gate one truth was removed. Here: four substitutions are given, one is removed. Find the removed one.",
            "When you have the full key, move left to right across the encoded inscription. Each sign tells you exactly what to write beneath it. There is no ambiguity — the cipher is a bijection. One sign, one answer."
        ],
        symbols: [.an, .ki, .a, .ud, .gal],
        encodedSequence: [.an, .ki, .a, .ud, .gal, .an, .ki, .gal, .a, .ud, .ki, .an],
        cipherKey: [.an: .ud, .ki: .gal, .a: .an, .ud: .ki, .gal: .a],
        revealedPositions: [0, 2, 4, 6],
        decodedMessage: "The tree has no top and no bottom — only the endless middle, which is now. Inanna returned from the great below carrying this knowledge: what seemed like descent was always ascent seen from the other side. The Tree grows in both directions simultaneously, and you are always standing at its center.",
        newGlyphs: [],
        artifact: "𒀀",
        journalTitle: "The Return of Inanna",
        journalBody: "She descended through seven gates. At each one she gave up a piece of her divinity. At the bottom she was nothing. And then she understood: the tree has no top and no bottom — only the endless middle, which is now. She rose carrying that knowledge. The substitution cipher was the same: strip away the surface signs until only the truth beneath remains. Then read it."
    )
}
