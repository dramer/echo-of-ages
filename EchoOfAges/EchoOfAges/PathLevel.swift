// PathLevel.swift
// EchoOfAges
//
// Norse pathfinding puzzles — Hamiltonian path through a grid of runestones.
// The player traces a continuous route that visits every cell exactly once,
// guided by pre-revealed rune waypoints that must be reached in sequence.
//
// Puzzle rules (displayed to the player):
//   1. Start at the marked rune (ᚠ or equivalent START stone).
//   2. Trace a path by tapping adjacent cells — left, right, up, or down.
//   3. Every stone on the tablet must be visited exactly once.
//   4. The visible rune waypoints mark landmarks on the correct route — reach
//      them in the order they are numbered.
//   5. Tap the last placed cell to backtrack one step.
//
// Verification: the player's full path must exactly match the solution path.
//
// Level progression:
//   L1 3×3   9 cells   4 waypoints   Bifrost Crossing     — learn the mechanic
//   L2 4×4  16 cells   6 waypoints   The Longship Route   — longer, non-obvious turns
//   L3 4×4  16 cells   5 waypoints   Yggdrasil's Root     — reversed start, harder routing
//   L4 5×5  25 cells   6 waypoints   Spiral of Nine       — inward spiral, 25 cells
//   L5 5×5  25 cells   5 waypoints   Ragnarök             — column serpentine, minimal anchors

import Foundation

// MARK: - Waypoint

struct Waypoint: Identifiable, Equatable {
    let id: Int           // unique per level
    let pathIndex: Int    // index in solution where this waypoint sits
    let position: GridPosition
    let rune: String      // Unicode rune character
    let runeName: String  // Name of the rune (e.g. "Fehu")
    let meaning: String   // Short meaning (e.g. "Wealth & Beginning")
    let isStart: Bool
    let isEnd: Bool

    init(id: Int, pathIndex: Int, position: GridPosition,
         rune: String, runeName: String, meaning: String,
         isStart: Bool = false, isEnd: Bool = false) {
        self.id = id; self.pathIndex = pathIndex; self.position = position
        self.rune = rune; self.runeName = runeName; self.meaning = meaning
        self.isStart = isStart; self.isEnd = isEnd
    }
}

// MARK: - PathLevel

struct PathLevel: Identifiable {
    let id: Int
    let civilization: CivilizationID
    let title: String
    let subtitle: String
    let lore: String
    let inscriptions: [String]
    let rows: Int
    let cols: Int
    let solution: [GridPosition]   // complete ordered path (all cells)
    let waypoints: [Waypoint]      // pre-revealed landmark cells
    let journalEntry: JournalEntry
    let decodedMessage: String

    var startPosition: GridPosition { solution[0] }
    var endPosition:   GridPosition { solution[solution.count - 1] }
    var totalCells:    Int          { rows * cols }

    func waypoint(at pos: GridPosition) -> Waypoint? {
        waypoints.first { $0.position == pos }
    }

    func isWaypoint(_ pos: GridPosition) -> Bool {
        waypoints.contains { $0.position == pos }
    }

    func isSolved(_ path: [GridPosition]) -> Bool {
        path == solution
    }

    var romanNumeral: String {
        switch id {
        case 1: return "I"; case 2: return "II"; case 3: return "III"
        case 4: return "IV"; case 5: return "V"; default: return "\(id)"
        }
    }
}

// MARK: - Level Definitions
//
// All solutions verified: Hamiltonian paths (visit every cell once),
// all steps H/V adjacent, waypoints lie on the solution path at stated indices.
//
// Rune key:
//   ᚠ Fehu (wealth)     ᚢ Uruz (strength)   ᚦ Thurisaz (thorn)
//   ᚨ Ansuz (Odin)      ᚱ Raidho (journey)  ᚲ Kenaz (torch)
//   ᚷ Gebo (gift)       ᚹ Wunjo (joy)       ᚾ Naudiz (need)
//   ᛁ Isa (ice)         ᛃ Jera (harvest)    ᛊ Sowilo (sun)
//   ᛏ Tiwaz (justice)   ᛟ Othala (home)

extension PathLevel {
    static let allLevels: [PathLevel] = [level1, level2, level3, level4, level5]

    // ─────────────────────────────────────────────────
    // LEVEL 1 · 3×3 · "Bifrost Crossing"
    //
    // Grid (0-indexed row, col):
    //   [W1] [ ] [W2]
    //   [ ]  [ ] [ ]
    //   [ ]  [W3][W4]
    //
    // Solution path (9 cells):
    //   (0,0)→(0,1)→(0,2)→(1,2)→(1,1)→(1,0)→(2,0)→(2,1)→(2,2)
    //
    // Waypoints:
    //   idx 0  (0,0) ᚠ Fehu   START
    //   idx 2  (0,2) ᚱ Raidho
    //   idx 5  (1,0) ᚨ Ansuz
    //   idx 8  (2,2) ᚢ Uruz   END
    // ─────────────────────────────────────────────────
    static let level1 = PathLevel(
        id: 1,
        civilization: .norse,
        title: "Bifrost Crossing",
        subtitle: "The Rainbow Bridge",
        lore: "The runestone before you marks the safe passage across Bifrost — the burning rainbow bridge that connects Midgard to Asgard. Only those who read the runes correctly and follow them in order may cross. Step wrong and the bridge collapses beneath you.",
        inscriptions: [
            "ᚠ Fehu marks the threshold where all journeys begin. Set your first foot there.",
            "ᚱ Raidho — the rune of riding and roads — appears at the far edge of the first row. The path must cross the bridge from left to right before descending.",
            "ᚨ Ansuz is Odin's rune: breath, voice, command. It appears after the bridge turns back. When you hear the wind change direction, you have found it.",
            "ᚢ Uruz marks the landing point — the far shore. Every stone of the bridge must bear your weight before you may arrive."
        ],
        rows: 3, cols: 3,
        solution: [
            GridPosition(row:0,col:0), GridPosition(row:0,col:1), GridPosition(row:0,col:2),
            GridPosition(row:1,col:2), GridPosition(row:1,col:1), GridPosition(row:1,col:0),
            GridPosition(row:2,col:0), GridPosition(row:2,col:1), GridPosition(row:2,col:2)
        ],
        waypoints: [
            Waypoint(id:1, pathIndex:0, position:GridPosition(row:0,col:0),
                     rune:"ᚠ", runeName:"Fehu", meaning:"Wealth · Beginning", isStart:true),
            Waypoint(id:2, pathIndex:2, position:GridPosition(row:0,col:2),
                     rune:"ᚱ", runeName:"Raidho", meaning:"Journey · Road"),
            Waypoint(id:3, pathIndex:5, position:GridPosition(row:1,col:0),
                     rune:"ᚨ", runeName:"Ansuz", meaning:"Odin · Breath"),
            Waypoint(id:4, pathIndex:8, position:GridPosition(row:2,col:2),
                     rune:"ᚢ", runeName:"Uruz", meaning:"Strength · Arrival", isEnd:true)
        ],
        journalEntry: JournalEntry(
            id: 6,
            title: "The Runestone of Bifrost",
            body: "The Norse tablet opens with four runes arranged as a bridge inscription. Fehu at the start, Uruz at the end — wealth to strength, beginning to arrival. Raidho and Ansuz mark the turns. I traced the path three times before I trusted it.",
            artifact: "ᚠ"
        ),
        decodedMessage: "The bridge is not made of stone or fire alone. It is made of the steps taken in the right order, without hesitation. Odin watches every crossing. He counts the feet."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 2 · 4×4 · "The Longship Route"
    //
    // Solution path (16 cells):
    //   (0,0)→(1,0)→(2,0)→(3,0)→(3,1)→(2,1)→(1,1)→(0,1)
    //       →(0,2)→(0,3)→(1,3)→(1,2)→(2,2)→(2,3)→(3,3)→(3,2)
    //
    // Waypoints:
    //   idx 0  (0,0) ᚠ START
    //   idx 3  (3,0) ᚦ Thurisaz
    //   idx 7  (0,1) ᚲ Kenaz
    //   idx 9  (0,3) ᚾ Naudiz
    //   idx 11 (1,2) ᚷ Gebo
    //   idx 15 (3,2) ᚹ END
    // ─────────────────────────────────────────────────
    static let level2 = PathLevel(
        id: 2,
        civilization: .norse,
        title: "The Longship Route",
        subtitle: "Through Ice and Current",
        lore: "The Norse carved their sailing routes into runestones so they could not be lost to memory or weather. This tablet maps a sea crossing — down the coast, up the fjord, across the headland, and into harbor. The longship visits every waypoint. Nothing is left uncharted.",
        inscriptions: [
            "Begin at ᚠ Fehu and drive south along the coast. The path descends the left column completely before it turns.",
            "ᚦ Thurisaz — the giant, the thorn, the obstacle — marks the southern headland. After this stone, the route turns inland and climbs.",
            "ᚲ Kenaz is the torch in the harbor. When you reach it, you have climbed back to the first row and turned east. The top of the tablet opens.",
            "ᚷ Gebo — the gift — waits at the crossing point. It is reached from the north, not the south. Remember that when you plan your approach.",
            "ᚹ Wunjo marks the final haven. Every stone before it must be visited. Nothing on the route is skipped."
        ],
        rows: 4, cols: 4,
        solution: [
            GridPosition(row:0,col:0), GridPosition(row:1,col:0), GridPosition(row:2,col:0), GridPosition(row:3,col:0),
            GridPosition(row:3,col:1), GridPosition(row:2,col:1), GridPosition(row:1,col:1), GridPosition(row:0,col:1),
            GridPosition(row:0,col:2), GridPosition(row:0,col:3), GridPosition(row:1,col:3), GridPosition(row:1,col:2),
            GridPosition(row:2,col:2), GridPosition(row:2,col:3), GridPosition(row:3,col:3), GridPosition(row:3,col:2)
        ],
        waypoints: [
            Waypoint(id:1, pathIndex:0,  position:GridPosition(row:0,col:0),
                     rune:"ᚠ", runeName:"Fehu", meaning:"Wealth · Departure", isStart:true),
            Waypoint(id:2, pathIndex:3,  position:GridPosition(row:3,col:0),
                     rune:"ᚦ", runeName:"Thurisaz", meaning:"Giant · Headland"),
            Waypoint(id:3, pathIndex:7,  position:GridPosition(row:0,col:1),
                     rune:"ᚲ", runeName:"Kenaz", meaning:"Torch · Harbor light"),
            Waypoint(id:4, pathIndex:9,  position:GridPosition(row:0,col:3),
                     rune:"ᚾ", runeName:"Naudiz", meaning:"Need · Crossing"),
            Waypoint(id:5, pathIndex:11, position:GridPosition(row:1,col:2),
                     rune:"ᚷ", runeName:"Gebo", meaning:"Gift · Waypoint"),
            Waypoint(id:6, pathIndex:15, position:GridPosition(row:3,col:2),
                     rune:"ᚹ", runeName:"Wunjo", meaning:"Joy · Safe harbor", isEnd:true)
        ],
        journalEntry: JournalEntry(
            id: 7,
            title: "The Navigator's Runestone",
            body: "Viking navigators memorized coastlines through rune sequences. Each rune along a sailing route named a landmark — a headland, a current, a safe harbor. This tablet is such a route map. Fehu to Wunjo: the full journey from departure to arrival, not one stone skipped.",
            artifact: "ᚱ"
        ),
        decodedMessage: "The sea does not forgive a wrong heading. Neither does the runestone. There is one route and one route only — determined not by the strongest current but by the runes that have gone before."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 3 · 4×4 · "Yggdrasil's Root"
    //
    // Solution path (16 cells) — starts top-right, ends mid-left:
    //   (0,3)→(0,2)→(0,1)→(0,0)→(1,0)→(1,1)→(1,2)→(1,3)
    //       →(2,3)→(3,3)→(3,2)→(3,1)→(3,0)→(2,0)→(2,1)→(2,2)
    //
    // Waypoints:
    //   idx 0  (0,3) ᛁ Isa      START
    //   idx 3  (0,0) ᛃ Jera
    //   idx 7  (1,3) ᛊ Sowilo
    //   idx 12 (3,0) ᛏ Tiwaz
    //   idx 15 (2,2) ᛟ Othala  END
    // ─────────────────────────────────────────────────
    static let level3 = PathLevel(
        id: 3,
        civilization: .norse,
        title: "Yggdrasil's Root",
        subtitle: "The World Tree Descends",
        lore: "Yggdrasil — the great ash tree at the center of all nine worlds — has three roots. Each root reaches into a different realm. This tablet traces one root from its frozen crown to the deep earth. The path begins at ice and ends at home.",
        inscriptions: [
            "ᛁ Isa — the rune of ice — marks the crown of the root at the far right of the first row. The journey moves leftward before it can descend.",
            "ᛃ Jera is the harvest rune — completion of a cycle. It rests at the far left, the end of the first row's traversal. After Jera, the path turns and grows downward.",
            "ᛊ Sowilo — the sun rune — burns at the end of the second row. It arrives from the left after traversing all of row one. The sun only rises on a completed passage.",
            "ᛏ Tiwaz is Tyr's rune — justice and sacrifice. It waits at the bottom-left corner. The world tree's root does not avoid the hardest ground.",
            "ᛟ Othala — home and heritage — closes the path. The root ends not at an edge but at the center of the lower half. Home is never at the boundary. It is always deeper in."
        ],
        rows: 4, cols: 4,
        solution: [
            GridPosition(row:0,col:3), GridPosition(row:0,col:2), GridPosition(row:0,col:1), GridPosition(row:0,col:0),
            GridPosition(row:1,col:0), GridPosition(row:1,col:1), GridPosition(row:1,col:2), GridPosition(row:1,col:3),
            GridPosition(row:2,col:3), GridPosition(row:3,col:3), GridPosition(row:3,col:2), GridPosition(row:3,col:1),
            GridPosition(row:3,col:0), GridPosition(row:2,col:0), GridPosition(row:2,col:1), GridPosition(row:2,col:2)
        ],
        waypoints: [
            Waypoint(id:1, pathIndex:0,  position:GridPosition(row:0,col:3),
                     rune:"ᛁ", runeName:"Isa", meaning:"Ice · Stillness", isStart:true),
            Waypoint(id:2, pathIndex:3,  position:GridPosition(row:0,col:0),
                     rune:"ᛃ", runeName:"Jera", meaning:"Harvest · Cycle"),
            Waypoint(id:3, pathIndex:7,  position:GridPosition(row:1,col:3),
                     rune:"ᛊ", runeName:"Sowilo", meaning:"Sun · Victory"),
            Waypoint(id:4, pathIndex:12, position:GridPosition(row:3,col:0),
                     rune:"ᛏ", runeName:"Tiwaz", meaning:"Justice · Sacrifice"),
            Waypoint(id:5, pathIndex:15, position:GridPosition(row:2,col:2),
                     rune:"ᛟ", runeName:"Othala", meaning:"Home · Heritage", isEnd:true)
        ],
        journalEntry: JournalEntry(
            id: 8,
            title: "The Root Inscription",
            body: "The three roots of Yggdrasil reach into Asgard, Jotunheim, and Niflheim. Each root was carved on a separate tablet. This is the Niflheim root — the root of ice, sacrifice, and return. I traced it backwards three times before I accepted that it begins where it seems to end.",
            artifact: "ᛁ"
        ),
        decodedMessage: "The tree descends before it rises. Every root goes down into darkness before the crown can reach the sky. Do not fear the depth. The path through ice and sacrifice is the only path that reaches home."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 4 · 5×5 · "Spiral of Nine"
    //
    // Solution path (25 cells) — clockwise inward spiral:
    //   (0,0)→(0,1)→(0,2)→(0,3)→(0,4)
    //       →(1,4)→(2,4)→(3,4)→(4,4)
    //       →(4,3)→(4,2)→(4,1)→(4,0)
    //       →(3,0)→(2,0)→(1,0)
    //       →(1,1)→(1,2)→(1,3)→(2,3)→(3,3)→(3,2)→(3,1)→(2,1)→(2,2)
    //
    // Waypoints:
    //   idx 0  (0,0) ᚠ START  (top-left)
    //   idx 4  (0,4) ᚱ        (top-right)
    //   idx 8  (4,4) ᚢ        (bottom-right)
    //   idx 12 (4,0) ᚨ        (bottom-left)
    //   idx 15 (1,0) ᚦ        (inner spiral start)
    //   idx 24 (2,2) ᛟ END    (center)
    // ─────────────────────────────────────────────────
    static let level4 = PathLevel(
        id: 4,
        civilization: .norse,
        title: "Spiral of Nine",
        subtitle: "The Nine Worlds Turning",
        lore: "The nine worlds of Norse cosmology spiral around Yggdrasil — Asgard at the crown, Niflheim at the roots, Midgard at the center. This tablet maps the spiral inward: outer ring first, then inner ring, then the still point at the heart. To read it you must think in circles, not lines.",
        inscriptions: [
            "ᚠ Fehu opens at the top-left corner. The outer ring of the spiral must be traced completely before entering the inner.",
            "ᚱ Raidho marks the top-right corner. You must travel the entire top row before descending. The outer spiral runs clockwise.",
            "ᚢ Uruz stands at the bottom-right corner. The right column, the bottom row — the outer ring has one direction and never reverses.",
            "ᚨ Ansuz at the bottom-left completes the outer ring. From here the path turns inward — a new, tighter spiral begins.",
            "ᚦ Thurisaz marks where the inner spiral starts, back at the left edge. After traversing the outer ring, the path dips inward and spirals to the center.",
            "ᛟ Othala waits at the very center of the stone. All worlds spiral inward to the same still point. That is where the path ends."
        ],
        rows: 5, cols: 5,
        solution: [
            // Outer spiral — top row →
            GridPosition(row:0,col:0), GridPosition(row:0,col:1), GridPosition(row:0,col:2),
            GridPosition(row:0,col:3), GridPosition(row:0,col:4),
            // right col ↓
            GridPosition(row:1,col:4), GridPosition(row:2,col:4), GridPosition(row:3,col:4),
            GridPosition(row:4,col:4),
            // bottom row ←
            GridPosition(row:4,col:3), GridPosition(row:4,col:2), GridPosition(row:4,col:1),
            GridPosition(row:4,col:0),
            // left col ↑ (partial — back to row 1)
            GridPosition(row:3,col:0), GridPosition(row:2,col:0), GridPosition(row:1,col:0),
            // Inner spiral — row 1 →
            GridPosition(row:1,col:1), GridPosition(row:1,col:2), GridPosition(row:1,col:3),
            // col 3 ↓
            GridPosition(row:2,col:3), GridPosition(row:3,col:3),
            // row 3 ←
            GridPosition(row:3,col:2), GridPosition(row:3,col:1),
            // col 1 ↑
            GridPosition(row:2,col:1),
            // center
            GridPosition(row:2,col:2)
        ],
        waypoints: [
            Waypoint(id:1, pathIndex:0,  position:GridPosition(row:0,col:0),
                     rune:"ᚠ", runeName:"Fehu", meaning:"Wealth · Outer world", isStart:true),
            Waypoint(id:2, pathIndex:4,  position:GridPosition(row:0,col:4),
                     rune:"ᚱ", runeName:"Raidho", meaning:"Journey · Turn east"),
            Waypoint(id:3, pathIndex:8,  position:GridPosition(row:4,col:4),
                     rune:"ᚢ", runeName:"Uruz", meaning:"Strength · Turn south"),
            Waypoint(id:4, pathIndex:12, position:GridPosition(row:4,col:0),
                     rune:"ᚨ", runeName:"Ansuz", meaning:"Odin · Turn west"),
            Waypoint(id:5, pathIndex:15, position:GridPosition(row:1,col:0),
                     rune:"ᚦ", runeName:"Thurisaz", meaning:"Thorn · Inner spiral"),
            Waypoint(id:6, pathIndex:24, position:GridPosition(row:2,col:2),
                     rune:"ᛟ", runeName:"Othala", meaning:"Home · The center", isEnd:true)
        ],
        journalEntry: JournalEntry(
            id: 9,
            title: "The Nine-World Map",
            body: "The Norse cosmology is not a hierarchy — it is a spiral. The worlds are nested, and the outermost ring connects to the inner in ways that are not obvious until you trace the full pattern. This tablet is the map. The center stone is always Othala — home — regardless of where you begin.",
            artifact: "ᛟ"
        ),
        decodedMessage: "All nine worlds spiral around the same axis. You do not navigate the nine worlds by going in a straight line. You spiral inward. The center is always home. And home is always reached last."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 5 · 5×5 · "Ragnarök"
    //
    // Solution path (25 cells) — column-by-column serpentine:
    //   col 0 ↓: (0,0)→(1,0)→(2,0)→(3,0)→(4,0)
    //   col 1 ↑: →(4,1)→(3,1)→(2,1)→(1,1)→(0,1)
    //   col 2 ↓: →(0,2)→(1,2)→(2,2)→(3,2)→(4,2)
    //   col 3 ↑: →(4,3)→(3,3)→(2,3)→(1,3)→(0,3)
    //   col 4 ↓: →(0,4)→(1,4)→(2,4)→(3,4)→(4,4)
    //
    // Waypoints (minimal — 5 only):
    //   idx 0  (0,0) ᛟ START
    //   idx 4  (4,0) ᚾ Naudiz
    //   idx 10 (0,2) ᛁ Isa
    //   idx 20 (0,4) ᛊ Sowilo
    //   idx 24 (4,4) ᚠ END
    // ─────────────────────────────────────────────────
    static let level5 = PathLevel(
        id: 5,
        civilization: .norse,
        title: "Ragnarök",
        subtitle: "The Final Reckoning",
        lore: "At the end of all things, even the gods follow a prescribed path. Ragnarök is not chaos — it is the final order, playing out as written by the Norns before time began. This tablet records that path. Five rune anchors remain. All others must be found through reason alone.",
        inscriptions: [
            "Only five runes are visible. The path between them must be discovered entirely through deduction and trial.",
            "ᛟ Othala opens the final reckoning — homeland, heritage, that which must be protected. The first column falls before anything else moves.",
            "ᚾ Naudiz — need and necessity — marks the base of the first column. When you reach it, you have earned the right to change direction for the first time.",
            "ᛁ Isa stands frozen at the top of the middle column. Ice does not flow — it waits. The path must climb to it before descending again.",
            "ᛊ Sowilo — the sun — blazes at the top of the last column. After the sun, only the final descent remains. Every stone before it must already have been claimed."
        ],
        rows: 5, cols: 5,
        solution: [
            // Col 0 ↓
            GridPosition(row:0,col:0), GridPosition(row:1,col:0), GridPosition(row:2,col:0),
            GridPosition(row:3,col:0), GridPosition(row:4,col:0),
            // Col 1 ↑
            GridPosition(row:4,col:1), GridPosition(row:3,col:1), GridPosition(row:2,col:1),
            GridPosition(row:1,col:1), GridPosition(row:0,col:1),
            // Col 2 ↓
            GridPosition(row:0,col:2), GridPosition(row:1,col:2), GridPosition(row:2,col:2),
            GridPosition(row:3,col:2), GridPosition(row:4,col:2),
            // Col 3 ↑
            GridPosition(row:4,col:3), GridPosition(row:3,col:3), GridPosition(row:2,col:3),
            GridPosition(row:1,col:3), GridPosition(row:0,col:3),
            // Col 4 ↓
            GridPosition(row:0,col:4), GridPosition(row:1,col:4), GridPosition(row:2,col:4),
            GridPosition(row:3,col:4), GridPosition(row:4,col:4)
        ],
        waypoints: [
            Waypoint(id:1, pathIndex:0,  position:GridPosition(row:0,col:0),
                     rune:"ᛟ", runeName:"Othala", meaning:"Home · Heritage", isStart:true),
            Waypoint(id:2, pathIndex:4,  position:GridPosition(row:4,col:0),
                     rune:"ᚾ", runeName:"Naudiz", meaning:"Need · Necessity"),
            Waypoint(id:3, pathIndex:10, position:GridPosition(row:0,col:2),
                     rune:"ᛁ", runeName:"Isa", meaning:"Ice · The frozen mid-point"),
            Waypoint(id:4, pathIndex:20, position:GridPosition(row:0,col:4),
                     rune:"ᛊ", runeName:"Sowilo", meaning:"Sun · The final turn"),
            Waypoint(id:5, pathIndex:24, position:GridPosition(row:4,col:4),
                     rune:"ᚠ", runeName:"Fehu", meaning:"Wealth · New age begins", isEnd:true)
        ],
        journalEntry: JournalEntry(
            id: 10,
            title: "The Ragnarök Inscription",
            body: "The Norse did not fear Ragnarök — they accepted it. The gods know they will fall. They fight anyway. This tablet was the last one on the runestone site. Fewest clues. Longest path. I worked on it for two days. When I finally traced it, I understood why they put it last. It is not the hardest path. It is the most honest one.",
            artifact: "ᚾ"
        ),
        decodedMessage: "Even at the end of all things, the path is not random. The Norns wove it before the first god drew breath. Five anchor runes. Twenty more unnamed stones. Each one necessary. Not one wasted. This is how all things end: in perfect, terrible order."
    )
}
