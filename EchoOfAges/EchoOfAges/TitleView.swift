// TitleView.swift
// EchoOfAges

import SwiftUI

struct TitleView: View {
    @EnvironmentObject var gameState: GameState
    @State private var glowPulse = false
    @State private var appeared  = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()
                glyphDecoration
                Spacer(minLength: 24)
                titleBlock
                Spacer(minLength: 36)
                imageButtons
                Spacer()
                footerHieroglyphs
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
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
            RadialGradient(
                colors: [Color(red: 0.25, green: 0.15, blue: 0.06).opacity(0.7), Color.clear],
                center: .center, startRadius: 80, endRadius: 380
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.5)],
                center: .center, startRadius: 250, endRadius: 550
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Glyph Decoration

    private var glyphDecoration: some View {
        HStack(spacing: 0) {
            decorativeGlyph("𓂀")
            decorativeDivider
            decorativeGlyph("𓅓")
            decorativeDivider
            decorativeGlyph("𓈖")
            decorativeDivider
            decorativeGlyph("𓃭")
            decorativeDivider
            decorativeGlyph("𓇯")
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeIn(duration: 0.9), value: appeared)
    }

    private func decorativeGlyph(_ symbol: String) -> some View {
        Text(symbol)
            .font(.system(size: 44))
            .foregroundStyle(Color.goldMid.opacity(0.75))
            .shadow(color: Color.goldDark.opacity(glowPulse ? 0.5 : 0.2), radius: 6, x: 0, y: 0)
    }

    private var decorativeDivider: some View {
        Text("·")
            .font(EgyptFont.title(24))
            .foregroundStyle(Color.goldDark.opacity(0.5))
            .padding(.horizontal, 8)
    }

    // MARK: Title Block

    private var titleBlock: some View {
        VStack(spacing: 0) {
            Image("banner")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .shadow(color: Color.goldDark.opacity(glowPulse ? 0.6 : 0.2), radius: 16, x: 0, y: 4)
                .padding(.horizontal, -24)

            Spacer(minLength: 18)

            Text("An Ancient Hieroglyph Deduction Puzzle")
                .font(EgyptFont.bodyItalic(22))
                .foregroundStyle(Color.papyrus.opacity(0.70))
                .multilineTextAlignment(.center)

            Spacer(minLength: 18)

            Text("\"In the beginning was the Word,\nand the Word was carved in stone.\"")
                .font(EgyptFont.bodyItalic(20))
                .foregroundStyle(Color.papyrus.opacity(0.50))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.easeOut(duration: 0.8).delay(0.1), value: appeared)
    }

    // MARK: Image Buttons

    private var imageButtons: some View {
        HStack(spacing: 0) {
            // Begin Journey — always shown
            landingButton(
                asset:    "begin_journey",
                fallback: "arrow.right.circle.fill",
                label:    "Begin Journey"
            ) {
                HapticFeedback.heavy()
                withAnimation(.easeInOut(duration: 0.4)) { gameState.startNewGame() }
            }

            // Continue Journey — only shown when progress exists
            if gameState.hasProgress {
                landingButton(
                    asset:    "continue_journey",
                    fallback: "forward.fill",
                    label:    "Continue"
                ) {
                    HapticFeedback.tap()
                    withAnimation(.easeInOut(duration: 0.4)) { gameState.continueGame() }
                }
            }

            // Open Journal
            landingButton(
                asset:    "open_journal",
                fallback: "book.closed.fill",
                label:    "Journal"
            ) {
                HapticFeedback.tap()
                withAnimation(.easeInOut(duration: 0.4)) { gameState.openJournal() }
            }

            // Settings
            landingButton(
                asset:    "settings",
                fallback: "gearshape.fill",
                label:    "Settings"
            ) {
                HapticFeedback.tap()
                gameState.openSettings()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.stoneMid.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.goldDark.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.easeOut(duration: 0.7).delay(0.25), value: appeared)
    }

    /// Single landing-page button: image asset with label below.
    /// Falls back to an SF Symbol if the asset has no artwork yet.
    private func landingButton(
        asset:    String,
        fallback: String,
        label:    String,
        action:   @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if UIImage(named: asset) != nil {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 70)
                } else {
                    Image(systemName: fallback)
                        .font(.system(size: 40))
                        .foregroundStyle(Color.goldMid)
                        .frame(height: 70)
                }
                Text(label)
                    .font(EgyptFont.body(18))
                    .foregroundStyle(Color.stoneSurface)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    // MARK: Footer

    private var footerHieroglyphs: some View {
        Text("𓅱 𓆑 𓏏 𓈖 𓊪")
            .font(.system(size: 26))
            .foregroundStyle(Color.stoneLight.opacity(0.4))
            .tracking(10)
            .opacity(appeared ? 1 : 0)
            .animation(.easeIn(duration: 1.0).delay(0.5), value: appeared)
    }
}

#Preview {
    TitleView()
        .environmentObject(GameState())
}
