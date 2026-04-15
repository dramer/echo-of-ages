// SumerianGameView.swift
// EchoOfAges
//
// Substitution cipher puzzle screen for the Sumerian / Cuneiform civilization.
//
// Layout (portrait):
//   • Header bar — back, title, level numeral
//   • Level title / subtitle / instruction
//   • Cipher Key panel — shows discovered AN→?, KI→? etc. as player fills in
//   • Encoded row  — fixed cuneiform symbols pressed into clay (never changes)
//   • Decoded row  — anchors pre-revealed; player taps blanks and picks a symbol
//   • Symbol palette — tap to arm, then tap a blank decoded position to place
//   • Decipher / Reset buttons
//   • Collapsible field inscriptions

import SwiftUI

// MARK: - SumerianGameView

struct SumerianGameView: View {
    @EnvironmentObject var gameState: GameState

    @State private var showComplete          = false
    @State private var messageRevealed      = false
    @State private var inscriptionsExpanded = false
    @State private var showTabletGateNote   = false
    @State private var showHelpDialog       = false
    @State private var helpTask: Task<Void, Never>? = nil

    /// Tablet is locked until the player selects a testimony scribe.
    /// Levels with no scribes (L5) have no gate — tablet is always open.
    private var scribeGateActive: Bool {
        !gameState.sumerianScribeConfirmed(for: level.id)
    }

    private var level: SumerianLevel { gameState.sumerianCurrentLevel }

    // Sumerian cuneiform direction is determined by the opening sign.
    // KI (earth) and GAL (great) descend toward the underworld — right to left.
    // AN (heaven), A (water), UD (sun) rise and flow — left to right.
    private var isRightToLeft: Bool {
        switch level.encodedSequence.first {
        case .ki, .gal: return true
        default: return false
        }
    }

    private var readingDirectionLabel: String {
        let name = level.encodedSequence.first?.displayName ?? ""
        return isRightToLeft
            ? "← \(name) opens this inscription · reads right to left"
            : "\(name) opens this inscription · reads left to right →"
    }

    // Returns indices for one display chunk, reversed when RTL so that
    // position 0 always appears at the "start" of the reading direction.
    private func chunkIndices(start: Int, end: Int) -> [Int] {
        let indices = Array(start..<end)
        return isRightToLeft ? indices.reversed() : indices
    }

    var body: some View {
        ZStack {
            clayBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        levelHeader
                        cipherKeyPanel
                        if !level.scribes.isEmpty {
                            testimonySection
                        }
                        tabletSection
                        palette
                        actionRow
                        inscriptionsSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 48)
                }
            }

            // Level complete overlay
            if showComplete {
                Color.black.opacity(0.55).ignoresSafeArea()
                    .transition(.opacity).zIndex(9)
                levelCompleteCard
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .zIndex(10)
            }

            // Help dialog overlay
            if showHelpDialog {
                Color.black.opacity(0.50).ignoresSafeArea()
                    .onTapGesture { withAnimation { showHelpDialog = false } }
                    .transition(.opacity).zIndex(11)
                helpDialog
                    .transition(.scale(scale: 0.93).combined(with: .opacity))
                    .zIndex(12)
            }
        }
        .onChange(of: gameState.sumerianPendingComplete) { _, newVal in
            if newVal {
                helpTask?.cancel()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    showComplete = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    withAnimation(.easeOut(duration: 0.6)) { messageRevealed = true }
                }
            }
        }
        .onAppear { scheduleHelpDialog() }
        .onDisappear {
            helpTask?.cancel()
            showComplete = false
            messageRevealed = false
        }
    }

    // MARK: Header

    private var headerBar: some View {
        HStack {
            Button { HapticFeedback.tap(); gameState.closeSumerianGame() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(clayDark)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            VStack(spacing: 1) {
                Text("𒀭 𒆳 𒀀 𒌓 𒃲")
                    .font(.system(size: 13))
                    .foregroundStyle(clayDark.opacity(0.50))
                    .tracking(4)
                Text("Cuneiform Cipher")
                    .font(EgyptFont.title(11))
                    .foregroundStyle(clayDark.opacity(0.50))
                    .tracking(2)
            }
            Spacer()
            Text(level.romanNumeral)
                .font(EgyptFont.titleBold(20))
                .foregroundStyle(clayDark)
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
        .background(Color(red: 0.72, green: 0.54, blue: 0.34).opacity(0.6))
    }

    // MARK: Level Header

    private var levelHeader: some View {
        VStack(spacing: 6) {
            Text(level.title)
                .font(EgyptFont.titleBold(26))
                .foregroundStyle(clayDark)
                .multilineTextAlignment(.center)
            Text(level.subtitle)
                .font(EgyptFont.bodyItalic(18))
                .foregroundStyle(clayDark.opacity(0.70))
                .multilineTextAlignment(.center)
            Capsule()
                .fill(clayDark.opacity(0.22))
                .frame(height: 1)
                .padding(.vertical, 2)
            Text(level.scribes.isEmpty
                 ? "Deduce the cipher key from the anchor stones, then decode every blank"
                 : "Pick a testimony to unlock the tablet, then decode every blank")
                .font(EgyptFont.body(16))
                .foregroundStyle(clayDark.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    // MARK: Cipher Key Panel

    private var cipherKeyPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Text("IMPRESSIONS KNOWN")
                    .font(EgyptFont.title(13))
                    .foregroundStyle(clayDark.opacity(0.55))
                    .tracking(2)
                Spacer()
                let known = gameState.sumerianKnownMappings.count
                let total = level.symbols.count
                Text("\(known) of \(total)")
                    .font(EgyptFont.body(13))
                    .foregroundStyle(clayDark.opacity(0.45))
            }

            // One "decipher stone" per symbol in the level's alphabet.
            // Shows the encoded glyph · its decoded partner (or ?) as a line of script.
            // Stones fill in automatically when a truth-teller scribe is confirmed.
            HStack(spacing: 6) {
                ForEach(level.symbols) { encoded in
                    let decoded = gameState.sumerianKnownMappings[encoded]
                    decipherStone(encoded: encoded, decoded: decoded)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.72, green: 0.55, blue: 0.35).opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(clayDark.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private func decipherStone(encoded: CuneiformGlyph, decoded: CuneiformGlyph?) -> some View {
        let known = decoded != nil
        return VStack(spacing: 3) {
            HStack(spacing: 3) {
                Text(encoded.rawValue)
                    .font(.system(size: 28))
                    .foregroundStyle(clayDark.opacity(known ? 0.70 : 0.55))
                Text("·")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(clayDark.opacity(0.35))
                if let decoded {
                    Text(decoded.rawValue)
                        .font(.system(size: 28))
                        .foregroundStyle(clayDark)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("?")
                        .font(EgyptFont.titleBold(24))
                        .foregroundStyle(clayDark.opacity(0.25))
                }
            }
            HStack(spacing: 3) {
                Text(encoded.displayName)
                    .font(EgyptFont.body(10))
                    .foregroundStyle(clayDark.opacity(0.45))
                Text("·")
                    .font(.system(size: 9))
                    .foregroundStyle(clayDark.opacity(0.25))
                Text(decoded?.displayName ?? "—")
                    .font(EgyptFont.body(10))
                    .foregroundStyle(known ? clayDark.opacity(0.65) : clayDark.opacity(0.25))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(known
                      ? Color(red: 0.93, green: 0.80, blue: 0.58).opacity(0.65)
                      : Color(red: 0.78, green: 0.61, blue: 0.40).opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(known ? clayDark.opacity(0.38) : clayDark.opacity(0.15), lineWidth: 1)
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: decoded)
    }

    // MARK: Tablet — Encoded + Decoded rows

    private var tabletSection: some View {
        VStack(spacing: 0) {
            // Reading direction indicator — replaces mechanical ENCODED/DECODED labels
            HStack {
                if isRightToLeft {
                    Image(systemName: "arrow.backward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(clayDark.opacity(0.50))
                }
                Text(readingDirectionLabel)
                    .font(EgyptFont.bodyItalic(13))
                    .foregroundStyle(clayDark.opacity(0.55))
                if !isRightToLeft {
                    Spacer()
                } else {
                    Spacer()
                }
            }
            .padding(.bottom, 10)

            // The inscription — encoded glyphs, flows in reading direction
            symbolRow(glyphs: level.encodedSequence.map { Optional($0) },
                      isEncoded: true,
                      selectedIndex: nil)

            // A single ruled line between inscription and translation
            Rectangle()
                .fill(clayDark.opacity(0.22))
                .frame(height: 1)
                .padding(.vertical, 10)

            // The decipherment — player fills this in (locked until truth-teller scribe confirmed)
            decodedRow

            // Note shown when player taps the tablet before confirming the truth-teller
            if showTabletGateNote {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.90, green: 0.72, blue: 0.25))
                    Text("Identify the truth-teller above before deciphering the tablet")
                        .font(EgyptFont.bodyItalic(13))
                        .foregroundStyle(clayDark.opacity(0.85))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.42, green: 0.28, blue: 0.10).opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(red: 0.90, green: 0.72, blue: 0.25).opacity(0.70), lineWidth: 1.2))
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 6)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.68, green: 0.50, blue: 0.31).opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(clayDark.opacity(0.38), lineWidth: 1.5)
                )
        )
    }

    private func symbolRow(glyphs: [CuneiformGlyph?], isEncoded: Bool, selectedIndex: Int?) -> some View {
        let count = glyphs.count
        let chunkSize = 6
        return VStack(spacing: 4) {
            ForEach(Array(stride(from: 0, to: count, by: chunkSize)), id: \.self) { start in
                let end = min(start + chunkSize, count)
                let indices = chunkIndices(start: start, end: end)
                let padCount = chunkSize - (end - start)
                HStack(spacing: 4) {
                    // For RTL, padding goes on the RIGHT so the start of reading is at the right edge
                    if isRightToLeft && padCount > 0 {
                        ForEach(0..<padCount, id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        }
                    }
                    ForEach(indices, id: \.self) { idx in
                        encodedCell(glyph: glyphs[idx], index: idx, isFixed: true)
                    }
                    if !isRightToLeft && padCount > 0 {
                        ForEach(0..<padCount, id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }

    // MARK: Testimony Section

    private var testimonySection: some View {
        let selectedId = gameState.sumerianSelectedScribeIds[level.id]
        let hasSelection = selectedId != nil
        let amber = Color(red: 0.90, green: 0.72, blue: 0.25)

        return VStack(spacing: 10) {
            // Header row
            HStack {
                Text("SWORN TESTIMONIES")
                    .font(EgyptFont.title(14))
                    .foregroundStyle(clayDark)
                    .tracking(2)
                Spacer()
                if hasSelection {
                    Text("Testimony active")
                        .font(EgyptFont.bodyItalic(13))
                        .foregroundStyle(amber.opacity(0.80))
                        .transition(.opacity)
                }
                Button {
                    withAnimation { showHelpDialog = true }
                    helpTask?.cancel()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(clayDark.opacity(0.70))
                }
                .buttonStyle(.plain)
            }

            // Scribe cards side by side
            HStack(spacing: 8) {
                ForEach(level.scribes) { scribe in
                    scribeCard(scribe)
                }
            }

            // Level 1: foreign mark banner — shown after level is solved
            if level.id == 1, gameState.sumerianUnlockedLevels.contains(1) {
                HStack(spacing: 10) {
                    Text("𓊹").font(.system(size: 28)).foregroundStyle(amber)
                    Text("Egyptian divine mark — recorded in your diary")
                        .font(EgyptFont.bodyItalic(14))
                        .foregroundStyle(amber.opacity(0.85))
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.28, green: 0.18, blue: 0.06).opacity(0.70))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(amber.opacity(0.55), lineWidth: 1.2))
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.55, green: 0.38, blue: 0.20).opacity(0.50))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(clayDark.opacity(0.35), lineWidth: 1))
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.80), value: hasSelection)
    }

    /// Compact scribe card — fits 2–3 side by side in an HStack.
    /// Tapping selects this scribe's testimony and unlocks the tablet immediately.
    /// Switching scribes resets the tablet. Any selection can be changed freely.
    private func scribeCard(_ scribe: SumerianScribe) -> some View {
        let levelId   = level.id
        let selected  = gameState.sumerianSelectedScribeIds[levelId] == scribe.id
        let amber     = Color(red: 0.90, green: 0.72, blue: 0.25)
        let ink       = Color(red: 0.14, green: 0.08, blue: 0.02)   // near-black for readability

        return Button {
            gameState.selectSumerianScribe(scribe.id)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                // Name + selection indicator
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(scribe.name)
                            .font(EgyptFont.titleBold(16))
                            .foregroundStyle(selected ? amber : ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(scribe.title)
                            .font(EgyptFont.bodyItalic(13))
                            .foregroundStyle(selected ? amber.opacity(0.80) : ink.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(amber)
                    } else {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 13))
                            .foregroundStyle(ink.opacity(0.35))
                    }
                }

                Divider().overlay(selected ? amber.opacity(0.40) : ink.opacity(0.20))

                // Claims — each on its own line: symbol (NAME) → symbol (NAME)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(scribe.claims.indices, id: \.self) { i in
                        let c = scribe.claims[i]
                        HStack(spacing: 4) {
                            Text(c.encoded.rawValue).font(.system(size: 22))
                            Text(c.encoded.displayName)
                                .font(EgyptFont.body(13)).foregroundStyle(ink.opacity(0.55))
                            Text("→").font(EgyptFont.bodySemiBold(14))
                            Text(c.decoded.rawValue).font(.system(size: 22))
                            Text(c.decoded.displayName)
                                .font(EgyptFont.body(13)).foregroundStyle(ink.opacity(0.55))
                        }
                        .foregroundStyle(selected ? amber : ink)
                    }
                    // Foreign mark line
                    if let mark = scribe.foreignMarkSymbol {
                        HStack(spacing: 6) {
                            Text(mark).font(.system(size: 22))
                            Text("foreign mark")
                                .font(EgyptFont.bodyItalic(13))
                                .foregroundStyle(selected ? amber.opacity(0.80) : ink.opacity(0.65))
                        }
                        .foregroundStyle(selected ? amber : ink)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(selected
                          ? Color(red: 0.35, green: 0.24, blue: 0.06).opacity(0.90)
                          : Color(red: 0.88, green: 0.72, blue: 0.50).opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(selected ? amber.opacity(0.70) : ink.opacity(0.25),
                                    lineWidth: selected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.25), value: selected)
    }

    // MARK: Help Dialog

    private var helpDialog: some View {
        let hasScribes = !level.scribes.isEmpty
        return VStack(alignment: .leading, spacing: 0) {
            // Title bar
            HStack {
                Text("𒀭  How to Play")
                    .font(EgyptFont.titleBold(20))
                    .foregroundStyle(Color(red: 0.90, green: 0.72, blue: 0.25))
                Spacer()
                Button { withAnimation { showHelpDialog = false } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(red: 0.90, green: 0.72, blue: 0.25).opacity(0.70))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 14)

            if hasScribes {
                helpRow(number: "1", title: "Read the anchor stones",
                        body: "One or more decoded positions are already revealed in the tablet. Each shows a confirmed pairing — an encoded symbol and what it truly becomes.")
                helpRow(number: "2", title: "Pick a testimony",
                        body: "Each scribe swears to a complete cipher key. Tap the one you believe. Their claims fill in the Impressions Known panel and unlock the tablet. You can switch scribes at any time — but switching resets your tablet work.")
                helpRow(number: "3", title: "Cross-check against anchors",
                        body: "Compare the scribe's claims to the anchor stones. A liar's key will contradict the physical evidence — at least one claim won't match.")
                helpRow(number: "4", title: "Decode the tablet",
                        body: "Tap a blank cell in the decoded row, then tap the matching symbol in the palette. Use the Impressions Known panel as your guide.")
                helpRow(number: "5", title: "Decipher",
                        body: "When all blanks are filled, tap Decipher. Wrong cells flash red. If you chose a false testimony, adjust your scribe selection and start again.")
            } else {
                helpRow(number: "1", title: "Read the anchor stones",
                        body: "Two decoded positions are already revealed. Each gives you one confirmed cipher pairing — which encoded symbol maps to which decoded symbol.")
                helpRow(number: "2", title: "Identify unused mappings",
                        body: "List the encoded symbols not yet explained. List the decoded symbols not yet assigned. In a one-to-one cipher, each remaining input takes exactly one remaining output.")
                helpRow(number: "3", title: "Decode the tablet",
                        body: "Tap a blank cell, then tap the matching symbol in the palette. The Impressions Known panel tracks what you've discovered.")
                helpRow(number: "4", title: "Decipher",
                        body: "When all blanks are filled, tap Decipher to check your work.")
            }

            Button {
                withAnimation { showHelpDialog = false }
                scheduleHelpDialog()
            } label: {
                Text("Got it")
                    .font(EgyptFont.titleBold(17))
                    .foregroundStyle(Color(red: 0.14, green: 0.08, blue: 0.02))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.90, green: 0.72, blue: 0.25))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.18, green: 0.11, blue: 0.05))
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(red: 0.90, green: 0.72, blue: 0.25).opacity(0.55), lineWidth: 1.5))
        )
        .padding(.horizontal, 20)
    }

    private func helpRow(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(EgyptFont.titleBold(15))
                .foregroundStyle(Color(red: 0.90, green: 0.72, blue: 0.25))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(Color(red: 0.93, green: 0.85, blue: 0.68))
                Text(body)
                    .font(EgyptFont.body(14))
                    .foregroundStyle(Color(red: 0.93, green: 0.85, blue: 0.68).opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
        }
        .padding(.bottom, 12)
    }

    private func scheduleHelpDialog() {
        helpTask?.cancel()
        helpTask = Task {
            try? await Task.sleep(nanoseconds: 14_000_000_000)   // 14 seconds idle
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !showComplete, !showHelpDialog else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.80)) {
                    showHelpDialog = true
                }
            }
        }
    }

    private var decodedRow: some View {
        let count = level.encodedSequence.count
        let chunkSize = 6
        return VStack(spacing: 4) {
            ForEach(Array(stride(from: 0, to: count, by: chunkSize)), id: \.self) { start in
                let end = min(start + chunkSize, count)
                let indices = chunkIndices(start: start, end: end)
                let padCount = chunkSize - (end - start)
                HStack(spacing: 4) {
                    if isRightToLeft && padCount > 0 {
                        ForEach(0..<padCount, id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        }
                    }
                    ForEach(indices, id: \.self) { idx in
                        decodedCell(index: idx)
                    }
                    if !isRightToLeft && padCount > 0 {
                        ForEach(0..<padCount, id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }

    private func encodedCell(glyph: CuneiformGlyph?, index: Int, isFixed: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.68, green: 0.51, blue: 0.33))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(clayDark.opacity(0.30), lineWidth: 1))
            if let glyph {
                Text(glyph.rawValue)
                    .font(.system(size: cellFontSize))
                    .foregroundStyle(Color(red: 0.22, green: 0.13, blue: 0.04))
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    private func decodedCell(index: Int) -> some View {
        let isRevealed = level.isRevealed(index)
        let glyph = gameState.playerSumerianDecoded[safe: index] ?? nil
        let isError = gameState.sumerianErrorPositions.contains(index)
        let isSelected = gameState.sumerianSelectedDecodedIndex == index

        return Button {
            if scribeGateActive {
                HapticFeedback.error()
                withAnimation(.spring(response: 0.3)) { showTabletGateNote = true }
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    withAnimation(.easeOut(duration: 0.4)) { showTabletGateNote = false }
                }
                return
            }
            if !isRevealed {
                gameState.tapSumerianDecodedPosition(index)
            } else {
                HapticFeedback.error()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(decodedCellColor(isRevealed: isRevealed, isError: isError,
                                          isSelected: isSelected, hasGlyph: glyph != nil))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? clayDark.opacity(0.85) : clayDark.opacity(0.25),
                                    lineWidth: isSelected ? 2 : 1)
                    )
                if let glyph {
                    Text(glyph.rawValue)
                        .font(.system(size: cellFontSize))
                        .foregroundStyle(isRevealed
                                         ? Color(red: 0.22, green: 0.13, blue: 0.04)
                                         : Color(red: 0.30, green: 0.18, blue: 0.06))
                        .minimumScaleFactor(0.5)
                } else if !isRevealed {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(clayDark.opacity(0.28))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isError)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private func decodedCellColor(isRevealed: Bool, isError: Bool, isSelected: Bool, hasGlyph: Bool) -> Color {
        if isError   { return Color(red: 0.72, green: 0.22, blue: 0.18) }
        if isRevealed { return Color(red: 0.70, green: 0.53, blue: 0.33) }
        if isSelected { return Color(red: 0.96, green: 0.84, blue: 0.62) }
        if hasGlyph  { return Color(red: 0.89, green: 0.74, blue: 0.54) }
        return Color(red: 0.83, green: 0.66, blue: 0.45)
    }

    private var cellFontSize: CGFloat { 38 }

    // MARK: Palette

    private var palette: some View {
        VStack(spacing: 8) {
            if gameState.sumerianSelectedDecodedIndex != nil {
                Text("Choose a symbol to place")
                    .font(EgyptFont.body(12))
                    .foregroundStyle(clayDark.opacity(0.60))
            }
            HStack(spacing: 8) {
                ForEach(level.symbols) { glyph in
                    Button {
                        if scribeGateActive {
                            HapticFeedback.error()
                            withAnimation(.spring(response: 0.3)) { showTabletGateNote = true }
                            Task {
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                withAnimation(.easeOut(duration: 0.4)) { showTabletGateNote = false }
                            }
                            return
                        }
                        gameState.placeSumerianGlyph(glyph)
                    } label: {
                        VStack(spacing: 5) {
                            Text(glyph.rawValue)
                                .font(.system(size: 40))
                                .foregroundStyle(clayDark)
                            Text(glyph.displayName)
                                .font(EgyptFont.body(13))
                                .foregroundStyle(clayDark.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Color(red: 0.86, green: 0.70, blue: 0.49))
                                .overlay(RoundedRectangle(cornerRadius: 9)
                                    .stroke(clayDark.opacity(0.28), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Action Row

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                HapticFeedback.heavy()
                gameState.resetSumerianCurrentLevel()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(EgyptFont.body(14))
                    .foregroundStyle(clayDark.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color(red: 0.80, green: 0.63, blue: 0.43))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(clayDark.opacity(0.3), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            Button {
                HapticFeedback.tap()
                gameState.verifySumerianPlacement()
            } label: {
                Label("Decipher", systemImage: "checkmark.seal")
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(Color(red: 0.95, green: 0.88, blue: 0.70))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color(red: 0.55, green: 0.38, blue: 0.22))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(clayDark.opacity(0.5), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Inscriptions

    private var inscriptionsSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { inscriptionsExpanded.toggle() }
            } label: {
                HStack {
                    Text("Field Inscriptions")
                        .font(EgyptFont.title(13))
                        .foregroundStyle(clayDark.opacity(0.75))
                        .tracking(1)
                    Spacer()
                    Image(systemName: inscriptionsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(clayDark.opacity(0.55))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 9)
                    .fill(Color(red: 0.80, green: 0.63, blue: 0.43).opacity(0.55)))
            }
            .buttonStyle(.plain)

            if inscriptionsExpanded {
                let acrostic = TreeOfLifeKeys.acrosticLetter(for: .sumerian, levelIndex: gameState.sumerianCurrentLevelIndex)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(level.inscriptions.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: 10) {
                            Text("𒀭")
                                .font(.system(size: 13))
                                .foregroundStyle(clayDark.opacity(0.45))
                            Text(acrosticUnderlined(level.inscriptions[i], letter: acrostic))
                                .font(EgyptFont.bodyItalic(14))
                                .foregroundStyle(clayDark.opacity(0.85))
                                .lineSpacing(4)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(red: 0.88, green: 0.72, blue: 0.52).opacity(0.4))
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: Level Complete Card

    private var levelCompleteCard: some View {
        let isLastLevel = gameState.sumerianCurrentLevelIndex == SumerianLevel.allLevels.count - 1
        let newCivs     = isLastLevel ? gameState.newlyUnlockedCivs(completingLevel5Of: .sumerian) : []
        let gold        = Color(red: 0.90, green: 0.72, blue: 0.35)
        let parchment   = Color(red: 0.93, green: 0.85, blue: 0.68)

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Spacer(minLength: 30)

                Text(level.artifact)
                    .font(.system(size: 64))
                    .foregroundStyle(gold)
                    .shadow(color: Color(red: 0.60, green: 0.42, blue: 0.15).opacity(0.8),
                            radius: 14, x: 0, y: 0)

                VStack(spacing: 8) {
                    Text("Cipher Broken")
                        .font(EgyptFont.titleBold(26))
                        .foregroundStyle(Color(red: 0.92, green: 0.78, blue: 0.45))
                        .tracking(2)
                    clayRule
                    Text(level.title)
                        .font(EgyptFont.bodyItalic(17))
                        .foregroundStyle(parchment)
                }

                if messageRevealed {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Decoded Message", systemImage: "scroll")
                            .font(EgyptFont.title(11))
                            .foregroundStyle(gold)
                            .tracking(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(gameState.sumerianPendingDecodedMessage)
                            .font(EgyptFont.bodyItalic(15))
                            .foregroundStyle(parchment)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.28, green: 0.18, blue: 0.08).opacity(0.55))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(gold.opacity(0.4), lineWidth: 1))
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                    if !level.newGlyphs.isEmpty {
                        VStack(spacing: 6) {
                            Text("New Signs Discovered")
                                .font(EgyptFont.title(11))
                                .foregroundStyle(gold.opacity(0.8))
                                .tracking(1)
                            HStack(spacing: 16) {
                                ForEach(level.newGlyphs) { glyph in
                                    VStack(spacing: 3) {
                                        Text(glyph.rawValue).font(.system(size: 28))
                                            .foregroundStyle(Color(red: 0.92, green: 0.78, blue: 0.45))
                                        Text(glyph.displayName).font(EgyptFont.body(10))
                                            .foregroundStyle(parchment.opacity(0.7))
                                    }
                                }
                            }
                        }
                        .transition(.opacity)
                    }

                    // Journal nudge — every level
                    HStack(spacing: 8) {
                        Image(systemName: "book.fill").font(.system(size: 11))
                            .foregroundStyle(gold.opacity(0.60))
                        Text("A new entry has been written in your Field Diary.")
                            .font(EgyptFont.bodyItalic(13))
                            .foregroundStyle(gold.opacity(0.60))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)

                    // Level 5 — key earned + newly unlocked civs
                    if isLastLevel {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "key.fill").font(.system(size: 12))
                                    .foregroundStyle(gold)
                                Text("The Sumerian key has been carved in your Field Diary.")
                                    .font(EgyptFont.bodyItalic(13))
                                    .foregroundStyle(gold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if !newCivs.isEmpty {
                                Text("NEW PATHS OPEN")
                                    .font(EgyptFont.title(11))
                                    .foregroundStyle(gold.opacity(0.55))
                                    .tracking(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(newCivs) { civ in
                                    HStack(spacing: 12) {
                                        Text(civ.emblem).font(.system(size: 24))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(civ.name).font(EgyptFont.titleBold(14))
                                                .foregroundStyle(civ.accentColor)
                                            Text(civ.era).font(EgyptFont.bodyItalic(12))
                                                .foregroundStyle(parchment.opacity(0.55))
                                        }
                                        Spacer()
                                        Image(systemName: "lock.open.fill").font(.system(size: 12))
                                            .foregroundStyle(gold)
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(red: 0.22, green: 0.14, blue: 0.06).opacity(0.6))
                                            .overlay(RoundedRectangle(cornerRadius: 8)
                                                .stroke(civ.accentColor.opacity(0.35), lineWidth: 1))
                                    )
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.20, green: 0.12, blue: 0.04).opacity(0.65))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(gold.opacity(0.35), lineWidth: 1))
                        )
                        .transition(.opacity)
                    }
                }

                VStack(spacing: 10) {
                    if isLastLevel && gameState.allSixCivsComplete {
                        Button {
                            HapticFeedback.heavy()
                            showComplete = false
                            messageRevealed = false
                            gameState.sumerianPendingComplete = false
                            withAnimation(.easeInOut(duration: 0.4)) { gameState.openManduTablet() }
                        } label: { StoneButton(title: "Open the Mandu Tablet", icon: "seal.fill", style: .gold) }
                    } else if isLastLevel {
                        Button {
                            HapticFeedback.heavy()
                            showComplete = false
                            messageRevealed = false
                            gameState.sumerianPendingComplete = false
                            withAnimation(.easeInOut(duration: 0.4)) { gameState.startNewGame() }
                        } label: { StoneButton(title: "Continue Expedition", icon: "arrow.right", style: .gold) }
                    } else {
                        Button {
                            HapticFeedback.heavy()
                            showComplete = false
                            messageRevealed = false
                            gameState.sumerianPendingComplete = false
                            withAnimation(.easeInOut(duration: 0.35)) {
                                gameState.advanceSumerianToNextLevel()
                            }
                        } label: { StoneButton(title: "Press the Next Tablet", icon: "arrow.right", style: .gold) }
                    }
                    Button {
                        HapticFeedback.tap()
                        gameState.openJournal()
                    } label: { StoneButton(title: "Open Field Diary", icon: "book.fill", style: .muted) }
                }
                .padding(.horizontal, 8)

                Spacer(minLength: 30)
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.18, green: 0.11, blue: 0.05))
                    .overlay(RoundedRectangle(cornerRadius: 18)
                        .stroke(gold.opacity(0.5), lineWidth: 1.5))
            )
            .padding(.horizontal, 20)
        }
    }

    // MARK: Colours & Helpers

    private var clayBackground: some View {
        ZStack {
            Color(red: 0.80, green: 0.62, blue: 0.40)
            RadialGradient(colors: [Color(red: 0.88, green: 0.72, blue: 0.52).opacity(0.60), .clear],
                           center: .center, startRadius: 60, endRadius: 420)
            RadialGradient(colors: [.clear, Color(red: 0.42, green: 0.28, blue: 0.12).opacity(0.55)],
                           center: .center, startRadius: 280, endRadius: 700)
        }
    }

    private var clayDark: Color { Color(red: 0.28, green: 0.17, blue: 0.06) }

    private var clayRule: some View {
        HStack {
            Rectangle()
                .fill(LinearGradient(colors: [.clear, Color(red: 0.90, green: 0.72, blue: 0.35), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 0.8)
            Text("𒀭")
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.90, green: 0.72, blue: 0.35))
                .padding(.horizontal, 8)
            Rectangle()
                .fill(LinearGradient(colors: [.clear, Color(red: 0.90, green: 0.72, blue: 0.35), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 0.8)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 4)
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    SumerianGameView()
        .environmentObject(GameState())
}
