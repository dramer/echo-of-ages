// SettingsView.swift
// EchoOfAges
//
// Sound settings sheet — accessible via the speaker icon on TitleView.
// Master toggle at the top; per-civilization and Field Diary toggles below.
// Changes take effect immediately and persist across sessions.

import SwiftUI
import GameKit

struct SettingsView: View {
    @Environment(SoundManager.self) var soundManager
    @Environment(\.dismiss) private var dismiss
    @State private var showAchievements = false

    var body: some View {
        @Bindable var sm = soundManager

        ZStack {
            Color(red: 0.06, green: 0.04, blue: 0.02).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: Header
                    VStack(spacing: 6) {
                        HStack {
                            Spacer()
                            Button { dismiss() } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.goldMid.opacity(0.60))
                            }
                            .padding(.trailing, 24)
                            .padding(.top, 20)
                        }
                        Text("SETTINGS")
                            .font(EgyptFont.title(13))
                            .foregroundStyle(Color.goldBright)
                            .tracking(3)
                            .padding(.top, 4)
                        Text("Background music plays softly while you solve each inscription.")
                            .font(EgyptFont.bodyItalic(13))
                            .foregroundStyle(Color.papyrus.opacity(0.50))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 4)
                    }
                    .padding(.bottom, 20)

                    // MARK: Master
                    sectionLabel("MASTER")
                    row(icon: sm.masterEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill",
                        label: "All Sound",
                        sublabel: sm.masterEnabled ? "Music is on" : "All music silenced",
                        isOn: $sm.masterEnabled,
                        accent: Color.goldBright,
                        sfSymbol: true)

                    divider

                    // MARK: Civilizations
                    sectionLabel("CIVILIZATIONS")
                    Group {
                        row(icon: "𓂀", label: "Egyptian",
                            sublabel: "Tomb of Kha · Sanctuary of Thoth",
                            isOn: $sm.egyptEnabled,
                            accent: Color(red: 0.82, green: 0.68, blue: 0.35))
                        row(icon: "ᚱ", label: "Norse",
                            sublabel: "The Elder Futhark Pathways",
                            isOn: $sm.norseEnabled,
                            accent: Color(red: 0.55, green: 0.75, blue: 0.90))
                        row(icon: "𒀭", label: "Sumerian",
                            sublabel: "The Cuneiform Tablets",
                            isOn: $sm.sumerianEnabled,
                            accent: Color(red: 0.85, green: 0.72, blue: 0.45))
                        row(icon: "🌿", label: "Maya",
                            sublabel: "The Wheel of the Calendar",
                            isOn: $sm.mayaEnabled,
                            accent: Color(red: 0.35, green: 0.70, blue: 0.45))
                        row(icon: "ᚁ", label: "Celtic",
                            sublabel: "The Ogham Standing Stones",
                            isOn: $sm.celticEnabled,
                            accent: Color(red: 0.55, green: 0.78, blue: 0.40))
                        row(icon: "☰", label: "Chinese",
                            sublabel: "The Celestial Trigrams",
                            isOn: $sm.chineseEnabled,
                            accent: Color(red: 0.88, green: 0.40, blue: 0.35))
                    }
                    .disabled(!sm.masterEnabled)
                    .opacity(sm.masterEnabled ? 1.0 : 0.38)
                    .animation(.easeInOut(duration: 0.2), value: sm.masterEnabled)

                    divider

                    // MARK: Field Diary
                    sectionLabel("FIELD DIARY")
                    row(icon: "book.fill", label: "Field Diary",
                        sublabel: "Ambient music while reading lore entries",
                        isOn: $sm.journalEnabled,
                        accent: Color(red: 0.75, green: 0.60, blue: 0.40),
                        sfSymbol: true)
                    .disabled(!sm.masterEnabled)
                    .opacity(sm.masterEnabled ? 1.0 : 0.38)
                    .animation(.easeInOut(duration: 0.2), value: sm.masterEnabled)

                    divider

                    // MARK: Sound Effects
                    sectionLabel("SOUND EFFECTS")
                    row(icon: "waveform.circle.fill", label: "Move Sounds",
                        sublabel: "Taps, placements, errors, and solve chimes",
                        isOn: $sm.effectsEnabled,
                        accent: Color(red: 0.60, green: 0.78, blue: 0.90),
                        sfSymbol: true)
                    .disabled(!sm.masterEnabled)
                    .opacity(sm.masterEnabled ? 1.0 : 0.38)
                    .animation(.easeInOut(duration: 0.2), value: sm.masterEnabled)

                    divider

                    // MARK: Haptics
                    sectionLabel("HAPTICS")
                    row(icon: "hand.tap.fill", label: "Gameplay Haptics",
                        sublabel: "Vibration feedback on taps, errors, and solves",
                        isOn: $sm.hapticsEnabled,
                        accent: Color(red: 0.75, green: 0.55, blue: 0.85),
                        sfSymbol: true)

                    divider

                    // MARK: Game Center
                    sectionLabel("GAME CENTER")
                    actionRow(
                        icon: "gamecontroller.fill",
                        label: "Achievements",
                        sublabel: "View your earned achievements",
                        accent: Color(red: 0.35, green: 0.75, blue: 0.55)
                    ) {
                        showAchievements = true
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .sheet(isPresented: $showAchievements) {
            GameCenterAchievementsView()
                .ignoresSafeArea()
        }
    }

    // MARK: - Reusable Row

    private func row(
        icon: String, label: String, sublabel: String,
        isOn: Binding<Bool>, accent: Color, sfSymbol: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(accent.opacity(0.15))
                    .frame(width: 42, height: 42)
                if sfSymbol {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(accent)
                } else {
                    Text(icon)
                        .font(.system(size: 20))
                        .foregroundStyle(accent)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(EgyptFont.bodyItalic(15))
                    .foregroundStyle(Color.papyrus.opacity(0.90))
                Text(sublabel)
                    .font(EgyptFont.body(11))
                    .foregroundStyle(Color.papyrus.opacity(0.42))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(accent)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(Rectangle().fill(Color.white.opacity(0.03)).padding(.horizontal, 12))
    }

    // MARK: - Action Row (tappable, no toggle)

    private func actionRow(
        icon: String, label: String, sublabel: String,
        accent: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accent.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(EgyptFont.bodyItalic(15))
                        .foregroundStyle(Color.papyrus.opacity(0.90))
                    Text(sublabel)
                        .font(EgyptFont.body(11))
                        .foregroundStyle(Color.papyrus.opacity(0.42))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.papyrus.opacity(0.30))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Rectangle().fill(Color.white.opacity(0.03)).padding(.horizontal, 12))
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(EgyptFont.title(10))
            .foregroundStyle(Color.goldMid.opacity(0.50))
            .tracking(2)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Divider()
            .background(Color.goldMid.opacity(0.25))
            .padding(.horizontal, 24)
            .padding(.vertical, 4)
    }
}

// MARK: - Game Center Achievements Wrapper

/// Wraps GKGameCenterViewController so it can be presented as a SwiftUI sheet.
struct GameCenterAchievementsView: UIViewControllerRepresentable {

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let vc = GKGameCenterViewController(state: .achievements)
        vc.gameCenterDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}

    class Coordinator: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(animated: true)
        }
    }
}
