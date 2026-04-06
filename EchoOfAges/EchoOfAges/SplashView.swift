// SplashView.swift
// EchoOfAges
//
// Full-screen splash shown once per app launch.
// Background matches the diary page colour exactly.
// The banner appears at the top, then rows of hieroglyphs rise from the
// bottom of the screen and settle into a stone-tablet formation.
// After the animation completes the view calls onFinished() and fades out.

import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    // Banner fade-in
    @State private var bannerVisible = false
    // Each tablet row gets its own flag so they stagger independently
    @State private var rowVisible: [Bool] = Array(repeating: false, count: 5)

    // Five rows × six hieroglyphs — chosen for visual variety
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
                // ── Banner at the top ──────────────────────────────────
                Spacer(minLength: 10)

                Image("banner")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, -24)
                    .shadow(color: Color(red: 0.20, green: 0.12, blue: 0.02).opacity(0.20),
                            radius: 14, x: 0, y: 5)
                    .opacity(bannerVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.80), value: bannerVisible)

                // ── Flexible space between banner and tablet ───────────
                Spacer()

                // ── Stone tablet: rows rise from the bottom ────────────
                glyphTablet

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 24)
        }
        .onAppear { beginSequence() }
    }

    // MARK: Animation sequence

    private func beginSequence() {
        // 1. Banner fades in immediately
        bannerVisible = true

        // 2. Tablet rows rise one by one from the bottom.
        //    Row 4 (lowest) fires first → rows stack upward.
        let rowCount = tabletRows.count
        for i in 0..<rowCount {
            let rowFromBottom = rowCount - 1 - i   // 4, 3, 2, 1, 0
            let delay = 0.55 + Double(rowFromBottom) * 0.13
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.58, dampingFraction: 0.78)) {
                    rowVisible[i] = true
                }
            }
        }

        // 3. Hold briefly after the top row settles, then hand off
        let holdDelay = 0.55 + Double(rowCount - 1) * 0.13 + 0.58 + 0.90
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDelay) {
            onFinished()
        }
    }

    // MARK: Background — exact diary paperCream

    private var background: some View {
        ZStack {
            Color(red: 0.93, green: 0.87, blue: 0.73).ignoresSafeArea()
            // Warm candlelight glow
            RadialGradient(
                colors: [Color(red: 0.98, green: 0.94, blue: 0.80).opacity(0.60), .clear],
                center: .center, startRadius: 40, endRadius: 380
            )
            .ignoresSafeArea()
            // Aged-edge vignette
            RadialGradient(
                colors: [.clear, Color(red: 0.35, green: 0.22, blue: 0.08).opacity(0.45)],
                center: .center, startRadius: 260, endRadius: 680
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Glyph Tablet

    private var glyphTablet: some View {
        ZStack {
            // Stone tablet backing
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.80, green: 0.71, blue: 0.52))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(red: 0.40, green: 0.28, blue: 0.10).opacity(0.55),
                                lineWidth: 1.8)
                )

            // Rows of glyphs — each rises into the tablet from beneath
            VStack(spacing: 6) {
                ForEach(0..<tabletRows.count, id: \.self) { idx in
                    HStack(spacing: 0) {
                        ForEach(tabletRows[idx], id: \.self) { glyph in
                            Text(glyph)
                                .font(.system(size: 30))
                                .foregroundStyle(
                                    Color(red: 0.16, green: 0.10, blue: 0.04).opacity(0.80)
                                )
                                .frame(maxWidth: .infinity)
                        }
                    }
                    // Start each row far below; animate up when its flag fires
                    .offset(y: rowVisible[idx] ? 0 : 280)
                    .opacity(rowVisible[idx] ? 1 : 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        // Clip so rows only appear once they enter the tablet from the bottom
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color(red: 0.20, green: 0.12, blue: 0.02).opacity(0.28),
                radius: 8, x: 0, y: 4)
    }
}

#Preview {
    SplashView(onFinished: {})
}
