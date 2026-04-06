// SplashView.swift
// EchoOfAges
//
// App launch splash screen.
//
// Animation sequence:
//   1. Diary-page background appears instantly.
//   2. The banner starts at the vertical centre of the screen and slides UP
//      to its resting position near the top — as if being lifted into place.
//   3. Simultaneously, a block of hieroglyphs rises from below the screen
//      and settles in the lower half — two opposing movements that "open"
//      the scene from the centre outward.
//   4. A short hold, then onFinished() is called and the view fades away.

import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    @State private var bannerUp    = false   // drives banner sliding upward
    @State private var glyphsUp    = false   // drives glyph block rising

    // Three rows of hieroglyphs that form the stone tablet panel
    private let tabletRows: [[String]] = [
        ["𓂀", "𓅓", "𓈖", "𓃭", "𓇯", "𓀭"],
        ["𓆑", "𓏏", "𓊪", "𓅱", "𓁷", "𓃒"],
        ["𓋴", "𓂋", "𓈗", "𓇋", "𓆼", "𓂧"],
    ]

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                // ── Banner: starts in the middle, moves UP ────────────
                Image("banner")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, -24)
                    .shadow(color: Color(red: 0.20, green: 0.12, blue: 0.02).opacity(0.22),
                            radius: 14, x: 0, y: 5)
                    // Large positive offset = banner starts near screen centre;
                    // animates to 0 = its natural top position
                    .offset(y: bannerUp ? 0 : 220)
                    .opacity(bannerUp ? 1 : 0)
                    .animation(
                        .spring(response: 0.70, dampingFraction: 0.76),
                        value: bannerUp
                    )

                Spacer()   // pushes the glyph block to the lower half

                // ── Glyph tablet: rises from below the screen ─────────
                glyphPanel
                    .offset(y: glyphsUp ? 0 : 520)
                    .animation(
                        .spring(response: 0.78, dampingFraction: 0.80).delay(0.05),
                        value: glyphsUp
                    )

                Spacer(minLength: 64)
            }
            .padding(.horizontal, 24)
        }
        .onAppear { beginSequence() }
    }

    // MARK: Animation sequence

    private func beginSequence() {
        // Both movements start at the same moment — the banner lifts upward
        // while the glyphs rise from below, creating an "opening" reveal.
        bannerUp = true
        glyphsUp = true

        // Hold after animations settle (spring response 0.78 + delay 0.05 = ~0.83s
        // to start settling; springs decay over ~3× response = ~2.4s total).
        // We wait 2.6s then give a 0.7s hold before handing off.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.3) {
            onFinished()
        }
    }

    // MARK: Background — exact diary paperCream

    private var background: some View {
        ZStack {
            Color(red: 0.93, green: 0.87, blue: 0.73).ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.98, green: 0.94, blue: 0.80).opacity(0.55), .clear],
                center: .center, startRadius: 40, endRadius: 380
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [.clear, Color(red: 0.35, green: 0.22, blue: 0.08).opacity(0.42)],
                center: .center, startRadius: 260, endRadius: 680
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Glyph Panel

    private var glyphPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.80, green: 0.71, blue: 0.52))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(red: 0.40, green: 0.28, blue: 0.10).opacity(0.55),
                                lineWidth: 1.8)
                )

            VStack(spacing: 8) {
                ForEach(tabletRows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(row, id: \.self) { glyph in
                            Text(glyph)
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    Color(red: 0.16, green: 0.10, blue: 0.04).opacity(0.78)
                                )
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .shadow(color: Color(red: 0.20, green: 0.12, blue: 0.02).opacity(0.26),
                radius: 8, x: 0, y: 4)
    }
}

#Preview {
    SplashView(onFinished: {})
}
