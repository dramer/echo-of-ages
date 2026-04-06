// TitleView.swift
// EchoOfAges — main landing / menu screen
//
// Everything fades in gently — no sliding or floating animations.
// The splash screen has already done the dramatic reveal;
// the landing page simply appears, ready for the player.

import SwiftUI

struct TitleView: View {
    @EnvironmentObject var gameState: GameState
    @State private var glowPulse = false
    @State private var appeared  = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer(minLength: 12)
                bannerImage
                Spacer(minLength: 18)
                glyphDecoration
                Spacer(minLength: 22)
                textBlock
                Spacer()
                imageButtons
                Spacer(minLength: 18)
                footerHieroglyphs
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            Color(red: 0.88, green: 0.82, blue: 0.63).ignoresSafeArea()
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

    // MARK: Banner — fades in, no sliding

    private var bannerImage: some View {
        Image("banner")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, -24)
            .shadow(color: Color.stoneDark.opacity(glowPulse ? 0.25 : 0.10),
                    radius: 12, x: 0, y: 4)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.5), value: appeared)
    }

    // MARK: Glyph Row — fades in, no sliding

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
        .animation(.easeOut(duration: 0.6).delay(0.05), value: appeared)
    }

    private func decorativeGlyph(_ symbol: String) -> some View {
        Text(symbol)
            .font(.system(size: 50))
            .foregroundStyle(Color.stoneDark.opacity(0.82))
            .shadow(color: Color.stoneDark.opacity(glowPulse ? 0.22 : 0.06),
                    radius: 4, x: 0, y: 1)
    }

    private var decorativeDivider: some View {
        Text("·")
            .font(EgyptFont.title(26))
            .foregroundStyle(Color.stoneMid.opacity(0.55))
            .padding(.horizontal, 8)
    }

    // MARK: Text — fades in

    private var textBlock: some View {
        VStack(spacing: 16) {
            Text("An Ancient Hieroglyph Deduction Puzzle")
                .font(EgyptFont.bodyItalic(26))
                .foregroundStyle(Color(red: 0.25, green: 0.16, blue: 0.06))
                .multilineTextAlignment(.center)

            Text("\"In the beginning was the Word,\nand the Word was carved in stone.\"")
                .font(EgyptFont.bodyItalic(23))
                .foregroundStyle(Color(red: 0.25, green: 0.16, blue: 0.06).opacity(0.58))
                .multilineTextAlignment(.center)
                .lineSpacing(7)
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.6).delay(0.10), value: appeared)
    }

    // MARK: Buttons — fade in

    private var imageButtons: some View {
        HStack(spacing: 8) {
            landingButton(asset: "begin_journey", fallback: "arrow.right.circle.fill") {
                HapticFeedback.heavy()
                withAnimation(.easeInOut(duration: 0.4)) { gameState.startNewGame() }
            }
            if gameState.hasProgress {
                landingButton(asset: "continue_journey", fallback: "forward.fill") {
                    HapticFeedback.tap()
                    withAnimation(.easeInOut(duration: 0.4)) { gameState.continueGame() }
                }
            }
            landingButton(asset: "open_journal", fallback: "book.closed.fill") {
                HapticFeedback.tap()
                withAnimation(.easeInOut(duration: 0.4)) { gameState.openJournal() }
            }
            landingButton(asset: "settings", fallback: "gearshape.fill") {
                HapticFeedback.tap()
                gameState.openSettings()
            }
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.6).delay(0.15), value: appeared)
    }

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

    // MARK: Footer

    private var footerHieroglyphs: some View {
        Text("𓅱 𓆑 𓏏 𓈖 𓊪")
            .font(.system(size: 24))
            .foregroundStyle(Color(red: 0.30, green: 0.20, blue: 0.06).opacity(0.28))
            .tracking(10)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.20), value: appeared)
    }
}

#Preview {
    TitleView()
        .environmentObject(GameState())
}
