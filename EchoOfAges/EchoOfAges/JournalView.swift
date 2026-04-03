// JournalView.swift
// EchoOfAges
//
// The Field Diary — the archaeologist's growing reference book.
// Four tabs: Tablet | Codex | Chronicle | Method

import SwiftUI

// MARK: - Diary Tab

private enum DiaryTab: String, CaseIterable {
    case tablet    = "Tablet"
    case codex     = "Codex"
    case chronicle = "Chronicle"
    case method    = "Mechanics"
}

// MARK: - Journal View (Field Diary)

struct JournalView: View {
    @EnvironmentObject var gameState: GameState
    @State private var selectedTab: DiaryTab = .tablet
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
                Divider().background(Color.goldDark.opacity(0.4))

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .tablet:    tabletContent
                        case .codex:     codexContent
                        case .chronicle: chronicleContent
                        case .method:    methodContent
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
        HStack {
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
                        .overlay(RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.stoneLight.opacity(0.4), lineWidth: 0.7))
                )
            }

            Spacer()

            VStack(spacing: 2) {
                Image("diary")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                Text("FIELD DIARY")
                    .font(EgyptFont.title(13))
                    .foregroundStyle(Color.goldBright)
                    .tracking(3)
            }

            Spacer()
            Color.clear.frame(width: 80, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Tab Picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(DiaryTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                        HapticFeedback.tap()
                    }) {
                        VStack(spacing: 6) {
                            Text(tab.rawValue.uppercased())
                                .font(EgyptFont.title(12))
                                .foregroundStyle(selectedTab == tab ? Color.goldBright : Color.stoneSurface)
                                .tracking(2)
                                .fixedSize()
                            Rectangle()
                                .fill(selectedTab == tab ? Color.goldBright : Color.clear)
                                .frame(height: 2)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
        .background(Color.stoneMid.opacity(0.3))
    }

    // ═══════════════════════════════════════════════════
    // MARK: - TABLET TAB
    // ═══════════════════════════════════════════════════

    private var tabletContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            tabletIntro
            discoveryMap
            tabletGrid
            civilizationLegend
            tabletDecodedMessage
        }
    }

    private var discoveryMap: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DISCOVERY SITE")
                .font(EgyptFont.title(11))
                .foregroundStyle(Color.stoneLight.opacity(0.6))
                .tracking(3)

            Image("map")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.goldDark.opacity(0.5), lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)

            Text("The island bearing the Tablet of Mandu lies at the convergence of ancient maritime routes — equidistant between South America and Africa. It appears on no modern navigational chart. The expedition team has withheld its exact coordinates pending further excavation.")
                .font(EgyptFont.bodyItalic(13))
                .foregroundStyle(Color.papyrus.opacity(0.6))
                .lineSpacing(4)
        }
    }

    private var tabletIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THE TABLET OF MANDU")
                .font(EgyptFont.title(11))
                .foregroundStyle(Color.stoneLight.opacity(0.6))
                .tracking(3)
            Text("Discovered in 2024 on an uncharted island in the mid-Atlantic — equidistant between South America, Africa, and Europe. The island appears on no modern chart and no ancient map.")
                .font(EgyptFont.bodyItalic(14))
                .foregroundStyle(Color.papyrus.opacity(0.7))
                .lineSpacing(4)
            Text("The tablet bears 30 symbols from six ancient civilizations that had no known contact with one another. It should not exist.")
                .font(EgyptFont.bodyItalic(14))
                .foregroundStyle(Color.papyrus.opacity(0.55))
                .lineSpacing(4)
            Text("Scattered around it: six partial tablets, each in a single script. Decipher them to read the main tablet.")
                .font(EgyptFont.body(13))
                .foregroundStyle(Color.goldMid.opacity(0.7))
                .lineSpacing(3)
                .padding(.top, 2)
        }
    }

    private var tabletGrid: some View {
        let slots = TabletSlot.all
        let decoded = gameState.decodedTabletSlots
        let civs = Civilization.all

        return VStack(spacing: 3) {
            ForEach(civs) { civ in
                let row = slots.filter { $0.civilization == civ.id }
                let isCivDone = decoded.contains(row.first?.id ?? -1)

                HStack(spacing: 3) {
                    // Civilization marker
                    Text(civ.emblem)
                        .font(.system(size: 16))
                        .foregroundStyle(isCivDone ? civ.accentColor : Color.stoneLight.opacity(0.2))
                        .frame(width: 26)

                    ForEach(row) { slot in
                        let isDecoded = decoded.contains(slot.id)
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isDecoded
                                      ? civ.accentColor.opacity(0.18)
                                      : Color.stoneDark.opacity(0.7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isDecoded ? civ.accentColor.opacity(0.7) : Color.stoneLight.opacity(0.15),
                                                lineWidth: isDecoded ? 1 : 0.5)
                                )
                            if isDecoded {
                                VStack(spacing: 1) {
                                    Text(slot.character)
                                        .font(.system(size: 18))
                                        .foregroundStyle(civ.accentColor)
                                    Text(slot.decoded)
                                        .font(EgyptFont.body(8))
                                        .foregroundStyle(Color.papyrus.opacity(0.7))
                                        .lineLimit(1)
                                }
                            } else {
                                Text("?")
                                    .font(EgyptFont.titleBold(16))
                                    .foregroundStyle(Color.stoneLight.opacity(0.2))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.stoneMid.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.goldDark.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private var civilizationLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CIVILIZATIONS")
                .font(EgyptFont.title(10))
                .foregroundStyle(Color.stoneLight.opacity(0.5))
                .tracking(3)

            ForEach(Civilization.all) { civ in
                let isDone = gameState.completedCivilizations.contains(civ.id)
                HStack(spacing: 10) {
                    Circle()
                        .fill(isDone ? civ.accentColor : Color.stoneLight.opacity(0.2))
                        .frame(width: 8, height: 8)
                    Text(civ.emblem)
                        .font(.system(size: 14))
                        .foregroundStyle(isDone ? civ.accentColor : Color.stoneLight.opacity(0.3))
                    Text(civ.name)
                        .font(EgyptFont.body(13))
                        .foregroundStyle(isDone ? Color.papyrus : Color.stoneLight.opacity(0.4))
                    Spacer()
                    if isDone {
                        Text("Deciphered")
                            .font(EgyptFont.bodyItalic(12))
                            .foregroundStyle(civ.accentColor.opacity(0.8))
                    } else if civ.isUnlocked {
                        Text("In progress")
                            .font(EgyptFont.bodyItalic(12))
                            .foregroundStyle(Color.goldDark.opacity(0.6))
                    } else {
                        Text("Locked")
                            .font(EgyptFont.bodyItalic(12))
                            .foregroundStyle(Color.stoneLight.opacity(0.3))
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.stoneDark.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.stoneLight.opacity(0.15), lineWidth: 0.5))
        )
    }

    @ViewBuilder
    private var tabletDecodedMessage: some View {
        let decodedCount = gameState.decodedTabletSlots.count
        let total = TabletSlot.all.count

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DECODED MESSAGE")
                    .font(EgyptFont.title(10))
                    .foregroundStyle(Color.stoneLight.opacity(0.5))
                    .tracking(3)
                Spacer()
                Text("\(decodedCount) / \(total) symbols")
                    .font(EgyptFont.body(12))
                    .foregroundStyle(Color.stoneSurface)
            }

            if decodedCount == 0 {
                Text("No symbols decoded yet. Decipher the Egyptian partial tablets to reveal the first line.")
                    .font(EgyptFont.bodyItalic(15))
                    .foregroundStyle(Color.stoneLight.opacity(0.4))
                    .lineSpacing(4)
            } else {
                // Show each civilization's decoded line
                ForEach(Civilization.all) { civ in
                    if gameState.completedCivilizations.contains(civ.id) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text(civ.emblem)
                                    .font(.system(size: 13))
                                    .foregroundStyle(civ.accentColor)
                                Text(civ.name.uppercased())
                                    .font(EgyptFont.title(10))
                                    .foregroundStyle(civ.accentColor.opacity(0.8))
                                    .tracking(2)
                            }
                            Text(civ.tabletLine)
                                .font(EgyptFont.bodyItalic(15))
                                .foregroundStyle(Color.papyrus)
                                .lineSpacing(4)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(civ.accentColor.opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(civ.accentColor.opacity(0.3), lineWidth: 0.7))
                        )
                    }
                }

                if gameState.isTabletFullyDecoded {
                    VStack(spacing: 10) {
                        ornamentalRule
                        Text("THE COMPLETE MESSAGE")
                            .font(EgyptFont.title(11))
                            .foregroundStyle(Color.goldBright)
                            .tracking(3)
                        Text(TabletSlot.fullMessage)
                            .font(EgyptFont.bodyItalic(17))
                            .foregroundStyle(Color.papyrus)
                            .lineSpacing(7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ornamentalRule
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.22, green: 0.16, blue: 0.06).opacity(0.8))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.goldBright.opacity(0.5), lineWidth: 1.2))
                    )
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════
    // MARK: - CODEX TAB
    // ═══════════════════════════════════════════════════

    private var codexContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("THE CODEX", subtitle: "Symbols encountered and recorded during this expedition.")

            ForEach(gameState.codexGlyphs) { glyph in
                codexCard(glyph, isKnown: true)
            }

            let undiscovered = Glyph.allCases.filter { !gameState.discoveredGlyphs.contains($0) }
            if !undiscovered.isEmpty {
                sectionHeader("UNKNOWN SYMBOLS", subtitle: nil)
                ForEach(undiscovered) { glyph in
                    codexCard(glyph, isKnown: false)
                }
            }

            if gameState.discoveredGlyphs.isEmpty {
                emptyCodexPrompt
            }

            greekAlphabetSection
        }
    }

    @ViewBuilder
    private func codexCard(_ glyph: Glyph, isKnown: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isKnown
                          ? LinearGradient(colors: [Color.stoneMid, Color(red: 0.18, green: 0.13, blue: 0.08)],
                                           startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [Color.stoneDark, Color.stoneDark],
                                           startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(isKnown ? Color.goldDark.opacity(0.6) : Color.stoneLight.opacity(0.2), lineWidth: 1))
                Text(isKnown ? glyph.rawValue : "𓎟")
                    .font(.system(size: 32))
                    .foregroundStyle(isKnown ? Color.goldBright : Color.stoneLight.opacity(0.3))
            }
            .frame(width: 58, height: 58)

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
                    Text("Decipher the partial tablet to identify this glyph.")
                        .font(EgyptFont.body(13))
                        .foregroundStyle(Color.stoneLight.opacity(0.35))
                        .lineSpacing(3)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isKnown ? Color.stoneMid.opacity(0.35) : Color.stoneDark.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(isKnown ? Color.goldDark.opacity(0.3) : Color.stoneLight.opacity(0.1), lineWidth: 0.7))
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    private var emptyCodexPrompt: some View {
        VStack(spacing: 12) {
            Text("𓎟").font(.system(size: 44)).foregroundStyle(Color.stoneLight.opacity(0.3))
            Text("No symbols recorded yet.\nDecipher the first partial tablet to begin your codex.")
                .font(EgyptFont.bodyItalic(15))
                .foregroundStyle(Color.stoneLight.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var greekAlphabetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("GREEK ALPHABET REFERENCE", subtitle: nil)
                Text("The Rosetta Stone was decoded because scholars already knew Greek. This reference serves the same purpose — a known script to cross-reference against the Tablet of Mandu.")
                    .font(EgyptFont.bodyItalic(13))
                    .foregroundStyle(Color.papyrus.opacity(0.55))
                    .lineSpacing(3)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(GreekLetter.alphabet) { letter in
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Text(letter.upper)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.goldMid)
                            Text(letter.lower)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.goldDark.opacity(0.8))
                        }
                        Text(letter.name)
                            .font(EgyptFont.body(9))
                            .foregroundStyle(Color.papyrus.opacity(0.6))
                        Text("/" + letter.sound + "/")
                            .font(EgyptFont.bodyItalic(9))
                            .foregroundStyle(Color.stoneLight.opacity(0.5))
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.stoneMid.opacity(0.3))
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.goldDark.opacity(0.2), lineWidth: 0.5))
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.stoneDark.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.stoneLight.opacity(0.2), lineWidth: 0.7))
        )
    }

    // ═══════════════════════════════════════════════════
    // MARK: - CHRONICLE TAB
    // ═══════════════════════════════════════════════════

    private var chronicleContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("THE CHRONICLE", subtitle: "Each partial tablet deciphered adds a fragment to the Tree of Life message. Together, they mirror the message on the Tablet of Mandu.")
            treeOfLifePanel

            HStack {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, .goldDark.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.8)
                Text("𓊹").font(.system(size: 12)).foregroundStyle(Color.goldDark.opacity(0.5)).padding(.horizontal, 8)
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, .goldDark.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.8)
            }

            ForEach(Array(gameState.chronicleMessages.enumerated()), id: \.offset) { _, entry in
                chronicleEntry(level: entry.level, message: entry.message)
            }
        }
    }

    private var treeOfLifePanel: some View {
        let decoded = gameState.chronicleMessages.compactMap(\.message)
        let remaining = Level.allLevels.count - decoded.count
        let combined = decoded.joined(separator: "\n\n")

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("𓇋").font(.system(size: 22)).foregroundStyle(Color.goldBright)
                VStack(alignment: .leading, spacing: 2) {
                    Text("THE TREE OF LIFE").font(EgyptFont.titleBold(13)).foregroundStyle(Color.goldBright).tracking(2)
                    Text(decoded.isEmpty ? "Message not yet begun"
                         : remaining == 0 ? "Complete — all fragments deciphered"
                         : "\(decoded.count) of \(Level.allLevels.count) fragments deciphered")
                        .font(EgyptFont.bodyItalic(12))
                        .foregroundStyle(decoded.isEmpty ? Color.stoneLight.opacity(0.5) : Color.goldMid.opacity(0.8))
                }
                Spacer()
            }

            if decoded.isEmpty {
                Text("Decipher the first partial tablet to reveal the opening of the ancient message.")
                    .font(EgyptFont.bodyItalic(15))
                    .foregroundStyle(Color.stoneLight.opacity(0.45))
                    .lineSpacing(4)
            } else {
                Text(combined)
                    .font(EgyptFont.bodyItalic(16))
                    .foregroundStyle(Color.papyrus)
                    .lineSpacing(7)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    ForEach(0..<Level.allLevels.count, id: \.self) { i in
                        Circle()
                            .fill(i < decoded.count ? Color.goldBright : Color.stoneLight.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                    if remaining > 0 {
                        Text("· \(remaining) fragment\(remaining == 1 ? "" : "s") remaining")
                            .font(EgyptFont.body(12))
                            .foregroundStyle(Color.stoneLight.opacity(0.5))
                    } else {
                        Text("𓊹 Complete").font(EgyptFont.bodyItalic(12)).foregroundStyle(Color.goldDark.opacity(0.8))
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(decoded.isEmpty
                      ? AnyShapeStyle(Color.stoneDark.opacity(0.5))
                      : AnyShapeStyle(LinearGradient(
                            colors: [Color(red: 0.22, green: 0.16, blue: 0.07), Color.stoneMid.opacity(0.6)],
                            startPoint: .top, endPoint: .bottom)))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(decoded.isEmpty ? Color.stoneLight.opacity(0.15) : Color.goldDark.opacity(0.6), lineWidth: decoded.isEmpty ? 0.5 : 1.2))
        )
        .shadow(color: decoded.isEmpty ? .clear : Color.goldDark.opacity(0.2), radius: 8)
    }

    @ViewBuilder
    private func chronicleEntry(level: Level, message: String?) -> some View {
        let isDeciphered = message != nil
        let isExpanded = expandedEntryId == level.id

        VStack(spacing: 0) {
            Button(action: {
                guard isDeciphered else { return }
                withAnimation(.easeInOut(duration: 0.28)) {
                    expandedEntryId = isExpanded ? nil : level.id
                }
                HapticFeedback.tap()
            }) {
                HStack(spacing: 14) {
                    Text(isDeciphered ? level.journalEntry.artifact : "𓎟")
                        .font(.system(size: 28))
                        .foregroundStyle(isDeciphered ? Color.goldBright : Color.stoneLight.opacity(0.3))
                        .frame(width: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isDeciphered ? level.journalEntry.title : "Undeciphered Partial Tablet")
                            .font(EgyptFont.titleBold(15))
                            .foregroundStyle(isDeciphered ? Color.goldBright : Color.stoneLight.opacity(0.5))
                        Text(isDeciphered ? "\(level.title)  ·  Partial Tablet \(level.romanNumeral)"
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
                .padding(.vertical, 14).padding(.horizontal, 16)
            }

            if isDeciphered && isExpanded, let msg = message {
                Divider().background(Color.goldDark.opacity(0.3)).padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Decoded Inscription", systemImage: "scroll")
                            .font(EgyptFont.title(12)).foregroundStyle(Color.goldDark).tracking(1)
                        Text(msg)
                            .font(EgyptFont.bodyItalic(16)).foregroundStyle(Color.papyrus).lineSpacing(5)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.stoneDark.opacity(0.6))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.goldDark.opacity(0.3), lineWidth: 0.7)))

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Field Notes", systemImage: "pencil")
                            .font(EgyptFont.title(12)).foregroundStyle(Color.stoneLight.opacity(0.7)).tracking(1)
                        Text(level.journalEntry.body)
                            .font(EgyptFont.body(14)).foregroundStyle(Color.papyrus.opacity(0.75)).lineSpacing(4)
                    }
                }
                .padding(.vertical, 14).padding(.horizontal, 16)
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
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(isDeciphered ? Color.goldDark.opacity(0.5) : Color.stoneLight.opacity(0.15), lineWidth: isDeciphered ? 1 : 0.5))
        )
        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 3)
    }

    // ═══════════════════════════════════════════════════
    // MARK: - METHOD TAB
    // ═══════════════════════════════════════════════════

    private var methodContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("THE ARCHAEOLOGIST'S MECHANICS", subtitle: "How ancient scripts were deciphered — and how to decipher the partial tablets.")

            methodCard(
                icon: "𓇳",
                title: "The Rosetta Stone, 1799",
                body: "French soldiers in Egypt discovered a black granite slab bearing the same royal decree in three scripts: formal hieroglyphs at the top, everyday Egyptian script (Demotic) in the middle, and Ancient Greek at the bottom.\n\nScholars already knew Greek. That was the key. By matching Greek words to their hieroglyph equivalents, they found the door."
            )

            methodCard(
                icon: "Φ",
                title: "Champollion's Breakthrough, 1822",
                body: "Jean-François Champollion spent years cross-referencing the Rosetta Stone. His three-step method:\n\n1. Find anchor points — symbols you already know.\n2. Find cartouches — oval frames around royal names. Names are spelled phonetically, so you learn sounds from them.\n3. Use determinatives — context symbols at the end of words that tell you the category of meaning (person, water, land).\n\nEach certain symbol revealed two more. The cipher cascaded open."
            )

            methodCard(
                icon: "𓊹",
                title: "How to Decipher the Partial Tablets",
                body: "The partial tablets work the same way.\n\nFixed stones (the darker cells) are your anchor points — the known symbols. Begin there. Each position you fill with certainty constrains the remaining cells.\n\nThe rule each inscription follows: no symbol appears twice in any row or column. This was the Egyptian grammatical law — each sacred concept appears exactly once in each line of thought.\n\nWhen you're stuck, use Field Notes for positional clues. Use Known Glyphs in the diary to reference symbols you've already learned. Each partial tablet teaches you symbols that unlock the next."
            )

            methodCard(
                icon: "𓎟",
                title: "The Tablet of Mandu — What We Don't Know",
                body: "The six partial tablets surrounding the main tablet appear to be teaching tools — as if someone wanted any explorer who found them to have everything needed to decode the central inscription.\n\nWho carved them? No civilization has a record of the island. No expedition reached all six cultures. The carbon dating places the tablet before any of the civilizations whose scripts appear on it.\n\nScholars call it the Tablet of Mandu. No one knows what Mandu means. No one has found the language it comes from.\n\nNot yet."
            )
        }
    }

    private func methodCard(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(icon)
                    .font(.system(size: 22))
                    .foregroundStyle(Color.goldMid)
                    .frame(width: 32)
                Text(title)
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(Color.goldBright)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(body)
                .font(EgyptFont.body(14))
                .foregroundStyle(Color.papyrus.opacity(0.8))
                .lineSpacing(5)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.stoneMid.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.goldDark.opacity(0.3), lineWidth: 0.8))
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    // ═══════════════════════════════════════════════════
    // MARK: - Shared Components
    // ═══════════════════════════════════════════════════

    private func sectionHeader(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(EgyptFont.title(11))
                .foregroundStyle(Color.stoneLight.opacity(0.6))
                .tracking(3)
            if let sub = subtitle {
                Text(sub)
                    .font(EgyptFont.bodyItalic(14))
                    .foregroundStyle(Color.papyrus.opacity(0.6))
                    .lineSpacing(3)
            }
        }
        .padding(.bottom, 2)
    }

    private var ornamentalRule: some View {
        HStack {
            Rectangle()
                .fill(LinearGradient(colors: [.clear, .goldDark, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 0.8)
            Text("𓊹").font(.system(size: 14)).foregroundStyle(Color.goldDark).padding(.horizontal, 8)
            Rectangle()
                .fill(LinearGradient(colors: [.clear, .goldDark, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 0.8)
        }
    }
}

#Preview {
    JournalView()
        .environmentObject({
            let gs = GameState()
            gs.unlockedJournalEntries = [1, 2, 3, 4, 5]
            gs.discoveredGlyphs = [.eye, .owl, .water, .lion, .sky]
            gs.decodedMessages = Level.allLevels.reduce(into: [:]) { $0[$1.id] = $1.decodedMessage }
            return gs
        }())
}
