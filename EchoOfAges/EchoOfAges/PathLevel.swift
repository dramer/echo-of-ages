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
//   6. No backtracking — use the Reset button to start over if you reach a dead end.
//
// Difficulty design principles:
//   • Irregular (non-serpentine) paths with dead-end traps
//   • Blocked cells change grid topology — standard patterns fail
//   • Fewer waypoints on harder levels force deduction over guidance
//
// Level progression:
//   L1  4×4   0 blocked   3 waypoints   Odin's Spiral        — clockwise outer spiral
//   L2  4×4   1 blocked   3 waypoints   The Fjord Route      — cracked stone near inlet
//   L3  5×5   2 blocked   3 waypoints   The Cracked Stone    — opposite corners blocked
//   L4  5×5   3 blocked   2 waypoints   The Broken Altar     — 3 obstacles, start+end only
//   L5  6×6   3 blocked   2 waypoints   Jormungandr's Back   — 6×6, 3 coils, no guidance

import Foundation

// MARK: - PassThroughType

/// Describes how the path must pass through a directional waypoint cell.
/// The constraint is symmetric — the path may traverse the cell in either direction
/// along the indicated axis (e.g. left→right OR right→left for .straightH).
enum PassThroughType: Equatable {
    case straightH   // ─  path enters/exits through left and right sides
    case straightV   // │  path enters/exits through top and bottom
    case bendNE      // ┌  path connects N neighbor (row-1) and E neighbor (col+1)
    case bendNW      // ┐  path connects N neighbor (row-1) and W neighbor (col-1)
    case bendSE      // └  path connects S neighbor (row+1) and E neighbor (col+1)
    case bendSW      // ┘  path connects S neighbor (row+1) and W neighbor (col-1)

    /// Unicode box-drawing character representing this direction.
    var symbol: String {
        switch self {
        case .straightH: return "─"
        case .straightV: return "│"
        case .bendNE:    return "┌"
        case .bendNW:    return "┐"
        case .bendSE:    return "└"
        case .bendSW:    return "┘"
        }
    }

    /// Returns true if the path's prev→pos→next matches this constraint.
    /// The constraint is direction-agnostic (left→right == right→left).
    func isSatisfied(at pos: GridPosition, prev: GridPosition, next: GridPosition) -> Bool {
        allowedNeighborPair(at: pos) == Set([prev, next])
    }

    /// The two grid positions that must be {prev, next} in the player's path.
    func allowedNeighborPair(at pos: GridPosition) -> Set<GridPosition> {
        let r = pos.row, c = pos.col
        switch self {
        case .straightH: return [GridPosition(row: r, col: c-1), GridPosition(row: r, col: c+1)]
        case .straightV: return [GridPosition(row: r-1, col: c), GridPosition(row: r+1, col: c)]
        case .bendNE:    return [GridPosition(row: r-1, col: c), GridPosition(row: r, col: c+1)]
        case .bendNW:    return [GridPosition(row: r-1, col: c), GridPosition(row: r, col: c-1)]
        case .bendSE:    return [GridPosition(row: r+1, col: c), GridPosition(row: r, col: c+1)]
        case .bendSW:    return [GridPosition(row: r+1, col: c), GridPosition(row: r, col: c-1)]
        }
    }

    /// Determine the PassThroughType from the actual path context at a cell.
    static func from(prev: GridPosition, at pos: GridPosition, next: GridPosition) -> PassThroughType {
        let r = pos.row, c = pos.col
        let pair = Set([prev, next])
        if pair == Set([GridPosition(row: r, col: c-1), GridPosition(row: r, col: c+1)]) { return .straightH }
        if pair == Set([GridPosition(row: r-1, col: c), GridPosition(row: r+1, col: c)]) { return .straightV }
        if pair == Set([GridPosition(row: r-1, col: c), GridPosition(row: r, col: c+1)]) { return .bendNE }
        if pair == Set([GridPosition(row: r-1, col: c), GridPosition(row: r, col: c-1)]) { return .bendNW }
        if pair == Set([GridPosition(row: r+1, col: c), GridPosition(row: r, col: c+1)]) { return .bendSE }
        if pair == Set([GridPosition(row: r+1, col: c), GridPosition(row: r, col: c-1)]) { return .bendSW }
        return .straightH // fallback
    }
}

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
    let passThrough: PassThroughType?   // nil = rune waypoint; non-nil = directional stone

    /// True for direction-only stones — no rune, just a bend/straight constraint.
    var isDirectional: Bool { passThrough != nil }

    init(id: Int, pathIndex: Int, position: GridPosition,
         rune: String, runeName: String, meaning: String,
         isStart: Bool = false, isEnd: Bool = false,
         passThrough: PassThroughType? = nil) {
        self.id = id; self.pathIndex = pathIndex; self.position = position
        self.rune = rune; self.runeName = runeName; self.meaning = meaning
        self.isStart = isStart; self.isEnd = isEnd
        self.passThrough = passThrough
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

        // Rune waypoints must be visited in ascending pathIndex order.
        // Directional waypoints are NOT checked for order — only for direction.
        let runeWPs = waypoints.filter { !$0.isDirectional }.sorted { $0.pathIndex < $1.pathIndex }
        var wi = 0
        for pos in path {
            if wi < runeWPs.count && pos == runeWPs[wi].position { wi += 1 }
        }
        guard wi == runeWPs.count else { return false }

        // Directional waypoints: the path must pass through each one
        // with the correct bend or straight orientation.
        for wp in waypoints where wp.isDirectional {
            guard let idx = path.firstIndex(of: wp.position),
                  idx > 0, idx < path.count - 1 else { return false }
            guard wp.passThrough!.isSatisfied(at: wp.position,
                                              prev: path[idx - 1],
                                              next: path[idx + 1]) else { return false }
        }

        return true
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
    // LEVEL 1 · 4×4 · "Odin's Spiral"
    //
    // Grid (no blocked cells):
    //   [W1][ ][ ][ ]
    //   [ ] [ ][ ][ ]
    //   [ ] [ ][ ][ ]
    //   [ ][W2][ ][.]→[W3]
    //
    // Solution path (16 cells) — clockwise outer spiral, ends interior:
    //   (0,0)→(0,1)→(0,2)→(0,3)→(1,3)→(2,3)→(3,3)→(3,2)
    //       →(3,1)→(3,0)→(2,0)→(1,0)→(1,1)→(1,2)→(2,2)→(2,1)
    //
    // Why harder than row-sweep: going along row 0 first is correct, but the
    // path then runs the entire right column, bottom row, left column — before
    // threading inward. Ending at the interior (2,1) requires planning the
    // inner spiral before committing to the outer ring. A simple serpentine
    // approach leaves either (2,1) or (1,1) isolated.
    //
    // Parity (4×4): 8B+8W, 0 blocked → |8-8|=0 ✓ (Hamiltonian path exists)
    //
    // Waypoints:
    //   idx 0  (0,0) ᚠ Fehu   START
    //   idx 8  (3,1) ᚱ Raidho — bottom ring midpoint
    //   idx 15 (2,1) ᛟ Othala END — interior
    // ─────────────────────────────────────────────────
    static let level1 = PathLevel(
        id: 1,
        civilization: .norse,
        title: "Odin's Spiral",
        subtitle: "The Allfather's Pattern",
        lore: "Before the worlds were named, Odin carved his knowledge into the first runestone in the shape of a spiral — not left to right, but outward first, then inward. The path walks the full outer ring before threading toward the centre. The first move is east. The centre is reached last.",
        inscriptions: [
            "The path begins in the top-left corner, where ᚠ Fehu marks the threshold of wealth and beginning. Walk east first — the outer ring runs clockwise. Do not turn south until you have reached the far edge.",
            "ᚱ Raidho — the rune of roads — marks a point on the bottom edge. The outer ring must be fully walked before the inner path opens. The journey is not straight.",
            "ᛟ Othala, home, rests in the interior — not at a corner but inside the ring. All outer paths lead here only when the ring has been completed. The centre is always reached last."
        ],
        rows: 4, cols: 4,
        solution: [
            GridPosition(row:0,col:0), GridPosition(row:0,col:1), GridPosition(row:0,col:2), GridPosition(row:0,col:3),
            GridPosition(row:1,col:3), GridPosition(row:2,col:3), GridPosition(row:3,col:3),
            GridPosition(row:3,col:2), GridPosition(row:3,col:1), GridPosition(row:3,col:0),
            GridPosition(row:2,col:0), GridPosition(row:1,col:0),
            GridPosition(row:1,col:1), GridPosition(row:1,col:2),
            GridPosition(row:2,col:2), GridPosition(row:2,col:1)
        ],
        waypoints: [
            Waypoint(id:1, pathIndex:0,  position:GridPosition(row:0,col:0),
                     rune:"ᚠ", runeName:"Fehu", meaning:"Wealth · The threshold", isStart:true),
            Waypoint(id:2, pathIndex:8,  position:GridPosition(row:3,col:1),
                     rune:"ᚱ", runeName:"Raidho", meaning:"Journey · The far ring"),
            Waypoint(id:3, pathIndex:15, position:GridPosition(row:2,col:1),
                     rune:"ᛟ", runeName:"Othala", meaning:"Home · The interior end", isEnd:true)
        ],
        blockedCells: [],
        journalEntry: JournalEntry(
            id: 6,
            title: "The First Runestone",
            body: "The spiral is Odin's signature — not inward from the start, but outward first. Walk the full outer ring before the centre becomes reachable. I made the mistake of cutting inward too early. The stone taught me: complete the ring before you thread the interior.",
            artifact: "ᚠ"
        ),
        decodedMessage: "The spiral is not decoration. It is instruction. You cannot reach the centre of anything without first walking its full edge. All the way around. Every stone. Only then does the interior open — and only from the one direction that remains."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 2 · 4×4 · "The Fjord Route"
    // BLOCKED: (1,1) — a cracked stone near the inlet
    //
    // Grid (X = blocked):
    //   [.][.][.][.]
    //   [.][X][.][.]
    //   [.][.][.][.]
    //   [.][.][.][.]
    //
    // Solution path (15 cells):
    //   (0,1)→(0,0)→(1,0)→(2,0)→(3,0)→(3,1)→(2,1)→(2,2)
    //       →(1,2)→(0,2)→(0,3)→(1,3)→(2,3)→(3,3)→(3,2)
    //
    // Parity check (4×4 = 8B+8W; block (1,1) BLACK [1+1=2 even]):
    //   7 black + 8 white = 15 cells; |7-8|=1 ✓
    //
    // Why harder: the cracked stone near the inlet severs the obvious row-sweep.
    // The start is NOT the top-left corner — that corner must be visited second,
    // doubling back immediately. The path then must descend the left column
    // before crossing through the open middle toward the right side.
    //
    // Waypoints:
    //   idx 0  (0,1) ᚠ Fehu    START — one step east of the corner
    //   idx 7  (2,2) ᚾ Naudiz  — centre crossing
    //   idx 14 (3,2) ᛟ Othala  END
    // ─────────────────────────────────────────────────
    static let level2 = PathLevel(
        id: 2,
        civilization: .norse,
        title: "The Fjord Route",
        subtitle: "The Cracked Stone Blocks the Inlet",
        lore: "A fjord demands that you enter its narrow throat before you may reach its far end. One stone near the inlet is cracked and impassable — it cuts the obvious path across the top. The navigator who tries to sweep east first will find the left column stranded. The route begins one step in from the corner.",
        inscriptions: [
            "One stone near the top-left is cracked and impassable. The inlet is still navigable — but the path cannot cross it directly. ᚠ Fehu opens the route one step east of the corner. The first move is west — back toward the corner — before the path descends.",
            "The cracked stone divides the row. What looks like a simple east-west crossing is now impossible without first doubling back. Descend the full left column before you attempt to cross.",
            "ᚾ Naudiz — necessity — marks the crossing point in the centre. You reach it from the left, not from above. The path climbs back up the right side of the grid from here.",
            "ᛟ Othala closes the route at the bottom of the right-centre. All four sides of the fjord have been touched by the time you arrive."
        ],
        rows: 4, cols: 4,
        solution: [
            GridPosition(row:0,col:1), GridPosition(row:0,col:0),
            GridPosition(row:1,col:0), GridPosition(row:2,col:0), GridPosition(row:3,col:0),
            GridPosition(row:3,col:1), GridPosition(row:2,col:1),
            GridPosition(row:2,col:2), GridPosition(row:1,col:2), GridPosition(row:0,col:2),
            GridPosition(row:0,col:3), GridPosition(row:1,col:3),
            GridPosition(row:2,col:3), GridPosition(row:3,col:3), GridPosition(row:3,col:2)
        ],
        waypoints: [
            Waypoint(id:1, pathIndex:0,  position:GridPosition(row:0,col:1),
                     rune:"ᚠ", runeName:"Fehu", meaning:"Wealth · One step from the corner", isStart:true),
            Waypoint(id:2, pathIndex:7,  position:GridPosition(row:2,col:2),
                     rune:"ᚾ", runeName:"Naudiz", meaning:"Need · The centre crossing"),
            Waypoint(id:3, pathIndex:14, position:GridPosition(row:3,col:2),
                     rune:"ᛟ", runeName:"Othala", meaning:"Home · The far headland", isEnd:true)
        ],
        blockedCells: [GridPosition(row:1, col:1)],
        journalEntry: JournalEntry(
            id: 7,
            title: "The Navigator's Fjord Tablet",
            body: "Viking navigators carved route maps into stone — not as straight lines but as exact sequences. This tablet shows a fjord crossing where a cracked stone near the inlet forces a non-obvious start. I tried sweeping east first. It left the left column stranded every time. The route begins one step east of the corner — not at it.",
            artifact: "ᚱ"
        ),
        decodedMessage: "The fjord demands that you trust the narrow passage. When one stone is cracked, the whole approach must change. Those who swept east from the corner always ran aground. The route begins by doubling back — one step west, into what looks like retreat. Then the column opens."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 3 · 5×5 · "The Cracked Stone"
    // BLOCKED: (0,0) and (4,4) — opposite corners shattered by frost and time
    //
    // Grid (X = blocked):
    //   [X][.][.][.][.]
    //   [.][.][.][.][.]
    //   [.][.][.][.][.]
    //   [.][.][.][.][.]
    //   [.][.][.][.][X]
    //
    // Solution path (23 cells):
    //   (0,1)→(0,2)→(0,3)→(0,4)→(1,4)→(1,3)→(1,2)→(1,1)→(1,0)
    //       →(2,0)→(3,0)→(4,0)→(4,1)→(4,2)→(4,3)→(3,3)→(3,4)
    //       →(2,4)→(2,3)→(2,2)→(2,1)→(3,1)→(3,2)
    //
    // Parity check (5×5 = 13B+12W; block (0,0) BLACK [0+0=0] and (4,4) BLACK [4+4=8]):
    //   11 black + 12 white = 23 cells; |11-12|=1 ✓
    //
    // Why harder: both corners blocked creates two "dead ends" — (0,1) and (4,3)
    // must each be handled carefully. The path must enter the top row from (0,1),
    // not a corner, and sweep the bottom via the left side before cutting back
    // through the interior. The interior return (2,1)→(3,1)→(3,2) is easy to miss.
    //
    // Waypoints:
    //   idx 0  (0,1) ᛁ Isa    START — top row, one step from blocked corner
    //   idx 11 (4,0) ᛏ Tiwaz  — bottom-left reached after sweeping the left side
    //   idx 22 (3,2) ᛟ Othala END — interior finish
    // ─────────────────────────────────────────────────
    static let level3 = PathLevel(
        id: 3,
        civilization: .norse,
        title: "The Cracked Stone",
        subtitle: "Two Corners Lost to Frost",
        lore: "Permafrost had claimed both corners of this runestone — the top-left and bottom-right, each shattered beyond use. The inscription survived between them. The rune-carver had built the path to begin and end near the damage, not despite it. Both corners were anticipated long before the frost arrived.",
        inscriptions: [
            "Two corner stones are gone — one at the top-left, one at the bottom-right. The path cannot begin at either corner. ᛁ Isa marks the cold's origin, one step from the shattered top-left stone. The route sweeps the top row first, then descends the far side.",
            "After sweeping the top, descend the right column and cross the bottom. The left side must be approached from below — the column runs all the way up before you can enter the interior.",
            "ᛏ Tiwaz — justice, sacrifice — marks a point on the descent. The path passes through a carved stone whose direction is inscribed upon it. The carving tells you which way the path must bend.",
            "ᛟ Othala closes the path in the interior. Three rune waypoints and one carved directional stone are visible — the rest must be deduced."
        ],
        rows: 5, cols: 5,
        solution: [
            GridPosition(row:0,col:1), GridPosition(row:0,col:2), GridPosition(row:0,col:3), GridPosition(row:0,col:4),
            GridPosition(row:1,col:4), GridPosition(row:1,col:3), GridPosition(row:1,col:2), GridPosition(row:1,col:1), GridPosition(row:1,col:0),
            GridPosition(row:2,col:0), GridPosition(row:3,col:0), GridPosition(row:4,col:0),
            GridPosition(row:4,col:1), GridPosition(row:4,col:2), GridPosition(row:4,col:3),
            GridPosition(row:3,col:3), GridPosition(row:3,col:4),
            GridPosition(row:2,col:4), GridPosition(row:2,col:3), GridPosition(row:2,col:2), GridPosition(row:2,col:1),
            GridPosition(row:3,col:1), GridPosition(row:3,col:2)
        ],
        waypoints: [
            Waypoint(id:1, pathIndex:0,  position:GridPosition(row:0,col:1),
                     rune:"ᛁ", runeName:"Isa", meaning:"Ice · One step from the shattered corner", isStart:true),
            Waypoint(id:2, pathIndex:7,  position:GridPosition(row:1,col:1),
                     rune:"ᛏ", runeName:"Tiwaz", meaning:"Justice · The descent begins"),
            Waypoint(id:3, pathIndex:15, position:GridPosition(row:3,col:3),
                     rune:"", runeName:"Carved Stone", meaning:"Pass through in this direction",
                     passThrough:.bendSE),
            Waypoint(id:4, pathIndex:22, position:GridPosition(row:3,col:2),
                     rune:"ᛟ", runeName:"Othala", meaning:"Home · The interior close", isEnd:true)
        ],
        blockedCells: [GridPosition(row:0, col:0), GridPosition(row:4, col:4)],
        journalEntry: JournalEntry(
            id: 8,
            title: "The Two-Corner Stone",
            body: "Both ends of this runestone were shattered — not by accident but, I now believe, by design. The inscription begins one step from where a corner would have been and ends in the interior. I spent two days trying to start at (0,0). It does not exist. The path starts at (0,1). Once I accepted that, the descent made sense.",
            artifact: "ᛁ"
        ),
        decodedMessage: "The frost breaks what stands at the edge. The corners are always first to go. But the path was never meant to begin or end there. It begins one step in — where the stone still holds — and ends in the interior, where the cold never reached. The design anticipated the damage."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 4 · 5×5 · "The Broken Altar"
    // BLOCKED: (0,0) BLACK, (4,4) BLACK, (2,3) WHITE
    //          Three scattered obstacles — no corner anchor, interior gap
    //
    // Grid (X = blocked):
    //   [X][.][.][.][.]
    //   [.][.][.][.][.]
    //   [.][.][.][X][.]
    //   [.][.][.][.][.]
    //   [.][.][.][.][X]
    //
    // Solution path (22 cells):
    //   (0,1)→(0,2)→(0,3)→(0,4)→(1,4)→(1,3)→(1,2)→(1,1)→(1,0)
    //       →(2,0)→(3,0)→(4,0)→(4,1)→(3,1)→(2,1)→(2,2)→(3,2)→(4,2)
    //       →(4,3)→(3,3)→(3,4)→(2,4)
    //
    // Parity check (5×5 = 13B+12W; block (0,0) B + (4,4) B + (2,3) W):
    //   11 black + 11 white = 22 cells; |11-11|=0 ✓
    //
    // Why hard: NO waypoints reveal the interior path (only start + end shown).
    // The scattered blocks mean no corner anchors and a mid-grid gap at (2,3).
    // The route through columns 3-4 must visit (3,3)(3,4)(2,4) in a pocket
    // with only one entry/exit — easy to miss until the rest of the grid is done.
    //
    // Waypoints (2 only — start + end):
    //   idx 0  (0,1) ᚲ Kenaz  START
    //   idx 21 (2,4) ᚷ Gebo   END
    // ─────────────────────────────────────────────────
    static let level4 = PathLevel(
        id: 4,
        civilization: .norse,
        title: "The Broken Altar",
        subtitle: "Three Stones Missing, No Landmarks",
        lore: "The altar at Gamla Uppsala had been damaged three times over the centuries — one corner taken, one interior stone cracked through, one far corner collapsed. What remained was a 5×5 tablet with three gaps. No rune was carved to mark the route except at the very beginning and the very end. The path between them had to be held in the mind.",
        inscriptions: [
            "Three stones are gone — one top-left corner, one in the interior, one bottom-right corner. Only two runes mark this altar: ᚲ Kenaz at the start, ᚷ Gebo at the end. Two carved stones mark the direction the path must bend as it passes through them.",
            "Carved directional stones show a line — straight or bent — indicating how the path must thread through that cell. The path must enter and exit in the directions the carving shows.",
            "ᚷ Gebo — the gift — marks the end. It lies in the right side of the grid. The route to it winds through both directional constraints before arriving.",
            "Two runes. Two carved stones. The twenty-two steps between them belong to the solver."
        ],
        rows: 5, cols: 5,
        solution: [
            GridPosition(row:0,col:1), GridPosition(row:0,col:2), GridPosition(row:0,col:3), GridPosition(row:0,col:4),
            GridPosition(row:1,col:4), GridPosition(row:1,col:3), GridPosition(row:1,col:2), GridPosition(row:1,col:1), GridPosition(row:1,col:0),
            GridPosition(row:2,col:0), GridPosition(row:3,col:0), GridPosition(row:4,col:0),
            GridPosition(row:4,col:1), GridPosition(row:3,col:1), GridPosition(row:2,col:1),
            GridPosition(row:2,col:2), GridPosition(row:3,col:2), GridPosition(row:4,col:2),
            GridPosition(row:4,col:3), GridPosition(row:3,col:3), GridPosition(row:3,col:4),
            GridPosition(row:2,col:4)
        ],
        waypoints: [
            Waypoint(id:1, pathIndex:0,  position:GridPosition(row:0,col:1),
                     rune:"ᚲ", runeName:"Kenaz", meaning:"Torch · The start", isStart:true),
            Waypoint(id:2, pathIndex:7,  position:GridPosition(row:1,col:1),
                     rune:"", runeName:"Carved Stone", meaning:"Pass through in this direction",
                     passThrough:.straightH),
            Waypoint(id:3, pathIndex:14, position:GridPosition(row:2,col:1),
                     rune:"", runeName:"Carved Stone", meaning:"Pass through in this direction",
                     passThrough:.bendSE),
            Waypoint(id:4, pathIndex:21, position:GridPosition(row:2,col:4),
                     rune:"ᚷ", runeName:"Gebo", meaning:"Gift · The end", isEnd:true)
        ],
        blockedCells: [GridPosition(row:0, col:0), GridPosition(row:4, col:4), GridPosition(row:2, col:3)],
        journalEntry: JournalEntry(
            id: 9,
            title: "The Three-Gap Altar",
            body: "Gamla Uppsala. Three gaps, two runes. I spent most of a day convinced there was a third landmark somewhere I had missed. There isn't. The start and end are all you get. The path between them requires holding the full 22-cell route in your head — no markers, no shortcuts. I found it on my ninth attempt.",
            artifact: "ᛟ"
        ),
        decodedMessage: "When the altar is broken in three places, you cannot lean on landmarks. You must carry the path. Start at the torch. End at the gift. The twenty-two steps between are yours to reason out alone — no rune marks the way, no sign points the direction. Only the shape of what remains."
    )

    // ─────────────────────────────────────────────────
    // LEVEL 5 · 6×6 · "Jormungandr's Back"
    // BLOCKED: (1,1) BLACK, (2,5) WHITE, (3,3) BLACK
    //          Three coils — one near the top-left, one severing the right side,
    //          one cutting the interior diagonal
    //
    // Grid (X = blocked):
    //   [.][.][.][.][.][.]
    //   [.][X][.][.][.][.]
    //   [.][.][.][.][.][X]
    //   [.][.][.][X][.][.]
    //   [.][.][.][.][.][.]
    //   [.][.][.][.][.][.]
    //
    // Solution path (33 cells):
    //   (1,0)→(0,0)→(0,1)→(0,2)→(0,3)→(0,4)→(0,5)
    //       →(1,5)→(1,4)→(1,3)→(1,2)→(2,2)→(2,1)→(2,0)
    //       →(3,0)→(4,0)→(5,0)→(5,1)→(4,1)→(3,1)→(3,2)
    //       →(4,2)→(5,2)→(5,3)→(4,3)→(4,4)→(5,4)→(5,5)
    //       →(4,5)→(3,5)→(3,4)→(2,4)→(2,3)
    //
    // Parity check (6×6 = 18B+18W; block (1,1) B + (3,3) B + (2,5) W):
    //   16 black + 17 white = 33 cells; |16-17|=1 ✓
    //
    // Why hard: (1,0) is the forced start — (0,0) has only one non-blocked
    // neighbour after (1,1) is removed, so it must be visited from (1,0).
    // The (2,5) block severs the right edge midway — the right side pocket
    // (3,4)(3,5)(4,5) can only be entered from the bottom.
    // The (3,3) block creates an interior fork; column 3-4 must be handled
    // as two separate segments joined at the bottom. Only start + end shown.
    //
    // Waypoints (2 only — start + end):
    //   idx 0  (1,0) ᛟ Othala START — one step from corner
    //   idx 32 (2,3) ᚠ Fehu   END   — interior, right of the centre block
    // ─────────────────────────────────────────────────
    static let level5 = PathLevel(
        id: 5,
        civilization: .norse,
        title: "Jormungandr's Back",
        subtitle: "The World Serpent Coils Three Times",
        lore: "Jormungandr — the Midgard Serpent — lies coiled beneath the sea, its back breaking the surface in three places. Three stones on this 6×6 tablet are sealed by its body — one near the top-left, one severing the right edge, one cutting the interior. The only route is the one that honours each coil: curving around it, not through it.",
        inscriptions: [
            "Three stones are sealed by the serpent's coils. Only two runes mark the path: ᛟ Othala at the start, ᚠ Fehu at the end. Three carved directional stones mark required bends along the route — the path must thread through each one in the indicated direction.",
            "The serpent's first coil sits near the top-left — forcing the path to begin one step from the corner and sweep upward before descending.",
            "Carved directional stones show a line — straight or bent — cut into the face of the runestone. Your path must approach and exit each carved stone in exactly the direction shown.",
            "Thirty-three stones. Two runes. Three carved direction markers. The serpent leaves no further guidance."
        ],
        rows: 6, cols: 6,
        solution: [
            GridPosition(row:1,col:0), GridPosition(row:0,col:0), GridPosition(row:0,col:1),
            GridPosition(row:0,col:2), GridPosition(row:0,col:3), GridPosition(row:0,col:4), GridPosition(row:0,col:5),
            GridPosition(row:1,col:5), GridPosition(row:1,col:4), GridPosition(row:1,col:3), GridPosition(row:1,col:2),
            GridPosition(row:2,col:2), GridPosition(row:2,col:1), GridPosition(row:2,col:0),
            GridPosition(row:3,col:0), GridPosition(row:4,col:0), GridPosition(row:5,col:0),
            GridPosition(row:5,col:1), GridPosition(row:4,col:1), GridPosition(row:3,col:1), GridPosition(row:3,col:2),
            GridPosition(row:4,col:2), GridPosition(row:5,col:2),
            GridPosition(row:5,col:3), GridPosition(row:4,col:3), GridPosition(row:4,col:4),
            GridPosition(row:5,col:4), GridPosition(row:5,col:5),
            GridPosition(row:4,col:5), GridPosition(row:3,col:5), GridPosition(row:3,col:4),
            GridPosition(row:2,col:4), GridPosition(row:2,col:3)
        ],
        waypoints: [
            Waypoint(id:1, pathIndex:0,  position:GridPosition(row:1,col:0),
                     rune:"ᛟ", runeName:"Othala", meaning:"Home · One step from the sealed corner", isStart:true),
            Waypoint(id:2, pathIndex:8,  position:GridPosition(row:1,col:4),
                     rune:"", runeName:"Carved Stone", meaning:"Pass through in this direction",
                     passThrough:.straightH),
            Waypoint(id:3, pathIndex:16, position:GridPosition(row:5,col:0),
                     rune:"", runeName:"Carved Stone", meaning:"Pass through in this direction",
                     passThrough:.bendNE),
            Waypoint(id:4, pathIndex:24, position:GridPosition(row:4,col:3),
                     rune:"", runeName:"Carved Stone", meaning:"Pass through in this direction",
                     passThrough:.bendSE),
            Waypoint(id:5, pathIndex:32, position:GridPosition(row:2,col:3),
                     rune:"ᚠ", runeName:"Fehu", meaning:"Wealth · The serpent's final coil", isEnd:true)
        ],
        blockedCells: [GridPosition(row:1, col:1), GridPosition(row:2, col:5), GridPosition(row:3, col:3)],
        journalEntry: JournalEntry(
            id: 10,
            title: "The Jormungandr Inscription",
            body: "The final tablet was the largest. Six columns, six rows, three blocked stones, two runes. I spent four days on it. The mistake I kept making was treating the right side as a single corridor — it isn't. The mid-edge block cuts it in two. The bottom must be threaded as two separate zigzags that join at the floor. I found the path on my twelfth attempt.",
            artifact: "ᚾ"
        ),
        decodedMessage: "Jormungandr does not coil to be cruel. It coils to teach you where the path actually goes. Three obstacles, three redirections. None of them are punishments. Each one tells you: not here — somewhere else first. The serpent holds the world together precisely because it cannot be crossed. You must go around. Every time."
    )
}
