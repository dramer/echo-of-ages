// SoundManager.swift
// EchoOfAges
//
// Central audio manager for all background music and move sound effects.
// Handles crossfading between civilization tracks, master on/off,
// per-context enable/disable, and one-shot effect playback.
// Settings are persisted in UserDefaults.
//
// Background track files expected in the app bundle:
//   egypt_sound.mp3    — Egyptian puzzles
//   norse_sound.mp3    — Norse puzzles
//   sumerian_sound.mp3 — Sumerian puzzles
//   maya_sound.mp3     — Maya puzzles
//   celtic_sound.mp3   — Celtic puzzles
//   chinese_sound.mp3  — Chinese puzzles
//   journal_sound.mp3  — Field Diary
//   tree_sound.mp3     — Tree of Life / Mandu Tablet finale
//
// Sound effect files expected in the app bundle:
//   sfx_place.mp3  — glyph / path cell placed
//   sfx_clear.mp3  — glyph cleared / backtrack
//   sfx_error.mp3  — wrong answer / verify fail
//   sfx_solve.mp3  — puzzle level complete
//
// IntroView manages its own AVAudioPlayer and is excluded from
// SoundManager's control — the manager goes silent during .intro.

import AVFoundation
import Observation
import SwiftUI

@Observable
final class SoundManager {

    // MARK: - Settings (all default true on first launch)

    var masterEnabled: Bool   = true { didSet { persist(); applySettingsChange() } }
    var egyptEnabled: Bool    = true { didSet { persist(); applySettingsChange() } }
    var norseEnabled: Bool    = true { didSet { persist(); applySettingsChange() } }
    var sumerianEnabled: Bool = true { didSet { persist(); applySettingsChange() } }
    var mayaEnabled: Bool     = true { didSet { persist(); applySettingsChange() } }
    var celticEnabled: Bool   = true { didSet { persist(); applySettingsChange() } }
    var chineseEnabled: Bool  = true { didSet { persist(); applySettingsChange() } }
    var journalEnabled: Bool  = true { didSet { persist(); applySettingsChange() } }
    var treeEnabled: Bool     = true { didSet { persist(); applySettingsChange() } }
    var effectsEnabled: Bool  = true { didSet { persist() } }
    var hapticsEnabled: Bool  = true { didSet { persist(); HapticFeedback.isEnabled = hapticsEnabled } }

    // MARK: - Sound Effects

    enum SoundEffect: String {
        case place  = "sfx_place"
        case clear  = "sfx_clear"
        case error  = "sfx_error"
        case solve  = "sfx_solve"
    }

    /// Pool of pre-loaded effect players (max 4 per effect) to allow overlapping playback.
    private var effectPlayers: [SoundEffect: [AVAudioPlayer]] = [:]

    func playEffect(_ effect: SoundEffect) {
        guard masterEnabled, effectsEnabled else { return }
        // Lazy-load the pool for this effect on first use
        if effectPlayers[effect] == nil {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "mp3") else { return }
            var pool: [AVAudioPlayer] = []
            for _ in 0..<4 {
                if let p = try? AVAudioPlayer(contentsOf: url) {
                    p.prepareToPlay()
                    pool.append(p)
                }
            }
            effectPlayers[effect] = pool
        }
        // Play the first idle player in the pool (or the first one if all busy)
        let pool = effectPlayers[effect] ?? []
        let target = pool.first(where: { !$0.isPlaying }) ?? pool.first
        target?.volume = 0.55
        target?.play()
    }

    // MARK: - Private state

    private var player: AVAudioPlayer?
    private var fadingPlayer: AVAudioPlayer?
    private var currentTrack: String?
    private var activeScreen: GameScreen = .title

    private let targetVolume: Float      = 0.30
    private let fadeInDuration: TimeInterval  = 2.5
    private let fadeOutDuration: TimeInterval = 1.8
    private let fadeSteps = 20

    // MARK: - Init

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default,
                                                          options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        loadSettings()
    }

    // MARK: - Screen Routing

    func updateForScreen(_ screen: GameScreen) {
        activeScreen = screen

        switch screen {
        case .intro:
            immediateStop()
            return
        case .levelComplete, .gameComplete:
            return  // keep current track playing
        case .title, .debug:
            fadeOutAndStop()
            return
        default:
            break
        }

        guard masterEnabled else { fadeOutAndStop(); return }

        let track   = trackName(for: screen)
        let enabled = isEnabled(for: screen)

        if let track, enabled {
            if track != currentTrack { crossfade(to: track) }
        } else {
            fadeOutAndStop()
        }
    }

    // MARK: - Lookups

    func trackName(for screen: GameScreen) -> String? {
        switch screen {
        case .game:         return "egypt_sound"
        case .norseGame:    return "norse_sound"
        case .sumerianGame: return "sumerian_sound"
        case .mayanGame:    return "maya_sound"
        case .celticGame:   return "celtic_sound"
        case .chineseGame:  return "chinese_sound"
        case .journal:      return "journal_sound"
        case .manduTablet:  return "tree_sound"
        default:            return nil
        }
    }

    func isEnabled(for screen: GameScreen) -> Bool {
        switch screen {
        case .game:         return egyptEnabled
        case .norseGame:    return norseEnabled
        case .sumerianGame: return sumerianEnabled
        case .mayanGame:    return mayaEnabled
        case .celticGame:   return celticEnabled
        case .chineseGame:  return chineseEnabled
        case .journal:      return journalEnabled
        case .manduTablet:  return treeEnabled
        default:            return false
        }
    }

    // MARK: - Playback

    private func crossfade(to track: String) {
        guard let url = Bundle.main.url(forResource: track, withExtension: "mp3") else {
            fadeOutAndStop(); return
        }

        // Move current player to fading slot and start fade-out
        if let old = player {
            fadingPlayer?.stop()
            fadingPlayer = old
            fadeOut(fadingPlayer) { [weak self] in
                self?.fadingPlayer?.stop()
                self?.fadingPlayer = nil
            }
        }

        // Start new player at zero and fade in
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1
            newPlayer.volume = 0
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
            currentTrack = track
            fadeIn(newPlayer)
        } catch {
            player = nil
            currentTrack = nil
        }
    }

    private func fadeIn(_ target: AVAudioPlayer) {
        let stepDuration = fadeInDuration / Double(fadeSteps)
        for i in 0..<fadeSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak target] in
                target?.volume = self.targetVolume * Float(i + 1) / Float(self.fadeSteps)
            }
        }
    }

    private func fadeOut(_ target: AVAudioPlayer?, completion: (() -> Void)? = nil) {
        guard let target else { completion?(); return }
        let start = target.volume
        let stepDuration = fadeOutDuration / Double(fadeSteps)
        for i in 0..<fadeSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak target] in
                target?.volume = start * (1.0 - Float(i + 1) / Float(self.fadeSteps))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) { completion?() }
    }

    func fadeOutAndStop() {
        let old = player
        fadeOut(old) { old?.stop() }
        player = nil
        currentTrack = nil
    }

    private func immediateStop() {
        fadingPlayer?.stop(); fadingPlayer = nil
        player?.stop();       player = nil
        currentTrack = nil
    }

    // MARK: - Settings change

    private func applySettingsChange() {
        updateForScreen(activeScreen)
    }

    // MARK: - UserDefaults

    private enum UDKey {
        static let master   = "EOA_soundMaster"
        static let egypt    = "EOA_soundEgypt"
        static let norse    = "EOA_soundNorse"
        static let sumerian = "EOA_soundSumerian"
        static let maya     = "EOA_soundMaya"
        static let celtic   = "EOA_soundCeltic"
        static let chinese  = "EOA_soundChinese"
        static let journal  = "EOA_soundJournal"
        static let tree     = "EOA_soundTree"
        static let effects  = "EOA_soundEffects"
        static let haptics  = "EOA_hapticsEnabled"
    }

    private func loadSettings() {
        let d = UserDefaults.standard
        func bool(_ key: String) -> Bool {
            d.object(forKey: key) == nil ? true : d.bool(forKey: key)
        }
        masterEnabled   = bool(UDKey.master)
        egyptEnabled    = bool(UDKey.egypt)
        norseEnabled    = bool(UDKey.norse)
        sumerianEnabled = bool(UDKey.sumerian)
        mayaEnabled     = bool(UDKey.maya)
        celticEnabled   = bool(UDKey.celtic)
        chineseEnabled  = bool(UDKey.chinese)
        journalEnabled  = bool(UDKey.journal)
        treeEnabled     = bool(UDKey.tree)
        effectsEnabled  = bool(UDKey.effects)
        hapticsEnabled  = bool(UDKey.haptics)
        HapticFeedback.isEnabled = hapticsEnabled
    }

    func persist() {
        let d = UserDefaults.standard
        d.set(masterEnabled,   forKey: UDKey.master)
        d.set(egyptEnabled,    forKey: UDKey.egypt)
        d.set(norseEnabled,    forKey: UDKey.norse)
        d.set(sumerianEnabled, forKey: UDKey.sumerian)
        d.set(mayaEnabled,     forKey: UDKey.maya)
        d.set(celticEnabled,   forKey: UDKey.celtic)
        d.set(chineseEnabled,  forKey: UDKey.chinese)
        d.set(journalEnabled,  forKey: UDKey.journal)
        d.set(treeEnabled,     forKey: UDKey.tree)
        d.set(effectsEnabled,  forKey: UDKey.effects)
        d.set(hapticsEnabled,  forKey: UDKey.haptics)
    }
}
