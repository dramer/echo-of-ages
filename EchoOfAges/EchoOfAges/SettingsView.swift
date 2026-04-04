// SettingsView.swift
// EchoOfAges
//
// Settings screen — intro toggle, per-civilization reset, and replay intro.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var gameState: GameState
    @State private var confirmingReset: CivilizationID? = nil
    @State private var confirmingResetAll = false

    var body: some View {
        ZStack {
            // Background
            Color.stoneDark.ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.22, green: 0.14, blue: 0.05).opacity(0.6), .clear],
                center: .center, startRadius: 80, endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        introSection
                        civilizationsSection
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        // Confirm reset alert for a single civilization
        .alert("Reset \(confirmingReset.map { civName($0) } ?? "") Progress?",
               isPresented: Binding(
                get: { confirmingReset != nil },
                set: { if !$0 { confirmingReset = nil } }
               )) {
            Button("Reset", role: .destructive) {
                if let civ = confirmingReset {
                    gameState.resetCivilization(civ)
                }
                confirmingReset = nil
            }
            Button("Cancel", role: .cancel) { confirmingReset = nil }
        } message: {
            Text("All completed puzzles, decoded messages, and discovered glyphs for this civilization will be erased. This cannot be undone.")
        }
        // Confirm reset all
        .alert("Reset All Progress?", isPresented: $confirmingResetAll) {
            Button("Reset Everything", role: .destructive) {
                resetAll()
                confirmingResetAll = false
            }
            Button("Cancel", role: .cancel) { confirmingResetAll = false }
        } message: {
            Text("Every solved puzzle, decoded message, and codex entry will be permanently erased across all civilizations.")
        }
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { gameState.closeSettings() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(EgyptFont.body(17))
                }
                .foregroundStyle(Color.goldDark)
            }
            Spacer()
            Text("Settings")
                .font(EgyptFont.titleBold(20))
                .foregroundStyle(Color.stoneDark)
                .tracking(2)
            Spacer()
            // Balance spacer
            Color.clear.frame(width: 60, height: 30)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Color.white
                .overlay(
                    Rectangle()
                        .fill(Color.goldDark.opacity(0.35))
                        .frame(height: 0.8),
                    alignment: .bottom
                )
        )
    }

    // MARK: Introduction Section

    private var introSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 20) {

                sectionHeader(icon: "film", title: "Introduction")

                // Toggle
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show on Launch")
                            .font(EgyptFont.titleBold(17))
                            .foregroundStyle(Color.goldBright)
                        Text("Play the opening story each time the app starts.")
                            .font(EgyptFont.body(14))
                            .foregroundStyle(Color.papyrus.opacity(0.7))
                    }
                    Spacer()
                    Toggle("", isOn: $gameState.showIntroOnLaunch)
                        .labelsHidden()
                        .tint(Color.goldMid)
                        .onChange(of: gameState.showIntroOnLaunch) { _, _ in
                            gameState.saveSettings()
                        }
                }

                settingsDivider

                // Replay button
                Button(action: {
                    HapticFeedback.tap()
                    gameState.closeSettings()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        gameState.playIntro()
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20))
                        Text("Watch Introduction Again")
                            .font(EgyptFont.title(16))
                    }
                    .foregroundStyle(Color.goldMid)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.stoneDark.opacity(0.6))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.goldDark.opacity(0.5), lineWidth: 1))
                    )
                }
            }
        }
    }

    // MARK: Civilizations Reset Section

    private var civilizationsSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 20) {

                sectionHeader(icon: "arrow.counterclockwise.circle", title: "Reset Civilization Progress")

                Text("Erasing a civilization's progress removes all solved puzzles, decoded messages, and codex glyphs for that culture. Use this if you want to replay a civilization from the beginning.")
                    .font(EgyptFont.bodyItalic(14))
                    .foregroundStyle(Color.papyrus.opacity(0.65))
                    .lineSpacing(4)

                settingsDivider

                // One row per civilization
                VStack(spacing: 12) {
                    ForEach(Civilization.all) { civ in
                        civRow(civ)
                    }
                }

                settingsDivider

                // Reset all
                Button(action: { confirmingResetAll = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                        Text("Reset All Progress")
                            .font(EgyptFont.title(15))
                    }
                    .foregroundStyle(Color.rubyRed.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.25, green: 0.05, blue: 0.05).opacity(0.6))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.rubyRed.opacity(0.4), lineWidth: 1))
                    )
                }
            }
        }
    }

    // MARK: Civilization Row

    @ViewBuilder
    private func civRow(_ civ: Civilization) -> some View {
        let civLevels = Level.allLevels.filter { $0.civilization == civ.id }
        let solvedCount = civLevels.filter { gameState.unlockedJournalEntries.contains($0.journalEntry.id) }.count
        let total = civLevels.count

        HStack(spacing: 14) {
            // Emblem
            Text(civ.emblem)
                .font(.system(size: 28))
                .frame(width: 38)

            // Civilization info
            VStack(alignment: .leading, spacing: 3) {
                Text(civ.name)
                    .font(EgyptFont.titleBold(16))
                    .foregroundStyle(civ.isUnlocked ? Color.goldBright : Color.stoneSurface)

                if civ.isUnlocked {
                    Text("\(solvedCount) of \(total) tablets solved")
                        .font(EgyptFont.body(13))
                        .foregroundStyle(Color.papyrus.opacity(0.6))
                } else {
                    Text("Coming Soon")
                        .font(EgyptFont.bodyItalic(13))
                        .foregroundStyle(Color.stoneSurface.opacity(0.5))
                }
            }

            Spacer()

            // Reset button (only for unlocked civs with progress)
            if civ.isUnlocked && solvedCount > 0 {
                Button(action: { confirmingReset = civ.id }) {
                    Text("Reset")
                        .font(EgyptFont.body(14))
                        .foregroundStyle(Color.rubyRed.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(red: 0.25, green: 0.05, blue: 0.05).opacity(0.5))
                                .overlay(RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.rubyRed.opacity(0.35), lineWidth: 1))
                        )
                }
            } else if civ.isUnlocked {
                Text("No progress")
                    .font(EgyptFont.body(13))
                    .foregroundStyle(Color.stoneSurface.opacity(0.45))
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.stoneSurface.opacity(0.3))
            }
        }
        .padding(.vertical, 4)
        .opacity(civ.isUnlocked ? 1.0 : 0.5)
    }

    // MARK: Reset All

    private func resetAll() {
        for civ in Civilization.all where civ.isUnlocked {
            gameState.resetCivilization(civ.id)
        }
        UserDefaults.standard.removeObject(forKey: "EOA_hasSeenIntro")
        HapticFeedback.heavy()
    }

    // MARK: Helpers

    private func civName(_ id: CivilizationID) -> String {
        Civilization.all.first { $0.id == id }?.name ?? "Civilization"
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.stoneMid.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.goldDark.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
            Text(title.uppercased())
                .font(EgyptFont.title(13))
                .tracking(2)
        }
        .foregroundStyle(Color.goldDark)
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(Color.goldDark.opacity(0.2))
            .frame(height: 0.7)
    }
}
