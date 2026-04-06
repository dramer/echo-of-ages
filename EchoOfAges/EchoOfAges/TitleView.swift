// TitleView.swift
// EchoOfAges

import SwiftUI

struct TitleView: View {
    @EnvironmentObject var gameState: GameState
    @State private var glowPulse  = false
    @State private var appeared   = false   // banner + text + buttons
    @State private var tabletUp   = false   // glyph rows rising into tablet

    // Hieroglyph rows that form the stone tablet.
    // 5 rows × 6 columns = 30 signs; chosen for visual variety.
    private let tabletRows: [[String]] = [
        ["𓂀", "𓅓", "𓈖", "𓃭", "𓇯", "𓀭"],
        ["𓆑", "𓏏", "𓊪", "𓅱", "𓁷", "𓃒"],
        ["𓋴", "𓂋", "𓈗", "𓇋", "𓆼", "𓂧"],
        ["𓌀", "𓅆", "𓏛", "𓄿", "𓃀", "𓏤"],
        ["𓏭", "𓅐", "𓍿", "𓊃", "𓇌", "𓈀"],
    ]

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                // Banner pinned near the top — drops in from above
                Spacer(minLength: 8)
                bannerImage

                // Glyph tablet assembles from the bottom
                Spacer(minLength: 20)
                glyphTablet

                // Subtitle text
                Spacer(minLength: 22)
                textBlock

                // Buttons toward the bottom
                Spacer()
                imageButtons
                Spacer(minLength: 16)
                footerHieroglyphs
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            // Glow pulse — continuous
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            // Banner, text & buttons fade-in
            withAnimation(.easeOut(duration: 0.7)) {
                appeared = true
            }
            // Glyph rows rise into the tablet a beat later
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                tabletUp = true
            }
        }
    }

    // MARK: Background — exact diary paperCream colour

    private var background: some View {
        ZStack {
            // Match the journal page exactly
            Color(red: 0.93, green: 0.87, blue: 0.73).ignoresSafeArea()
            // Soft warm glow from centre (candlelight)
            RadialGradient(
                colors: [Color(red: 0.98, green: 0.94, blue: 0.80).opacity(0.55), .clear],
                center: .center, startRadius: 40, endRadius: 340
            )
            .ignoresSafeArea()
            // Aged-parchment edge vignette
            RadialGradient(
                colors: [.clear, Color(red: 0.35, green: 0.22, blue: 0.08).opacity(0.45)],
                center: .center, startRadius: 260, endRadius: 640
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Banner — slides down from above

    private var bannerImage: some View {
        Image("banner")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, -24)  // bleed to full screen width
            .shadow(color: Color.stoneDark.opacity(glowPulse ? 0.22 : 0.08),
                    radius: 12, x: 0, y: 5)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : -28)
            .animation(.spring(response: 0.65, dampingFraction: 0.78), value: appeared)
    }

    // MARK: Glyph Tablet

    private var glyphTablet: some View {
        ZStack {
            // Stone tablet background
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.80, green: 0.71, blue: 0.52))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(red: 0.40, green: 0.28, blue: 0.10).opacity(0.55),
                                lineWidth: 1.8)
                )

            // Glyph rows — each row rises into the tablet from below
            VStack(spacing: 6) {
                ForEach(0..<tabletRows.count, id: \.self) { rowIdx in
                    glyphRow(tabletRows[rowIdx], rowIndex: rowIdx)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        // Clip so rows only appear once they enter the tablet from the bottom
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color(red: 0.20, green: 0.12, blue: 0.02).opacity(0.30),
                radius: 8, x: 0, y: 4)
    }

    /// One row of hieroglyphs with its slide-up animation.
    /// Bottom rows get shorter delays so they arrive first,
    /// stacking upward to "fill" the tablet from the base.
    private func glyphRow(_ glyphs: [String], rowIndex: Int) -> some View {
        let totalRows  = tabletRows.count
        // Row at bottom of tablet (index = totalRows-1) has smallest delay → arrives first
        let rowFromBottom = totalRows - 1 - rowIndex
        let delay = Double(rowFromBottom) * 0.10   // 0.0, 0.10, 0.20, 0.30, 0.40

        return HStack(spacing: 0) {
            ForEach(glyphs, id: \.self) { glyph in
                Text(glyph)
                    .font(.system(size: 30))
                    .foregroundStyle(Color(red: 0.16, green: 0.10, blue: 0.04).opacity(0.80))
                    .frame(maxWidth: .infinity)
            }
        }
        // Start far below the tablet — clip hides until the row enters from the bottom
        .offset(y: tabletUp ? 0 : 220)
        .animation(
            .spring(response: 0.60, dampingFraction: 0.82).delay(delay),
            value: tabletUp
        )
    }

    // MARK: Text Block

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
        .offset(y: appeared ? 0 : 14)
        .animation(.easeOut(duration: 0.7).delay(0.20), value: appeared)
    }

    // MARK: Image Buttons

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
        .offset(y: appeared ? 0 : 14)
        .animation(.easeOut(duration: 0.7).delay(0.30), value: appeared)
    }

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
            .animation(.easeIn(duration: 1.0).delay(0.5), value: appeared)
    }
}

#Preview {
    TitleView()
        .environmentObject(GameState())
}
