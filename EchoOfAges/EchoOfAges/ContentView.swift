// ContentView.swift
// EchoOfAges

import SwiftUI

struct ContentView: View {
    @StateObject private var gameState = GameState()

    var body: some View {
        ZStack {
            Color.stoneDark.ignoresSafeArea()

            Group {
                switch gameState.currentScreen {
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
                }
            }
            .animation(.easeInOut(duration: 0.38), value: gameState.currentScreen)
        }
        .environmentObject(gameState)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Level Complete

struct LevelCompleteView: View {
    @EnvironmentObject var gameState: GameState
    @State private var appeared = false

    private var entry: JournalEntry { gameState.currentLevel.journalEntry }

    var body: some View {
        ZStack {
            Color.stoneDark.ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.30, green: 0.20, blue: 0.05).opacity(0.6), .clear],
                center: .center, startRadius: 60, endRadius: 350
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Artifact symbol
                Text(entry.artifact)
                    .font(.system(size: 72))
                    .foregroundStyle(Color.goldBright)
                    .shadow(color: Color.goldDark.opacity(0.8), radius: 14, x: 0, y: 0)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: appeared)

                Spacer(minLength: 28)

                VStack(spacing: 10) {
                    Text("Seal Complete")
                        .font(EgyptFont.titleBold(34))
                        .foregroundStyle(Color.goldBright)
                        .tracking(2)

                    ornamentalRule

                    Text(entry.title)
                        .font(EgyptFont.bodyItalic(20))
                        .foregroundStyle(Color.papyrus)

                    Spacer(minLength: 12)

                    Text("A new inscription has been added to your journal.")
                        .font(EgyptFont.body(15))
                        .foregroundStyle(Color.papyrus.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: appeared)

                Spacer(minLength: 44)

                VStack(spacing: 14) {
                    Button(action: {
                        HapticFeedback.tap()
                        gameState.openJournal()
                    }) {
                        StoneButton(title: "Read the Inscription", icon: "book.fill", style: .muted)
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
        .onAppear {
            withAnimation { appeared = true }
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

    var body: some View {
        ZStack {
            Color.stoneDark.ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.35, green: 0.22, blue: 0.04).opacity(0.65), .clear],
                center: .center, startRadius: 100, endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

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

                Spacer(minLength: 32)

                VStack(spacing: 14) {
                    Text("The Gate Opens")
                        .font(EgyptFont.titleBold(38))
                        .foregroundStyle(Color.goldBright)
                        .tracking(3)
                        .shadow(color: Color.goldDark.opacity(glowPulse ? 1 : 0.4), radius: 14, x: 0, y: 0)

                    ornamentalRule

                    Text("You have unsealed all five chambers.\nThe path to eternity lies open before you.")
                        .font(EgyptFont.body(18))
                        .foregroundStyle(Color.papyrus)
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Spacer(minLength: 24)

                    Text("𓅱 𓆑 𓏏 𓈖 𓊪")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.goldMid.opacity(0.6))
                        .tracking(6)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
                .animation(.easeOut(duration: 0.7).delay(0.25), value: appeared)

                Spacer(minLength: 48)

                VStack(spacing: 14) {
                    Button(action: {
                        HapticFeedback.tap()
                        gameState.openJournal()
                    }) {
                        StoneButton(title: "Read All Inscriptions", icon: "book.fill", style: .muted)
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
        .onAppear {
            withAnimation { appeared = true }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowPulse = true
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
