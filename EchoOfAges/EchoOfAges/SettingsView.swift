// SettingsView.swift
// EchoOfAges
//
// Settings screen — intro toggle, per-civilization reset, and replay intro.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var gameState: GameState
    @State private var confirmingReset: CivilizationID? = nil
    @State private var confirmingMasterReset = false
    @State private var editingName = false
    @State private var nameInput: String = ""

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
                        archaeologistSection
                        introSection
                        civilizationsSection
                        masterResetSection
                        versionSection
                        #if DEBUG
                        debugSection
                        #endif
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
        // Confirm master reset
        .alert("Begin a New Expedition?", isPresented: $confirmingMasterReset) {
            Button("Erase Everything", role: .destructive) {
                gameState.masterReset()
            }
            Button("Keep My Progress", role: .cancel) { }
        } message: {
            Text("All solved puzzles, decoded messages, diary entries, discovered keys, and Field Journal records will be permanently erased — across every civilization.\n\nDr. Mandu's expedition begins again from nothing.")
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

    // MARK: Archaeologist Section

    private var archaeologistSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader(icon: "person.fill", title: "Archaeologist")

                if editingName {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("FIRST NAME")
                            .font(EgyptFont.title(11))
                            .foregroundStyle(Color(red: 0.45, green: 0.30, blue: 0.10).opacity(0.65))
                            .tracking(3)

                        HStack(spacing: 10) {
                            TextField("Enter your name", text: $nameInput)
                                .font(EgyptFont.titleBold(18))
                                .foregroundStyle(Color(red: 0.18, green: 0.11, blue: 0.03))
                                .tint(Color.goldDark)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.words)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.99, green: 0.96, blue: 0.88))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.goldDark.opacity(0.60), lineWidth: 1.5)
                                        )
                                )
                                .onSubmit { commitNameEdit() }

                            Button(action: commitNameEdit) {
                                Text("Save")
                                    .font(EgyptFont.titleBold(15))
                                    .foregroundStyle(Color(red: 0.96, green: 0.88, blue: 0.68))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(nameInput.trimmingCharacters(in: .whitespaces).isEmpty
                                                ? Color(red: 0.28, green: 0.17, blue: 0.05).opacity(0.45)
                                                : Color(red: 0.28, green: 0.17, blue: 0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.goldDark.opacity(0.55), lineWidth: 1)
                                            )
                                    )
                            }
                            .disabled(nameInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        Button(action: { editingName = false }) {
                            Text("Cancel")
                                .font(EgyptFont.body(14))
                                .foregroundStyle(Color(red: 0.40, green: 0.28, blue: 0.12))
                        }
                    }
                } else {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name")
                                .font(EgyptFont.titleBold(17))
                                .foregroundStyle(Color(red: 0.16, green: 0.10, blue: 0.04))
                            Text(gameState.playerName.isEmpty ? "Not set" : gameState.playerName)
                                .font(gameState.playerName.isEmpty
                                    ? EgyptFont.bodyItalic(15)
                                    : EgyptFont.bodySemiBold(15))
                                .foregroundStyle(gameState.playerName.isEmpty
                                    ? Color(red: 0.45, green: 0.30, blue: 0.12)
                                    : Color(red: 0.30, green: 0.20, blue: 0.08))
                        }
                        Spacer()
                        Button(action: {
                            HapticFeedback.tap()
                            nameInput = gameState.playerName
                            withAnimation(.easeInOut(duration: 0.20)) { editingName = true }
                        }) {
                            Text(gameState.playerName.isEmpty ? "Set Name" : "Edit")
                                .font(EgyptFont.body(14))
                                .foregroundStyle(Color.goldDark)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(red: 0.88, green: 0.81, blue: 0.65))
                                        .overlay(RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.goldDark.opacity(0.40), lineWidth: 1))
                                )
                        }
                    }
                }
            }
        }
    }

    private func commitNameEdit() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        HapticFeedback.tap()
        gameState.savePlayerName(trimmed)
        withAnimation(.easeInOut(duration: 0.20)) { editingName = false }
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
                            .foregroundStyle(Color(red: 0.16, green: 0.10, blue: 0.04))
                        Text("Play the opening story each time the app starts.")
                            .font(EgyptFont.body(14))
                            .foregroundStyle(Color(red: 0.30, green: 0.20, blue: 0.08))
                    }
                    Spacer()
                    Toggle("", isOn: $gameState.showIntroOnLaunch)
                        .labelsHidden()
                        .toggleStyle(GreenRedToggleStyle())
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
                    .foregroundStyle(Color.goldDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.88, green: 0.81, blue: 0.65))
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
                    .foregroundStyle(Color(red: 0.30, green: 0.20, blue: 0.08))
                    .lineSpacing(4)

                settingsDivider

                // One row per civilization
                VStack(spacing: 12) {
                    ForEach(Civilization.all) { civ in
                        civRow(civ)
                    }
                }

            }
        }
    }

    // MARK: Civilization Row

    @ViewBuilder
    private func civRow(_ civ: Civilization) -> some View {
        let solvedCount = gameState.solvedLevelCount(for: civ.id)
        let total       = gameState.totalLevelCount(for: civ.id)

        HStack(spacing: 14) {
            // Emblem
            Text(civ.emblem)
                .font(.system(size: 28))
                .frame(width: 38)

            // Civilization info
            VStack(alignment: .leading, spacing: 3) {
                Text(civ.name)
                    .font(EgyptFont.titleBold(16))
                    .foregroundStyle(civ.isUnlocked
                        ? Color(red: 0.16, green: 0.10, blue: 0.04)
                        : Color(red: 0.45, green: 0.35, blue: 0.20))

                if civ.isUnlocked {
                    Text("\(solvedCount) of \(total) tablets solved")
                        .font(EgyptFont.body(13))
                        .foregroundStyle(Color(red: 0.35, green: 0.25, blue: 0.10))
                } else {
                    Text("Coming Soon")
                        .font(EgyptFont.bodyItalic(13))
                        .foregroundStyle(Color(red: 0.50, green: 0.40, blue: 0.25))
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
                    .foregroundStyle(Color(red: 0.50, green: 0.40, blue: 0.25))
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.50, green: 0.40, blue: 0.25).opacity(0.5))
            }
        }
        .padding(.vertical, 4)
        .opacity(civ.isUnlocked ? 1.0 : 0.5)
    }

    // MARK: Master Reset Section

    private var masterResetSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {

                sectionHeader(icon: "exclamationmark.triangle.fill", title: "Master Reset")

                Text("Erase all progress across every civilization — puzzles, decoded messages, diary entries, discovered keys, and the Mandu Tablet. The expedition starts again from the very beginning.")
                    .font(EgyptFont.bodyItalic(14))
                    .foregroundStyle(Color(red: 0.30, green: 0.20, blue: 0.08))
                    .lineSpacing(4)

                settingsDivider

                Button(action: {
                    HapticFeedback.tap()
                    confirmingMasterReset = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Begin a New Expedition")
                                .font(EgyptFont.titleBold(16))
                            Text("Permanently erases all progress")
                                .font(EgyptFont.body(12))
                                .opacity(0.75)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .opacity(0.6)
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.58, green: 0.08, blue: 0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.rubyRed.opacity(0.55), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.22, green: 0.08, blue: 0.08).opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.rubyRed.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
    }

    // MARK: Version Section

    private var versionSection: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")            as? String ?? "—"

        return settingsCard {
            VStack(alignment: .leading, spacing: 16) {

                sectionHeader(icon: "info.circle", title: "About")

                HStack {
                    Text("Echo of Ages")
                        .font(EgyptFont.titleBold(17))
                        .foregroundStyle(Color(red: 0.16, green: 0.10, blue: 0.04))
                    Spacer()
                }

                settingsDivider

                HStack {
                    Text("Version")
                        .font(EgyptFont.body(16))
                        .foregroundStyle(Color(red: 0.30, green: 0.20, blue: 0.08))
                    Spacer()
                    Text(version)
                        .font(EgyptFont.bodySemiBold(16))
                        .foregroundStyle(Color(red: 0.16, green: 0.10, blue: 0.04))
                }

                HStack {
                    Text("Build")
                        .font(EgyptFont.body(16))
                        .foregroundStyle(Color(red: 0.30, green: 0.20, blue: 0.08))
                    Spacer()
                    Text(build)
                        .font(EgyptFont.bodySemiBold(16))
                        .foregroundStyle(Color(red: 0.16, green: 0.10, blue: 0.04))
                }

                settingsDivider

                Text("An Ancient Hieroglyph Deduction Puzzle")
                    .font(EgyptFont.bodyItalic(14))
                    .foregroundStyle(Color(red: 0.40, green: 0.28, blue: 0.12))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: Debug Section (only compiled in DEBUG builds)

    #if DEBUG
    private var debugSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(icon: "ladybug.fill", title: "Developer")

                Text("Jump to any puzzle, mark levels solved, and test all civilizations — including ones not yet unlocked.")
                    .font(EgyptFont.bodyItalic(14))
                    .foregroundStyle(Color(red: 0.30, green: 0.20, blue: 0.08))
                    .lineSpacing(4)

                settingsDivider

                Button(action: {
                    HapticFeedback.tap()
                    gameState.openDebug()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20))
                        Text("Open Puzzle Debug Panel")
                            .font(EgyptFont.title(16))
                    }
                    .foregroundStyle(Color(red: 0.10, green: 0.35, blue: 0.60))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.10, green: 0.28, blue: 0.55).opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 0.10, green: 0.35, blue: 0.60).opacity(0.5), lineWidth: 1))
                    )
                }
            }
        }
    }
    #endif

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
                // Same aged-paper cream used for diary pages
                .fill(Color(red: 0.93, green: 0.87, blue: 0.73))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(red: 0.65, green: 0.55, blue: 0.40).opacity(0.6), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
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
            .fill(Color(red: 0.65, green: 0.55, blue: 0.40).opacity(0.45))
            .frame(height: 0.8)
    }
}

// MARK: - Green / Red Toggle Style

struct GreenRedToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn
        RoundedRectangle(cornerRadius: 16)
            .fill(isOn ? Color(red: 0.18, green: 0.60, blue: 0.22) : Color(red: 0.75, green: 0.15, blue: 0.12))
            .frame(width: 56, height: 32)
            .overlay(
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                    .frame(width: 26, height: 26)
                    .offset(x: isOn ? 12 : -12)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isOn)
            )
            .onTapGesture {
                HapticFeedback.tap()
                configuration.isOn.toggle()
            }
    }
}
