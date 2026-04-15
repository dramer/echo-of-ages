// SumerianLevel.swift
// EchoOfAges
//
// Substitution cipher puzzles for the Sumerian / Cuneiform civilization.
//
// Mechanic: A clay tablet shows a row of ENCODED cuneiform symbols.
// Beneath it the player fills in the DECODED symbols.
// A cipher panel shows discovered symbol mappings as the player progresses.
//
// Testimony mechanic: Each level presents 2–3 scribes who have sworn testimony
// about the cipher key. Exactly one scribe tells the truth on every count.
// One or more anchors (pre-revealed decoded positions) provide ground truth
// the player uses to cross-check each scribe's claims and identify the liar(s).
// Once the truth-teller is confirmed, their claims fill the cipher panel and
// the tablet unlocks for decoding.
//
// Level 1 special: The truth-teller also identifies the Egyptian foreign mark
// found in the Sumerian ruins — resolving Egypt's key gate.
//
// Difficulty progression:
//   L1 — 3 symbols, 1 anchor, 2 scribes (1 liar — contradicts anchor directly)
//   L2 — 4 symbols, 1 anchor, 2 scribes (1 liar — contradicts anchor directly)
//   L3 — 4 symbols, 2 anchors, 3 scribes (2 liars — each ruled out by one anchor)
//   L4 — 5 symbols, 2 anchors, 3 scribes (partial liar — bijection violation)
//   L5 — 5 symbols, 1 anchor, 3 scribes (bijection violation as only differentiator)

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
    /// The encoded (input) symbol this scribe claims to have deciphered.
    let encoded: CuneiformGlyph
    /// The decoded (output) symbol this scribe claims the encoded maps to.
    let decoded: CuneiformGlyph
    /// Whether this claim matches the actual cipher key.
    let isTrue: Bool
}

// MARK: - SumerianScribe

/// A court scribe who has sworn testimony about the cipher key.
/// Exactly one scribe per level is truthful — all their claims are correct.
/// Liars make at least one false claim that can be detected using the anchor positions.
struct SumerianScribe: Identifiable {
    let id: Int
    let name: String
    let title: String
    /// Sworn claims about specific cipher mappings.
    let claims: [ScribeClaim]
    /// Level 1 only: the Egyptian symbol this scribe claims is the foreign mark
    /// hidden in the Sumerian ruins. nil on levels 2–5.
    let foreignMarkSymbol: String?
    /// Whether this scribe's foreign mark claim is correct.
    /// Vacuously true (true) when foreignMarkSymbol is nil.
    let foreignMarkCorrect: Bool

    /// A truthful scribe makes only correct cipher claims and (on Level 1)
    /// a correct foreign mark claim.
    var isTruthful: Bool {
        claims.allSatisfy { $0.isTrue } && foreignMarkCorrect
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

    /// Indices where the decoded symbol is pre-revealed as an anchor (ground truth).
    /// These are the evidence the player uses to cross-check scribe testimony.
    let revealedPositions: Set<Int>

    /// The sworn scribes for this level. Exactly one is truthful.
    let scribes: [SumerianScribe]

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
//
// Testimony design rule: every liar makes at least one claim that directly
// contradicts a pre-revealed anchor OR violates the bijection (two symbols
// claiming the same output). The truth-teller is the only scribe consistent
// with ALL anchor positions and ALL bijection constraints.

extension SumerianLevel {
    static let allLevels: [SumerianLevel] = [level1, level2, level3, level4, level5]

    // ─────────────────────────────────────────────────
    // LEVEL 1 · 3 symbols · 1 anchor · 4 blanks
    //
    // Key:   AN→KI   KI→A   A→AN       (cyclic shift)
    // Seq:   AN  KI  A   AN  KI  A
    // Sol:   KI  A   AN  KI  A   AN
    // Anchor: {0}  →  position 0: encoded AN, decoded KI  →  AN→KI revealed
    //
    // Scribe Enlil-bani (truthful):
    //   "AN decodes to KI" ✓  |  "KI decodes to A" ✓  |  foreignMark = 𓊹 ✓
    // Scribe Nanna-iddin (liar):
    //   "AN decodes to A" ✗  CONTRADICTS anchor!
    //   "KI decodes to AN" ✗
    //   foreignMark = 𓊽 ✗
    //
    // Deduction: anchor shows AN→KI; Nanna-iddin claims AN→A → contradiction
    //            → Nanna-iddin lies → Enlil-bani is truthful.
    //            Confirmed: AN→KI, KI→A → A→AN by elimination.
    // ─────────────────────────────────────────────────
    static let level1 = SumerianLevel(
        id: 1,
        title: "Tablet of Ur-Namma",
        subtitle: "The Sworn Testimonies",
        lore: "The law code of Ur-Namma is the oldest written law on earth — pressed into clay before any other civilization dared put justice into words. His scribes encoded their records using a substitution cipher. Two scribes have been called to testify before the court. One anchor position is already revealed, showing you one true pairing. Cross-check each scribe's claims against that evidence. Only one speaks the whole truth.",
        inscriptions: [
            "One position on the tablet is already deciphered — an anchor pressed into the clay itself. It shows you one true substitution: which sign it is, and what it becomes. Now read what each scribe has sworn. One of them contradicts that anchor. The contradiction is proof of a lie.",
            "Enlil-bani and Nanna-iddin cannot both be telling the truth. The anchor shows AN becomes KI. One scribe agrees. The other does not. That disagreement is not ambiguity — it is evidence.",
            "Once you have identified the truth-teller, his testimony fills two pairings. The third pairing writes itself: only one symbol remains unused as an output. There is only one place it can go.",
            "I confirmed Enlil-bani first. His claim matched the anchor. Then Nanna-iddin's claim contradicted it directly. Two scribes, one contradiction — it was not difficult to see which one had been bribed."
        ],
        symbols: [.an, .ki, .a],
        encodedSequence: [.an, .ki, .a, .an, .ki, .a],
        cipherKey: [.an: .ki, .ki: .a, .a: .an],
        revealedPositions: [0],
        scribes: [
            SumerianScribe(
                id: 1,
                name: "Enlil-bani",
                title: "Royal Scribe of Ur-Namma",
                claims: [
                    ScribeClaim(encoded: .an, decoded: .ki, isTrue: true),
                    ScribeClaim(encoded: .ki, decoded: .a,  isTrue: true)
                ],
                foreignMarkSymbol: "𓊹",
                foreignMarkCorrect: true
            ),
            SumerianScribe(
                id: 2,
                name: "Nanna-iddin",
                title: "Temple Archivist of Nanna",
                claims: [
                    ScribeClaim(encoded: .an, decoded: .a,  isTrue: false),   // contradicts anchor!
                    ScribeClaim(encoded: .ki, decoded: .an, isTrue: false)
                ],
                foreignMarkSymbol: "𓊽",
                foreignMarkCorrect: false
            )
        ],
        decodedMessage: "In the great above, AN was fixed and named. Something pressed downward through the clay, seeking the dark waters below the world. Heaven was made real the moment it was written.",
        newGlyphs: [.an, .ki, .a],
        artifact: "𒀭",
        journalTitle: "The First Law",
        journalBody: "Ur-Namma's code did not begin with punishment. It began with substitution. AN became KI, KI became A, A became AN — an endless cycle carved into the clay. The priest explained: before we could write law, we had to write the world in secret. The substitution cipher was the first act of both secrecy and trust.\n\nAnd in the margin, apart from the inscription: a sign that did not belong to cuneiform. Egypt's divine mark — the Neter. Left there deliberately. A message from someone who had come before."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 2 · 4 symbols · 1 anchor · 5 blanks
    //
    // Key:   AN→KI   KI→UD   UD→A   A→AN
    // Seq:   AN  A   UD  KI  AN  KI  A   UD
    // Sol:   KI  AN  A   UD  KI  UD  AN  A
    // Anchor: {0}  →  position 0: encoded AN, decoded KI  →  AN→KI revealed
    //
    // Scribe Ninlil-ama (truthful — gives only 2 of 4 mappings):
    //   "AN decodes to KI" ✓  |  "KI decodes to UD" ✓
    // Scribe Ur-Enlil (liar):
    //   "AN decodes to UD" ✗  CONTRADICTS anchor!
    //   "KI decodes to A" ✗
    //
    // Deduction: anchor shows AN→KI; Ur-Enlil claims AN→UD → contradiction
    //            → Ur-Enlil lies → Ninlil-ama is truthful.
    // Confirmed: AN→KI, KI→UD (from scribe) + AN→KI (anchor).
    // Remaining: A and UD map to {A, AN}. Player deduces from sequence.
    //   Encoded pos 1 = A, pos 2 = UD, pos 6 = A, pos 7 = UD.
    //   Try A→AN: pos 1 = AN, pos 6 = AN. Try UD→A: pos 2 = A, pos 7 = A.
    //   Full solution: KI AN A UD KI UD AN A  ← consistent → correct.
    // ─────────────────────────────────────────────────
    static let level2 = SumerianLevel(
        id: 2,
        title: "Temple of Nanna",
        subtitle: "The Half-Key",
        lore: "The Moon god Nanna's priests encoded their temple records with a four-sign substitution. Two scribes have been brought before the court. The honest scribe is modest — he will only swear to the two pairings he personally witnessed. The other two substitutions you must work out from the tablet itself. One anchor is pre-revealed. Identify the liar, use what the truth-teller knows, and deduce the rest.",
        inscriptions: [
            "The anchor shows you the first pairing. One scribe agrees with it; the other contradicts it. Once the liar is eliminated, you have two confirmed pairings — but four are needed. The remaining two must come from the tablet itself.",
            "Look at the encoded symbols that are not yet explained by the two known pairings. Which inputs remain? Which outputs have not yet been assigned? In a one-to-one cipher, each output appears exactly once — use that constraint to narrow the possibilities.",
            "The two unknown mappings each have only two possible answers. Apply one tentatively: does it create a consistent decoded sequence? If the same symbol appears in the solution where you expect it, you are on the right path.",
            "I found the last two pairings by looking at positions where A and UD appeared as encoded signs. Only two decoded values were left unclaimed. One arrangement made the inscription coherent. The other did not."
        ],
        symbols: [.an, .ki, .a, .ud],
        encodedSequence: [.an, .a, .ud, .ki, .an, .ki, .a, .ud],
        cipherKey: [.an: .ki, .ki: .ud, .ud: .a, .a: .an],
        revealedPositions: [0],
        scribes: [
            SumerianScribe(
                id: 1,
                name: "Ninlil-ama",
                title: "Moon Temple Recordkeeper",
                claims: [
                    ScribeClaim(encoded: .an, decoded: .ki, isTrue: true),
                    ScribeClaim(encoded: .ki, decoded: .ud, isTrue: true)
                ],
                foreignMarkSymbol: nil,
                foreignMarkCorrect: true
            ),
            SumerianScribe(
                id: 2,
                name: "Ur-Enlil",
                title: "Archive Deputy",
                claims: [
                    ScribeClaim(encoded: .an, decoded: .ud, isTrue: false),   // contradicts anchor!
                    ScribeClaim(encoded: .ki, decoded: .a,  isTrue: false)
                ],
                foreignMarkSymbol: nil,
                foreignMarkCorrect: true
            )
        ],
        decodedMessage: "In the great below, KI was planted and known. The Moon measured its depths and found: what grows in the dark grows as surely as what grows in the light. Time, it seems, has roots that go very deep.",
        newGlyphs: [.ud],
        artifact: "𒌓",
        journalTitle: "The Moon's Record",
        journalBody: "Nanna's temple kept the first calendar. The scribes encoded UD — the sun — into their records using the moon's cipher, as if to say: the sun belongs to us too, hidden in our sequence. Four signs, four substitutions, one endless cycle. The moon and sun taking turns, each becoming the other."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 3 · 4 symbols · 2 anchors · 5 blanks
    //
    // Key:   AN→A   KI→AN   A→UD   UD→KI
    // Seq:   KI  AN  UD  A   KI  A   AN  UD
    // Sol:   AN  A   KI  UD  AN  UD  A   KI
    // Anchors: {0, 2}
    //   position 0: encoded KI, decoded AN  →  KI→AN
    //   position 2: encoded UD, decoded KI  →  UD→KI
    //
    // Scribe Adad-shuma (truthful):
    //   "KI decodes to AN" ✓  |  "AN decodes to A" ✓  |  "A decodes to UD" ✓
    // Scribe Enlil-iqisha (liar):
    //   "KI decodes to A" ✗  CONTRADICTS anchor 1!
    //   "AN decodes to KI" ✗
    //   "A decodes to AN" ✗
    // Scribe Anu-balassu (liar):
    //   "KI decodes to AN" ✓  (matches anchor 1)
    //   "AN decodes to UD" ✗
    //   "UD decodes to AN" ✗  CONTRADICTS anchor 2!
    //
    // Deduction: Enlil-iqisha says KI→A, anchor 1 shows KI→AN → eliminated.
    //            Anu-balassu says UD→AN, anchor 2 shows UD→KI → eliminated.
    //            Only Adad-shuma is consistent with both anchors → truthful.
    // ─────────────────────────────────────────────────
    static let level3 = SumerianLevel(
        id: 3,
        title: "Sacred Precinct of Nippur",
        subtitle: "The Court of Two Witnesses",
        lore: "Nippur's archives were protected by a different cipher rotation — not the same as the Moon Temple's. Three scribes have been called to testify, but two have been paid to mislead. Two anchor positions are revealed in the tablet. Each liar contradicts one of them. Your task: use both anchors to eliminate both liars and find the single scribe whose testimony survives all scrutiny.",
        inscriptions: [
            "Two anchor positions are deciphered in the tablet — two confirmed pairings. Read each one carefully: which encoded sign, which decoded sign. Now read each scribe's testimony. Each liar contradicts exactly one anchor. If a scribe claims a pairing that the tablet itself contradicts — that scribe has lied.",
            "Enlil-iqisha makes a claim about KI. The first anchor shows what KI actually becomes. Compare them. Anu-balassu makes a claim about UD. The second anchor shows what UD actually becomes. Compare that too. One truth-teller survives both comparisons.",
            "Once the two liars are eliminated, the truth-teller's remaining claims fill three pairings. The fourth writes itself. With all four substitutions known, work across every blank position in the tablet.",
            "Three scribes. Two anchors. Two liars, one for each anchor. I eliminated Enlil-iqisha at the first stone, Anu-balassu at the second. Adad-shuma was the only one left standing."
        ],
        symbols: [.an, .ki, .a, .ud],
        encodedSequence: [.ki, .an, .ud, .a, .ki, .a, .an, .ud],
        cipherKey: [.an: .a, .ki: .an, .a: .ud, .ud: .ki],
        revealedPositions: [0, 2],
        scribes: [
            SumerianScribe(
                id: 1,
                name: "Adad-shuma",
                title: "Archive Master of Nippur",
                claims: [
                    ScribeClaim(encoded: .ki, decoded: .an, isTrue: true),
                    ScribeClaim(encoded: .an, decoded: .a,  isTrue: true),
                    ScribeClaim(encoded: .a,  decoded: .ud, isTrue: true)
                ],
                foreignMarkSymbol: nil,
                foreignMarkCorrect: true
            ),
            SumerianScribe(
                id: 2,
                name: "Enlil-iqisha",
                title: "Deputy Recordkeeper",
                claims: [
                    ScribeClaim(encoded: .ki, decoded: .a,  isTrue: false),   // contradicts anchor 1!
                    ScribeClaim(encoded: .an, decoded: .ki, isTrue: false),
                    ScribeClaim(encoded: .a,  decoded: .an, isTrue: false)
                ],
                foreignMarkSymbol: nil,
                foreignMarkCorrect: true
            ),
            SumerianScribe(
                id: 3,
                name: "Anu-balassu",
                title: "Tablet Room Keeper",
                claims: [
                    ScribeClaim(encoded: .ki, decoded: .an, isTrue: true),    // matches anchor 1
                    ScribeClaim(encoded: .an, decoded: .ud, isTrue: false),
                    ScribeClaim(encoded: .ud, decoded: .an, isTrue: false)    // contradicts anchor 2!
                ],
                foreignMarkSymbol: nil,
                foreignMarkCorrect: true
            )
        ],
        decodedMessage: "What reaches upward also reaches downward. As AN is above, KI is below. As the branch grows outward, the root grows inward. The priests of Nippur knew: the world is divided into invisible chambers, and all of them are full.",
        newGlyphs: [],
        artifact: "𒆳",
        journalTitle: "The Invisible Boundaries",
        journalBody: "The Nippur archives were protected not by physical walls but by a substitution cipher that changed with each archive season. No two seasons used the same key. The priests memorized the annual cycle. An outsider who cracked one tablet could not read the next — they would have to start the deduction again."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 4 · 5 symbols · 2 anchors · 6 blanks
    //
    // Key:   AN→GAL   KI→AN   A→KI   UD→A   GAL→UD
    // Seq:   AN  KI  A   UD  GAL  AN  A   KI  GAL  UD
    // Sol:   GAL AN  KI  A   UD   GAL KI  AN  UD   A
    // Anchors: {0, 3}
    //   position 0: encoded AN, decoded GAL  →  AN→GAL
    //   position 3: encoded UD, decoded A    →  UD→A
    //
    // Scribe Marduk-nadin (truthful):
    //   "AN→GAL" ✓  |  "KI→AN" ✓  |  "A→KI" ✓  |  "UD→A" ✓
    // Scribe Enlil-nasir (liar):
    //   "AN→KI" ✗  CONTRADICTS anchor 1!
    //   "KI→A" ✗
    //   "A→AN" ✗
    // Scribe Adad-apla (partial liar — bijection violation):
    //   "AN→GAL" ✓  (matches anchor 1)
    //   "UD→A" ✓   (matches anchor 2)
    //   "KI→GAL" ✗  GAL is already AN's output — cannot be KI's output too.
    //               This is a bijection violation, not just a factual error.
    //
    // Deduction: Enlil-nasir says AN→KI, anchor 1 shows AN→GAL → eliminated.
    //            Adad-apla's third claim "KI→GAL" is impossible: AN→GAL (anchor)
    //            already uses GAL as an output; a one-to-one cipher cannot assign
    //            GAL to KI as well → bijection violation → eliminated.
    //            Only Marduk-nadin remains → truthful.
    // ─────────────────────────────────────────────────
    static let level4 = SumerianLevel(
        id: 4,
        title: "Ziggurat of Eridu",
        subtitle: "The Five-Step Descent",
        lore: "Eridu's ziggurat had seven levels, but its cipher used five. Three scribes have testified — one honest, one who contradicts the physical evidence, and one who has made a subtler error: he has assigned the same output symbol to two different inputs. In a true substitution cipher, every input maps to a unique output. A cipher that assigns the same output twice is no cipher at all.",
        inscriptions: [
            "Two anchor positions are revealed. They show you two confirmed pairings. Read each scribe's testimony carefully. Enlil-nasir contradicts one anchor directly. Adad-apla's claims are trickier — he agrees with both anchors, but one of his other claims assigns an output that is already taken. In a one-to-one cipher, every output can only appear once.",
            "The key insight: the first anchor already tells you what AN maps to. If any scribe then claims that a different sign also maps to that same output, that scribe has made a logical error. The cipher cannot assign the same output to two inputs. This is the flaw to find.",
            "Once both false scribes are eliminated, the truth-teller's four claims fill four pairings. The fifth writes itself: the remaining input and the remaining output belong together.",
            "I recognized Adad-apla's error when I checked his third claim against the first anchor stone. The output he named for KI was already spoken for. He had not thought his false testimony all the way through. A liar's trap: consistency requires more effort than honesty."
        ],
        symbols: [.an, .ki, .a, .ud, .gal],
        encodedSequence: [.an, .ki, .a, .ud, .gal, .an, .a, .ki, .gal, .ud],
        cipherKey: [.an: .gal, .ki: .an, .a: .ki, .ud: .a, .gal: .ud],
        revealedPositions: [0, 3],
        scribes: [
            SumerianScribe(
                id: 1,
                name: "Marduk-nadin",
                title: "Chief Scribe of Eridu",
                claims: [
                    ScribeClaim(encoded: .an,  decoded: .gal, isTrue: true),
                    ScribeClaim(encoded: .ki,  decoded: .an,  isTrue: true),
                    ScribeClaim(encoded: .a,   decoded: .ki,  isTrue: true),
                    ScribeClaim(encoded: .ud,  decoded: .a,   isTrue: true)
                ],
                foreignMarkSymbol: nil,
                foreignMarkCorrect: true
            ),
            SumerianScribe(
                id: 2,
                name: "Enlil-nasir",
                title: "Tablet House Warden",
                claims: [
                    ScribeClaim(encoded: .an,  decoded: .ki,  isTrue: false),   // contradicts anchor 1!
                    ScribeClaim(encoded: .ki,  decoded: .a,   isTrue: false),
                    ScribeClaim(encoded: .a,   decoded: .an,  isTrue: false)
                ],
                foreignMarkSymbol: nil,
                foreignMarkCorrect: true
            ),
            SumerianScribe(
                id: 3,
                name: "Adad-apla",
                title: "Junior Archivist",
                claims: [
                    ScribeClaim(encoded: .an,  decoded: .gal, isTrue: true),    // matches anchor 1
                    ScribeClaim(encoded: .ud,  decoded: .a,   isTrue: true),    // matches anchor 2
                    ScribeClaim(encoded: .ki,  decoded: .gal, isTrue: false)    // bijection violation! GAL already taken by AN
                ],
                foreignMarkSymbol: nil,
                foreignMarkCorrect: true
            )
        ],
        decodedMessage: "What grows toward AN-GAL — the great heaven — also grows toward KI-GAL — the great earth. The ziggurat reaches in both directions at once — seven levels descending into the earth, seven levels ascending into heaven, the middle level the world where people live. All growth has two directions. All things reach both ways.",
        newGlyphs: [.gal],
        artifact: "𒃲",
        journalTitle: "The First City's Secret",
        journalBody: "Eridu's priests claimed their city was built before the flood, before the other cities, before time itself. The five-sign cipher was their oldest secret — older than cuneiform, they said, carved in the mind before the stylus existed. AN became GAL and descended through UD and A and KI until it returned to itself. The city and the cipher were both circles."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 5 · 5 symbols · 2 anchors · 8 blanks · NO SCRIBES
    //
    // Key:   AN→UD   KI→GAL   A→AN   UD→KI   GAL→A
    // Seq:   AN  KI  A   UD  GAL  AN  KI  GAL  A   UD  KI  AN
    // Sol:   UD  GAL AN  KI  A    UD  GAL A    AN  KI  GAL UD
    // Anchors: {0, 1}
    //   position 0: encoded AN, decoded UD  →  AN→UD
    //   position 1: encoded KI, decoded GAL →  KI→GAL
    //
    // NO SCRIBES. The scribes have left. Two anchors are all that remain.
    //
    // Deduction from anchors alone:
    //   AN→UD and KI→GAL are known. Outputs used: UD, GAL.
    //   Remaining inputs: A, UD, GAL. Remaining outputs: AN, KI, A.
    //   Look at the sequence — encoded A appears at positions 2, 8.
    //   Look at encoded UD: position 3. Look at encoded GAL: positions 4, 7.
    //   From bijection: A→{AN, KI, or A}. UD→{AN, KI, or A}. GAL→{AN, KI, or A}.
    //   Each remaining output used exactly once across these three inputs.
    //   Step: UD→KI, A→AN, GAL→A are the only valid bijection. Verify against sol.
    // ─────────────────────────────────────────────────
    static let level5 = SumerianLevel(
        id: 5,
        title: "The Great Descent",
        subtitle: "Inanna's Silence",
        lore: "Inanna descended through seven gates. At each gate she surrendered one truth — crown, robe, lapis beads, breastplate, ring, scepter, robe of ladyship — until at the bottom she held nothing and understood everything. The scribes who kept her cipher have gone. No testimony remains. Only two anchor stones are pressed into the clay. From them, and from the structure of the cipher itself, everything must be deduced.",
        inscriptions: [
            "Two anchor positions are revealed — the only evidence remaining. Each gives one confirmed pairing: one encoded sign and what it becomes. Write them down. Five inputs, five outputs, two already known. Three pairs remain to be found.",
            "Identify the three remaining inputs — the encoded signs not yet explained by the two anchors. Identify the three remaining outputs — the decoded signs not yet assigned to any input. In a one-to-one cipher, each of the three remaining inputs must take one of the three remaining outputs. There are only six possible arrangements. Eliminate impossible ones.",
            "Look at the tablet. Which encoded signs appear most often? Where does each unknown encoded sign appear in the sequence? If you tentatively assign an output to an input, does the resulting decoded sequence look internally consistent? Every symbol appearing multiple times as the same encoded sign must decode to the same value, every time.",
            "Inanna gave up everything to gain understanding. Here: the testimonies are gone, the witnesses have fled, the court is empty. Only the marks in the clay remain. The cipher yields its last secret not through trust — but through logic alone."
        ],
        symbols: [.an, .ki, .a, .ud, .gal],
        encodedSequence: [.an, .ki, .a, .ud, .gal, .an, .ki, .gal, .a, .ud, .ki, .an],
        cipherKey: [.an: .ud, .ki: .gal, .a: .an, .ud: .ki, .gal: .a],
        revealedPositions: [0, 1],
        scribes: [],
        decodedMessage: "The tree has no top and no bottom — only the endless middle, which is now. Inanna returned from the great below carrying this knowledge: what seemed like descent was always ascent seen from the other side. Something grows in both directions simultaneously, and you are always standing at its center.",
        newGlyphs: [],
        artifact: "𒀀",
        journalTitle: "The Return of Inanna",
        journalBody: "She descended through seven gates. At each one she gave up a piece of her divinity. At the bottom she was nothing. And then she understood: the tree has no top and no bottom — only the endless middle, which is now. She rose carrying that knowledge. The substitution cipher was the same: strip away the surface signs until only the truth beneath remains. Then read it."
    )
}
