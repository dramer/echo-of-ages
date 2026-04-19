// IntroView.swift
// EchoOfAges
//
// Three-phase opening sequence:
//   Phase 1 — Map reveal:    discovery site image fades in and holds.
//   Phase 2 — Tablet reveal: Mandu tablet image fades in and holds.
//   Phase 3 — Text crawl:    story text scrolls bottom→top; intro ends
//                             the moment the last line exits the screen.

import SwiftUI
import AVFoundation

// MARK: - Intro phases

private enum IntroPhase {
    case mapReveal
    case tabletReveal
    case crawl
}

// MARK: - Sentinel preference key
// Tracks the global Y of the 1-pt sentinel at the END of the crawl text.
// When it drops ≤ 110 (behind the top fade mask) all text has cleared.

private struct TextEndYKey: PreferenceKey {
    static var defaultValue: CGFloat = CGFloat.greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

// MARK: - IntroView

struct IntroView: View {
    @EnvironmentObject var gameState: GameState

    @State private var phase: IntroPhase = .mapReveal

    // Map layer
    @State private var mapOpacity:      Double = 0
    @State private var mapLabelOpacity: Double = 0

    // Tablet layer
    @State private var tabletOpacity:   Double = 0

    // Crawl layer
    @State private var crawlOpacity:    Double = 0
    @State private var crawlOffset:     CGFloat = 0
    @State private var crawlStarted:    Bool   = false

    // Fade-to-black
    @State private var blackOpacity:    Double = 0

    // Skip button
    @State private var skipOpacity:     Double = 0

    // Audio
    @State private var audioPlayer: AVAudioPlayer?

    private let crawlSpeed: CGFloat = 45   // pts / second
    private var screenH: CGFloat { UIScreen.main.bounds.height }

    // MARK: Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [Color(red: 0.12, green: 0.07, blue: 0.02).opacity(0.85), Color.black],
                center: .center, startRadius: 80, endRadius: 500
            )
            .ignoresSafeArea()

            // Phase 1 — Map
            if phase == .mapReveal {
                mapLayer
            }

            // Phase 2 — Tablet
            if phase == .tabletReveal {
                tabletLayer
            }

            // Phase 3 — Crawl
            if phase == .crawl {
                crawlLayer
            }

            // Fade-to-black overlay
            Color.black
                .ignoresSafeArea()
                .opacity(blackOpacity)
                .allowsHitTesting(false)

            // Top + bottom fade masks
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

            // Skip button
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

    // MARK: - Phase 1: Map

    private var mapLayer: some View {
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

    // MARK: - Phase 2: Tablet

    private var tabletLayer: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("· · · · ·")
                .font(EgyptFont.title(16))
                .foregroundStyle(Color.goldDark.opacity(0.5))
                .tracking(8)
            Image("tree_tablet")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320)
                .shadow(color: Color.goldBright.opacity(0.45), radius: 40, x: 0, y: 0)
            Text("THE TABLET OF MANDU")
                .font(EgyptFont.titleBold(20))
                .foregroundStyle(Color.goldBright)
                .tracking(5)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .opacity(tabletOpacity)
    }

    // MARK: - Phase 3: Crawl

    private var crawlLayer: some View {
        crawlContent
            .offset(y: crawlOffset)
            .opacity(crawlOpacity)
            // Sentinel fires each animation frame — end intro when text clears
            .onPreferenceChange(TextEndYKey.self) { y in
                guard phase == .crawl, !crawlStarted == false, y <= 110 else { return }
                // All text has cleared the top fade mask
                endIntro()
            }
    }

    private var crawlContent: some View {
        let name = gameState.playerName.trimmingCharacters(in: .whitespaces)
        let greeting = name.isEmpty ? "Archaeologist" : name

        return VStack(spacing: 0) {

            Text("𓊹  ·  𓂀  ·  𓊹")
                .font(.system(size: 26))
                .foregroundStyle(Color.goldMid.opacity(0.55))
                .tracking(8)
                .padding(.bottom, 44)

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
                .padding(.bottom, 40)

            // Sentinel: 1 pt tall, reports its global Y each frame so we know
            // the instant the last line of text clears the top fade mask.
            Color.clear
                .frame(height: 1)
                .background(
                    GeometryReader { g in
                        Color.clear.preference(
                            key: TextEndYKey.self,
                            value: g.frame(in: .global).maxY
                        )
                    }
                )
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .frame(maxWidth: 640)
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

    // MARK: - Sequencing

    private func startIntro() {
        playAudio()

        // Skip button appears after a beat
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 1.0)) { skipOpacity = 1 }
        }

        // ── Phase 1: Map ──────────────────────────────────────────────────────
        withAnimation(.easeIn(duration: 1.8)) { mapOpacity = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 1.2)) { mapLabelOpacity = 1 }
        }

        // Hold map for 5 s then fade out → Phase 2
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation(.easeOut(duration: 1.2)) { mapOpacity = 0; mapLabelOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showTabletPhase()
            }
        }
    }

    // ── Phase 2: Tablet ───────────────────────────────────────────────────────
    private func showTabletPhase() {
        phase = .tabletReveal
        withAnimation(.easeIn(duration: 1.5)) { tabletOpacity = 1 }

        // Hold tablet for 4 s then fade out → Phase 3
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 1.0)) { tabletOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                startCrawlPhase()
            }
        }
    }

    // ── Phase 3: Crawl ────────────────────────────────────────────────────────
    private func startCrawlPhase() {
        // Position content just off the bottom before making it visible
        withAnimation(.none) { crawlOffset = screenH }
        phase = .crawl

        // Fade in the crawl text
        withAnimation(.easeIn(duration: 0.8)) { crawlOpacity = 1 }

        // Wait for fade-in, then begin scrolling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            crawlStarted = true
            // Scroll far enough that even a very tall content block clears fully.
            // The sentinel preference key ends the intro the moment the last line
            // passes through the top fade mask — this distance is just a ceiling.
            let distance   = screenH * 2 + 4000   // generous upper bound
            let duration   = Double(distance) / Double(crawlSpeed)
            withAnimation(.linear(duration: duration)) {
                crawlOffset = -4000
            }
        }
    }

    // ── End ───────────────────────────────────────────────────────────────────
    private func endIntro() {
        // Guard against double-fire from the sentinel
        guard blackOpacity == 0 else { return }
        fadeOutAudio(duration: 2.0)
        withAnimation(.easeIn(duration: 0.4)) { skipOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 2.0)) { blackOpacity = 1.0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            gameState.finishIntro()
        }
    }

    // MARK: - Audio

    private func playAudio() {
        guard let url = Bundle.main.url(forResource: "egypt_sound", withExtension: "mp3") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.0
            audioPlayer?.play()
            fadeAudioIn()
        } catch { }
    }

    private func fadeAudioIn(targetVolume: Float = 0.70, steps: Int = 20) {
        let stepTime    = 2.0 / Double(steps)
        let stepVolume  = targetVolume / Float(steps)
        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepTime * Double(i)) {
                audioPlayer?.volume = stepVolume * Float(i + 1)
            }
        }
    }

    private func fadeOutAudio(duration: Double = 1.5) {
        guard let player = audioPlayer else { return }
        let steps       = 20
        let stepTime    = duration / Double(steps)
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
