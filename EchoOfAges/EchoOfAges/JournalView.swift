// JournalView.swift
// EchoOfAges
//
// The Field Diary — the archaeologist's growing reference book.
// Two tabs: Codex (known glyph meanings) and Chronicle (decoded inscriptions).

import SwiftUI

// MARK: - Diary Tab

private enum DiaryTab: String, CaseIterable {
    case codex     = "Codex"
    case chronicle = "Chronicle"
}

// MARK: - Journal View (Field Diary)

struct JournalView: View {
    @EnvironmentObject var gameState: GameState
    @State private var selectedTab: DiaryTab = .codex
    @State private var expandedEntryId: Int? = nil

    var body: some View {
        ZStack {
            Color.stoneDark.ignoresSafeArea()
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.4)],
                center: .center,
                startRadius: 150,
                endRadius: 450
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                tabPicker
                Divider()
                    .background(Color.goldDark.opacity(0.4))

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .codex:
                            codexContent
                        case .chronicle:
                            chronicleContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
        .onAppear {
            if let spotId = gameState.spotlightJournalId {
                expandedEntryId = spotId
                selectedTab = .chronicle
                gameState.spotlightJournalId = nil
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            Button(action: { gameState.closeJournal() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Return")
                        .font(EgyptFont.title(13))
                }
                .foregroundStyle(Color.goldMid)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.stoneMid.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.stoneLight.opacity(0.4), lineWidth: 0.7)
                        )
                )
            }

            Spacer()

            VStack(spacing: 2) {
                Text("𓏠")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.goldMid)
                Text("FIELD DIARY")
                    .font(EgyptFont.title(15))
                    .foregroundStyle(Color.goldBright)
                    .tracking(3)
            }

            Spacer()
            Color.clear.frame(width: 80, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(DiaryTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                    HapticFeedback.tap()
                }) {
                    VStack(spacing: 6) {
                        Text(tab.rawValue.uppercased())
                            .font(EgyptFont.title(13))
                            .foregroundStyle(selectedTab == tab ? Color.goldBright : Color.stoneSurface)
                            .tracking(2)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.goldBright : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Color.stoneMid.opacity(0.3))
    }

    // MARK: - Codex Tab

    private var codexContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            codexIntro

            // Known glyphs
            ForEach(gameState.codexGlyphs) { glyph in
                codexCard(glyph, isKnown: true)
            }

            // Undiscovered glyphs
            let undiscovered = Glyph.allCases.filter { !gameState.discoveredGlyphs.contains($0) }
            if !undiscovered.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("UNKNOWN SYMBOLS")
                        .font(EgyptFont.title(11))
                        .foregroundStyle(Color.stoneLight.opacity(0.6))
                        .tracking(3)
                        .padding(.top, 8)

                    ForEach(undiscovered) { glyph in
                        codexCard(glyph, isKnown: false)
                    }
                }
            }

            if gameState.discoveredGlyphs.isEmpty {
                emptyCodexPrompt
            }
        }
    }

    private var codexIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THE CODEX")
                .font(EgyptFont.title(11))
                .foregroundStyle(Color.stoneLight.opacity(0.6))
                .tracking(3)
            Text("Symbols encountered and recorded during this expedition. New glyphs are added each time an inscription is deciphered.")
                .font(EgyptFont.bodyItalic(14))
                .foregroundStyle(Color.papyrus.opacity(0.6))
                .lineSpacing(3)
        }
        .padding(.bottom, 4)
    }

    private var emptyCodexPrompt: some View {
        VStack(spacing: 12) {
            Text("𓎟")
                .font(.system(size: 44))
                .foregroundStyle(Color.stoneLight.opacity(0.3))
            Text("No symbols recorded yet.\nDecipher the first inscription to begin your codex.")
                .font(EgyptFont.bodyItalic(15))
                .foregroundStyle(Color.stoneLight.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private func codexCard(_ glyph: Glyph, isKnown: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Glyph symbol
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isKnown
                          ? LinearGradient(colors: [Color.stoneMid, Color(red: 0.18, green: 0.13, blue: 0.08)],
                                           startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [Color.stoneDark, Color.stoneDark],
                                           startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isKnown ? Color.goldDark.opacity(0.6) : Color.stoneLight.opacity(0.2), lineWidth: 1)
                    )
                Text(isKnown ? glyph.rawValue : "𓎟")
                    .font(.system(size: 32))
                    .foregroundStyle(isKnown ? Color.goldBright : Color.stoneLight.opacity(0.3))
            }
            .frame(width: 58, height: 58)

            // Description
            VStack(alignment: .leading, spacing: 4) {
                if isKnown {
                    Text(glyph.displayName.uppercased())
                        .font(EgyptFont.titleBold(14))
                        .foregroundStyle(Color.goldBright)
                        .tracking(1)
                    Text(glyph.meaning)
                        .font(EgyptFont.bodyItalic(13))
                        .foregroundStyle(Color.goldMid.opacity(0.8))
                    Spacer(minLength: 4)
                    Text(glyph.discoveryNote)
                        .font(EgyptFont.body(13))
                        .foregroundStyle(Color.papyrus.opacity(0.75))
                        .lineSpacing(3)
                } else {
                    Text("UNKNOWN SYMBOL")
                        .font(EgyptFont.titleBold(13))
                        .foregroundStyle(Color.stoneLight.opacity(0.5))
                        .tracking(1)
                    Text("Encountered in Chamber \(glyph.introducedInLevel)")
                        .font(EgyptFont.bodyItalic(13))
                        .foregroundStyle(Color.stoneLight.opacity(0.4))
                    Text("Decipher the inscription to identify this glyph.")
                        .font(EgyptFont.body(13))
                        .foregroundStyle(Color.stoneLight.opacity(0.35))
                        .lineSpacing(3)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isKnown
                      ? Color.stoneMid.opacity(0.35)
                      : Color.stoneDark.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isKnown ? Color.goldDark.opacity(0.3) : Color.stoneLight.opacity(0.1),
                                lineWidth: 0.7)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    // MARK: - Chronicle Tab

    private var chronicleContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            chronicleIntro

            ForEach(Array(gameState.chronicleMessages.enumerated()), id: \.offset) { _, entry in
                chronicleEntry(level: entry.level, message: entry.message)
            }
        }
    }

    private var chronicleIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THE CHRONICLE")
                .font(EgyptFont.title(11))
                .foregroundStyle(Color.stoneLight.opacity(0.6))
                .tracking(3)
            Text("Each inscription deciphered reveals a fragment of an ancient message. Together, they tell the story of the Tree of Life.")
                .font(EgyptFont.bodyItalic(14))
                .foregroundStyle(Color.papyrus.opacity(0.6))
                .lineSpacing(3)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func chronicleEntry(level: Level, message: String?) -> some View {
        let isDeciphered = message != nil
        let isExpanded = expandedEntryId == level.id

        VStack(spacing: 0) {
            // Entry header
            Button(action: {
                guard isDeciphered else { return }
                withAnimation(.easeInOut(duration: 0.28)) {
                    expandedEntryId = isExpanded ? nil : level.id
                }
                HapticFeedback.tap()
            }) {
                HStack(spacing: 14) {
                    // Artifact / lock icon
                    Text(isDeciphered ? level.journalEntry.artifact : "𓎟")
                        .font(.system(size: 28))
                        .foregroundStyle(isDeciphered ? Color.goldBright : Color.stoneLight.opacity(0.3))
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(isDeciphered ? level.journalEntry.title : "Undeciphered Inscription")
                            .font(EgyptFont.titleBold(15))
                            .foregroundStyle(isDeciphered ? Color.goldBright : Color.stoneLight.opacity(0.5))
                        Text(isDeciphered ? "\(level.title)  ·  Chamber \(level.romanNumeral)"
                                         : "Complete Chamber \(level.romanNumeral) to decode")
                            .font(EgyptFont.bodyItalic(13))
                            .foregroundStyle(isDeciphered ? Color.papyrus.opacity(0.7) : Color.stoneLight.opacity(0.4))
                    }

                    Spacer()

                    if isDeciphered {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.goldDark)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.stoneLight.opacity(0.3))
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }

            // Expanded decoded message + lore
            if isDeciphered && isExpanded, let msg = message {
                Divider()
                    .background(Color.goldDark.opacity(0.3))
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 14) {
                    // Decoded message — the "translation"
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Decoded Inscription", systemImage: "scroll")
                            .font(EgyptFont.title(12))
                            .foregroundStyle(Color.goldDark)
                            .tracking(1)

                        Text(msg)
                            .font(EgyptFont.bodyItalic(16))
                            .foregroundStyle(Color.papyrus)
                            .lineSpacing(5)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.stoneDark.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.goldDark.opacity(0.3), lineWidth: 0.7)
                            )
                    )

                    // Scholar's notes from the journal entry
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Field Notes", systemImage: "pencil")
                            .font(EgyptFont.title(12))
                            .foregroundStyle(Color.stoneLight.opacity(0.7))
                            .tracking(1)

                        Text(level.journalEntry.body)
                            .font(EgyptFont.body(14))
                            .foregroundStyle(Color.papyrus.opacity(0.75))
                            .lineSpacing(4)
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isDeciphered
                      ? LinearGradient(colors: [Color.stoneMid, Color(red: 0.20, green: 0.15, blue: 0.09)],
                                       startPoint: .top, endPoint: .bottom)
                      : LinearGradient(colors: [Color.stoneDark, Color.stoneDark],
                                       startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isDeciphered ? Color.goldDark.opacity(0.5) : Color.stoneLight.opacity(0.15),
                                lineWidth: isDeciphered ? 1 : 0.5)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 3)
    }
}

#Preview {
    JournalView()
        .environmentObject({
            let gs = GameState()
            gs.unlockedJournalEntries = [1, 2]
            gs.discoveredGlyphs = [.eye, .owl, .water, .lion]
            gs.decodedMessages = [
                1: Level.level1.decodedMessage,
                2: Level.level2.decodedMessage
            ]
            return gs
        }())
}
