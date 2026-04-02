// TitleView.swift
// EchoOfAges

import SwiftUI

struct TitleView: View {
    @EnvironmentObject var gameState: GameState
    @State private var glowPulse = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                Spacer()
                glyphDecoration
                Spacer(minLength: 28)
                titleBlock
                Spacer(minLength: 40)
                buttons
                Spacer()
                footerHieroglyphs
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
        }
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            Color.stoneDark.ignoresSafeArea()
            // Warm center glow
            RadialGradient(
                colors: [
                    Color(red: 0.25, green: 0.15, blue: 0.06).opacity(0.7),
                    Color.clear
                ],
                center: .center,
                startRadius: 80,
                endRadius: 380
            )
            .ignoresSafeArea()
            // Vignette
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.5)],
                center: .center,
                startRadius: 250,
                endRadius: 550
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Glyph Decoration

    private var glyphDecoration: some View {
        HStack(spacing: 0) {
            decorativeGlyph("𓂀", delay: 0.1)
            decorativeDivider
            decorativeGlyph("𓅓", delay: 0.2)
            decorativeDivider
            decorativeGlyph("𓈖", delay: 0.3)
            decorativeDivider
            decorativeGlyph("𓃭", delay: 0.2)
            decorativeDivider
            decorativeGlyph("𓇯", delay: 0.1)
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeIn(duration: 0.9), value: appeared)
    }

    private func decorativeGlyph(_ symbol: String, delay: Double) -> some View {
        Text(symbol)
            .font(.system(size: 32))
            .foregroundStyle(Color.goldMid.opacity(0.75))
            .shadow(color: Color.goldDark.opacity(glowPulse ? 0.5 : 0.2), radius: 6, x: 0, y: 0)
    }

    private var decorativeDivider: some View {
        Text("·")
            .font(EgyptFont.title(18))
            .foregroundStyle(Color.goldDark.opacity(0.5))
            .padding(.horizontal, 6)
    }

    // MARK: Title Block

    private var titleBlock: some View {
        VStack(spacing: 0) {
            // Gold banner with title
            ZStack {
                // Banner background
                LinearGradient(
                    colors: [
                        Color(red: 0.38, green: 0.26, blue: 0.04),
                        Color(red: 0.52, green: 0.37, blue: 0.07),
                        Color(red: 0.38, green: 0.26, blue: 0.04)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(maxWidth: .infinity)
                .frame(height: 120)

                // Top + bottom rule lines
                VStack {
                    Rectangle()
                        .fill(Color.goldBright.opacity(0.5))
                        .frame(height: 1.2)
                    Spacer()
                    Rectangle()
                        .fill(Color.goldBright.opacity(0.5))
                        .frame(height: 1.2)
                }
                .frame(height: 120)

                // Text content
                VStack(spacing: 6) {
                    Text("ECHO OF AGES")
                        .font(EgyptFont.titleBold(40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.goldBright, Color(red: 0.97, green: 0.86, blue: 0.50), Color.goldBright],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .tracking(5)
                        .shadow(color: Color.goldDark.opacity(glowPulse ? 0.9 : 0.3), radius: 10, x: 0, y: 0)

                    Text("by David Ramer")
                        .font(EgyptFont.bodyItalic(16))
                        .foregroundStyle(Color.papyrus.opacity(0.85))
                        .tracking(1)
                }
            }
            .padding(.horizontal, -32) // bleed to edges past parent padding

            Spacer(minLength: 20)

            Text("An Ancient Hieroglyph Deduction Puzzle")
                .font(EgyptFont.bodyItalic(16))
                .foregroundStyle(Color.papyrus.opacity(0.70))
                .multilineTextAlignment(.center)

            Spacer(minLength: 20)

            Text("\"In the beginning was the Word,\nand the Word was carved in stone.\"")
                .font(EgyptFont.bodyItalic(15))
                .foregroundStyle(Color.papyrus.opacity(0.50))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.easeOut(duration: 0.8).delay(0.1), value: appeared)
    }

    // MARK: Buttons

    private var buttons: some View {
        VStack(spacing: 14) {
            Button(action: {
                HapticFeedback.heavy()
                withAnimation(.easeInOut(duration: 0.4)) {
                    gameState.startNewGame()
                }
            }) {
                StoneButton(title: "Begin Journey", icon: "arrow.right.circle.fill", style: .gold)
            }

            if gameState.hasProgress {
                Button(action: {
                    HapticFeedback.tap()
                    withAnimation(.easeInOut(duration: 0.4)) {
                        gameState.continueGame()
                    }
                }) {
                    StoneButton(title: "Continue Journey", icon: "forward.fill", style: .muted)
                }
            }

            Button(action: {
                HapticFeedback.tap()
                withAnimation(.easeInOut(duration: 0.4)) {
                    gameState.openJournal()
                }
            }) {
                StoneButton(title: "Open Journal", icon: "book.closed.fill", style: .muted)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.easeOut(duration: 0.7).delay(0.25), value: appeared)
    }

    // MARK: Footer

    private var footerHieroglyphs: some View {
        Text("𓅱 𓆑 𓏏 𓈖 𓊪")
            .font(.system(size: 18))
            .foregroundStyle(Color.stoneLight.opacity(0.4))
            .tracking(8)
            .opacity(appeared ? 1 : 0)
            .animation(.easeIn(duration: 1.0).delay(0.5), value: appeared)
    }
}

#Preview {
    TitleView()
        .environmentObject(GameState())
}
