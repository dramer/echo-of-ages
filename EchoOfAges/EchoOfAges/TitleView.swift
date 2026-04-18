// TitleView.swift
// EchoOfAges
//
// Main landing / menu screen shown after the intro sequence.
// Presents the game title with a gold glow pulse and three actions:
//   • Begin / Continue — starts or resumes the Egyptian puzzle track
//   • Field Diary      — opens JournalView to review unlocked lore entries
//   • Settings         — opens the settings / debug panel

import SwiftUI

struct TitleView: View {
    @EnvironmentObject var gameState: GameState
    @Environment(SoundManager.self) var soundManager
    @State private var glowPulse = false
    @State private var showNameEntry = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            background

            // Settings gear — top-right corner
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: soundManager.masterEnabled
                              ? "speaker.wave.2.fill"
                              : "speaker.slash.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(red: 0.30, green: 0.20, blue: 0.06).opacity(0.55))
                            .padding(16)
                    }
                }
                Spacer()
            }

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                // Banner
                Image("banner")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, -24)
                    .shadow(color: Color.stoneDark.opacity(glowPulse ? 0.25 : 0.10),
                            radius: 12, x: 0, y: 4)

                Spacer(minLength: 12)

                // Hieroglyph row
                Text("𓂀 𓅓 𓈖 𓃭 𓇯 𓀭")
                    .font(.system(size: 34))
                    .foregroundStyle(Color(red: 0.22, green: 0.13, blue: 0.04).opacity(0.80))
                    .tracking(10)

                Spacer(minLength: 20)

                // Text
                VStack(spacing: 16) {
                    Text("An Ancient Hieroglyph Deduction Puzzle")
                        .font(EgyptFont.bodyItalic(30))
                        .foregroundStyle(Color(red: 0.18, green: 0.11, blue: 0.03))
                        .multilineTextAlignment(.center)

                    Text("\"In the beginning was the Word,\nand the Word was carved in stone.\"")
                        .font(EgyptFont.bodyItalic(26))
                        .foregroundStyle(Color(red: 0.18, green: 0.11, blue: 0.03).opacity(0.70))
                        .multilineTextAlignment(.center)
                        .lineSpacing(7)
                }

                Spacer()

                if gameState.hasProgress {
                    // Returning player — Continue + Journal side by side
                    HStack(spacing: 16) {
                        // Continue Journey — green pill Play button
                        Button {
                            HapticFeedback.heavy()
                            withAnimation(.easeInOut(duration: 0.4)) {
                                gameState.openJournalToCivilizations()
                            }
                        } label: {
                            Text("Play")
                                .font(EgyptFont.titleBold(32))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 22)
                                .background(
                                    Capsule()
                                        .fill(LinearGradient(
                                            colors: [Color(red: 0.25, green: 0.78, blue: 0.35),
                                                     Color(red: 0.15, green: 0.60, blue: 0.25)],
                                            startPoint: .top, endPoint: .bottom))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color(red: 0.10, green: 0.45, blue: 0.18), lineWidth: 1.5)
                                )
                                .shadow(color: Color(red: 0.10, green: 0.45, blue: 0.18).opacity(0.6),
                                        radius: 10, x: 0, y: 5)
                        }

                        // Open the Journal
                        Button {
                            HapticFeedback.tap()
                            withAnimation(.easeInOut(duration: 0.4)) { gameState.openJournal() }
                        } label: {
                            VStack(spacing: 14) {
                                Image("diary")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 160)
                                Text("Open the Journal")
                                    .font(EgyptFont.bodyItalic(28))
                                    .foregroundStyle(Color(red: 0.22, green: 0.14, blue: 0.05).opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.65)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                } else {
                    // First launch — image buttons matching returning-player style
                    HStack(spacing: 16) {
                        landingButton(asset: "begin_journey", fallback: "arrow.right.circle.fill") {
                            HapticFeedback.heavy()
                            withAnimation(.easeInOut(duration: 0.4)) { gameState.startNewGame() }
                        }
                        Button {
                            HapticFeedback.tap()
                            withAnimation(.easeInOut(duration: 0.4)) { gameState.openJournal() }
                        } label: {
                            VStack(spacing: 14) {
                                Image("diary")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 160)
                                Text("Read the Field Diary")
                                    .font(EgyptFont.bodyItalic(28))
                                    .foregroundStyle(Color(red: 0.22, green: 0.14, blue: 0.05).opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.65)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                Spacer(minLength: 18)

                // Footer
                Text("𓅱 𓆑 𓏏 𓈖 𓊪")
                    .font(.system(size: 24))
                    .foregroundStyle(Color(red: 0.30, green: 0.20, blue: 0.06).opacity(0.28))
                    .tracking(10)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            if gameState.needsPlayerName {
                showNameEntry = true
            }
        }
        .sheet(isPresented: $showNameEntry) {
            NameEntryView()
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(soundManager)
        }
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            Color(red: 0.93, green: 0.87, blue: 0.73).ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.96, green: 0.91, blue: 0.74).opacity(0.65), .clear],
                center: .center, startRadius: 50, endRadius: 360
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [.clear, Color(red: 0.38, green: 0.26, blue: 0.10).opacity(0.50)],
                center: .center, startRadius: 270, endRadius: 640
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Helpers

    private func landingButton(
        asset: String,
        fallback: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if UIImage(named: asset) != nil {
                    Image(asset).resizable().scaledToFit()
                } else {
                    Image(systemName: fallback)
                        .font(.system(size: 62))
                        .foregroundStyle(Color(red: 0.40, green: 0.26, blue: 0.04))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 145)
        }
    }
}

// MARK: - Name Entry Sheet

struct NameEntryView: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) private var dismiss

    @State private var nameInput: String = ""
    @State private var glowPulse = false

    private var isValid: Bool {
        !nameInput.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            // Papyrus background matching TitleView
            Color(red: 0.93, green: 0.87, blue: 0.73).ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.96, green: 0.91, blue: 0.74).opacity(0.65), .clear],
                center: .center, startRadius: 50, endRadius: 360
            ).ignoresSafeArea()
            RadialGradient(
                colors: [.clear, Color(red: 0.38, green: 0.26, blue: 0.10).opacity(0.45)],
                center: .center, startRadius: 270, endRadius: 640
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    // Icon
                    Text("𓂀")
                        .font(.system(size: 72))
                        .foregroundStyle(Color(red: 0.28, green: 0.17, blue: 0.05).opacity(0.85))
                        .shadow(color: Color.goldDark.opacity(glowPulse ? 0.40 : 0.10),
                                radius: 14, x: 0, y: 0)

                    // Title
                    VStack(spacing: 8) {
                        Text("Welcome, Archaeologist")
                            .font(EgyptFont.titleBold(28))
                            .foregroundStyle(Color(red: 0.18, green: 0.11, blue: 0.03))
                            .multilineTextAlignment(.center)
                            .tracking(1)

                        Text("Before the expedition begins,\nwhat shall we call you?")
                            .font(EgyptFont.bodyItalic(19))
                            .foregroundStyle(Color(red: 0.30, green: 0.20, blue: 0.06).opacity(0.80))
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                    }

                    // Name input
                    VStack(spacing: 10) {
                        Text("FIRST NAME")
                            .font(EgyptFont.title(12))
                            .foregroundStyle(Color(red: 0.45, green: 0.30, blue: 0.10).opacity(0.65))
                            .tracking(3)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        TextField("Dr. …", text: $nameInput)
                            .font(EgyptFont.titleBold(22))
                            .foregroundStyle(Color(red: 0.18, green: 0.11, blue: 0.03))
                            .tint(Color.goldDark)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(red: 0.99, green: 0.96, blue: 0.88))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isValid
                                                ? Color.goldDark.opacity(0.70)
                                                : Color(red: 0.60, green: 0.48, blue: 0.30).opacity(0.45),
                                                lineWidth: 1.5)
                                    )
                            )
                            .shadow(color: Color.goldDark.opacity(isValid ? 0.20 : 0.05),
                                    radius: 6, x: 0, y: 2)
                            .onSubmit { if isValid { confirmName() } }
                    }
                    .padding(.horizontal, 4)

                    // Confirm button
                    Button(action: confirmName) {
                        Text("Begin the Expedition")
                            .font(EgyptFont.titleBold(20))
                            .tracking(1.5)
                            .foregroundStyle(isValid
                                ? Color(red: 0.96, green: 0.88, blue: 0.68)
                                : Color(red: 0.70, green: 0.60, blue: 0.45))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(isValid
                                        ? Color(red: 0.28, green: 0.17, blue: 0.05)
                                        : Color(red: 0.28, green: 0.17, blue: 0.05).opacity(0.45))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 13)
                                            .stroke(Color.goldDark.opacity(isValid
                                                ? (glowPulse ? 0.75 : 0.45)
                                                : 0.20),
                                                lineWidth: 1.5)
                                    )
                                    .shadow(color: Color.goldDark.opacity(isValid && glowPulse ? 0.40 : 0.05),
                                            radius: 16, x: 0, y: 0)
                            )
                    }
                    .disabled(!isValid)
                    .animation(.easeInOut(duration: 0.25), value: isValid)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(red: 0.97, green: 0.93, blue: 0.80).opacity(0.80))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color(red: 0.65, green: 0.50, blue: 0.28).opacity(0.50), lineWidth: 1)
                        )
                )
                .shadow(color: Color(red: 0.28, green: 0.17, blue: 0.05).opacity(0.18),
                        radius: 20, x: 0, y: 6)
                .padding(.horizontal, 24)

                Spacer()

                // Decorative footer rune row
                Text("𓅱 𓆑 𓏏 𓈖 𓊪")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0.30, green: 0.20, blue: 0.06).opacity(0.25))
                    .tracking(10)
                    .padding(.bottom, 28)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    private func confirmName() {
        guard isValid else { return }
        HapticFeedback.heavy()
        gameState.savePlayerName(nameInput)
        dismiss()
    }
}

#Preview {
    TitleView()
        .environmentObject(GameState())
}
