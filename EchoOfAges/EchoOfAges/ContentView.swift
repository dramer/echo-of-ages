// ContentView.swift
// EchoOfAges

import SwiftUI

struct ContentView: View {
    @StateObject private var gameState = GameState()

    var body: some View {
        mainContent
            .environmentObject(gameState)
            .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            Color.stoneDark.ignoresSafeArea()

            Group {
                switch gameState.currentScreen {
                case .intro:
                    IntroView()
                        .transition(.opacity)

                case .title:
                    TitleView()
                        .transition(.opacity)

                case .game:
                    GameView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))

                case .journal:
                    JournalView()
                        .transition(.move(edge: .trailing).combined(with: .opacity))

                case .levelComplete:
                    LevelCompleteView()
                        .transition(.scale(scale: 0.9).combined(with: .opacity))

                case .gameComplete:
                    GameCompleteView()
                        .transition(.scale(scale: 0.9).combined(with: .opacity))

                case .settings:
                    SettingsView()
                        .transition(.move(edge: .trailing).combined(with: .opacity))

                case .debug:
                    #if DEBUG
                    DebugView()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    #else
                    TitleView()
                    #endif

                case .norseGame:
                    PathGameView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))

                case .sumerianGame:
                    SumerianGameView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))

                case .manduTablet:
                    ManduTabletView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.38), value: gameState.currentScreen)
        }
    }
}

// MARK: - Level Complete

struct LevelCompleteView: View {
    @EnvironmentObject var gameState: GameState
    @State private var appeared = false
    @State private var messageRevealed = false

    private var entry: JournalEntry { gameState.currentLevel.journalEntry }
    private var message: String { gameState.pendingDecodedMessage }

    var body: some View {
        ZStack {
            Color.stoneDark.ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.30, green: 0.20, blue: 0.05).opacity(0.6), .clear],
                center: .center, startRadius: 60, endRadius: 350
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 40)

                    // Artifact symbol
                    Text(entry.artifact)
                        .font(.system(size: 72))
                        .foregroundStyle(Color.goldBright)
                        .shadow(color: Color.goldDark.opacity(0.8), radius: 14, x: 0, y: 0)
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: appeared)

                    Spacer(minLength: 24)

                    VStack(spacing: 10) {
                        Text("Inscription Deciphered")
                            .font(EgyptFont.titleBold(30))
                            .foregroundStyle(Color.goldBright)
                            .tracking(2)

                        ornamentalRule

                        Text(entry.title)
                            .font(EgyptFont.bodyItalic(20))
                            .foregroundStyle(Color.papyrus)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: appeared)

                    Spacer(minLength: 28)

                    // Decoded message reveal
                    if messageRevealed && !message.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Decoded Message", systemImage: "scroll")
                                .font(EgyptFont.title(12))
                                .foregroundStyle(Color.goldDark)
                                .tracking(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(message)
                                .font(EgyptFont.bodyItalic(17))
                                .foregroundStyle(Color.papyrus)
                                .lineSpacing(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.stoneMid.opacity(0.45))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.goldDark.opacity(0.5), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // New codex glyphs
                    let newGlyphs = gameState.currentLevel.newGlyphs
                    if !newGlyphs.isEmpty && messageRevealed {
                        VStack(spacing: 8) {
                            Text("New Glyphs Added to Your Codex")
                                .font(EgyptFont.title(12))
                                .foregroundStyle(Color.goldDark.opacity(0.8))
                                .tracking(1)

                            HStack(spacing: 16) {
                                ForEach(newGlyphs) { glyph in
                                    VStack(spacing: 4) {
                                        Text(glyph.rawValue)
                                            .font(.system(size: 30))
                                            .foregroundStyle(Color.goldBright)
                                        Text(glyph.displayName)
                                            .font(EgyptFont.body(11))
                                            .foregroundStyle(Color.papyrus.opacity(0.7))
                                    }
                                }
                            }
                        }
                        .padding(.top, 16)
                        .transition(.opacity)
                    }

                    Spacer(minLength: 36)

                    VStack(spacing: 14) {
                        Button(action: {
                            HapticFeedback.tap()
                            gameState.openJournal()
                        }) {
                            StoneButton(title: "Open Field Diary", icon: "book.fill", style: .muted)
                        }

                        Button(action: {
                            HapticFeedback.tap()
                            gameState.advanceToNextLevel()
                        }) {
                            StoneButton(title: "Enter Next Chamber", icon: "arrow.right", style: .gold)
                        }
                    }
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)

                    Spacer(minLength: 50)
                }
                .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            withAnimation { appeared = true }
            // Reveal message slightly after the header appears
            Task {
                try? await Task.sleep(nanoseconds: 700_000_000)
                withAnimation(.easeOut(duration: 0.7)) {
                    messageRevealed = true
                }
            }
        }
    }

    private var ornamentalRule: some View {
        HStack {
            Rectangle()
                .fill(LinearGradient(colors: [.clear, .goldDark, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 0.8)
            Text("𓊹")
                .font(.system(size: 14))
                .foregroundStyle(Color.goldDark)
                .padding(.horizontal, 8)
            Rectangle()
                .fill(LinearGradient(colors: [.clear, .goldDark, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 0.8)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 40)
    }
}

// MARK: - Game Complete

struct GameCompleteView: View {
    @EnvironmentObject var gameState: GameState
    @State private var appeared = false
    @State private var glowPulse = false
    @State private var messagesRevealed = false

    // Combine all decoded messages into the full Tree of Life narrative
    private var fullNarrative: String {
        gameState.chronicleMessages
            .compactMap(\.message)
            .joined(separator: "\n\n")
    }

    var body: some View {
        ZStack {
            Color.stoneDark.ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.35, green: 0.22, blue: 0.04).opacity(0.65), .clear],
                center: .center, startRadius: 100, endRadius: 400
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 40)

                    // All five glyphs
                    HStack(spacing: 16) {
                        ForEach(Glyph.allCases) { glyph in
                            Text(glyph.rawValue)
                                .font(.system(size: 36))
                                .foregroundStyle(Color.goldBright)
                                .shadow(color: Color.goldDark.opacity(glowPulse ? 0.9 : 0.3), radius: 10, x: 0, y: 0)
                        }
                    }
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.65), value: appeared)

                    Spacer(minLength: 28)

                    VStack(spacing: 14) {
                        Text("The Tree of Life")
                            .font(EgyptFont.titleBold(38))
                            .foregroundStyle(Color.goldBright)
                            .tracking(3)
                            .shadow(color: Color.goldDark.opacity(glowPulse ? 1 : 0.4), radius: 14, x: 0, y: 0)

                        ornamentalRule

                        Text("All five inscriptions deciphered.\nThe ancient message is complete.")
                            .font(EgyptFont.body(17))
                            .foregroundStyle(Color.papyrus)
                            .lineSpacing(5)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)
                    .animation(.easeOut(duration: 0.7).delay(0.25), value: appeared)

                    Spacer(minLength: 32)

                    // The complete Tree of Life narrative — all 5 messages
                    if messagesRevealed && !fullNarrative.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("The Complete Inscription", systemImage: "scroll")
                                .font(EgyptFont.title(13))
                                .foregroundStyle(Color.goldDark)
                                .tracking(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(fullNarrative)
                                .font(EgyptFont.bodyItalic(16))
                                .foregroundStyle(Color.papyrus)
                                .lineSpacing(7)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ornamentalRule
                                .padding(.top, 4)

                            Text("𓅱 𓆑 𓏏 𓈖 𓊪")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.goldMid.opacity(0.6))
                                .tracking(6)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.stoneMid.opacity(0.4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.goldDark.opacity(0.5), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer(minLength: 40)

                    VStack(spacing: 14) {
                        Button(action: {
                            HapticFeedback.tap()
                            gameState.openJournal()
                        }) {
                            StoneButton(title: "Read Field Diary", icon: "book.fill", style: .muted)
                        }
                        Button(action: {
                            HapticFeedback.heavy()
                            withAnimation(.easeInOut(duration: 0.4)) {
                                gameState.goToTitle()
                            }
                        }) {
                            StoneButton(title: "Return to the Beginning", icon: "house.fill", style: .gold)
                        }
                    }
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.45), value: appeared)

                    Spacer(minLength: 50)
                }
                .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            withAnimation { appeared = true }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                withAnimation(.easeOut(duration: 1.0)) {
                    messagesRevealed = true
                }
            }
        }
    }

    private var ornamentalRule: some View {
        HStack {
            Rectangle()
                .fill(LinearGradient(colors: [.clear, .goldDark, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 0.8)
            Text("𓊹")
                .font(.system(size: 14))
                .foregroundStyle(Color.goldDark)
                .padding(.horizontal, 8)
            Rectangle()
                .fill(LinearGradient(colors: [.clear, .goldDark, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 0.8)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 40)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
