// IntroView.swift
// EchoOfAges
//
// Two-phase opening sequence:
//   Phase 1 — Discovery reveal: map image fades in on a dark background,
//              held for a few seconds so the player can study it.
//   Phase 2 — Star Wars crawl: map fades out, gold text scrolls slowly upward.
//              Text starts centred on screen. The Mandu tablet is revealed as a
//              separate centred overlay AFTER the text has cleared — guaranteeing
//              it is always fully visible before the fade-to-black transition.
//
// egypt_sound.mp3 plays throughout and fades out when the intro ends.

import SwiftUI
import AVFoundation

// MARK: - Intro phases

private enum IntroPhase {
    case mapReveal    // map is showing
    case crawl        // text scrolling
    case tabletReveal // Mandu tablet centred on screen after crawl
}

// MARK: - Crawl height preference key

private struct CrawlHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - IntroView

struct IntroView: View {
    @EnvironmentObject var gameState: GameState

    // Phase
    @State private var phase: IntroPhase = .mapReveal

    // Map-reveal layer
    @State private var mapOpacity:      Double = 0
    @State private var mapLabelOpacity: Double = 0

    // Crawl layer
    @State private var crawlOpacity:    Double = 0
    @State private var crawlOffset:     CGFloat = 0   // set properly in beginCrawl
    @State private var contentHeight:   CGFloat = 0
    @State private var crawlStarted:    Bool    = false

    // Tablet overlay (shown after text clears)
    @State private var tabletOpacity:   Double = 0

    // Fade-to-black overlay (used for final transition)
    @State private var blackOpacity:    Double = 0

    // UI chrome
    @State private var skipOpacity:     Double = 0

    // Audio
    @State private var audioPlayer: AVAudioPlayer?

    private let crawlSpeed: CGFloat = 38   // points per second
    private let fadeInDuration: Double = 0.8

    private var screenH: CGFloat { UIScreen.main.bounds.height }

    // MARK: Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Warm amber undertone — feels like torchlight on stone
            RadialGradient(
                colors: [Color(red: 0.12, green: 0.07, blue: 0.02).opacity(0.85), Color.black],
                center: .center, startRadius: 80, endRadius: 500
            )
            .ignoresSafeArea()

            // ── Phase 1: Map reveal ───────────────────────────────────────────
            if phase == .mapReveal {
                mapRevealLayer
            }

            // ── Phase 2: Text crawl (no tablet — tablet is separate below) ───
            if phase == .crawl || phase == .tabletReveal {
                crawlLayer
            }

            // ── Tablet of Mandu — centred reveal after text clears ────────────
            if phase == .tabletReveal {
                tabletOverlay
                    .opacity(tabletOpacity)
                    .transition(.opacity)
            }

            // ── Fade-to-black overlay (final transition) ──────────────────────
            Color.black
                .ignoresSafeArea()
                .opacity(blackOpacity)
                .allowsHitTesting(false)

            // ── Fade masks (always on top of content) ─────────────────────────
            VStack(spacing: 0) {
                LinearGradient(colors: [.black, .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 110)
                Spacer()
                LinearGradient(colors: [.clear, .black],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 160)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // ── Skip button ───────────────────────────────────────────────────
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { endIntro() }) {
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
                                .fill(Color.black.opacity(0.65))
                                .overlay(Capsule()
                                    .stroke(Color.goldDark.opacity(0.55), lineWidth: 1))
                        )
                    }
                    .padding(.trailing, 28)
                    .padding(.bottom, 36)
                }
            }
            .opacity(skipOpacity)
        }
        .ignoresSafeArea()
        .onAppear { startIntro() }
    }

    // MARK: Map reveal layer

    private var mapRevealLayer: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("map")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 480)
                .shadow(color: Color.goldDark.opacity(0.5), radius: 28, x: 0, y: 10)
                .opacity(mapOpacity)
            VStack(spacing: 6) {
                Text("· DISCOVERY SITE ·")
                    .font(EgyptFont.title(14))
                    .foregroundStyle(Color.goldDark)
                    .tracking(5)
                Text("Mid-Atlantic Ridge  —  2024")
                    .font(EgyptFont.bodyItalic(16))
                    .foregroundStyle(Color.papyrus.opacity(0.65))
            }
            .opacity(mapLabelOpacity)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Crawl layer

    private var crawlLayer: some View {
        crawlContent
            .background(
                GeometryReader { tg in
                    Color.clear
                        .preference(key: CrawlHeightKey.self, value: tg.size.height)
                }
            )
            .offset(y: crawlOffset)
            .opacity(crawlOpacity)
            .onPreferenceChange(CrawlHeightKey.self) { height in
                guard height > 0, !crawlStarted else { return }
                contentHeight = height
                beginCrawl()
            }
    }

    // MARK: Crawl text content (tablet NOT included — shown separately after crawl)

    private var crawlContent: some View {
        let name = gameState.playerName.trimmingCharacters(in: .whitespaces)
        let greeting = name.isEmpty ? "Archaeologist" : name

        return VStack(spacing: 0) {

            Text("𓊹  ·  𓂀  ·  𓊹")
                .font(.system(size: 26))
                .foregroundStyle(Color.goldMid.opacity(0.55))
                .tracking(8)
                .padding(.bottom, 44)

            // Title card
            Text("THE TABLET")
                .font(EgyptFont.titleBold(40))
                .foregroundStyle(Color.goldBright)
                .tracking(8)
            Text("OF MANDU")
                .font(EgyptFont.titleBold(40))
                .foregroundStyle(Color.goldBright)
                .tracking(8)
                .padding(.bottom, 70)

            crawlEmphasis("Welcome, \(greeting).")

            crawlParagraph("The call came at 2:47 in the morning.")

            crawlParagraph("Dr. Sandra Mandu —\nlead archaeologist,\ncross-cultural linguist,\nand the most relentless person\nany of us have ever worked with —\nhad found something she\ncould not explain.")

            separatorGlyphs

            crawlParagraph("On a remote volcanic island\nin the mid-Atlantic —\nuncharted, unmapped,\nunreachable by any ordinary route —\nburied beneath centuries of\nash and ocean-stone:")

            crawlParagraph("Six tablets.\n\nEach carved in the ancient script\nof a different civilization.")

            crawlEmphasis("Egyptian.  Norse.  Sumerian.")
            crawlEmphasis("Maya.  Celtic.  Chinese.")

            crawlParagraph("No single culture could have\ncrossed paths with all the others.\n\nAnd yet —\nhere they were.\nTogether.")

            separatorGlyphs

            crawlParagraph("But that was not the discovery\nthat made her call\nat 2:47 in the morning.")

            crawlParagraph("Beneath the six tablets,\nhalf-buried in the volcanic stone,\nDr. Mandu found a seventh.")

            crawlEmphasis("Partially carved.")

            crawlParagraph("Six empty spaces\nwhere symbols should have been.\n\nOne space for each civilization.\n\nThe carver had stopped\nbefore finishing —\nor left it for someone else\nto complete.")

            separatorGlyphs

            crawlParagraph("The question is not\nwhat the tablet says.")

            crawlEmphasis("The question is:\nwhat symbols are missing?")

            crawlParagraph("Dr. Mandu believes the answer\nis hidden in the six\npartial tablets themselves.\n\nEach civilization left\nfive teaching stones.\nStudy them. Solve them.\nLearn their scripts.")

            crawlParagraph("Each solution will reveal\nwhich symbol belongs\nin that empty space\non the partial tablet.")

            separatorGlyphs

            crawlParagraph("That is why you are here,\n\(greeting).")

            crawlParagraph("Your insights may be\nthe ones that finally\ncomplete what was started\nthousands of years ago.")

            crawlEmphasis("Begin with Egypt.")

            crawlEmphasis("The tablets await.")

            Text("𓅱  𓆑  𓏏  𓈖  𓊪")
                .font(.system(size: 22))
                .foregroundStyle(Color.goldMid.opacity(0.4))
                .tracking(10)
                .padding(.top, 80)
                .padding(.bottom, 60)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }

    // MARK: Tablet overlay (centred, shown after text clears)

    private var tabletOverlay: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("· · · · ·")
                .font(EgyptFont.title(16))
                .foregroundStyle(Color.goldDark.opacity(0.5))
                .tracking(8)
                .padding(.bottom, 8)

            Image("tree_tablet")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320)
                .shadow(color: Color.goldBright.opacity(0.45), radius: 40, x: 0, y: 0)

            Text("THE TABLET OF MANDU")
                .font(EgyptFont.titleBold(20))
                .foregroundStyle(Color.goldBright)
                .tracking(5)
                .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func crawlParagraph(_ text: String) -> some View {
        Text(text)
            .font(EgyptFont.body(22))
            .foregroundStyle(Color(red: 0.88, green: 0.82, blue: 0.60))
            .lineSpacing(9)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 38)
    }

    private func crawlEmphasis(_ text: String) -> some View {
        Text(text)
            .font(EgyptFont.titleBold(24))
            .foregroundStyle(Color.goldBright)
            .tracking(2)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 38)
    }

    private var separatorGlyphs: some View {
        Text("· · · · ·")
            .font(EgyptFont.title(16))
            .foregroundStyle(Color.goldDark.opacity(0.5))
            .tracking(8)
            .padding(.vertical, 34)
    }

    // MARK: Sequencing

    private func startIntro() {
        playAudio()

        // Show skip after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 1.0)) { skipOpacity = 1 }
        }

        // Phase 1: fade in map
        withAnimation(.easeIn(duration: 1.8)) { mapOpacity = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 1.2)) { mapLabelOpacity = 1 }
        }

        // After 5.5 s, fade out map and start crawl
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            withAnimation(.easeOut(duration: 1.2)) { mapOpacity = 0; mapLabelOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Position content at screen mid-point BEFORE making it visible,
                // using withAnimation(.none) so the jump is instant with no inherited transaction
                withAnimation(.none) { crawlOffset = screenH }
                phase = .crawl
                withAnimation(.easeIn(duration: fadeInDuration)) { crawlOpacity = 1 }
            }
        }
    }

    private func beginCrawl() {
        guard !crawlStarted else { return }
        crawlStarted = true

        let startOffset = screenH

        // Scroll just far enough for the last line to clear the top fade mask (110 pt).
        // This is when the bottom of the content reaches y = 110.
        // crawlOffset at that moment = -(contentHeight - 110)
        let endOffset     = -(contentHeight - 110)
        let totalDistance = startOffset - endOffset            // screenH + contentHeight - 110
        let scrollDuration = Double(totalDistance) / Double(crawlSpeed)

        // Wait for the fade-in to finish before the crawl begins.
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeInDuration) {
            withAnimation(.linear(duration: scrollDuration)) {
                crawlOffset = endOffset
            }

            // The tablet reveal is tied directly to when the last text visually clears —
            // i.e. exactly when the scroll animation ends — no extra overshoot wait.
            DispatchQueue.main.asyncAfter(deadline: .now() + scrollDuration) {
                phase = .tabletReveal
                withAnimation(.easeIn(duration: 0.3)) { tabletOpacity = 1 }

                // Hold the tablet for 3.5 s then fade to black → title
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    endIntro()
                }
            }
        }
    }

    private func endIntro() {
        fadeOutAudio(duration: 2.0)
        withAnimation(.easeIn(duration: 0.4)) { skipOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 2.0)) { blackOpacity = 1.0 }
        }
        // Once fully black, transition to title screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            gameState.finishIntro()
        }
    }

    // MARK: Audio

    private func playAudio() {
        guard let url = Bundle.main.url(forResource: "egypt_sound", withExtension: "mp3") else {
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.0
            audioPlayer?.play()
            fadeAudioIn()
        } catch { }
    }

    private func fadeAudioIn(targetVolume: Float = 0.70, steps: Int = 20) {
        let stepTime = 2.0 / Double(steps)
        let stepVolume = targetVolume / Float(steps)
        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepTime * Double(i)) {
                audioPlayer?.volume = stepVolume * Float(i + 1)
            }
        }
    }

    private func fadeOutAudio(duration: Double = 1.5) {
        guard let player = audioPlayer else { return }
        let steps = 20
        let stepTime = duration / Double(steps)
        let startVolume = player.volume
        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepTime * Double(i)) {
                audioPlayer?.volume = startVolume * (1.0 - Float(i + 1) / Float(steps))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            audioPlayer?.stop()
            audioPlayer = nil
        }
    }
}
