// IntroView.swift
// EchoOfAges
//
// Star Wars-style opening crawl with map image and full backstory.
// Text scrolls slowly upward from below the screen.

import SwiftUI

// MARK: - Preference key for measuring crawl content height

private struct CrawlHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Intro View

struct IntroView: View {
    @EnvironmentObject var gameState: GameState

    @State private var crawlOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var animationStarted = false
    @State private var skipOpacity: Double = 0

    // Crawl speed — points per second. Lower = slower.
    private let crawlSpeed: CGFloat = 48

    var body: some View {
        GeometryReader { geo in
            ZStack {

                // Deep space / stone background
                Color.black.ignoresSafeArea()
                RadialGradient(
                    colors: [
                        Color(red: 0.10, green: 0.07, blue: 0.02).opacity(0.8),
                        Color.black
                    ],
                    center: .center,
                    startRadius: 100,
                    endRadius: 500
                )
                .ignoresSafeArea()

                // ── Crawl content ─────────────────────────────────────────────
                crawlContent
                    .background(
                        GeometryReader { tg in
                            Color.clear
                                .preference(key: CrawlHeightKey.self, value: tg.size.height)
                        }
                    )
                    .offset(y: crawlOffset)

                // ── Fade masks — hides text appearing/disappearing at edges ───
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 100)
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 160)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // ── Skip button ───────────────────────────────────────────────
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { skipIntro() }) {
                            HStack(spacing: 6) {
                                Text("Skip")
                                    .font(EgyptFont.body(18))
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 14))
                            }
                            .foregroundStyle(Color.goldMid)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                                    .overlay(Capsule()
                                        .stroke(Color.goldDark.opacity(0.5), lineWidth: 1))
                            )
                        }
                        .padding(.trailing, 28)
                        .padding(.bottom, 32)
                    }
                }
                .opacity(skipOpacity)
            }
        }
        // Measure content height and start animation
        .onPreferenceChange(CrawlHeightKey.self) { height in
            guard height > 0, !animationStarted else { return }
            contentHeight = height
            startCrawl()
        }
        .onAppear {
            // Show skip button after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeIn(duration: 1.0)) { skipOpacity = 1 }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Crawl Content

    private var crawlContent: some View {
        VStack(spacing: 0) {

            // ── Opening glyph row ─────────────────────────────────────────────
            Text("𓊹  ·  𓂀  ·  𓊹")
                .font(.system(size: 28))
                .foregroundStyle(Color.goldMid.opacity(0.6))
                .tracking(8)
                .padding(.bottom, 40)

            // ── Map image ─────────────────────────────────────────────────────
            Image("map")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 400)
                .opacity(0.90)
                .shadow(color: Color.goldDark.opacity(0.4), radius: 20, x: 0, y: 8)
                .padding(.bottom, 36)

            crawlLabel("DISCOVERY SITE")
                .padding(.bottom, 48)

            // ── Title ─────────────────────────────────────────────────────────
            Text("THE TABLET")
                .font(EgyptFont.titleBold(38))
                .foregroundStyle(Color.goldBright)
                .tracking(8)

            Text("OF MANDU")
                .font(EgyptFont.titleBold(38))
                .foregroundStyle(Color.goldBright)
                .tracking(8)
                .padding(.bottom, 64)

            // ── Act I ─────────────────────────────────────────────────────────
            crawlParagraph("""
Summer, 2024.

A research vessel mapping the
Mid-Atlantic Ridge makes an
extraordinary discovery.
""")

            crawlParagraph("""
On a remote volcanic island —
uncharted, unnamed, and unreachable
by ordinary means —
buried beneath centuries of
ash and ocean-stone...
""")

            crawlEmphasis("...a tablet.")

            crawlParagraph("""
Carved from a single slab of
black obsidian, it bears thirty
symbols drawn from six of
humanity's oldest civilizations.
""")

            crawlEmphasis("Egyptian.  Norse.  Sumerian.")
            crawlEmphasis("Mayan.  Celtic.  Chinese.")

            crawlParagraph("""
No single culture could have
created it alone.
""")

            // ── Act II ────────────────────────────────────────────────────────
            divider.padding(.vertical, 32)

            crawlParagraph("""
Lead archaeologist Dr. Elena Mandu —
for whom the tablet is now named —
recognized fragments of each
ancient script immediately.

But the tablet was incomplete.
""")

            crawlParagraph("""
The symbols are arranged in a
sacred pattern. A puzzle.
Without the key, the full
message cannot be read.
""")

            crawlEmphasis("But the key still exists.")

            crawlParagraph("""
Across six ancient sites, five
partial tablets survive from
each civilization.

Together, they hold the answer.
""")

            // ── Act III ───────────────────────────────────────────────────────
            divider.padding(.vertical, 32)

            crawlEmphasis("Your mission:")

            crawlParagraph("""
Decipher the partial tablets,
one inscription at a time.

Each solved puzzle adds known
glyphs to your codex and brings
the Tablet of Mandu closer to
revealing its hidden truth.
""")

            crawlParagraph("""
The ancients placed these symbols
here for a reason.

They were waiting for someone
with the patience to listen.
""")

            crawlEmphasis("Begin with the Egyptian Chamber.")

            crawlEmphasis("The tablets await.")

            // ── Closing glyph row ─────────────────────────────────────────────
            Text("𓅱  𓆑  𓏏  𓈖  𓊪")
                .font(.system(size: 24))
                .foregroundStyle(Color.goldMid.opacity(0.4))
                .tracking(10)
                .padding(.top, 80)
                .padding(.bottom, 120)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    // MARK: Crawl text helpers

    private func crawlParagraph(_ text: String) -> some View {
        Text(text)
            .font(EgyptFont.body(22))
            .foregroundStyle(Color(red: 0.88, green: 0.82, blue: 0.60))
            .lineSpacing(10)
            .padding(.bottom, 36)
    }

    private func crawlEmphasis(_ text: String) -> some View {
        Text(text)
            .font(EgyptFont.titleBold(24))
            .foregroundStyle(Color.goldBright)
            .tracking(2)
            .padding(.bottom, 36)
    }

    private func crawlLabel(_ text: String) -> some View {
        Text(text)
            .font(EgyptFont.title(13))
            .foregroundStyle(Color.goldDark)
            .tracking(5)
    }

    private var divider: some View {
        Text("· · · · ·")
            .font(EgyptFont.title(16))
            .foregroundStyle(Color.goldDark.opacity(0.5))
            .tracking(8)
    }

    // MARK: Animation

    private func startCrawl() {
        guard !animationStarted else { return }
        animationStarted = true

        // Start text just below screen bottom
        let screenH = UIScreen.main.bounds.height
        crawlOffset = screenH

        let totalDistance = screenH + contentHeight
        let duration = Double(totalDistance) / Double(crawlSpeed)

        DispatchQueue.main.async {
            withAnimation(.linear(duration: duration)) {
                self.crawlOffset = -(self.contentHeight + 80)
            }
        }

        // Auto-finish when crawl ends
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            skipIntro()
        }
    }

    private func skipIntro() {
        withAnimation(.easeIn(duration: 0.7)) {
            gameState.finishIntro()
        }
    }
}
