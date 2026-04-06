// TitleView.swift
// EchoOfAges — main landing / menu screen

import SwiftUI

struct TitleView: View {
    @EnvironmentObject var gameState: GameState
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            background

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

                // Two primary actions — Continue if there's a session, always Open Journal
                HStack(spacing: 16) {
                    if gameState.hasProgress {
                        landingButton(asset: "continue_journey", fallback: "forward.fill") {
                            HapticFeedback.tap()
                            withAnimation(.easeInOut(duration: 0.4)) { gameState.continueGame() }
                        }
                    }
                    // Journal button — image + tagline
                    Button {
                        HapticFeedback.tap()
                        withAnimation(.easeInOut(duration: 0.4)) { gameState.openJournal() }
                    } label: {
                        VStack(spacing: 10) {
                            Group {
                                if UIImage(named: "journal") != nil {
                                    Image("journal").resizable().scaledToFit()
                                } else {
                                    Image(systemName: "book.closed.fill")
                                        .font(.system(size: 62))
                                        .foregroundStyle(Color(red: 0.40, green: 0.26, blue: 0.04))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 145)

                            Text(gameState.hasProgress ? "Open the Journal" : "Let the adventure begin")
                                .font(EgyptFont.bodyItalic(17))
                                .foregroundStyle(Color(red: 0.22, green: 0.14, blue: 0.05).opacity(0.80))
                                .multilineTextAlignment(.center)
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

#Preview {
    TitleView()
        .environmentObject(GameState())
}
