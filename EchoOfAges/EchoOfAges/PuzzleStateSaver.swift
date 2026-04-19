// PuzzleStateSaver.swift
// EchoOfAges
//
// Lightweight UserDefaults-backed save/restore for each civilization's
// in-progress puzzle state. Each save is keyed by civilization + level index
// with a version tag so old data is safely ignored after format changes.

import Foundation

// MARK: - Shared position helper

struct SavedPos: Codable {
    let row: Int; let col: Int
}

// MARK: - Per-civilization save envelopes

struct EgyptianSave: Codable {
    let v: Int                  // format version — always 2
    let levelIndex: Int
    let solution: [[String]]    // Glyph.rawValue for every cell of the generated solution
    let fixedPositions: [SavedPos] // which cells are pre-filled (the anchor cells)
    let grid: [[String?]]       // player's placed glyphs — Glyph.rawValue or nil
    let savedAt: Date
}

struct SumerianSave: Codable {
    let v: Int
    let levelIndex: Int
    let decoded: [String?]      // CuneiformGlyph.rawValue or nil
    let savedAt: Date
}

struct MayanSaveCycle: Codable {
    let symbols: [String]           // MayanGlyph.rawValue for each symbol in the cycle
    let startOffset: Int
    let revealedPositions: [Int]    // Set<Int> serialised as sorted array
}

struct MayanSave: Codable {
    let v: Int                      // format version — always 2
    let levelIndex: Int
    let cycles: [MayanSaveCycle]    // full generated cycle structure (needed for L3 & L4)
    let sequenceLength: Int
    let grid: [[String?]]           // player's placed glyphs — MayanGlyph.rawValue or nil
    let savedAt: Date
}

struct CelticSaveCell: Codable {
    let row: Int; let col: Int; let value: Int
}

struct CelticSave: Codable {
    let v: Int
    let levelIndex: Int
    // Enough to reconstruct CelticPuzzle (randomly generated — must persist)
    let rows: Int
    let cols: Int
    let rowSums: [Int]
    let colSums: [Int]
    let fixedCells: [CelticSaveCell]  // row, col, value for each fixed cell
    let solution: [[Int]]             // full solution grid
    let playerGrid: [[String?]]       // OghamGlyph.rawValue or nil
    let savedAt: Date
}

struct ChineseSave: Codable {
    let v: Int
    let levelIndex: Int
    let pieces: [String: ChinesePiecePlacement]   // pieceId → placement
    let savedAt: Date
}

struct NorseSaveWaypoint: Codable {
    let id: Int
    let pathIndex: Int
    let pos: SavedPos
    let rune: String
    let runeName: String
    let meaning: String
    let isStart: Bool
    let isEnd: Bool
}

struct NorseSave: Codable {
    let v: Int
    let levelIndex: Int
    let solution: [SavedPos]           // ordered Hamiltonian path
    let blocked: [SavedPos]            // blocked / impassable cells
    let waypoints: [NorseSaveWaypoint]
    let path: [SavedPos]               // player's drawn path so far
    let resetCount: Int
    let savedAt: Date
}

// MARK: - Save / Load helpers

enum PuzzleStateSaver {

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .secondsSince1970; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .secondsSince1970; return d
    }()

    // MARK: Egyptian

    static func saveEgyptian(_ save: EgyptianSave) {
        store(save, key: "EOA_pstate_egypt_v2_\(save.levelIndex)")
    }
    static func loadEgyptian(levelIndex: Int) -> EgyptianSave? {
        load(EgyptianSave.self, key: "EOA_pstate_egypt_v2_\(levelIndex)")
    }
    static func clearEgyptian(levelIndex: Int) {
        UserDefaults.standard.removeObject(forKey: "EOA_pstate_egypt_v2_\(levelIndex)")
    }

    // MARK: Sumerian

    static func saveSumerian(_ save: SumerianSave) {
        store(save, key: "EOA_pstate_sumerian_v1_\(save.levelIndex)")
    }
    static func loadSumerian(levelIndex: Int) -> SumerianSave? {
        load(SumerianSave.self, key: "EOA_pstate_sumerian_v1_\(levelIndex)")
    }
    static func clearSumerian(levelIndex: Int) {
        UserDefaults.standard.removeObject(forKey: "EOA_pstate_sumerian_v1_\(levelIndex)")
    }

    // MARK: Maya

    static func saveMaya(_ save: MayanSave) {
        store(save, key: "EOA_pstate_maya_v2_\(save.levelIndex)")
    }
    static func loadMaya(levelIndex: Int) -> MayanSave? {
        load(MayanSave.self, key: "EOA_pstate_maya_v2_\(levelIndex)")
    }
    static func clearMaya(levelIndex: Int) {
        UserDefaults.standard.removeObject(forKey: "EOA_pstate_maya_v2_\(levelIndex)")
    }

    // MARK: Celtic

    static func saveCeltic(_ save: CelticSave) {
        store(save, key: "EOA_pstate_celtic_v1_\(save.levelIndex)")
    }
    static func loadCeltic(levelIndex: Int) -> CelticSave? {
        load(CelticSave.self, key: "EOA_pstate_celtic_v1_\(levelIndex)")
    }
    static func clearCeltic(levelIndex: Int) {
        UserDefaults.standard.removeObject(forKey: "EOA_pstate_celtic_v1_\(levelIndex)")
    }

    // MARK: Chinese

    static func saveChinese(_ save: ChineseSave) {
        store(save, key: "EOA_pstate_chinese_v1_\(save.levelIndex)")
    }
    static func loadChinese(levelIndex: Int) -> ChineseSave? {
        load(ChineseSave.self, key: "EOA_pstate_chinese_v1_\(levelIndex)")
    }
    static func clearChinese(levelIndex: Int) {
        UserDefaults.standard.removeObject(forKey: "EOA_pstate_chinese_v1_\(levelIndex)")
    }

    // MARK: Norse

    static func saveNorse(_ save: NorseSave) {
        store(save, key: "EOA_pstate_norse_v1_\(save.levelIndex)")
    }
    static func loadNorse(levelIndex: Int) -> NorseSave? {
        load(NorseSave.self, key: "EOA_pstate_norse_v1_\(levelIndex)")
    }
    static func clearNorse(levelIndex: Int) {
        UserDefaults.standard.removeObject(forKey: "EOA_pstate_norse_v1_\(levelIndex)")
    }

    // MARK: Private helpers

    private static func store<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}

// MARK: - Restore Banner

import SwiftUI

/// Slide-in banner shown when a puzzle is restored from a saved state.
struct RestoreBanner: View {
    let savedAt: Date

    private var label: String {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .short
        f.timeStyle = .short
        return "Puzzle restored from \(f.string(from: savedAt))"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 15, weight: .semibold))
            Text(label)
                .font(EgyptFont.body(13))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(red: 0.15, green: 0.40, blue: 0.65).opacity(0.92))
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 3)
        )
        .padding(.horizontal, 24)
    }
}
