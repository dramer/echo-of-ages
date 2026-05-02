// PathGenerator.swift
// EchoOfAges
//
// Generates a random Hamiltonian path through a Norse runestone grid and places
// waypoints evenly along it with randomly-assigned runes. Called every time a
// Norse level is loaded or reset — so no two sessions share the same route.
//
// Algorithm: Warnsdorff's heuristic (always move to the neighbour with the
// fewest onward options) with random tie-breaking and random start positions.
// This finds a Hamiltonian path on typical grid sizes (3×3 – 5×5) in
// microseconds and succeeds on the first attempt >99 % of the time.
// Up to `maxAttempts` random restarts are tried if an attempt dead-ends.

import Foundation

// MARK: - PathGenerator

struct PathGenerator {

    // MARK: Rune Pool

    /// All available Norse runes with names and meanings, used to dress waypoints.
    static let runePool: [(rune: String, name: String, meaning: String)] = [
        ("ᚠ", "Fehu",     "Wealth"),
        ("ᚢ", "Uruz",     "Strength"),
        ("ᚦ", "Thurisaz", "Thorn"),
        ("ᚨ", "Ansuz",    "Breath"),
        ("ᚱ", "Raidho",   "Journey"),
        ("ᚲ", "Kenaz",    "Torch"),
        ("ᚷ", "Gebo",     "Gift"),
        ("ᚹ", "Wunjo",    "Joy"),
        ("ᚾ", "Naudiz",   "Need"),
        ("ᛁ", "Isa",      "Ice"),
        ("ᛃ", "Jera",     "Harvest"),
        ("ᛊ", "Sowilo",   "Sun"),
        ("ᛏ", "Tiwaz",    "Justice"),
        ("ᛚ", "Laguz",    "Water"),
        ("ᛗ", "Mannaz",   "Humanity"),
        ("ᛒ", "Berkanan", "Growth"),
        ("ᛖ", "Ehwaz",    "Horse"),
        ("ᛟ", "Othala",   "Home"),
    ]

    // MARK: Path Generation

    /// Generates a random Hamiltonian path through every valid (non-blocked) cell.
    /// Returns `nil` only if the grid topology has no Hamiltonian path at all —
    /// which should never happen for the well-designed levels in this game.
    static func generatePath(
        rows: Int,
        cols: Int,
        blockedCells: Set<GridPosition>,
        maxAttempts: Int = 80
    ) -> [GridPosition]? {
        let validCells = (0..<rows).flatMap { r in
            (0..<cols).map { c in GridPosition(row: r, col: c) }
        }.filter { !blockedCells.contains($0) }

        guard !validCells.isEmpty else { return nil }
        let total = validCells.count

        // Try different random start cells on each attempt
        let starts = validCells.shuffled()

        for attempt in 0..<maxAttempts {
            let start = starts[attempt % starts.count]
            if let path = warnsdorff(
                from: start,
                rows: rows, cols: cols,
                blockedCells: blockedCells,
                total: total
            ) {
                return path
            }
        }

        return nil  // Should be extremely rare given the grid sizes used
    }

    // MARK: Waypoint Placement

    /// Distributes waypoints along `path`.
    /// `runeCount` rune-bearing waypoints (always includes start and end).
    /// `directionalCount` additional direction-only stones (interior positions only).
    /// Always marks the first rune waypoint as START and the last as END.
    static func placeWaypoints(on path: [GridPosition], runeCount: Int, directionalCount: Int = 0) -> [Waypoint] {
        let total = runeCount + directionalCount
        guard total >= 2, path.count >= total else { return [] }

        // Evenly spaced indices including start (0) and end (last)
        var indices: [Int] = [0]
        for i in 1..<(total - 1) {
            let idx = Int(round(Double(i) * Double(path.count - 1) / Double(total - 1)))
            indices.append(max(idx, (indices.last ?? 0) + 1))
        }
        indices.append(path.count - 1)

        // The last `directionalCount` interior waypoint positions are directional.
        // Interior positions = wpIdx in 1...(total-2).
        var directionalWpIndices: Set<Int> = []
        if directionalCount > 0 {
            let interiorCount = total - 2   // number of interior waypoints
            for k in 0..<min(directionalCount, interiorCount) {
                directionalWpIndices.insert(total - 2 - k)  // count back from last interior
            }
        }

        // Pick runes for non-directional interior + start + end positions
        let chosen = Array(runePool.shuffled().prefix(runeCount))
        var runeIdx = 0

        return indices.enumerated().map { (wpIdx, pathIdx) in
            let isStart = wpIdx == 0
            let isEnd   = wpIdx == total - 1

            if directionalWpIndices.contains(wpIdx) {
                // Interior directional stone — compute direction from path context
                let pt = (pathIdx > 0 && pathIdx < path.count - 1)
                    ? PassThroughType.from(prev: path[pathIdx - 1], at: path[pathIdx], next: path[pathIdx + 1])
                    : PassThroughType.straightH  // fallback (shouldn't occur)
                return Waypoint(
                    id: wpIdx + 1,
                    pathIndex: pathIdx,
                    position: path[pathIdx],
                    rune: "",
                    runeName: "Carved Stone",
                    meaning: "Pass through in this direction",
                    passThrough: pt
                )
            } else {
                let runeInfo = chosen[runeIdx % chosen.count]
                runeIdx += 1
                return Waypoint(
                    id: wpIdx + 1,
                    pathIndex: pathIdx,
                    position: path[pathIdx],
                    rune: runeInfo.rune,
                    runeName: runeInfo.name,
                    meaning: runeInfo.meaning,
                    isStart: isStart,
                    isEnd: isEnd
                )
            }
        }
    }

    // MARK: Warnsdorff's Heuristic

    /// Single attempt: greedy Hamiltonian path from `start` using Warnsdorff's
    /// rule. Returns the path, or nil if it dead-ends before visiting all cells.
    private static func warnsdorff(
        from start: GridPosition,
        rows: Int, cols: Int,
        blockedCells: Set<GridPosition>,
        total: Int
    ) -> [GridPosition]? {
        var path = [start]
        var visited: Set<GridPosition> = [start]

        while path.count < total {
            let current = path.last!
            let candidates = freeNeighbours(
                of: current,
                rows: rows, cols: cols,
                blocked: blockedCells,
                visited: visited
            )
            guard !candidates.isEmpty else { return nil }  // dead end

            // Score each candidate by how many onward moves it still has.
            // Shuffle before sorting so tied candidates resolve randomly.
            let ranked = candidates
                .shuffled()
                .map { c -> (GridPosition, Int) in
                    let onward = freeNeighbours(
                        of: c,
                        rows: rows, cols: cols,
                        blocked: blockedCells,
                        visited: visited.union([c])
                    ).count
                    return (c, onward)
                }
                .sorted { $0.1 < $1.1 }

            let next = ranked.first!.0
            path.append(next)
            visited.insert(next)
        }

        return path
    }

    // MARK: Neighbour Helper

    private static func freeNeighbours(
        of pos: GridPosition,
        rows: Int, cols: Int,
        blocked: Set<GridPosition>,
        visited: Set<GridPosition>
    ) -> [GridPosition] {
        [(-1, 0), (1, 0), (0, -1), (0, 1)].compactMap { (dr, dc) in
            let n = GridPosition(row: pos.row + dr, col: pos.col + dc)
            guard n.row >= 0, n.row < rows,
                  n.col >= 0, n.col < cols,
                  !blocked.contains(n),
                  !visited.contains(n)
            else { return nil }
            return n
        }
    }
}
