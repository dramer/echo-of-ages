// Civilization.swift
// EchoOfAges
//
// Six ancient civilizations, each with a writing system and a set of puzzles.
// Completing a civilization's inscriptions decodes one line of the Tablet of Mandu —
// the Tree of Life story written in all six scripts by an unknown hand.

import SwiftUI

// MARK: - Civilization ID

enum CivilizationID: String, CaseIterable, Identifiable, Codable {
    case egyptian  = "egyptian"
    case norse     = "norse"
    case sumerian  = "sumerian"
    case maya      = "maya"
    case celtic    = "celtic"
    case chinese   = "chinese"

    var id: String { rawValue }
}

// MARK: - Script Symbol

struct ScriptSymbol: Identifiable {
    let id: String
    let character: String       // Unicode character
    let transliteration: String // how it sounds
    let meaning: String
    let civilization: CivilizationID
}

// MARK: - Civilization

struct Civilization: Identifiable {
    let id: CivilizationID
    let name: String
    let region: String
    let era: String
    let emblem: String          // Unicode symbol representing this civilization
    let scriptName: String
    let accentHex: String
    let symbols: [ScriptSymbol]
    let isUnlocked: Bool
    let levelCount: Int
    let tabletLine: String      // The line of the Tree of Life this civilization reveals

    var accentColor: Color {
        Color(hex: accentHex) ?? .goldMid
    }
}

// MARK: - Civilization Definitions

extension Civilization {

    static let all: [Civilization] = [
        egyptian, norse, sumerian, maya, celtic, chinese
    ]

    // ── EGYPTIAN ─────────────────────────────────────────
    // Tablet line: "From eternal sky, through the eye of wisdom,
    //               where waters flow and lions guard —
    //               the first root was planted."
    static let egyptian = Civilization(
        id: .egyptian,
        name: "Ancient Egypt",
        region: "Nile Valley, North Africa",
        era: "3200 – 400 BCE",
        emblem: "𓇳",
        scriptName: "Hieroglyphics",
        accentHex: "C8961E",
        symbols: [
            ScriptSymbol(id: "eye",   character: "𓂀", transliteration: "ḥr",  meaning: "Eye — Wisdom & Sight",    civilization: .egyptian),
            ScriptSymbol(id: "owl",   character: "𓅓", transliteration: "m",   meaning: "Owl — Knowledge & Night", civilization: .egyptian),
            ScriptSymbol(id: "water", character: "𓈖", transliteration: "n",   meaning: "Water — Life & Renewal",  civilization: .egyptian),
            ScriptSymbol(id: "lion",  character: "𓃭", transliteration: "rw",  meaning: "Lion — Strength & Power", civilization: .egyptian),
            ScriptSymbol(id: "sky",   character: "𓇯", transliteration: "pt",  meaning: "Sky — Eternity & Heaven", civilization: .egyptian),
        ],
        isUnlocked: true,
        levelCount: 5,
        tabletLine: "From eternal sky, through the eye of wisdom, where waters flow and lions stand guard — the first root was planted in silence, before memory began."
    )

    // ── NORSE ────────────────────────────────────────────
    // Tablet line: "Across the ocean's fury, beneath the world-tree Yggdrasil,
    //               the runes were carved into the roots by Odin's own hand."
    static let norse = Civilization(
        id: .norse,
        name: "Norse / Viking",
        region: "Scandinavia & North Atlantic",
        era: "150 – 1100 CE",
        emblem: "ᚢ",
        scriptName: "Elder Futhark Runes",
        accentHex: "4A7BA7",
        symbols: [
            ScriptSymbol(id: "fehu",     character: "ᚠ", transliteration: "f",  meaning: "Fehu — Cattle, Wealth",     civilization: .norse),
            ScriptSymbol(id: "uruz",     character: "ᚢ", transliteration: "u",  meaning: "Uruz — Aurochs, Strength",  civilization: .norse),
            ScriptSymbol(id: "thurisaz", character: "ᚦ", transliteration: "th", meaning: "Þurisaz — Giant, Force",    civilization: .norse),
            ScriptSymbol(id: "ansuz",    character: "ᚨ", transliteration: "a",  meaning: "Ansuz — Gods, Breath",      civilization: .norse),
            ScriptSymbol(id: "raidho",   character: "ᚱ", transliteration: "r",  meaning: "Raidho — Journey, Ride",    civilization: .norse),
        ],
        isUnlocked: false,
        levelCount: 5,
        tabletLine: "Across the fury of all oceans, beneath the world-tree Yggdrasil, the trunk rose through nine worlds. Odin hung nine nights to learn this: the tree is everything, and everything is the tree."
    )

    // ── SUMERIAN ─────────────────────────────────────────
    // Tablet line: "In the great above, in the great below,
    //               Inanna walked between worlds. The branches reached both directions."
    static let sumerian = Civilization(
        id: .sumerian,
        name: "Sumerian",
        region: "Mesopotamia, modern Iraq",
        era: "3500 – 2000 BCE",
        emblem: "𒀭",
        scriptName: "Cuneiform",
        accentHex: "8B6340",
        symbols: [
            ScriptSymbol(id: "an",   character: "𒀭", transliteration: "an",  meaning: "Heaven, God",  civilization: .sumerian),
            ScriptSymbol(id: "ki",   character: "𒆳", transliteration: "ki",  meaning: "Earth, Land",  civilization: .sumerian),
            ScriptSymbol(id: "a",    character: "𒀀", transliteration: "a",   meaning: "Water",        civilization: .sumerian),
            ScriptSymbol(id: "ud",   character: "𒌓", transliteration: "ud",  meaning: "Sun, Day",     civilization: .sumerian),
            ScriptSymbol(id: "gal",  character: "𒃲", transliteration: "gal", meaning: "Great, Large", civilization: .sumerian),
        ],
        isUnlocked: false,
        levelCount: 5,
        tabletLine: "In the great above and the great below, the branches reach in both directions. What grows toward heaven also grows into earth. The tree has no top and no bottom — only the endless middle, which is now."
    )

    // ── MAYA ─────────────────────────────────────────────
    // Tablet line: "The World Tree — Wakah-Chan — rises from the turtle shell of creation.
    //               The sun circles it. The calendar measures its breath."
    static let maya = Civilization(
        id: .maya,
        name: "Maya",
        region: "Mesoamerica — Yucatán & Guatemala",
        era: "2000 BCE – 1500 CE",
        emblem: "𝋡",
        scriptName: "Maya Glyphs",
        accentHex: "2E7D4F",
        symbols: [
            ScriptSymbol(id: "kin",   character: "𝋡", transliteration: "kin",  meaning: "Sun, Day",         civilization: .maya),
            ScriptSymbol(id: "haab",  character: "𝋢", transliteration: "haab", meaning: "Year",             civilization: .maya),
            ScriptSymbol(id: "tzolk", character: "𝋣", transliteration: "tzʼ",  meaning: "Sacred Round",     civilization: .maya),
            ScriptSymbol(id: "imix",  character: "𝋠", transliteration: "imix", meaning: "Earth, Crocodile", civilization: .maya),
            ScriptSymbol(id: "ik",    character: "𝋤", transliteration: "ik",   meaning: "Wind, Breath",     civilization: .maya),
        ],
        isUnlocked: false,
        levelCount: 5,
        tabletLine: "The World Tree — Wakah-Chan — rises from the turtle shell of creation. The sun has circled it since before the first human opened their eyes. Every calendar measures not time, but the breath of the tree between heartbeats."
    )

    // ── CELTIC ───────────────────────────────────────────
    // Tablet line: "The Druids named every tree sacred, for every tree is the same tree —
    //               reflected in water, carved in stone, spoken in wind."
    static let celtic = Civilization(
        id: .celtic,
        name: "Celtic / Druidic",
        region: "British Isles & Western Europe",
        era: "500 BCE – 500 CE",
        emblem: "ᚉ",
        scriptName: "Ogham Script",
        accentHex: "5A7A3A",
        symbols: [
            ScriptSymbol(id: "beith", character: "ᚁ", transliteration: "b", meaning: "Beith — Birch, New Beginnings", civilization: .celtic),
            ScriptSymbol(id: "luis",  character: "ᚂ", transliteration: "l", meaning: "Luis — Rowan, Protection",      civilization: .celtic),
            ScriptSymbol(id: "fearn", character: "ᚃ", transliteration: "f", meaning: "Fearn — Alder, Strength",       civilization: .celtic),
            ScriptSymbol(id: "sail",  character: "ᚄ", transliteration: "s", meaning: "Sail — Willow, Flow",           civilization: .celtic),
            ScriptSymbol(id: "nion",  character: "ᚅ", transliteration: "n", meaning: "Nion — Ash, World Connection",  civilization: .celtic),
        ],
        isUnlocked: false,
        levelCount: 5,
        tabletLine: "The Druids named every tree sacred, for every tree is the same tree — reflected in water, carved in stone, whispered in wind from grove to grove across all the cold seas of the world."
    )

    // ── CHINESE ──────────────────────────────────────────
    // Tablet line: "The sun rises and the moon follows.
    //               Water finds its way. Fire transforms.
    //               Wood remembers every ring of every year."
    static let chinese = Civilization(
        id: .chinese,
        name: "Ancient China",
        region: "Yellow River Valley",
        era: "1250 BCE – 221 BCE",
        emblem: "日",
        scriptName: "Oracle Bone Script",
        accentHex: "A63228",
        symbols: [
            ScriptSymbol(id: "ri",   character: "日", transliteration: "rì",   meaning: "Sun, Day",    civilization: .chinese),
            ScriptSymbol(id: "yue",  character: "月", transliteration: "yuè",  meaning: "Moon, Month", civilization: .chinese),
            ScriptSymbol(id: "shui", character: "水", transliteration: "shuǐ", meaning: "Water",       civilization: .chinese),
            ScriptSymbol(id: "huo",  character: "火", transliteration: "huǒ",  meaning: "Fire",        civilization: .chinese),
            ScriptSymbol(id: "mu",   character: "木", transliteration: "mù",   meaning: "Wood, Tree",  civilization: .chinese),
        ],
        isUnlocked: false,
        levelCount: 5,
        tabletLine: "The sun rises. The moon follows. Water finds the lowest place and calls it home. Fire transforms everything it touches and regrets nothing. Wood remembers every year in every ring. The tree does not forget."
    )
}

// MARK: - Tablet of Mandu
//
// Found in 2024 on a nameless island in the mid-Atlantic — coordinates
// withheld by the expedition team. The island appears on no modern chart.
//
// The tablet is carved from a black stone unknown to modern geology.
// It bears 30 symbols — 5 from each of 6 ancient civilizations — arranged
// in rows that read, in their original languages, as a single coherent message
// about the Tree of Life.
//
// No civilization could have traveled to meet the others. No trade route
// connects them all. The tablet should not exist.
//
// Scholars call it the Tablet of Mandu.
// No one knows what "Mandu" means.

struct TabletSlot: Identifiable {
    let id: Int
    let character: String
    let civilization: CivilizationID
    let decoded: String         // The meaning revealed when that civilization is learned
}

extension TabletSlot {
    // 30 symbols — 6 rows of 5 — one row per civilization, in order of discovery
    static let all: [TabletSlot] = [
        // Row 1 — Egyptian (unlocked by playing Egyptian levels)
        TabletSlot(id:  0, character: "𓇯", civilization: .egyptian, decoded: "sky"),
        TabletSlot(id:  1, character: "𓂀", civilization: .egyptian, decoded: "eye"),
        TabletSlot(id:  2, character: "𓈖", civilization: .egyptian, decoded: "water"),
        TabletSlot(id:  3, character: "𓃭", civilization: .egyptian, decoded: "strength"),
        TabletSlot(id:  4, character: "𓅓", civilization: .egyptian, decoded: "wisdom"),
        // Row 2 — Norse
        TabletSlot(id:  5, character: "ᚠ",  civilization: .norse,    decoded: "root"),
        TabletSlot(id:  6, character: "ᚢ",  civilization: .norse,    decoded: "grows"),
        TabletSlot(id:  7, character: "ᚦ",  civilization: .norse,    decoded: "through"),
        TabletSlot(id:  8, character: "ᚨ",  civilization: .norse,    decoded: "nine"),
        TabletSlot(id:  9, character: "ᚱ",  civilization: .norse,    decoded: "worlds"),
        // Row 3 — Sumerian
        TabletSlot(id: 10, character: "𒀭", civilization: .sumerian, decoded: "heaven"),
        TabletSlot(id: 11, character: "𒆳", civilization: .sumerian, decoded: "and"),
        TabletSlot(id: 12, character: "𒀀", civilization: .sumerian, decoded: "earth"),
        TabletSlot(id: 13, character: "𒌓", civilization: .sumerian, decoded: "are"),
        TabletSlot(id: 14, character: "𒃲", civilization: .sumerian, decoded: "one"),
        // Row 4 — Maya
        TabletSlot(id: 15, character: "𝋡", civilization: .maya,     decoded: "the"),
        TabletSlot(id: 16, character: "𝋠", civilization: .maya,     decoded: "tree"),
        TabletSlot(id: 17, character: "𝋢", civilization: .maya,     decoded: "breathes"),
        TabletSlot(id: 18, character: "𝋣", civilization: .maya,     decoded: "with"),
        TabletSlot(id: 19, character: "𝋤", civilization: .maya,     decoded: "time"),
        // Row 5 — Celtic
        TabletSlot(id: 20, character: "ᚁ", civilization: .celtic,   decoded: "all"),
        TabletSlot(id: 21, character: "ᚂ", civilization: .celtic,   decoded: "voices"),
        TabletSlot(id: 22, character: "ᚃ", civilization: .celtic,   decoded: "speak"),
        TabletSlot(id: 23, character: "ᚄ", civilization: .celtic,   decoded: "the"),
        TabletSlot(id: 24, character: "ᚅ", civilization: .celtic,   decoded: "same"),
        // Row 6 — Chinese (completes the message)
        TabletSlot(id: 25, character: "日", civilization: .chinese,  decoded: "word"),
        TabletSlot(id: 26, character: "月", civilization: .chinese,  decoded: "the"),
        TabletSlot(id: 27, character: "水", civilization: .chinese,  decoded: "word"),
        TabletSlot(id: 28, character: "火", civilization: .chinese,  decoded: "is"),
        TabletSlot(id: 29, character: "木", civilization: .chinese,  decoded: "remember"),
    ]

    // The complete decoded message when all 6 civilizations are learned:
    // "sky · eye · water · strength · wisdom
    //  root · grows · through · nine · worlds
    //  heaven · and · earth · are · one
    //  the · tree · breathes · with · time
    //  all · voices · speak · the · same
    //  word · the · word · is · remember"
    static let fullMessage = """
    From the eternal sky, through the eye of wisdom,
    where waters flow and strength stands guard —
    the root grows through nine worlds.
    Heaven and earth are one.
    The tree breathes with time.
    All voices speak the same word.
    The word is: remember.
    """
}

// MARK: - Greek Alphabet Reference
// The Rosetta Stone was decoded because scholars already knew Greek.
// This reference page serves the same function — a known script
// the archaeologist uses to cross-reference the Tablet of Mandu.

struct GreekLetter: Identifiable {
    let id: String
    let upper: String
    let lower: String
    let name: String
    let sound: String
}

extension GreekLetter {
    static let alphabet: [GreekLetter] = [
        GreekLetter(id: "alpha",   upper: "Α", lower: "α", name: "Alpha",   sound: "a"),
        GreekLetter(id: "beta",    upper: "Β", lower: "β", name: "Beta",    sound: "b"),
        GreekLetter(id: "gamma",   upper: "Γ", lower: "γ", name: "Gamma",   sound: "g"),
        GreekLetter(id: "delta",   upper: "Δ", lower: "δ", name: "Delta",   sound: "d"),
        GreekLetter(id: "epsilon", upper: "Ε", lower: "ε", name: "Epsilon", sound: "e"),
        GreekLetter(id: "zeta",    upper: "Ζ", lower: "ζ", name: "Zeta",    sound: "z"),
        GreekLetter(id: "eta",     upper: "Η", lower: "η", name: "Eta",     sound: "ē"),
        GreekLetter(id: "theta",   upper: "Θ", lower: "θ", name: "Theta",   sound: "th"),
        GreekLetter(id: "iota",    upper: "Ι", lower: "ι", name: "Iota",    sound: "i"),
        GreekLetter(id: "kappa",   upper: "Κ", lower: "κ", name: "Kappa",   sound: "k"),
        GreekLetter(id: "lambda",  upper: "Λ", lower: "λ", name: "Lambda",  sound: "l"),
        GreekLetter(id: "mu",      upper: "Μ", lower: "μ", name: "Mu",      sound: "m"),
        GreekLetter(id: "nu",      upper: "Ν", lower: "ν", name: "Nu",      sound: "n"),
        GreekLetter(id: "xi",      upper: "Ξ", lower: "ξ", name: "Xi",      sound: "x"),
        GreekLetter(id: "omicron", upper: "Ο", lower: "ο", name: "Omicron", sound: "o"),
        GreekLetter(id: "pi",      upper: "Π", lower: "π", name: "Pi",      sound: "p"),
        GreekLetter(id: "rho",     upper: "Ρ", lower: "ρ", name: "Rho",     sound: "r"),
        GreekLetter(id: "sigma",   upper: "Σ", lower: "σ", name: "Sigma",   sound: "s"),
        GreekLetter(id: "tau",     upper: "Τ", lower: "τ", name: "Tau",     sound: "t"),
        GreekLetter(id: "upsilon", upper: "Υ", lower: "υ", name: "Upsilon", sound: "u/y"),
        GreekLetter(id: "phi",     upper: "Φ", lower: "φ", name: "Phi",     sound: "ph"),
        GreekLetter(id: "chi",     upper: "Χ", lower: "χ", name: "Chi",     sound: "ch"),
        GreekLetter(id: "psi",     upper: "Ψ", lower: "ψ", name: "Psi",     sound: "ps"),
        GreekLetter(id: "omega",   upper: "Ω", lower: "ω", name: "Omega",   sound: "ō"),
    ]
}

// MARK: - Color hex init

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }
}
