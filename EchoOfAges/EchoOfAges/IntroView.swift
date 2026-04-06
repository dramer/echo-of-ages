// IntroView.swift
// EchoOfAges
//
// Two-phase opening sequence:
//   Phase 1 — Discovery reveal: map image fades in on a dark background,
//              held for a few seconds so the player can study it.
//   Phase 2 — Star Wars crawl: map fades out, gold text scrolls slowly upward.
//
// egypt_sound.mp3 plays throughout and fades out when the intro ends.

import SwiftUI
import AVFoundation

// MARK: - Intro phases

private enum IntroPhase {
    case mapReveal    // map is showing
    case crawl        // text scrolling
    case tabletReveal // tree_tablet image shown before fade to black
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
    @State private var crawlOffset:     CGFloat = 0
    @State private var contentHeight:   CGFloat = 0
    @State private var crawlStarted:    Bool    = false

    // Tablet reveal layer
    @State private var tabletOpacity:   Double = 0
    @State private var tabletScale:     Double = 0.88

    // Fade-to-black overlay (used for final transition)
    @State private var blackOpacity:    Double = 0

    // UI chrome
    @State private var skipOpacity:     Double = 0

    // Audio
    @State private var audioPlayer: AVAudioPlayer?

    private let crawlSpeed: CGFloat = 46   // points per second

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

            // ── Phase 2: Text crawl ───────────────────────────────────────────
            if phase == .crawl {
                crawlLayer
            }

            // ── Phase 3: Tablet reveal ────────────────────────────────────────
            if phase == .tabletReveal {
                tabletRevealLayer
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
                    Button(action: {
                        if phase == .tabletReveal {
                            endIntro()
                        } else {
                            showTablet()
                        }
                    }) {
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

            // Map image — large, centred
            Image("map")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 480)
                .shadow(color: Color.goldDark.opacity(0.5), radius: 28, x: 0, y: 10)
                .opacity(mapOpacity)

            // Location label
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

    // MARK: Tablet reveal layer

    private var tabletRevealLayer: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("tree_tablet")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 460)
                .shadow(color: Color.goldBright.opacity(0.35), radius: 40, x: 0, y: 0)
                .opacity(tabletOpacity)
                .scaleEffect(tabletScale)

            Text("THE TABLET OF MANDU")
                .font(EgyptFont.titleBold(20))
                .foregroundStyle(Color.goldBright)
                .tracking(5)
                .opacity(tabletOpacity)

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

    // MARK: Crawl text content

    private var crawlContent: some View {
        VStack(spacing: 0) {

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

            crawlParagraph("Summer, 2024.\n\nA research vessel mapping the\nMid-Atlantic Ridge makes an\nextraordinary discovery.")

            crawlParagraph("On a remote volcanic island —\nuncharted, unnamed, and unreachable\nby ordinary means —\nburied beneath centuries of\nash and ocean-stone...")

            crawlEmphasis("...a tablet.")

            crawlParagraph("Carved from a single slab of\nblack obsidian, it bears thirty\nsymbols drawn from six of\nhumanity's oldest civilizations.")

            crawlEmphasis("Egyptian.  Norse.  Sumerian.")
            crawlEmphasis("Mayan.  Celtic.  Chinese.")

            crawlParagraph("No single culture could have\ncreated it alone.")

            separatorGlyphs

            crawlParagraph("Lead archaeologist Dr. Elena Mandu —\nfor whom the tablet is now named —\nrecognized fragments of each\nancient script immediately.\n\nBut the tablet was incomplete.")

            crawlParagraph("The symbols are arranged in a\nsacred pattern. A puzzle.\nWithout the key, the full\nmessage cannot be read.")

            crawlEmphasis("But the key still exists.")

            crawlParagraph("Across six ancient sites, five\npartial tablets survive from\neach civilization.\n\nTogether, they hold the answer.")

            separatorGlyphs

            crawlEmphasis("Your mission:")

            crawlParagraph("Decipher the partial tablets,\none civilization at a time.\n\nEgypt first. Then Norse and\nSumerian. Then Maya and Celtic.\nFinally — Chinese.")

            crawlParagraph("Each civilization you master\nunlocks the next.\n\nEach script you learn lets you\nplace one more row of symbols\nupon the Tablet of Mandu.")

            crawlParagraph("But the stone does not hold\nwhat you place upon it.\n\nNot yet.\n\nThe symbols fall away — every\ntime — until all six civilizations\nhave been fully deciphered.")

            crawlParagraph("When the last inscription yields\nits secret, return to the stone.\n\nPlace what you have learned.\n\nAll thirty symbols. All six rows.")

            crawlParagraph("The ancients placed these symbols\nhere for a reason.\n\nThey were waiting for someone\nwith the patience to listen.")

            crawlEmphasis("Begin with the Egyptian Chamber.")

            crawlEmphasis("The tablets await.")

            Text("𓅱  𓆑  𓏏  𓈖  𓊪")
                .font(.system(size: 22))
                .foregroundStyle(Color.goldMid.opacity(0.4))
                .tracking(10)
                .padding(.top, 80)
                .padding(.bottom, 130)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 44)
        .frame(maxWidth: 580)
        .frame(maxWidth: .infinity)
    }

    private func crawlParagraph(_ text: String) -> some View {
        Text(text)
            .font(EgyptFont.body(22))
            .foregroundStyle(Color(red: 0.88, green: 0.82, blue: 0.60))
            .lineSpacing(9)
            .padding(.bottom, 38)
    }

    private func crawlEmphasis(_ text: String) -> some View {
        Text(text)
            .font(EgyptFont.titleBold(24))
            .foregroundStyle(Color.goldBright)
            .tracking(2)
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
                phase = .crawl
                withAnimation(.easeIn(duration: 0.8)) { crawlOpacity = 1 }
            }
        }
    }

    private func beginCrawl() {
        guard !crawlStarted else { return }
        crawlStarted = true

        let screenH = UIScreen.main.bounds.height
        crawlOffset = screenH   // start below screen (no animation)

        let totalDistance = screenH + contentHeight
        let duration = Double(totalDistance) / Double(crawlSpeed)

        DispatchQueue.main.async {
            withAnimation(.linear(duration: duration)) {
                self.crawlOffset = -(self.contentHeight + 100)
            }
        }

        // When crawl finishes, show the tablet before ending
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            showTablet()
        }
    }

    private func showTablet() {
        // Fade out crawl, switch to tablet phase
        withAnimation(.easeOut(duration: 1.0)) { crawlOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            phase = .tabletReveal
            // Tablet rises in with a gentle scale + fade
            withAnimation(.easeOut(duration: 1.6)) {
                tabletOpacity = 1.0
                tabletScale   = 1.0
            }
        }
        // Hold on tablet for ~4 seconds then fade everything to black
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) {
            endIntro()
        }
    }

    private func endIntro() {
        fadeOutAudio(duration: 2.0)
        // Fade skip button and then bring in the black overlay
        withAnimation(.easeIn(duration: 0.4)) { skipOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 2.0)) { blackOpacity = 1.0 }
        }
        // Once fully black, transition to title
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
            audioPlayer?.numberOfLoops = -1   // loop until intro ends
            audioPlayer?.volume = 0.0
            audioPlayer?.play()
            // Fade in over 2 seconds
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
