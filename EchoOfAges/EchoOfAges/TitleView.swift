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
                Spacer(minLength: 40)
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

    // MARK: Background — aged papyrus / diary-page warmth

    private var background: some View {
        ZStack {
            // Papyrus base
            Color(red: 0.88, green: 0.82, blue: 0.63).ignoresSafeArea()
            // Warm candlelight glow at centre
            RadialGradient(
                colors: [Color(red: 0.96, green: 0.91, blue: 0.74).opacity(0.65), .clear],
                center: .center, startRadius: 50, endRadius: 360
            )
            .ignoresSafeArea()
            // Aged-edge vignette — darker corners like old parchment
            RadialGradient(
                colors: [.clear, Color(red: 0.38, green: 0.26, blue: 0.10).opacity(0.50)],
                center: .center, startRadius: 270, endRadius: 640
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
            .foregroundStyle(Color.goldDark.opacity(0.85))
            .shadow(color: Color.goldDark.opacity(glowPulse ? 0.45 : 0.12), radius: 6, x: 0, y: 0)
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
                .shadow(color: Color.stoneDark.opacity(glowPulse ? 0.25 : 0.10), radius: 12, x: 0, y: 4)
                .padding(.horizontal, -24)

            Spacer(minLength: 18)

            Text("An Ancient Hieroglyph Deduction Puzzle")
                .font(EgyptFont.bodyItalic(22))
                .foregroundStyle(Color.stoneMid.opacity(0.90))
                .multilineTextAlignment(.center)

            Spacer(minLength: 18)

            Text("\"In the beginning was the Word,\nand the Word was carved in stone.\"")
                .font(EgyptFont.bodyItalic(20))
                .foregroundStyle(Color.stoneMid.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.easeOut(duration: 0.8).delay(0.1), value: appeared)
    }

    // MARK: Image Buttons — no bar, no labels, images speak for themselves

    private var imageButtons: some View {
        HStack(spacing: 8) {
            // Begin Journey — always shown
            landingButton(asset: "begin_journey", fallback: "arrow.right.circle.fill") {
                HapticFeedback.heavy()
                withAnimation(.easeInOut(duration: 0.4)) { gameState.startNewGame() }
            }

            // Continue Journey — only shown when progress exists
            if gameState.hasProgress {
                landingButton(asset: "continue_journey", fallback: "forward.fill") {
                    HapticFeedback.tap()
                    withAnimation(.easeInOut(duration: 0.4)) { gameState.continueGame() }
                }
            }

            // Open Journal
            landingButton(asset: "open_journal", fallback: "book.closed.fill") {
                HapticFeedback.tap()
                withAnimation(.easeInOut(duration: 0.4)) { gameState.openJournal() }
            }

            // Settings
            landingButton(asset: "settings", fallback: "gearshape.fill") {
                HapticFeedback.tap()
                gameState.openSettings()
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.easeOut(duration: 0.7).delay(0.25), value: appeared)
    }

    /// Single landing-page button: image asset only — no text label.
    /// Image is sized large enough to be read on its own.
    private func landingButton(
        asset:    String,
        fallback: String,
        action:   @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if UIImage(named: asset) != nil {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: fallback)
                        .font(.system(size: 52))
                        .foregroundStyle(Color.goldDark)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
        }
    }

    // MARK: Footer

    private var footerHieroglyphs: some View {
        Text("𓅱 𓆑 𓏏 𓈖 𓊪")
            .font(.system(size: 26))
            .foregroundStyle(Color.stoneMid.opacity(0.30))
            .tracking(10)
            .opacity(appeared ? 1 : 0)
            .animation(.easeIn(duration: 1.0).delay(0.5), value: appeared)
    }
}

#Preview {
    TitleView()
        .environmentObject(GameState())
}
