// PathLevel.swift
// EchoOfAges
//
// Norse pathfinding puzzles — Hamiltonian path through a grid of runestones.
// The player traces a continuous route visiting every valid stone exactly once,
// guided by pre-revealed rune waypoints that must be reached in the right order.
//
// Blocked cells (impassable stone) are introduced at level 3 and increase the
// topological difficulty — standard row-by-row sweeps fail around obstacles.
//
// Puzzle rules (displayed to the player):
//   1. Start at the marked rune (the glowing Start stone).
//   2. Trace a path by tapping adjacent cells — left, right, up, or down.
//   3. Every VALID stone on the tablet must be visited exactly once.
//   4. Cracked/dark stones are impassable — route around them.
//   5. Visible rune waypoints mark fixed landmarks — reach them in order.
//   6. Tap the last placed cell to backtrack one step.
//
// Difficulty design principles:
//   • Irregular (non-serpentine) paths with dead-end traps
//   • Blocked cells change grid topology — standard patterns fail
//   • Fewer waypoints on harder levels force deduction over guidance
//
// Level progression:
//   L1  3×3   0 blocked   3 waypoints   Odin's Spiral        — outer spiral, tutorial
//   L2  4×4   0 blocked   4 waypoints   The Fjord Route      — "inlet" trap at start
//   L3  4×4   1 blocked   3 waypoints   The Cracked Stone    — hole in centre-right
//   L4  4×4   1 blocked   3 waypoints   The Broken Altar     — missing corner, L-shape
//   L5  5×5   2 blocked   3 waypoints   Jormungandr's Back   — serpent blocks axis

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
    let solution: [GridPosition]      // complete ordered path (all valid cells)
    let waypoints: [Waypoint]         // pre-revealed landmark cells
    let blockedCells: Set<GridPosition>  // impassable stones — route around these
    let journalEntry: JournalEntry
    let decodedMessage: String

    // Total valid cells the player must visit
    var totalCells: Int { rows * cols - blockedCells.count }

    var startPosition: GridPosition { solution[0] }
    var endPosition:   GridPosition { solution[solution.count - 1] }

    func waypoint(at pos: GridPosition) -> Waypoint? {
        waypoints.first { $0.position == pos }
    }

    func isWaypoint(_ pos: GridPosition) -> Bool {
        waypoints.contains { $0.position == pos }
    }

    func isBlocked(_ pos: GridPosition) -> Bool {
        blockedCells.contains(pos)
    }

    func isSolved(_ path: [GridPosition]) -> Bool {
        // Must cover every valid cell exactly once.
        guard path.count == totalCells else { return false }

        // Must visit every waypoint in ascending pathIndex order.
        // We accept ANY Hamiltonian path that threads the waypoints correctly —
        // the exact cells between waypoints may differ from the generated solution,
        // since a 4×4 grid (for example) has many valid Hamiltonian paths.
        // Requiring exact solution equality caused players to be marked wrong when
        // they found a legitimate alternative route.
        let ordered = waypoints.sorted { $0.pathIndex < $1.pathIndex }
        var wi = 0
        for pos in path {
            if wi < ordered.count && pos == ordered[wi].position {
                wi += 1
            }
        }
        return wi == ordered.count
    }

    /// Returns a copy of this level with a newly generated path and waypoints,
    /// keeping all theme data (title, lore, blocked cells, etc.) unchanged.
    func withGeneratedPath(solution: [GridPosition], waypoints: [Waypoint]) -> PathLevel {
        PathLevel(
            id: id, civilization: civilization,
            title: title, subtitle: subtitle,
            lore: lore, inscriptions: inscriptions,
            rows: rows, cols: cols,
            solution: solution, waypoints: waypoints,
            blockedCells: blockedCells,
            journalEntry: journalEntry,
            decodedMessage: decodedMessage
        )
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
// All solutions verified:
//   • Hamiltonian paths — visit every valid (non-blocked) cell exactly once
//   • All steps are H/V adjacent
//   • Waypoints lie on the solution path at the stated pathIndex
//   • Parity check (chess-colour balance) confirms Hamiltonian path existence
//
// Rune key:
//   ᚠ Fehu (wealth/start)  ᚢ Uruz (strength)   ᚦ Thurisaz (thorn)
//   ᚨ Ansuz (Odin/breath)  ᚱ Raidho (journey)  ᚲ Kenaz (torch)
//   ᚷ Gebo (gift)          ᚹ Wunjo (joy)       ᚾ Naudiz (need)
//   ᛁ Isa (ice)            ᛃ Jera (harvest)    ᛊ Sowilo (sun)
//   ᛏ Tiwaz (justice)      ᛟ Othala (home)

extension PathLevel {
    static let allLevels: [PathLevel] = [level1, level2, level3, level4, level5]

    // ─────────────────────────────────────────────────
    // LEVEL 1 · 3×3 · "Odin's Spiral"
    //
    // Grid:
    //   [W1][ ][ ]
    //   [ ] [ ][W2←path comes back to this column]
    //   [ ] [ ][W3]
    //
    // Solution path (9 cells) — counterclockwise outer spiral, end at centre:
    //   (0,0)→(1,0)→(2,0)→(2,1)→(2,2)→(1,2)→(0,2)→(0,1)→(1,1)
    //
    // Why harder than a row-sweep: the path goes DOWN the left column first,
    // then across the bottom, up the right, across the top — ending in the
    // centre. Going across row 0 first leaves the centre unreachable.
    //
    // Waypoints:
    //   idx 0  (0,0) ᚠ START
    //   idx 4  (2,2) ᚱ Raidho
    //   idx 8  (1,1) ᛟ END
    // ─────────────────────────────────────────────────
    static let level1 = PathLevel(
        id: 1,
        civilization: .norse,
        title: "Odin's Spiral",
        subtitle: "The Allfather's Pattern",
        lore: "Before the worlds were named, Odin carved his knowledge into the first runestone in the shape of a spiral — not left to right, but inward, like thought itself. The path does not begin by going forward. It begins by going down.",
        inscriptions: [
            "Rather than move east along the top row, this path descends first — down the left column, before any horizontal step is taken. ᚠ Fehu marks the starting stone at the crown. Its road is not forward. It is down.",
            "ᚱ Raidho — the rune of roads — marks the far corner of the base. To reach it, you must first traverse the bottom, not the top.",
            "ᛟ Othala, home, rests at the centre of the spiral. All paths that are true end here — in the middle, not at the edge."
        ],
        rows: 3, cols: 3,
        solution: [
            GridPosition(row:0,col:0), GridPosition(row:1,col:0), GridPosition(row:2,col:0),
            GridPosition(row:2,col:1), GridPosition(row:2,col:2),
            GridPosition(row:1,col:2), GridPosition(row:0,col:2), GridPosition(row:0,col:1),
            GridPosition(row:1,col:1)
        ],
        waypoints: [
            Waypoint(id:1, pathIndex:0, position:GridPosition(row:0,col:0),
                     rune:"ᚠ", runeName:"Fehu", meaning:"Wealth · The threshold", isStart:true),
            Waypoint(id:2, pathIndex:4, position:GridPosition(row:2,col:2),
                     rune:"ᚱ", runeName:"Raidho", meaning:"Journey · The far corner"),
            Waypoint(id:3, pathIndex:8, position:GridPosition(row:1,col:1),
                     rune:"ᛟ", runeName:"Othala", meaning:"Home · The centre", isEnd:true)
        ],
        blockedCells: [],
        journalEntry: JournalEntry(
            id: 6,
            title: "The First Runestone",
            body: "The spiral is Odin's signature — not a serpentine sweep but an inward turn. I made the mistake of going east first. The stone taught me: descend before you cross. The centre is always reached last.",
            artifact: "ᚠ"
        ),
        decodedMessage: "The spiral is not decoration. It is instruction. You cannot reach the centre of anything by going straight across it. You must first walk the outer edge. All the way around. Only then does the middle open."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 2 · 4×4 · "The Fjord Route"
    //
    // Solution path (16 cells) — "inlet" pattern:
    //   (0,0)→(0,1)→(1,1)→(1,0)  ← dips into top-left 2×2 before heading south
    //       →(2,0)→(3,0)→(3,1)→(2,1)→(2,2)→(3,2)→(3,3)→(2,3)→(1,3)→(0,3)→(0,2)→(1,2)
    //
    // Why harder: going straight across row 0 first seems obvious but traps
    // (1,1)/(1,0) — they can only be reached together from (0,1)/(0,0).
    // The forced "inlet" move at the start must be discovered by deduction.
    //
    // Waypoints:
    //   idx 0  (0,0) ᚠ START
    //   idx 5  (3,0) ᚦ Thurisaz   — forces the first column fully down
    //   idx 11 (2,3) ᚹ Wunjo      — placed so only the correct zigzag approach works
    //   idx 15 (1,2) ᚨ END
    // ─────────────────────────────────────────────────
    static let level2 = PathLevel(
        id: 2,
        civilization: .norse,
        title: "The Fjord Route",
        subtitle: "Into the Inlet and Out",
        lore: "A fjord demands that you enter its narrow throat before you may reach its far end. Viking navigators who tried to sail the outer coast without entering the fjord always missed the safe harbour. This tablet maps such a route. The first move is never the obvious one.",
        inscriptions: [
            "Only by entering the inlet first can you reach the southern headland. The top-left two columns form a narrow pocket — the path dips into this inlet before it can continue south. ᚠ Fehu opens the route; do not go east from it without first dipping south.",
            "ᚦ Thurisaz — giant and obstacle — marks the bottom of the left column. You cannot reach it without first exploring the inlet formed by the first two columns.",
            "ᚹ Wunjo is the joy of safe harbour, reached near the bottom-right. The path arrives here from the south, not from the east.",
            "ᚨ Ansuz — Odin's breath — closes the route. It lies in the interior, reachable only after the outer ring of the right side has been fully traversed."
        ],
        rows: 4, cols: 4,
        solution: [
            GridPosition(row:0,col:0), GridPosition(row:0,col:1),
            GridPosition(row:1,col:1), GridPosition(row:1,col:0),
            GridPosition(row:2,col:0), GridPosition(row:3,col:0),
            GridPosition(row:3,col:1), GridPosition(row:2,col:1),
            GridPosition(row:2,col:2), GridPosition(row:3,col:2),
            GridPosition(row:3,col:3), GridPosition(row:2,col:3),
            GridPosition(row:1,col:3), GridPosition(row:0,col:3),
            GridPosition(row:0,col:2), GridPosition(row:1,col:2)
        ],
        waypoints: [
            Waypoint(id:1, pathIndex:0,  position:GridPosition(row:0,col:0),
                     rune:"ᚠ", runeName:"Fehu", meaning:"Wealth · Departure", isStart:true),
            Waypoint(id:2, pathIndex:5,  position:GridPosition(row:3,col:0),
                     rune:"ᚦ", runeName:"Thurisaz", meaning:"Giant · South headland"),
            Waypoint(id:3, pathIndex:11, position:GridPosition(row:2,col:3),
                     rune:"ᚹ", runeName:"Wunjo", meaning:"Joy · Harbour approach"),
            Waypoint(id:4, pathIndex:15, position:GridPosition(row:1,col:2),
                     rune:"ᚨ", runeName:"Ansuz", meaning:"Odin · Safe harbour", isEnd:true)
        ],
        blockedCells: [],
        journalEntry: JournalEntry(
            id: 7,
            title: "The Navigator's Fjord Tablet",
            body: "Viking navigators carved route maps into stone — not as straight lines but as exact sequences. This tablet shows an fjord crossing that requires entering an inlet before reaching the far harbour. I tried the direct route twice. It always stranded me. The inlet is not a detour. It is the route.",
            artifact: "ᚱ"
        ),
        decodedMessage: "The fjord demands that you trust the narrow passage. Those who refused to enter it, who clung to the outer coast thinking it safer, never found the harbour. The route is not the route that looks direct. It is the route that visits everywhere."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 3 · 4×4 · "The Cracked Stone"
    // BLOCKED: (2,2) — a split stone in the centre-right area
    //
    // Grid (X = blocked):
    //   [.][.][.][.]
    //   [.][.][.][.]
    //   [.][.][X][.]
    //   [.][.][.][.]
    //
    // Solution path (15 cells) — right-to-left start, winds around the crack:
    //   (0,3)→(0,2)→(0,1)→(0,0)
    //       →(1,0)→(2,0)→(3,0)→(3,1)→(2,1)→(1,1)
    //       →(1,2)→(1,3)→(2,3)→(3,3)→(3,2)
    //
    // Parity check (4×4 = 8B+8W; block (2,2) which is BLACK [2+2=4 even]):
    //   7 black + 8 white = 15 cells; |7-8|=1 ✓
    //
    // Why harder: start is top-right (non-obvious). Going top-left first seems
    // natural but leaves the bottom-right pocket inaccessible.
    //
    // Waypoints:
    //   idx 0  (0,3) ᛁ Isa     START
    //   idx 6  (3,0) ᛏ Tiwaz
    //   idx 14 (3,2) ᛟ END
    // ─────────────────────────────────────────────────
    static let level3 = PathLevel(
        id: 3,
        civilization: .norse,
        title: "The Cracked Stone",
        subtitle: "What the Fault Demands",
        lore: "The runestone had been split by frost — one stone in its centre-right was shattered and impassable. But the inscription remained readable around the fault. The rune-carver had anticipated this: the path was designed to avoid the crack from the beginning.",
        inscriptions: [
            "One stone in the centre-right is impassable — split by frost before any rune was carved. The path begins at the far right of the first row, where ᛁ Isa marks the cold's origin. Route around the crack as you would route around a reef at sea.",
            "The cracked stone lies in the second column from the right, second row from the bottom. Route around it as you would route around a reef.",
            "ᛏ Tiwaz — justice, sacrifice — rests at the bottom-left corner. You cannot reach it without first tracing the entire left side of the tablet.",
            "ᛟ Othala closes the path near the base. Home is found not by avoiding the damaged stone but by accepting the longer route around it."
        ],
        rows: 4, cols: 4,
        solution: [
            GridPosition(row:0,col:3), GridPosition(row:0,col:2), GridPosition(row:0,col:1), GridPosition(row:0,col:0),
            GridPosition(row:1,col:0), GridPosition(row:2,col:0), GridPosition(row:3,col:0),
            GridPosition(row:3,col:1), GridPosition(row:2,col:1), GridPosition(row:1,col:1),
            GridPosition(row:1,col:2), GridPosition(row:1,col:3),
            GridPosition(row:2,col:3), GridPosition(row:3,col:3), GridPosition(row:3,col:2)
        ],
        waypoints: [
            Waypoint(id:1, pathIndex:0,  position:GridPosition(row:0,col:3),
                     rune:"ᛁ", runeName:"Isa", meaning:"Ice · The crack's origin", isStart:true),
            Waypoint(id:2, pathIndex:6,  position:GridPosition(row:3,col:0),
                     rune:"ᛏ", runeName:"Tiwaz", meaning:"Justice · The far corner"),
            Waypoint(id:3, pathIndex:14, position:GridPosition(row:3,col:2),
                     rune:"ᛟ", runeName:"Othala", meaning:"Home · The end of the detour", isEnd:true)
        ],
        blockedCells: [GridPosition(row:2, col:2)],
        journalEntry: JournalEntry(
            id: 8,
            title: "The Frost-Split Inscription",
            body: "Not all runestones survive intact. This one had been cracked by permafrost — one stone impassable, the surrounding inscription still legible. I spent an hour assuming the path started from the top-left. It starts from the top-right. Once I saw that, the route around the fault was the only one possible.",
            artifact: "ᛁ"
        ),
        decodedMessage: "The frost does not break what is meant to last. It reveals the shape that was always there. When one stone is removed from the path, the route does not end. It simply shows its true form — the form that was always waiting for the obstacle."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 4 · 4×4 · "The Broken Altar"
    // BLOCKED: (0,3) — the far top-right corner stone has fallen
    //
    // Grid (X = blocked):
    //   [.][.][.][X]
    //   [.][.][.][.]
    //   [.][.][.][.]
    //   [.][.][.][.]
    //
    // Solution path (15 cells):
    //   (0,0)→(0,1)→(0,2)
    //       →(1,2)→(1,3)→(2,3)→(3,3)→(3,2)→(2,2)→(2,1)→(3,1)→(3,0)
    //       →(2,0)→(1,0)→(1,1)
    //
    // Parity check: block (0,3) WHITE [0+3=3 odd]:
    //   8 black + 7 white = 15 cells; |8-7|=1 ✓
    //
    // Why harder: missing corner means (0,2) connects DOWN not right.
    // The path turns south immediately after the top row instead of
    // continuing east — the blocked corner forces a non-obvious descent.
    // The ending (1,1) is interior, requiring the bottom-half zigzag first.
    //
    // Waypoints:
    //   idx 0  (0,0) ᚲ Kenaz   START
    //   idx 11 (3,0) ᚾ Naudiz
    //   idx 14 (1,1) ᚷ END
    // ─────────────────────────────────────────────────
    static let level4 = PathLevel(
        id: 4,
        civilization: .norse,
        title: "The Broken Altar",
        subtitle: "What Remains When a Corner Falls",
        lore: "The altar stone at Gamla Uppsala had lost its top-right corner to a Viking raid — carried off as a trophy or simply fallen. What remained was an L-shaped tablet, still inscribed. The runes could still be read. The path could still be traced. It only required accepting the shape as it was.",
        inscriptions: [
            "The top-right corner is gone — carried off or fallen — and what remains is an L-shaped altar. The path cannot sweep all the way across the first row. ᚲ Kenaz illuminates the top-left; from there, the missing corner forces a southward turn earlier than expected.",
            "The missing corner stone changes everything. Do not plan as if it were there. Plan as if the stone to the left of the gap is a dead end — and route accordingly.",
            "ᚾ Naudiz — necessity — marks the bottom-left corner. It is reached last on the left side, after a long diagonal sweep through the lower half of the altar.",
            "ᚷ Gebo — the gift — closes the path in the interior of the second row. The altar ends not at an edge but inward, where the gift of completion is found."
        ],
        rows: 4, cols: 4,
        solution: [
            GridPosition(row:0,col:0), GridPosition(row:0,col:1), GridPosition(row:0,col:2),
            GridPosition(row:1,col:2), GridPosition(row:1,col:3),
            GridPosition(row:2,col:3), GridPosition(row:3,col:3),
            GridPosition(row:3,col:2), GridPosition(row:2,col:2), GridPosition(row:2,col:1),
            GridPosition(row:3,col:1), GridPosition(row:3,col:0),
            GridPosition(row:2,col:0), GridPosition(row:1,col:0), GridPosition(row:1,col:1)
        ],
        waypoints: [
            Waypoint(id:1, pathIndex:0,  position:GridPosition(row:0,col:0),
                     rune:"ᚲ", runeName:"Kenaz", meaning:"Torch · The start", isStart:true),
            Waypoint(id:2, pathIndex:11, position:GridPosition(row:3,col:0),
                     rune:"ᚾ", runeName:"Naudiz", meaning:"Need · Necessity"),
            Waypoint(id:3, pathIndex:14, position:GridPosition(row:1,col:1),
                     rune:"ᚷ", runeName:"Gebo", meaning:"Gift · The interior close", isEnd:true)
        ],
        blockedCells: [GridPosition(row:0, col:3)],
        journalEntry: JournalEntry(
            id: 9,
            title: "The Altar With the Missing Corner",
            body: "Gamla Uppsala. The stone had been L-shaped for centuries. Every scholar before me tried to read it as if the corner were simply missing text — they filled it in. But the path inscribed on it ends at (1,1), well inside the stone. The missing corner is not a damage. It is part of the design.",
            artifact: "ᛟ"
        ),
        decodedMessage: "When something is taken from the altar — a corner, a word, a life — the inscription does not become incomplete. It becomes a different shape. Route the path through what remains. The shape that is left is always enough to reach the end."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 5 · 5×5 · "Jormungandr's Back"
    // BLOCKED: (0,2) and (4,2) — the serpent's coils block the centre-top and
    //          centre-bottom, splitting the top and bottom rows
    //
    // Grid (X = blocked):
    //   [.][.][X][.][.]
    //   [.][.][.][.][.]
    //   [.][.][.][.][.]
    //   [.][.][.][.][.]
    //   [.][.][X][.][.]
    //
    // Solution path (23 cells):
    //   (1,0)→(0,0)→(0,1)→(1,1)→(2,1)→(2,0)→(3,0)→(4,0)
    //       →(4,1)→(3,1)→(3,2)→(2,2)→(1,2)→(1,3)→(0,3)→(0,4)
    //       →(1,4)→(2,4)→(2,3)→(3,3)→(4,3)→(4,4)→(3,4)
    //
    // Parity check: block (0,2) BLACK [0+2=2] and (4,2) BLACK [4+2=6]:
    //   Original 5×5: 13B+12W. Block 2 black → 11B+12W; |11-12|=1 ✓
    //
    // Why hard: the two blocked cells split the top row into (0,0)(0,1) and
    // (0,3)(0,4) — you can't cross the top in one sweep. The bottom row is
    // similarly split. This forces the path to enter the top/bottom corner
    // pockets through their side connections, requiring careful planning of
    // when each pocket is visited. Only 3 waypoints — minimal guidance.
    //
    // Waypoints:
    //   idx 0  (1,0) ᛟ Othala  START
    //   idx 7  (4,0) ᚦ Thurisaz
    //   idx 22 (3,4) ᚠ Fehu    END
    // ─────────────────────────────────────────────────
    static let level5 = PathLevel(
        id: 5,
        civilization: .norse,
        title: "Jormungandr's Back",
        subtitle: "The World Serpent Divides the Sea",
        lore: "Jormungandr — the Midgard Serpent — lies beneath the sea with its body coiled around the world. Its back breaks the surface in two places, blocking the direct path across the water. The only route is the one that honours the serpent's shape: curving around each coil, not through it.",
        inscriptions: [
            "Sealed by the serpent's bulk: two stones, one at the top-centre, one at the bottom-centre, cannot be stepped on. The only route curves around each coil — into the left pocket first, descending, then north and east. ᛟ Othala begins one cell in from the edge, not at the corner itself.",
            "ᛟ Othala does not stand at the corner — it begins one step in from the edge. The path must enter the top-left pocket before descending. Do not begin at the actual corner.",
            "ᚦ Thurisaz — the obstacle — marks the bottom-left corner. You must descend the full left side before you may turn. The serpent's first coil forces this.",
            "Only three runes are visible on this stone. The remaining twenty must be found through deduction alone. The serpent does not offer more guidance than this."
        ],
        rows: 5, cols: 5,
        solution: [
            GridPosition(row:1,col:0), GridPosition(row:0,col:0), GridPosition(row:0,col:1),
            GridPosition(row:1,col:1), GridPosition(row:2,col:1), GridPosition(row:2,col:0),
            GridPosition(row:3,col:0), GridPosition(row:4,col:0),
            GridPosition(row:4,col:1), GridPosition(row:3,col:1), GridPosition(row:3,col:2),
            GridPosition(row:2,col:2), GridPosition(row:1,col:2),
            GridPosition(row:1,col:3), GridPosition(row:0,col:3), GridPosition(row:0,col:4),
            GridPosition(row:1,col:4), GridPosition(row:2,col:4), GridPosition(row:2,col:3),
            GridPosition(row:3,col:3), GridPosition(row:4,col:3),
            GridPosition(row:4,col:4), GridPosition(row:3,col:4)
        ],
        waypoints: [
            Waypoint(id:1, pathIndex:0,  position:GridPosition(row:1,col:0),
                     rune:"ᛟ", runeName:"Othala", meaning:"Home · One step from the edge", isStart:true),
            Waypoint(id:2, pathIndex:7,  position:GridPosition(row:4,col:0),
                     rune:"ᚦ", runeName:"Thurisaz", meaning:"Thorn · First coil cleared"),
            Waypoint(id:3, pathIndex:22, position:GridPosition(row:3,col:4),
                     rune:"ᚠ", runeName:"Fehu", meaning:"Wealth · The serpent's tail", isEnd:true)
        ],
        blockedCells: [GridPosition(row:0, col:2), GridPosition(row:4, col:2)],
        journalEntry: JournalEntry(
            id: 10,
            title: "The Jormungandr Inscription",
            body: "The final tablet was the hardest. Two stones blocked — not randomly, but symmetrically, splitting both the top and bottom rows. I kept trying to sweep across the full width. Every attempt failed at the same point. The solution required entering the top-left pocket before descending — a move that looks wrong until you understand why the serpent forced it. I spent three days on this stone.",
            artifact: "ᚾ"
        ),
        decodedMessage: "Jormungandr does not block the path to be cruel. It blocks the path to teach you where the path actually goes. Every obstacle in the world is like this — not an ending but a redirection. The serpent holds the world together precisely because it cannot be crossed directly. You must go around."
    )
}
