// GameCenterManager.swift
// EchoOfAges
//
// Manages all Game Center interactions for Echo of Ages.
//
// Responsibilities:
//   • Authenticating the local player with Game Center on launch
//   • Holding the canonical Achievement ID constants for all 20 achievements
//   • Reporting earned achievements to Apple via GKAchievement
//   • Preventing duplicate reports within a session via a local cache
//
// Usage:
//   Call GameCenterManager.shared.authenticate(in:) once on app launch.
//   Call GameCenterManager.shared.unlock(_:) whenever an achievement is earned.
//
// Achievement IDs must match exactly what is registered in App Store Connect
// under Features → Game Center → Achievements for com.gringogolf.EchoOfAges.

import GameKit
import SwiftUI

final class GameCenterManager {

    // MARK: - Shared instance

    static let shared = GameCenterManager()
    private init() {}

    // MARK: - Session cache (prevents duplicate API calls per session)

    private var reported = Set<String>()

    // MARK: - Achievement ID constants

    enum Achievement {

        // ── Civilization completions ──────────────────────────────────────────
        /// Complete all five Egyptian inscriptions
        static let egyptComplete    = "com.gringogolf.EchoOfAges.egypt_complete"
        /// Complete all five Norse path puzzles
        static let norseComplete    = "com.gringogolf.EchoOfAges.norse_complete"
        /// Complete all five Sumerian cipher tablets
        static let sumerianComplete = "com.gringogolf.EchoOfAges.sumerian_complete"
        /// Complete all five Mayan calendar wheels
        static let mayanComplete    = "com.gringogolf.EchoOfAges.maya_complete"
        /// Complete all five Celtic Ogham puzzles
        static let celticComplete   = "com.gringogolf.EchoOfAges.celtic_complete"
        /// Complete all five Chinese tangram puzzles
        static let chineseComplete  = "com.gringogolf.EchoOfAges.chinese_complete"

        // ── Progress milestones ───────────────────────────────────────────────
        /// Solve the very first puzzle
        static let firstSolve       = "com.gringogolf.EchoOfAges.first_solve"
        /// Open the Field Diary for the first time
        static let openJournal      = "com.gringogolf.EchoOfAges.open_journal"
        /// Complete all puzzles in three civilizations
        static let threeCivs        = "com.gringogolf.EchoOfAges.three_civs_complete"
        /// Complete all puzzles in all six civilizations
        static let allCivs          = "com.gringogolf.EchoOfAges.all_civs_complete"
        /// Complete the final Mandu tablet puzzle
        static let gameComplete     = "com.gringogolf.EchoOfAges.game_complete"
        /// Earn all six civilization keys
        static let allKeys          = "com.gringogolf.EchoOfAges.all_keys"
        /// Record every Egyptian glyph in the codex
        static let fullCodex        = "com.gringogolf.EchoOfAges.full_codex"

        // ── Skill achievements ────────────────────────────────────────────────
        /// Complete any puzzle without tapping Decipher until every cell is filled
        static let noHints          = "com.gringogolf.EchoOfAges.no_hints"
        /// Complete all Egyptian puzzles with no wrong Decipher attempts
        static let perfectEgypt     = "com.gringogolf.EchoOfAges.perfect_egypt"
        /// Complete all Norse puzzles with no wrong Decipher attempts
        static let perfectNorse     = "com.gringogolf.EchoOfAges.perfect_norse"
        /// Complete all Sumerian tablets with no wrong Decipher attempts
        static let perfectSumerian  = "com.gringogolf.EchoOfAges.perfect_sumerian"
        /// Complete all Mayan calendar wheels with no wrong Decipher attempts
        static let perfectMaya      = "com.gringogolf.EchoOfAges.perfect_maya"
        /// Complete all Celtic puzzles with no wrong Decipher attempts
        static let perfectCeltic    = "com.gringogolf.EchoOfAges.perfect_celtic"
        /// Complete all Chinese puzzles with no wrong Decipher attempts
        static let perfectChinese   = "com.gringogolf.EchoOfAges.perfect_chinese"
    }

    // MARK: - Authentication

    /// Call once on app launch. Presents the Game Center login UI if needed.
    /// Safe to call multiple times — Game Center ignores repeat calls.
    func authenticate(in viewController: UIViewController) {
        GKLocalPlayer.local.authenticateHandler = { [weak self] presentedVC, error in
            if let vc = presentedVC {
                // Game Center needs the player to log in — present its UI
                viewController.present(vc, animated: true)
            } else if GKLocalPlayer.local.isAuthenticated {
                // Player is signed in — clear session cache so fresh reports can go through
                self?.reported.removeAll()
            } else if let error {
                // Authentication failed silently — achievements won't report this session
                print("[GameCenter] Authentication failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Unlock

    /// Reports an achievement as 100% complete to Game Center.
    /// Shows the native iOS completion banner automatically.
    /// Silently ignored if the player is not authenticated or the achievement
    /// was already reported this session.
    func unlock(_ identifier: String) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        guard !reported.contains(identifier) else { return }

        reported.insert(identifier)

        let achievement = GKAchievement(identifier: identifier)
        achievement.percentComplete = 100
        achievement.showsCompletionBanner = true

        GKAchievement.report([achievement]) { error in
            if let error {
                print("[GameCenter] Failed to report \(identifier): \(error.localizedDescription)")
                // Remove from cache so it can be retried next session
                self.reported.remove(identifier)
            }
        }
    }
}
