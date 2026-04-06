// SplashView.swift
// EchoOfAges
//
// App launch splash screen.
//
// Animation sequence:
//   1. Diary-page background appears instantly.
//   2. The banner fades and slides gently upward into its resting position.
//   3. A short hold, then onFinished() is called and the view fades away.

import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    @State private var bannerVisible = false   // drives banner fade + slide

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                // ── Banner: fades in and slides gently upward ─────────
                Image("banner")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, -24)
                    .shadow(color: Color(red: 0.20, green: 0.12, blue: 0.02).opacity(0.22),
                            radius: 14, x: 0, y: 5)
                    .offset(y: bannerVisible ? 0 : 60)
                    .opacity(bannerVisible ? 1 : 0)
                    .animation(
                        .spring(response: 0.80, dampingFraction: 0.78),
                        value: bannerVisible
                    )

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onAppear { beginSequence() }
    }

    // MARK: Animation sequence

    private func beginSequence() {
        bannerVisible = true

        // Hold after the spring settles, then hand off to the landing page.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            onFinished()
        }
    }

    // MARK: Background — exact diary paperCream

    private var background: some View {
        Color(red: 0.93, green: 0.87, blue: 0.73).ignoresSafeArea()
    }
}

#Preview {
    SplashView(onFinished: {})
}
