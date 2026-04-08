// ManduTabletView.swift
// EchoOfAges
//
// The Tablet of Mandu — the final puzzle of Echo of Ages.
//
// The player has six civilization stones, each earned by completing a
// civilization's puzzles. The stones must be placed on the tablet in the
// correct left-to-right order matching the parts of the Tree of Life:
//
//   Roots · Water · Trunk · Branches · Leaves · Sun
//
// No civilization is labeled with its tree part — the player must infer
// the order from the decoded diary entries.

import SwiftUI

// MARK: - Tree Slot Data

private struct TreeSlotInfo {
    let index: Int
    let part: String
    let subtitle: String
}

private let treeSlots: [TreeSlotInfo] = [
    TreeSlotInfo(index: 0, part: "Roots",    subtitle: "Before the flood"),
    TreeSlotInfo(index: 1, part: "Water",    subtitle: "The primordial sea"),
    TreeSlotInfo(index: 2, part: "Trunk",    subtitle: "The world pillar"),
    TreeSlotInfo(index: 3, part: "Branches", subtitle: "Across nine worlds"),
    TreeSlotInfo(index: 4, part: "Leaves",   subtitle: "Each word, a leaf"),
    TreeSlotInfo(index: 5, part: "Sun",      subtitle: "Visible in light"),
]

// MARK: - ManduTabletView

struct ManduTabletView: View {
    @EnvironmentObject var gameState: GameState

    @State private var showReveal  = false
    @State private var revealStep  = 0
    @State private var showFullMsg = false
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            sandBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        titleStrip
                        stoneRow
                        civTray
                        instructionBanner
                        actionRow
                        loreNote
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 60)
                }
            }

            if showReveal {
                Color.black.opacity(0.90).ignoresSafeArea()
                    .transition(.opacity).zIndex(9)
                revealOverlay.zIndex(10)
            }
        }
        .onChange(of: gameState.isManduComplete) { _, complete in
            if complete { startReveal() }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button { HapticFeedback.tap(); gameState.closeManduTablet() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(paper)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("TABLET OF MANDU")
                    .font(EgyptFont.titleBold(20))
                    .tracking(3)
                    .foregroundStyle(paper)
                Text("The Tree of Life")
                    .font(EgyptFont.bodyItalic(15))
                    .foregroundStyle(paper.opacity(0.65))
            }
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .frame(height: 60)
        .background(ink.opacity(0.88))
    }

    // MARK: - Title Strip

    private var titleStrip: some View {
        VStack(spacing: 10) {
            Text("Found on a nameless island. No map charts its location.")
                .font(EgyptFont.bodyItalic(18))
                .foregroundStyle(ink.opacity(0.70))
                .multilineTextAlignment(.center)

            // Progress pips — 6 for 6 tree-part slots
            HStack(spacing: 6) {
                ForEach(0..<6, id: \.self) { i in
                    let civ = i < TreeOfLifeKeys.tabletOrder.count ? TreeOfLifeKeys.tabletOrder[i] : nil
                    let correct = civ.map { gameState.manduPlayerGrid[i] == $0.rawValue } ?? false
                    Circle()
                        .fill(correct ? gold : ink.opacity(0.20))
                        .frame(width: 9, height: 9)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: correct)
                }
            }

            Text("\(gameState.manduCorrectCount) of 6 in the right place")
                .font(EgyptFont.body(16))
                .foregroundStyle(gameState.manduCorrectCount == 6 ? gold : ink.opacity(0.60))
        }
    }

    // MARK: - Stone Slot Row

    private var stoneRow: some View {
        VStack(spacing: 8) {
            Text("ARRANGE THE STONES")
                .font(EgyptFont.title(12))
                .tracking(2)
                .foregroundStyle(ink.opacity(0.45))

            HStack(spacing: 6) {
                ForEach(treeSlots, id: \.index) { slot in
                    slotCell(slot)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.78, green: 0.68, blue: 0.50).opacity(0.40))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(ink.opacity(0.25), lineWidth: 1.5))
        )
    }

    private func slotCell(_ slot: TreeSlotInfo) -> some View {
        let placedRaw = gameState.manduPlayerGrid[slot.index]
        let placedCiv: CivilizationID? = placedRaw.flatMap { CivilizationID(rawValue: $0) }
        let civInfo = placedCiv.flatMap { id in Civilization.all.first(where: { $0.id == id }) }
        let isCorrect = placedCiv.map { TreeOfLifeKeys.tabletOrder[slot.index] == $0 } ?? false
        let isArmedTarget = gameState.manduArmedCiv != nil

        return Button { gameState.tapManduSlot(slot.index) } label: {
            VStack(spacing: 3) {
                // Part name label
                Text(slot.part)
                    .font(EgyptFont.title(10))
                    .tracking(0.5)
                    .foregroundStyle(ink.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Stone cell body
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(slotFill(placed: civInfo != nil, correct: isCorrect, accent: civInfo?.accentColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(slotBorder(placed: civInfo != nil, correct: isCorrect,
                                                   accent: civInfo?.accentColor, armedTarget: isArmedTarget),
                                        lineWidth: isCorrect ? 2.0 : (isArmedTarget && civInfo == nil ? 1.5 : 1.0))
                        )

                    if let civ = civInfo {
                        VStack(spacing: 2) {
                            Text(civ.emblem)
                                .font(.system(size: 24))
                                .foregroundStyle(isCorrect ? civ.accentColor : ink.opacity(0.80))
                        }
                    } else {
                        Text("+")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(isArmedTarget ? gold.opacity(0.6) : ink.opacity(0.18))
                    }
                }
                .frame(height: 54)

                // Subtitle label
                Text(slot.subtitle)
                    .font(EgyptFont.bodyItalic(9))
                    .foregroundStyle(ink.opacity(0.38))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.15), value: placedCiv?.rawValue)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCorrect)
    }

    private func slotFill(placed: Bool, correct: Bool, accent: Color?) -> Color {
        if correct  { return (accent ?? gold).opacity(0.18) }
        if placed   { return Color(red: 0.85, green: 0.77, blue: 0.60) }
        return Color(red: 0.70, green: 0.62, blue: 0.48).opacity(0.30)
    }

    private func slotBorder(placed: Bool, correct: Bool, accent: Color?, armedTarget: Bool) -> Color {
        if correct  { return (accent ?? gold).opacity(0.80) }
        if placed   { return ink.opacity(0.30) }
        if armedTarget { return gold.opacity(0.55) }
        return ink.opacity(0.20)
    }

    // MARK: - Civilization Token Tray

    private var civTray: some View {
        VStack(spacing: 8) {
            Text("YOUR CIVILIZATION STONES")
                .font(EgyptFont.title(12))
                .tracking(2)
                .foregroundStyle(ink.opacity(0.45))

            HStack(spacing: 6) {
                ForEach(Civilization.all) { civ in
                    civToken(civ)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.86, green: 0.78, blue: 0.60).opacity(0.45))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(ink.opacity(0.18), lineWidth: 1))
        )
    }

    private func civToken(_ civ: Civilization) -> some View {
        let isArmed = gameState.manduArmedCiv == civ.id
        let isPlaced = gameState.manduPlayerGrid.values.contains(civ.id.rawValue)
        let isAvailable = gameState.civilizationsCompletedForMandu.contains(civ.id)

        return Button { if isAvailable { gameState.tapManduCiv(civ.id) } } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isArmed ? civ.accentColor.opacity(0.25)
                              : (isPlaced ? ink.opacity(0.06) : ink.opacity(0.09)))
                        .overlay(
                            Circle()
                                .stroke(isArmed ? civ.accentColor : (isPlaced ? ink.opacity(0.15) : ink.opacity(0.25)),
                                        lineWidth: isArmed ? 2.0 : 1.0)
                        )
                        .frame(width: 40, height: 40)

                    Text(civ.emblem)
                        .font(.system(size: 20))
                        .foregroundStyle(
                            isArmed ? civ.accentColor
                            : (isAvailable ? (isPlaced ? ink.opacity(0.35) : ink.opacity(0.75))
                               : ink.opacity(0.15))
                        )
                }

                Text(civ.name.components(separatedBy: " ").first ?? civ.name)
                    .font(EgyptFont.body(9))
                    .foregroundStyle(isArmed ? civ.accentColor.opacity(0.90)
                                    : (isAvailable ? ink.opacity(isPlaced ? 0.35 : 0.60) : ink.opacity(0.18)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .animation(.easeInOut(duration: 0.15), value: isArmed)
        .animation(.easeInOut(duration: 0.15), value: isPlaced)
    }

    // MARK: - Instruction Banner

    @ViewBuilder
    private var instructionBanner: some View {
        if let civ = gameState.manduArmedCiv,
           let civInfo = Civilization.all.first(where: { $0.id == civ }) {
            HStack(spacing: 12) {
                Text(civInfo.emblem)
                    .font(.system(size: 26))
                    .foregroundStyle(civInfo.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(civInfo.name)
                        .font(EgyptFont.title(16))
                        .tracking(1)
                        .foregroundStyle(civInfo.accentColor)
                    Text("Tap a slot above to place this stone")
                        .font(EgyptFont.bodyItalic(17))
                        .foregroundStyle(ink.opacity(0.80))
                }
                Spacer()
                Button { gameState.manduArmedCiv = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ink.opacity(0.28))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(civInfo.accentColor.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(civInfo.accentColor.opacity(0.38), lineWidth: 1))
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: civ.rawValue)
        } else if !gameState.allSixCivsComplete {
            let done = gameState.civilizationsCompletedForMandu.count
            HStack(spacing: 10) {
                Image(systemName: done == 0 ? "lock.fill" : "arrow.down.to.line")
                    .font(.system(size: 16))
                    .foregroundStyle(ink.opacity(0.45))
                Text(done == 0
                     ? "Decipher Egypt's tablets first to unlock your first stone."
                     : "Stones fall away when you leave until all six civilizations are deciphered. \(done) of 6 complete.")
                    .font(EgyptFont.bodyItalic(17))
                    .foregroundStyle(ink.opacity(0.70))
                    .lineSpacing(3)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ink.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(ink.opacity(0.16), lineWidth: 1))
            )
        } else {
            Text("Tap a civilization stone, then tap where it belongs on the tree.")
                .font(EgyptFont.bodyItalic(17))
                .foregroundStyle(ink.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.vertical, 4)
        }
    }

    // MARK: - Action Row

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button { gameState.resetManduGrid() } label: {
                Label("Clear Stone", systemImage: "arrow.counterclockwise")
                    .font(EgyptFont.body(18))
                    .foregroundStyle(ink.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(ink.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(ink.opacity(0.20), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            if gameState.isManduComplete {
                Button { startReveal() } label: {
                    Label("Seal the Stone", systemImage: "sparkles")
                        .font(EgyptFont.titleBold(19))
                        .foregroundStyle(Color(red: 0.10, green: 0.08, blue: 0.02))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(gold)
                                .overlay(RoundedRectangle(cornerRadius: 9)
                                    .stroke(gold.opacity(0.50), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: gameState.isManduComplete)
    }

    // MARK: - Lore Note

    private var loreNote: some View {
        Text("Six civilizations. One stone. One message.\n\nPlace every stone in the part of the tree it represents — but they fall away each time you leave. Only when all six civilizations are deciphered will the stone hold them forever.")
            .font(EgyptFont.bodyItalic(17))
            .foregroundStyle(ink.opacity(0.60))
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .padding(.top, 4)
    }

    // MARK: - Reveal Overlay

    private var revealOverlay: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer(minLength: 50)

                Text("𓇳")
                    .font(.system(size: 100))
                    .foregroundStyle(gold)
                    .shadow(color: gold.opacity(0.85), radius: 50, x: 0, y: 0)

                VStack(spacing: 8) {
                    Text("THE WORD IS")
                        .font(EgyptFont.titleBold(20))
                        .tracking(6)
                        .foregroundStyle(gold.opacity(0.70))
                    Text("REMEMBER")
                        .font(EgyptFont.titleBold(36))
                        .tracking(8)
                        .foregroundStyle(gold)
                        .shadow(color: gold.opacity(0.60), radius: 14)
                }

                goldRule

                VStack(spacing: 12) {
                    ForEach(Array(Civilization.all.enumerated()), id: \.offset) { i, civ in
                        if revealStep > i {
                            civRevealCard(civ)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .animation(.easeOut(duration: 0.5), value: revealStep)

                if showFullMsg {
                    VStack(spacing: 16) {
                        goldRule
                        Text(TabletSlot.fullMessage)
                            .font(EgyptFont.bodyItalic(20))
                            .foregroundStyle(paper)
                            .multilineTextAlignment(.center)
                            .lineSpacing(9)
                            .padding(.horizontal, 8)
                        goldRule
                    }
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.8), value: showFullMsg)
                }

                Spacer(minLength: 20)

                Button {
                    withAnimation(.easeInOut(duration: 0.4)) { showReveal = false }
                } label: {
                    StoneButton(title: "Close the Stone", icon: "xmark", style: .muted)
                }

                Spacer(minLength: 50)
            }
            .padding(.horizontal, 22)
        }
    }

    private func civRevealCard(_ civ: Civilization) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(civ.emblem).font(.system(size: 18)).foregroundStyle(civ.accentColor)
                Text(civ.name.uppercased())
                    .font(EgyptFont.title(13))
                    .tracking(2)
                    .foregroundStyle(civ.accentColor.opacity(0.80))
                Spacer()
            }
            Text(civ.tabletLine)
                .font(EgyptFont.bodyItalic(17))
                .foregroundStyle(paper.opacity(0.90))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(civ.accentColor.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(civ.accentColor.opacity(0.30), lineWidth: 1))
        )
    }

    // MARK: - Reveal Sequencing

    private func startReveal() {
        guard !isAnimating else { return }
        isAnimating = true
        revealStep  = 0
        showFullMsg = false
        withAnimation(.easeIn(duration: 0.5)) { showReveal = true }
        Task {
            for step in 1...Civilization.all.count {
                try? await Task.sleep(nanoseconds: 750_000_000)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.5)) { revealStep = step }
                }
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.8)) { showFullMsg = true }
            }
            isAnimating = false
        }
    }

    // MARK: - Colors

    private var sandBackground: some View {
        ZStack {
            Color(red: 0.93, green: 0.87, blue: 0.73)
            RadialGradient(colors: [.clear, ink.opacity(0.10)],
                           center: .center, startRadius: 220, endRadius: 650)
        }
    }

    private var gold:  Color { Color(red: 0.92, green: 0.75, blue: 0.35) }
    private var ink:   Color { Color(red: 0.16, green: 0.10, blue: 0.04) }
    private var paper: Color { Color(red: 0.93, green: 0.87, blue: 0.73) }

    private var goldRule: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, gold, .clear],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(height: 0.8)
            .padding(.horizontal, 20)
    }
}

// MARK: - Preview

#Preview {
    ManduTabletView()
        .environmentObject(GameState())
}
