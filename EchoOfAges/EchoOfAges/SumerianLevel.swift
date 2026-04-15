// SumerianLevel.swift
// EchoOfAges
//
// Substitution cipher puzzles for the Sumerian / Cuneiform civilization.
//
// Mechanic: A clay tablet shows a row of ENCODED cuneiform symbols.
// Beneath it the player fills in the DECODED symbols.
//
// Testimony mechanic: Each level presents exactly 3 scribes. Each scribe offers
// a complete cipher key — a claim for every symbol in the level's alphabet.
// The player selects one scribe's testimony; their key fills the Impressions Known
// panel and the tablet unlocks immediately for decoding.
//
// If the player chose the wrong testimony, their decoded positions will be incorrect
// and the Decipher check will flag them. The player can switch to another scribe —
// the tablet resets and they try again with the new key.
//
// Anchor stones (pre-revealed decoded positions) are physical evidence the player
// can use to cross-check each scribe's claims before committing.
//
// Level 1 special: the truthful scribe also identifies Egypt's foreign mark (𓊹).
// Level 5: no scribes — two anchors only, pure deduction.
//
// Difficulty progression:
//   L1 — 3 symbols, 1 anchor, 3 scribes (2 wrong — one contradicts anchor)
//   L2 — 4 symbols, 1 anchor, 3 scribes (2 wrong — one contradicts anchor)
//   L3 — 4 symbols, 2 anchors, 3 scribes (2 wrong — each caught by a different anchor)
//   L4 — 5 symbols, 2 anchors, 3 scribes (bijection violation visible in cipher panel)
//   L5 — 5 symbols, 2 anchors, no scribes — pure elimination

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

// MARK: - ScribeClaim

/// A single claim a scribe makes about one cipher mapping.
struct ScribeClaim: Equatable {
    let encoded: CuneiformGlyph
    let decoded: CuneiformGlyph
    /// Whether this claim matches the actual cipher key.
    let isTrue: Bool
}

// MARK: - SumerianScribe

/// A court scribe offering a complete cipher key as sworn testimony.
/// Each level has exactly three scribes. Exactly one is truthful on all counts.
/// The player selects one testimony to work with — if wrong, Decipher reveals it.
struct SumerianScribe: Identifiable {
    let id: Int
    let name: String
    let title: String
    /// Complete cipher key claim — one entry per symbol in the level's alphabet.
    let claims: [ScribeClaim]
    /// Level 1 only: the Egyptian symbol this scribe claims is the foreign mark.
    let foreignMarkSymbol: String?
    /// Whether this scribe's foreign mark claim is correct (vacuously true if nil).
    let foreignMarkCorrect: Bool

    var isTruthful: Bool {
        claims.allSatisfy { $0.isTrue } && foreignMarkCorrect
    }
}

// MARK: - ForeignMarkGate

/// A special sub-puzzle embedded in the Impressions Known panel.
/// One cipher impression cannot be deduced from the anchor alone —
/// the player must identify the correct Egyptian foreign mark to unlock it.
/// Three candidate marks are shown (one per scribe's claim); only one is correct.
/// Correct pick → impression fills in. Wrong pick → brief error flash.
struct ForeignMarkGate {
    /// The encoded cuneiform symbol whose Impressions Known entry is gated.
    let encodedSymbol: CuneiformGlyph
    /// The decoded value revealed when the correct mark is chosen.
    let decodedSymbol: CuneiformGlyph
    /// Three Egyptian mark symbols shown as choices (order displayed as-is).
    let choices: [String]
    /// The one correct choice — the authentic Egyptian foreign mark.
    let correctChoice: String
}

// MARK: - SumerianLevel

struct SumerianLevel: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let lore: String
    let inscriptions: [String]

    let symbols: [CuneiformGlyph]
    let encodedSequence: [CuneiformGlyph]
    let cipherKey: [CuneiformGlyph: CuneiformGlyph]

    /// Pre-revealed decoded positions (anchor stones — physical evidence).
    let revealedPositions: Set<Int>

    /// Three sworn scribes. Empty on Level 5 (pure deduction).
    let scribes: [SumerianScribe]

    /// Optional sub-puzzle in the cipher key panel: player picks the correct Egyptian
    /// foreign mark to unlock one impression. Only Level 1 uses this gate.
    let foreignMarkGate: ForeignMarkGate?

    let decodedMessage: String
    let newGlyphs: [CuneiformGlyph]
    let artifact: String
    let journalTitle: String
    let journalBody: String

    var solution: [CuneiformGlyph] { encodedSequence.map { cipherKey[$0]! } }

    var romanNumeral: String {
        switch id {
        case 1: return "I";  case 2: return "II"; case 3: return "III"
        case 4: return "IV"; case 5: return "V";  default: return "\(id)"
        }
    }

    func isRevealed(_ index: Int) -> Bool { revealedPositions.contains(index) }

    func isSolved(_ decoded: [CuneiformGlyph?]) -> Bool {
        guard decoded.count == solution.count else { return false }
        return decoded.enumerated().allSatisfy { idx, glyph in glyph == solution[idx] }
    }
}

// MARK: - Level Definitions

extension SumerianLevel {
    static let allLevels: [SumerianLevel] = [level1, level2, level3, level4, level5]

    // ─────────────────────────────────────────────────
    // LEVEL 1 · 3 symbols · 1 anchor · 3 scribes
    //
    // Key:   AN→KI   KI→A   A→AN
    // Seq:   AN  KI  A   AN  KI  A
    // Sol:   KI  A   AN  KI  A   AN
    // Anchor: {0} → AN decoded as KI → AN→KI confirmed
    //
    // Scribes (each gives all 3 claims + foreign mark):
    //   Enlil-bani (true):    AN→KI ✓  KI→A ✓   A→AN ✓   mark=𓊹 ✓
    //   Nanna-iddin (false):  AN→A  ✗  KI→AN ✗  A→KI ✗   mark=𓊽 ✗  ← anchor catches AN→A
    //   Ur-Nammu (false):     AN→KI ✓  KI→AN ✗  A→KI ✗   mark=𓃭 ✗  ← anchor doesn't catch; try it
    //
    // Deduction: Nanna-iddin contradicts anchor (AN→KI). Ur-Nammu agrees with anchor
    // but his KI→AN is wrong — the player discovers this when Decipher fails.
    // ─────────────────────────────────────────────────
    static let level1 = SumerianLevel(
        id: 1,
        title: "Tablet of Ur-Namma",
        subtitle: "The Sworn Testimonies",
        lore: "The law code of Ur-Namma is the oldest written law on earth. His scribes encoded their records using a substitution cipher. Three scribes have been called to testify. One anchor position is already revealed — a confirmed pairing pressed into the clay. Select the testimony you believe, unlock the tablet, and begin decoding. If you are wrong, Decipher will tell you.",
        inscriptions: [
            "One position on the tablet is already deciphered — an anchor stone showing one true substitution. Compare it against what each scribe claims for that same symbol. A scribe who contradicts physical evidence has been paid to lie.",
            "Two scribes agree with the anchor. One does not — eliminate him immediately. Between the remaining two, their cipher keys differ on what KI becomes. Select one and decode. Decipher will confirm or deny your choice.",
            "If Decipher flags errors, switch to the other testimony. The tablet will reset. Apply the new key and decode again.",
            "I identified the liar at the anchor stone and chose between the two remaining scribes. One of them also named the Egyptian foreign mark found in the ruins — pressed apart from the inscription, unattached to any word."
        ],
        symbols: [.an, .ki, .a],
        encodedSequence: [.an, .ki, .a, .an, .ki, .a],
        cipherKey: [.an: .ki, .ki: .a, .a: .an],
        revealedPositions: [0],
        scribes: [
            SumerianScribe(id: 1, name: "Enlil-bani", title: "Royal Scribe of Ur-Namma",
                claims: [ScribeClaim(encoded: .an, decoded: .ki, isTrue: true),
                         ScribeClaim(encoded: .ki, decoded: .a,  isTrue: true),
                         ScribeClaim(encoded: .a,  decoded: .an, isTrue: true)],
                foreignMarkSymbol: "𓊹", foreignMarkCorrect: true),
            SumerianScribe(id: 2, name: "Nanna-iddin", title: "Temple Archivist of Nanna",
                claims: [ScribeClaim(encoded: .an, decoded: .a,  isTrue: false),  // contradicts anchor!
                         ScribeClaim(encoded: .ki, decoded: .an, isTrue: false),
                         ScribeClaim(encoded: .a,  decoded: .ki, isTrue: false)],
                foreignMarkSymbol: "𓊽", foreignMarkCorrect: false),
            SumerianScribe(id: 3, name: "Ur-Nammu", title: "Palace Record Keeper",
                claims: [ScribeClaim(encoded: .an, decoded: .ki, isTrue: true),   // matches anchor
                         ScribeClaim(encoded: .ki, decoded: .an, isTrue: false),  // wrong — only Decipher reveals
                         ScribeClaim(encoded: .a,  decoded: .ki, isTrue: false)],
                foreignMarkSymbol: "𓃭", foreignMarkCorrect: false)
        ],
        foreignMarkGate: ForeignMarkGate(
            encodedSymbol: .ki,
            decodedSymbol: .a,
            choices: ["𓊹", "𓊽", "𓃭"],   // Enlil-bani · Nanna-iddin · Ur-Nammu
            correctChoice: "𓊹"             // Egypt's Neter — the divine mark
        ),
        decodedMessage: "In the great above, AN was fixed and named. Something pressed downward through the clay, seeking the dark waters below the world. Heaven was made real the moment it was written.",
        newGlyphs: [.an, .ki, .a],
        artifact: "𒀭",
        journalTitle: "The First Law",
        journalBody: "Ur-Namma's code did not begin with punishment. It began with substitution. AN became KI, KI became A, A became AN — an endless cycle carved into the clay. The priest explained: before we could write law, we had to write the world in secret. The substitution cipher was the first act of both secrecy and trust.\n\nAnd in the margin, apart from the inscription: a sign that did not belong to cuneiform. Egypt's divine mark — the Neter. Left there deliberately. A message from someone who had come before."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 2 · 4 symbols · 1 anchor · 3 scribes
    //
    // Key:   AN→KI   KI→UD   UD→A   A→AN
    // Seq:   AN  A   UD  KI  AN  KI  A   UD
    // Sol:   KI  AN  A   UD  KI  UD  AN  A
    // Anchor: {0} → AN decoded as KI → AN→KI confirmed
    //
    // Scribes (each gives all 4 claims):
    //   Ninlil-ama (true):  AN→KI ✓  KI→UD ✓  UD→A ✓   A→AN ✓
    //   Ur-Enlil (false):   AN→UD ✗  KI→A  ✗  UD→KI ✗  A→AN ✓ (1 accidentally correct)
    //                       ← anchor catches AN→UD immediately
    //   Nanna-ama (false):  AN→KI ✓  KI→AN ✗  UD→KI ✗  A→UD ✗
    //                       ← matches anchor; only Decipher reveals the error
    //
    // Deduction: Ur-Enlil contradicts anchor. Ninlil-ama and Nanna-ama both match it.
    // Player picks between the two; wrong one fails on Decipher.
    // ─────────────────────────────────────────────────
    static let level2 = SumerianLevel(
        id: 2,
        title: "Temple of Nanna",
        subtitle: "The Half-Key",
        lore: "The Moon god Nanna's priests encoded their temple records with a four-sign substitution. Three scribes have testified. One anchor position reveals a confirmed pairing. One scribe contradicts it immediately — eliminate him. Between the remaining two, select the testimony you believe and decode the tablet.",
        inscriptions: [
            "The anchor at position one shows you what AN truly becomes. One scribe contradicts this directly — he is the liar. The other two both agree with the anchor but differ on what KI, UD, and A become.",
            "Select one of the two consistent testimonies and decode the tablet. Decipher will confirm your choice. If it fails, switch to the other testimony — the tablet resets and you try again with the new cipher key.",
            "Four symbols, four substitutions. The full key is in one of the testimonies. Trust the anchor to eliminate one scribe. Trust Decipher to confirm the other.",
            "The moon's light revealed the liar at the first stone. Between the remaining two testimonies, I chose the one whose KI-claim felt consistent with the pattern. Decipher confirmed it."
        ],
        symbols: [.an, .ki, .a, .ud],
        encodedSequence: [.an, .a, .ud, .ki, .an, .ki, .a, .ud],
        cipherKey: [.an: .ki, .ki: .ud, .ud: .a, .a: .an],
        revealedPositions: [0],
        scribes: [
            SumerianScribe(id: 1, name: "Ninlil-ama", title: "Moon Temple Recordkeeper",
                claims: [ScribeClaim(encoded: .an, decoded: .ki, isTrue: true),
                         ScribeClaim(encoded: .ki, decoded: .ud, isTrue: true),
                         ScribeClaim(encoded: .ud, decoded: .a,  isTrue: true),
                         ScribeClaim(encoded: .a,  decoded: .an, isTrue: true)],
                foreignMarkSymbol: nil, foreignMarkCorrect: true),
            SumerianScribe(id: 2, name: "Ur-Enlil", title: "Archive Deputy",
                claims: [ScribeClaim(encoded: .an, decoded: .ud, isTrue: false),  // contradicts anchor!
                         ScribeClaim(encoded: .ki, decoded: .a,  isTrue: false),
                         ScribeClaim(encoded: .ud, decoded: .ki, isTrue: false),
                         ScribeClaim(encoded: .a,  decoded: .an, isTrue: true)],  // 1 accidentally correct
                foreignMarkSymbol: nil, foreignMarkCorrect: true),
            SumerianScribe(id: 3, name: "Nanna-ama", title: "Tablet House Warden",
                claims: [ScribeClaim(encoded: .an, decoded: .ki, isTrue: true),   // matches anchor
                         ScribeClaim(encoded: .ki, decoded: .an, isTrue: false),  // wrong — Decipher reveals
                         ScribeClaim(encoded: .ud, decoded: .ki, isTrue: false),
                         ScribeClaim(encoded: .a,  decoded: .ud, isTrue: false)],
                foreignMarkSymbol: nil, foreignMarkCorrect: true)
        ],
        foreignMarkGate: nil,
        decodedMessage: "In the great below, KI was planted and known. The Moon measured its depths and found: what grows in the dark grows as surely as what grows in the light. Time, it seems, has roots that go very deep.",
        newGlyphs: [.ud],
        artifact: "𒌓",
        journalTitle: "The Moon's Record",
        journalBody: "Nanna's temple kept the first calendar. The scribes encoded UD — the sun — into their records using the moon's cipher, as if to say: the sun belongs to us too, hidden in our sequence. Four signs, four substitutions, one endless cycle. The moon and sun taking turns, each becoming the other."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 3 · 4 symbols · 2 anchors · 3 scribes
    //
    // Key:   AN→A   KI→AN   A→UD   UD→KI
    // Seq:   KI  AN  UD  A   KI  A   AN  UD
    // Sol:   AN  A   KI  UD  AN  UD  A   KI
    // Anchors: {0} KI→AN  |  {2} UD→KI
    //
    // Scribes (each gives all 4 claims):
    //   Adad-shuma (true):    KI→AN ✓  AN→A ✓   A→UD ✓   UD→KI ✓
    //   Enlil-iqisha (false): KI→A  ✗  AN→KI ✗  A→AN ✗   UD→AN ✗  ← anchor 1 catches KI→A
    //   Anu-balassu (false):  KI→AN ✓  AN→UD ✗  A→KI ✗   UD→AN ✗  ← anchor 2 catches UD→AN
    //
    // Deduction: two anchors, two liars — each caught by a different anchor.
    // Only Adad-shuma survives both. Player can verify before selecting.
    // ─────────────────────────────────────────────────
    static let level3 = SumerianLevel(
        id: 3,
        title: "Sacred Precinct of Nippur",
        subtitle: "The Court of Two Witnesses",
        lore: "Nippur's archives used a different cipher rotation. Three scribes have testified, two of them paid to mislead. Two anchor positions are revealed — enough physical evidence to rule out both liars. Each liar contradicts a different anchor. Select the testimony that survives both checks, then decode the inscription.",
        inscriptions: [
            "Two anchor positions are deciphered in the tablet. The first shows what KI becomes. The second shows what UD becomes. Check each scribe's claims against both anchors. A scribe who contradicts either is lying.",
            "Enlil-iqisha makes a claim about KI — check it against the first anchor. Anu-balassu makes a claim about UD — check it against the second. One truth-teller survives both checks.",
            "Select the testimony that agrees with both anchors, then decode the tablet. If you chose correctly, Decipher will confirm it. The fourth substitution — the one neither anchor shows — follows from what remains after the other three are known.",
            "Three scribes, two anchors, two liars. I eliminated them one at a time at the anchor stones. Adad-shuma was the only one left standing."
        ],
        symbols: [.an, .ki, .a, .ud],
        encodedSequence: [.ki, .an, .ud, .a, .ki, .a, .an, .ud],
        cipherKey: [.an: .a, .ki: .an, .a: .ud, .ud: .ki],
        revealedPositions: [0, 2],
        scribes: [
            SumerianScribe(id: 1, name: "Adad-shuma", title: "Archive Master of Nippur",
                claims: [ScribeClaim(encoded: .ki, decoded: .an, isTrue: true),
                         ScribeClaim(encoded: .an, decoded: .a,  isTrue: true),
                         ScribeClaim(encoded: .a,  decoded: .ud, isTrue: true),
                         ScribeClaim(encoded: .ud, decoded: .ki, isTrue: true)],
                foreignMarkSymbol: nil, foreignMarkCorrect: true),
            SumerianScribe(id: 2, name: "Enlil-iqisha", title: "Deputy Recordkeeper",
                claims: [ScribeClaim(encoded: .ki, decoded: .a,  isTrue: false),  // contradicts anchor 1!
                         ScribeClaim(encoded: .an, decoded: .ki, isTrue: false),
                         ScribeClaim(encoded: .a,  decoded: .an, isTrue: false),
                         ScribeClaim(encoded: .ud, decoded: .an, isTrue: false)],
                foreignMarkSymbol: nil, foreignMarkCorrect: true),
            SumerianScribe(id: 3, name: "Anu-balassu", title: "Tablet Room Keeper",
                claims: [ScribeClaim(encoded: .ki, decoded: .an, isTrue: true),   // matches anchor 1
                         ScribeClaim(encoded: .an, decoded: .ud, isTrue: false),
                         ScribeClaim(encoded: .a,  decoded: .ki, isTrue: false),
                         ScribeClaim(encoded: .ud, decoded: .an, isTrue: false)],  // contradicts anchor 2!
                foreignMarkSymbol: nil, foreignMarkCorrect: true)
        ],
        foreignMarkGate: nil,
        decodedMessage: "What reaches upward also reaches downward. As AN is above, KI is below. As the branch grows outward, the root grows inward. The priests of Nippur knew: the world is divided into invisible chambers, and all of them are full.",
        newGlyphs: [],
        artifact: "𒆳",
        journalTitle: "The Invisible Boundaries",
        journalBody: "The Nippur archives were protected not by physical walls but by a substitution cipher that changed with each archive season. No two seasons used the same key. The priests memorized the annual cycle. An outsider who cracked one tablet could not read the next — they would have to start the deduction again."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 4 · 5 symbols · 2 anchors · 3 scribes
    //
    // Key:   AN→GAL   KI→AN   A→KI   UD→A   GAL→UD
    // Seq:   AN  KI  A   UD  GAL  AN  A   KI  GAL  UD
    // Sol:   GAL AN  KI  A   UD   GAL KI  AN  UD   A
    // Anchors: {0} AN→GAL  |  {3} UD→A
    //
    // Scribes (each gives all 5 claims):
    //   Marduk-nadin (true):  AN→GAL ✓  KI→AN ✓  A→KI ✓   UD→A ✓   GAL→UD ✓
    //   Enlil-nasir (false):  AN→KI  ✗  KI→A  ✗  A→AN ✗   UD→KI ✗  GAL→UD ✓ (1 correct)
    //                         ← anchor 1 catches AN→KI immediately
    //   Adad-apla (false):    AN→GAL ✓  KI→GAL ✗  A→AN ✗  UD→A ✓   GAL→KI ✗
    //                         ← both anchors match! But cipher panel shows AN→GAL AND KI→GAL
    //                           — same output twice = bijection violation visible in the panel
    //
    // Deduction: Enlil-nasir caught by anchor 1. Adad-apla matches both anchors but
    // assigns GAL to two inputs — the bijection violation is visible when his key fills
    // the cipher panel. Only Marduk-nadin is fully consistent.
    // ─────────────────────────────────────────────────
    static let level4 = SumerianLevel(
        id: 4,
        title: "Ziggurat of Eridu",
        subtitle: "The Five-Step Descent",
        lore: "Eridu's ziggurat had seven levels; its cipher used five signs. Three scribes have testified. Two anchor positions are revealed. One scribe contradicts the first anchor. A second scribe agrees with both anchors — but his cipher key assigns the same output to two different inputs, which is impossible in a true substitution cipher. Select the testimony with no contradictions and no repeated outputs.",
        inscriptions: [
            "Two anchors are revealed. Check each scribe's claim for AN against anchor one, and for UD against anchor two. One scribe fails immediately at anchor one.",
            "The second liar is subtler: his claims match both anchors, but when his key fills the cipher panel, look carefully. Two different encoded signs map to the same decoded sign. In a one-to-one cipher, every output can only appear once. That is the forgery.",
            "Only one testimony has no anchor contradictions and no repeated outputs. Select it and decode the ten-position inscription.",
            "I found the bijection violation when the cipher panel showed the same sign appearing as an output twice. No true cipher does that. I switched to the third testimony and Decipher confirmed it."
        ],
        symbols: [.an, .ki, .a, .ud, .gal],
        encodedSequence: [.an, .ki, .a, .ud, .gal, .an, .a, .ki, .gal, .ud],
        cipherKey: [.an: .gal, .ki: .an, .a: .ki, .ud: .a, .gal: .ud],
        revealedPositions: [0, 3],
        scribes: [
            SumerianScribe(id: 1, name: "Marduk-nadin", title: "Chief Scribe of Eridu",
                claims: [ScribeClaim(encoded: .an,  decoded: .gal, isTrue: true),
                         ScribeClaim(encoded: .ki,  decoded: .an,  isTrue: true),
                         ScribeClaim(encoded: .a,   decoded: .ki,  isTrue: true),
                         ScribeClaim(encoded: .ud,  decoded: .a,   isTrue: true),
                         ScribeClaim(encoded: .gal, decoded: .ud,  isTrue: true)],
                foreignMarkSymbol: nil, foreignMarkCorrect: true),
            SumerianScribe(id: 2, name: "Enlil-nasir", title: "Tablet House Warden",
                claims: [ScribeClaim(encoded: .an,  decoded: .ki,  isTrue: false),  // contradicts anchor 1!
                         ScribeClaim(encoded: .ki,  decoded: .a,   isTrue: false),
                         ScribeClaim(encoded: .a,   decoded: .an,  isTrue: false),
                         ScribeClaim(encoded: .ud,  decoded: .ki,  isTrue: false),
                         ScribeClaim(encoded: .gal, decoded: .ud,  isTrue: true)],  // 1 accidentally correct
                foreignMarkSymbol: nil, foreignMarkCorrect: true),
            SumerianScribe(id: 3, name: "Adad-apla", title: "Junior Archivist",
                claims: [ScribeClaim(encoded: .an,  decoded: .gal, isTrue: true),   // matches anchor 1
                         ScribeClaim(encoded: .ki,  decoded: .gal, isTrue: false),  // bijection! GAL used twice
                         ScribeClaim(encoded: .a,   decoded: .an,  isTrue: false),
                         ScribeClaim(encoded: .ud,  decoded: .a,   isTrue: true),   // matches anchor 2
                         ScribeClaim(encoded: .gal, decoded: .ki,  isTrue: false)],
                foreignMarkSymbol: nil, foreignMarkCorrect: true)
        ],
        foreignMarkGate: nil,
        decodedMessage: "What grows toward AN-GAL — the great heaven — also grows toward KI-GAL — the great earth. The ziggurat reaches in both directions at once — seven levels descending into the earth, seven levels ascending into heaven, the middle level the world where people live. All growth has two directions. All things reach both ways.",
        newGlyphs: [.gal],
        artifact: "𒃲",
        journalTitle: "The First City's Secret",
        journalBody: "Eridu's priests claimed their city was built before the flood, before the other cities, before time itself. The five-sign cipher was their oldest secret — older than cuneiform, they said, carved in the mind before the stylus existed. AN became GAL and descended through UD and A and KI until it returned to itself. The city and the cipher were both circles."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 5 · 5 symbols · 2 anchors · NO SCRIBES
    //
    // Key:   AN→UD   KI→GAL   A→AN   UD→KI   GAL→A
    // Seq:   AN  KI  A   UD  GAL  AN  KI  GAL  A   UD  KI  AN
    // Sol:   UD  GAL AN  KI  A    UD  GAL A    AN  KI  GAL UD
    // Anchors: {0} AN→UD  |  {1} KI→GAL
    //
    // No scribes. Pure deduction from 2 anchors + bijection elimination.
    //   Known: AN→UD, KI→GAL. Outputs used: UD, GAL.
    //   Remaining inputs: A, UD, GAL. Remaining outputs: AN, KI, A.
    //   From structure: UD→KI, A→AN, GAL→A (only valid bijection).
    // ─────────────────────────────────────────────────
    static let level5 = SumerianLevel(
        id: 5,
        title: "The Great Descent",
        subtitle: "Inanna's Silence",
        lore: "Inanna descended through seven gates. At each she surrendered one truth — until at the bottom she held nothing and understood everything. The scribes who kept her cipher have gone. No testimony remains. Only two anchor stones are pressed into the clay. From them, and from the structure of the cipher itself, everything must be deduced.",
        inscriptions: [
            "Two anchor positions are revealed — the only evidence remaining. Each gives one confirmed pairing. Write them down. Five inputs, five outputs, two already known. Three pairs remain to be found.",
            "Identify the three remaining inputs — the encoded signs not yet explained. Identify the three remaining outputs — the decoded signs not yet assigned. Each remaining input takes one remaining output. Eliminate impossible arrangements.",
            "Look at the tablet. Where does each unknown encoded sign appear? If you tentatively assign an output to an input, does the resulting decoded sequence remain internally consistent? Every encoded sign must decode to the same value wherever it appears.",
            "Inanna gave up everything to gain understanding. Here: the testimonies are gone, the witnesses have fled. Only the marks in the clay remain. The cipher yields its last secret not through trust — but through logic alone."
        ],
        symbols: [.an, .ki, .a, .ud, .gal],
        encodedSequence: [.an, .ki, .a, .ud, .gal, .an, .ki, .gal, .a, .ud, .ki, .an],
        cipherKey: [.an: .ud, .ki: .gal, .a: .an, .ud: .ki, .gal: .a],
        revealedPositions: [0, 1],
        scribes: [],
        foreignMarkGate: nil,
        decodedMessage: "The tree has no top and no bottom — only the endless middle, which is now. Inanna returned from the great below carrying this knowledge: what seemed like descent was always ascent seen from the other side. Something grows in both directions simultaneously, and you are always standing at its center.",
        newGlyphs: [],
        artifact: "𒀀",
        journalTitle: "The Return of Inanna",
        journalBody: "She descended through seven gates. At each one she gave up a piece of her divinity. At the bottom she was nothing. And then she understood: the tree has no top and no bottom — only the endless middle, which is now. She rose carrying that knowledge. The substitution cipher was the same: strip away the surface signs until only the truth beneath remains. Then read it."
    )
}
