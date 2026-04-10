// TreeOfLife.swift
// EchoOfAges
//
// Constants for the Tree of Life meta-puzzle.
//
// TIER PROGRESSION (gate-key chain):
// Each civilization produces a gate-key symbol at Level 5. That key is
// required by the next civilization to unlock its own Level 5 element.
//
//   Egypt ──► Norse    (needs Egypt's Djed 𓊽)
//   Egypt ──► Sumerian (needs Egypt's Neter 𓊹)
//   Norse ──► Maya     (needs Norse's Laguz ᛚ)
//   Sumerian ──► Celtic (needs Sumerian's AN 𒀭)
//   Maya ──► China slot 1 (needs Maya's Nion ᚅ)
//   Celtic ──► China slot 2 (needs Celtic's Nion ᚅ)
//   China ──► Mandu Tablet mastermind
//
// MANDU TABLET MASTERMIND (7 symbols, 6 slots):
// Each civilization also contributes one tree-part symbol to the mastermind.
// A 7th symbol — the Ramer mark ᚱ — was already on the tablet when found.
// The player places 6 symbols in the correct order; ᚱ is always left over.
//
// Correct placement order (left to right):
//   BOUGH · WATER · TRUNK · ROOTS · FROND · SOLAR
//   Sumerian · Maya · Egypt · Norse · Celtic · China

import Foundation

// MARK: - Tree of Life Keys

enum TreeOfLifeKeys {

    // MARK: The Six Keys

    /// Djed pillar hieroglyph — the axis that holds everything up. Clue for Norse Level 1.
    static let egypt        = "𓊽"

    /// Neter hieroglyph — Egyptian symbol for "the divine / god". Clue for Sumerian Level 1.
    /// Egypt's ruins contain two foreign marks: the Djed (pointing to Norse) and Neter (pointing to Sumerian).
    static let egyptNeter   = "𓊹"

    /// Laguz rune — water, what the branches reach toward in the deep well.
    static let norse    = "ᛚ"

    /// AN cuneiform mark — what was above before the flood, the divine anchor.
    static let sumerian = "𒀭"

    /// Nion/Ash, value 5 — the water was always reaching upward toward the ash.
    static let maya     = "ᚅ"

    /// Nion/Ash, value 5 — the same symbol from a second source. The player's aha moment.
    static let celtic   = "ᚅ"

    /// Qian trigram — three unbroken lines, heaven, the light that reveals all form.
    static let china    = "☰"

    // MARK: - Ramer Mark

    /// The seventh mastermind symbol — attached to no civilization.
    /// References: Raidho rune (road/journey), German heritage, the Ramer name, cattle farmers.
    /// It was carved on the Mandu Tablet before any of the six teaching tablets were found.
    /// In the mastermind game ᚱ is always left over — it occupies no slot; it was already there.
    static let ramerMark = "ᚱ"

    // MARK: - Tree Part Symbols

    /// Each civilization's contribution to the Mandu Tablet mastermind.
    /// These represent the civilization's named role in the Tree of Life
    /// (TRUNK · ROOTS · BOUGH · WATER · FROND · SOLAR).
    ///
    /// Distinct from the gate-key symbols used in the tier-progression unlock chain —
    /// those are the foreign marks found hidden inside each civilization's final ruins.

    static let treeTrunk = "𓊽"  // Egypt   — Djed pillar, the World Axis · TRUNK
    static let treeRoots = "ᛇ"  // Norse   — Eihwaz, the cosmic Yew of Yggdrasil · ROOTS
    static let treeBough = "𒀭"  // Sumerian — AN, the heavenward reach · BOUGH
    static let treeWater = "☵"  // Maya    — Kan trigram, the primordial waters · WATER
    static let treeFrond = "ᚅ"  // Celtic  — Nion/Ash, frond of the sacred grove · FROND
    static let treeSolar = "☰"  // Chinese — Qian trigram, heaven and light · SOLAR

    /// Returns the tree-part symbol for a civilization.
    static func treePartSymbol(for civ: CivilizationID) -> String {
        switch civ {
        case .egyptian: return treeTrunk
        case .norse:    return treeRoots
        case .sumerian: return treeBough
        case .maya:     return treeWater
        case .celtic:   return treeFrond
        case .chinese:  return treeSolar
        }
    }

    /// All 7 mastermind symbols in display order: 6 tree parts + the Ramer mark.
    static let masterMindSymbols: [String] = [
        treeTrunk, treeRoots, treeBough, treeWater, treeFrond, treeSolar, ramerMark
    ]

    /// The correct 6-symbol left-to-right arrangement for the Mandu Tablet mastermind.
    /// Derived from `tabletOrder` — each civilization's tree-part symbol in tablet sequence.
    /// The Ramer mark is always left over and is never placed in a slot.
    static var masterMindSolution: [String] {
        tabletOrder.map { treePartSymbol(for: $0) }
    }

    // MARK: Mandu Tablet

    /// Correct left-to-right placement order.
    /// BOUGH → WATER → TRUNK → ROOTS → FROND → SOLAR
    static let tabletOrder: [CivilizationID] = [
        .sumerian,  // BOUGH — the great branch; oldest carved stone above the flood
        .maya,      // WATER — the tree grows from the primordial sea
        .egyptian,  // TRUNK — the World Pillar, the axis connecting all
        .norse,     // ROOTS — Yggdrasil's deep roots threading all nine worlds
        .celtic,    // FROND — each Ogham letter a leaf, each leaf a word
        .chinese    // SOLAR — the form only visible in the light above
    ]

    // MARK: Key Lookup

    /// The key symbol produced by a civilization on Level 5 completion.
    static func produced(by civ: CivilizationID) -> String? {
        switch civ {
        case .egyptian: return egypt
        case .norse:    return norse
        case .sumerian: return sumerian
        case .maya:     return maya
        case .celtic:   return celtic
        case .chinese:  return china
        }
    }

    /// The single key symbol required by a civilization to unlock its Level 5 element.
    /// Returns nil for Egypt (no key required) and China (two keys — use chinaRequiredKeys).
    static func required(by civ: CivilizationID) -> String? {
        switch civ {
        case .egyptian: return nil           // first — no key required
        case .norse:    return egypt         // needs Egypt's Djed pillar 𓊽
        case .sumerian: return egyptNeter    // needs Egypt's Neter mark 𓊹 (the divine)
        case .maya:     return norse     // needs Norse's Laguz rune
        case .celtic:   return sumerian  // needs Sumerian's AN mark
        case .chinese:  return nil       // two keys — see chinaRequiredKeys
        }
    }

    /// The two keys China requires — one from Maya, one from Celtic.
    /// Both happen to be "ᚅ" but they arrive from different civilizations.
    static let chinaRequiredKeys: [String] = [maya, celtic]

    // MARK: Choice Picker

    /// Six choices shown when a civilization's Level 5 missing element is tapped.
    /// The correct key is included; the rest are plausible decoys from the same writing system.
    static func choices(for civ: CivilizationID) -> [String] {
        switch civ {
        case .norse:    return ["𓊽", "𓅱", "𓆑", "𓇳", "𓈖", "𓊪"]   // Egyptian hieroglyphs
        case .sumerian: return ["𓊽", "𓏏", "𓂀", "𓇌", "𓊹", "𓃭"]   // Egyptian hieroglyphs
        case .maya:     return ["ᛚ", "ᚠ", "ᚢ", "ᛟ", "ᛏ", "ᚾ"]      // Norse runes
        case .celtic:   return ["𒀭", "𒀯", "𒆷", "𒄑", "𒐈", "𒀰"]   // Sumerian cuneiform
        case .chinese:  return []   // two pickers — see chinaSlot1Choices / chinaSlot2Choices
        case .egyptian: return []   // no key required
        }
    }

    /// China's first slot choices — player must pick Maya's ᚅ.
    static let chinaSlot1Choices: [String] = ["ᚅ", "ᚁ", "ᚂ", "ᚃ", "ᚄ", "ᛚ"]

    /// China's second slot choices — player must pick Celtic's ᚅ.
    static let chinaSlot2Choices: [String] = ["ᚅ", "𒀭", "𓊽", "ᛚ", "𓇳", "𒆷"]

    // MARK: - Key Gate UI

    /// Short label shown in the gate screen identifying where the mystery mark was found.
    static func gateSourceLabel(for civ: CivilizationID) -> String {
        switch civ {
        case .norse, .sumerian: return "Found in Egyptian ruins"
        case .maya:             return "Found among Norse runestones"
        case .celtic:           return "Found in Sumerian tablets"
        case .chinese:          return "Found in Maya and Celtic ruins"
        case .egyptian:         return ""
        }
    }

    /// Context paragraph shown in the gate screen before the cycling cell(s).
    static func gateIntroText(for civ: CivilizationID) -> String {
        switch civ {
        case .norse:
            return "Among the final Egyptian hieroglyphs, a mark was found carved in a different style — not part of their known script. It was placed there deliberately.\n\nWhich symbol did they leave behind?"
        case .sumerian:
            return "Two marks were found in the Egyptian ruins. The second — carved apart from the first, unattached to any word — is Egypt's symbol for the divine itself. The mark placed before the name of any god.\n\nWhich symbol did they leave behind?"
        case .maya:
            return "At the end of the final Norse runestone, one mark was carved in a different hand — not one of the Elder Futhark letters used in these pathways. It was not Norse.\n\nWhat mark did they leave?"
        case .celtic:
            return "In the margin of the final Sumerian tablet, a sign was isolated from the inscription. It does not belong to cuneiform. It was set apart on purpose.\n\nWhat is it?"
        case .chinese:
            return "Two marks were found in two separate excavations — one beside a Maya calendar wheel, one at the end of a Celtic Ogham stone. Neither belongs to its host civilization.\n\nIdentify both marks before you begin."
        case .egyptian:
            return ""
        }
    }

    // MARK: - Acrostic Letters

    /// The acrostic letter for a civilization's puzzle level, spelling out its Tree of Life role.
    /// Egypt=TRUNK, Norse=ROOTS, Sumerian=BOUGH, Maya=WATER, Celtic=FROND, Chinese=SOLAR
    /// levelIndex is 0-based (0 = Level 1).
    static func acrosticLetter(for civ: CivilizationID, levelIndex: Int) -> Character {
        let word: String
        switch civ {
        case .egyptian: word = "TRUNK"
        case .norse:    word = "ROOTS"
        case .sumerian: word = "BOUGH"
        case .maya:     word = "WATER"
        case .celtic:   word = "FROND"
        case .chinese:  word = "SOLAR"
        }
        guard levelIndex >= 0, levelIndex < word.count else { return "?" }
        return word[word.index(word.startIndex, offsetBy: levelIndex)]
    }

    // MARK: - Key Discovery Diary Entries

    /// Title of the field-diary entry written when a civilization's Level 5 is completed.
    static func keyDiscoveryTitle(for civ: CivilizationID) -> String {
        switch civ {
        case .egyptian: return "The Djed Mark"
        case .norse:    return "The Water Rune"
        case .sumerian: return "The Heaven Mark"
        case .maya:     return "The Foreign Mark"
        case .celtic:   return "The Ash Mark — Again"
        case .chinese:  return "The Heaven Trigram"
        }
    }

    /// Diary entry body text — Dr. Mandu's field note about the mysterious symbol found at Level 5.
    static func keyDiscoveryBody(for civ: CivilizationID) -> String {
        switch civ {
        case .egyptian:
            return """
            Beyond the final seal, among the hieroglyphs I had spent weeks learning, two marks stood apart. Neither belonged to our five-symbol set. Both carved deeper — more deliberate. Left by someone who knew what they were doing.

            The first: a vertical column with horizontal bands and a flat base. The Djed pillar. Spine of Osiris. Symbol of stability — of what endures when everything else falls away.

            The second, a few hand-widths to the right: the Neter. Egypt's mark for the divine itself — the sign placed before the name of any god. It stood alone, unattached to any word.

            Two marks. Two messages. Both addressed, I believe, to whoever came next. I do not yet know where they point. But I have copied them carefully.
            """
        case .norse:
            return """
            The final runestone solved. The last path closed. And there, in a corner that should have been blank, a rune carved in a different hand.

            Not one of the five path-runes I had mapped — not Fehu, Uruz, Thurisaz, Ansuz, or Raidho. This was Laguz. The water rune. The flow-toward-the-lowest-place rune.

            Left by a different traveller, at the end of a different journey. I copied it carefully. I do not yet know where it points.
            """
        case .sumerian:
            return """
            I was nearly finished transcribing when I found it. Tucked in the margin, isolated from the inscription — the AN mark. The divine determinative, placed before the names of gods in the oldest writing on earth.

            Here it stands alone. Not part of any sentence. Like a name without a body. Like a door with nothing behind it.

            Or perhaps: a door with something I cannot yet see behind it. I noted it carefully. I will remember it.
            """
        case .maya:
            return """
            The Calendar Round solved — three wheels turning together. And beside the Long Wheel's final position, a mark I had never seen in any Maya codex. Not a Maya glyph. Not from this hemisphere at all.

            Five short strokes crossing a single stem line.

            I have spent two days staring at it. Three colleagues — none recognized it as belonging here. Someone placed it deliberately. Someone knew what they were leaving behind.

            I do not know yet what it means to find it here.
            """
        case .celtic:
            return """
            The final Ogham stone solved. The complete sequence. And one mark left over — one I had not accounted for. It was Nion, the ash-tree mark, but placed separately, after the inscription ends. As if to say: take this with you.

            I copied it. And then I stopped.

            I have seen this mark before. Not in any Ogham record. In a Maya ruin, half a world away, four months ago. The same five strokes. The same stem.

            The same hand? That is impossible. And yet here it is.
            """
        case .chinese:
            return """
            The master's tray solved. The inscription read. And in the very last character, separately carved into the lacquer finish, a trigram I did not expect. Three unbroken lines. Qian. Heaven. The creative force — the beginning of the I Ching's sixty-four hexagrams.

            Not an oracle bone character. Not from this tradition at all. Someone added it knowing it would be found.

            Six marks. Six months. Six separate sites, no trade route connecting them. I lay them side by side in my notes and cannot explain what I am looking at.

            But I think I am beginning to.
            """
        }
    }
}
