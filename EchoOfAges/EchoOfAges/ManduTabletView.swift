// ManduTabletView.swift
// EchoOfAges
//
// The Tablet of Mandu — the final puzzle of Echo of Ages.
//
// The player has six civilization stones, each earned by completing a
// civilization's puzzles. The stones must be placed on the tablet in the
// correct left-to-right order matching the parts of the Tree of Life.
//
// Feedback is Mastermind-style: the player fills all six slots and submits.
// They learn how many are in the right position — but NOT which ones.
// Each failed attempt is recorded as a history row. The reveal triggers
// only when all six are placed correctly.

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

// MARK: - Attempt Record

private struct ManduAttempt: Identifiable {
    let id = UUID()
    let civIds: [String?]   // snapshot of the 6 slots at submission (index 0–5)
    let correct: Int        // how many were in the right position
}

// MARK: - ManduTabletView

struct ManduTabletView: View {
    @EnvironmentObject var gameState: GameState

    @State private var showReveal   = false
    @State private var treeProgress: CGFloat = 0
    @State private var revealStep   = 0
    @State private var showFullMsg  = false
    @State private var isAnimating  = false

    // Mastermind attempt history
    @State private var attempts: [ManduAttempt] = []

    // True when all 6 slots are filled (regardless of correctness)
    private var isManduFull: Bool { gameState.manduPlayerGrid.count == 6 }

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
                        if !attempts.isEmpty { attemptsHistory }
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
                    .foregroundStyle(paper.opacity(0.70))
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
                .font(EgyptFont.bodyItalic(22))
                .foregroundStyle(ink.opacity(0.97))
                .multilineTextAlignment(.center)

            Text("Fill all six slots, then submit to learn how many are correct.")
                .font(EgyptFont.body(18))
                .foregroundStyle(ink.opacity(0.90))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Stone Slot Row

    private var stoneRow: some View {
        VStack(spacing: 8) {
            Text("ARRANGE THE STONES")
                .font(EgyptFont.title(15))
                .tracking(2)
                .foregroundStyle(ink.opacity(0.92))

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
                    .stroke(ink.opacity(0.30), lineWidth: 1.5))
        )
    }

    private func slotCell(_ slot: TreeSlotInfo) -> some View {
        let placedRaw = gameState.manduPlayerGrid[slot.index]
        let placedCiv: CivilizationID? = placedRaw.flatMap { CivilizationID(rawValue: $0) }
        let civInfo = placedCiv.flatMap { id in Civilization.all.first(where: { $0.id == id }) }
        let isArmedTarget = gameState.manduArmedCiv != nil
        let placed = civInfo != nil

        return Button { gameState.tapManduSlot(slot.index) } label: {
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(slotFill(placed: placed, accent: civInfo?.accentColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(slotBorder(placed: placed, accent: civInfo?.accentColor,
                                                   armedTarget: isArmedTarget),
                                        lineWidth: isArmedTarget && !placed ? 1.5 : 1.0)
                        )

                    if let civ = civInfo {
                        Text(civ.emblem)
                            .font(.system(size: 24))
                            .foregroundStyle(ink.opacity(0.85))
                    } else {
                        Text("+")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(isArmedTarget ? gold.opacity(0.75) : ink.opacity(0.35))
                    }
                }
                .frame(height: 54)

                Text(slot.subtitle)
                    .font(EgyptFont.bodyItalic(12))
                    .foregroundStyle(ink.opacity(0.80))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.15), value: placedCiv?.rawValue)
    }

    private func slotFill(placed: Bool, accent: Color?) -> Color {
        if placed { return Color(red: 0.85, green: 0.77, blue: 0.60) }
        return Color(red: 0.70, green: 0.62, blue: 0.48).opacity(0.30)
    }

    private func slotBorder(placed: Bool, accent: Color?, armedTarget: Bool) -> Color {
        if placed   { return ink.opacity(0.35) }
        if armedTarget { return gold.opacity(0.60) }
        return ink.opacity(0.22)
    }

    // MARK: - Civilization Token Tray

    private var civTray: some View {
        VStack(spacing: 8) {
            Text("YOUR CIVILIZATION STONES")
                .font(EgyptFont.title(15))
                .tracking(2)
                .foregroundStyle(ink.opacity(0.92))

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
                    .stroke(ink.opacity(0.22), lineWidth: 1))
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
                                .stroke(isArmed ? civ.accentColor : (isPlaced ? ink.opacity(0.18) : ink.opacity(0.30)),
                                        lineWidth: isArmed ? 2.0 : 1.0)
                        )
                        .frame(width: 40, height: 40)

                    Text(civ.emblem)
                        .font(.system(size: 20))
                        .foregroundStyle(
                            isArmed ? civ.accentColor
                            : (isAvailable ? (isPlaced ? ink.opacity(0.40) : ink.opacity(0.85))
                               : ink.opacity(0.18))
                        )
                }

                Text(civ.name.components(separatedBy: " ").first ?? civ.name)
                    .font(EgyptFont.body(12))
                    .foregroundStyle(isArmed ? civ.accentColor.opacity(0.95)
                                    : (isAvailable ? ink.opacity(isPlaced ? 0.55 : 0.88) : ink.opacity(0.25)))
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
                        .font(EgyptFont.title(17))
                        .tracking(1)
                        .foregroundStyle(civInfo.accentColor)
                    Text("Tap a slot above to place this stone")
                        .font(EgyptFont.bodyItalic(19))
                        .foregroundStyle(ink.opacity(0.95))
                }
                Spacer()
                Button { gameState.manduArmedCiv = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ink.opacity(0.35))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(civInfo.accentColor.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(civInfo.accentColor.opacity(0.42), lineWidth: 1))
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: civ.rawValue)
        } else {
            Text("Tap a civilization stone, then tap where it belongs on the tree.")
                .font(EgyptFont.bodyItalic(20))
                .foregroundStyle(ink.opacity(0.95))
                .multilineTextAlignment(.center)
                .padding(.vertical, 4)
        }
    }

    // MARK: - Action Row

    private var actionRow: some View {
        HStack(spacing: 12) {
            // Clear — always available
            Button { gameState.resetManduGrid() } label: {
                Label("Clear All", systemImage: "arrow.counterclockwise")
                    .font(EgyptFont.body(18))
                    .foregroundStyle(ink.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(ink.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(ink.opacity(0.22), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            // Check Arrangement — only when all 6 slots filled
            if isManduFull {
                Button { checkArrangement() } label: {
                    Label("Check Arrangement", systemImage: "checkmark.seal")
                        .font(EgyptFont.titleBold(18))
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
        .animation(.spring(response: 0.4), value: isManduFull)
    }

    // MARK: - Mastermind: Check Arrangement

    private func checkArrangement() {
        let snapshot: [String?] = (0..<6).map { gameState.manduPlayerGrid[$0] }
        let correct = gameState.manduCorrectCount

        let attempt = ManduAttempt(civIds: snapshot, correct: correct)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.80)) {
            attempts.append(attempt)
        }

        if correct == 6 {
            HapticFeedback.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startReveal()
            }
        } else {
            HapticFeedback.heavy()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                gameState.resetManduGrid()
            }
        }
    }

    // MARK: - Attempts History

    private var attemptsHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PREVIOUS ARRANGEMENTS")
                .font(EgyptFont.title(14))
                .tracking(2)
                .foregroundStyle(ink.opacity(0.85))

            ForEach(attempts) { attempt in
                attemptRow(attempt)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ink.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(ink.opacity(0.22), lineWidth: 1))
        )
    }

    private func attemptRow(_ attempt: ManduAttempt) -> some View {
        HStack(spacing: 8) {
            // 6 stone dots showing which civ was placed (order preserved)
            HStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { i in
                    let raw = attempt.civIds[i]
                    let civ = raw.flatMap { CivilizationID(rawValue: $0) }
                    let civInfo = civ.flatMap { id in Civilization.all.first(where: { $0.id == id }) }
                    ZStack {
                        Circle()
                            .fill(civInfo.map { $0.accentColor.opacity(0.22) } ?? ink.opacity(0.10))
                            .overlay(Circle()
                                .stroke(civInfo.map { $0.accentColor.opacity(0.55) } ?? ink.opacity(0.18),
                                        lineWidth: 1))
                            .frame(width: 32, height: 32)
                        if let info = civInfo {
                            Text(info.emblem)
                                .font(.system(size: 14))
                        }
                    }
                }
            }

            Spacer()

            // Result badge
            VStack(spacing: 1) {
                Text("\(attempt.correct)")
                    .font(EgyptFont.titleBold(22))
                    .foregroundStyle(attempt.correct == 6 ? gold : ink.opacity(0.92))
                Text("of 6")
                    .font(EgyptFont.body(13))
                    .foregroundStyle(ink.opacity(0.72))
            }
            .frame(minWidth: 48)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(attempt.correct == 6 ? gold.opacity(0.18) : ink.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(attempt.correct == 6 ? gold.opacity(0.55) : ink.opacity(0.20), lineWidth: 1))
            )
        }
    }

    // MARK: - Lore Note

    private var loreNote: some View {
        Text("Six civilizations. One stone. One message.")
            .font(EgyptFont.bodyItalic(21))
            .foregroundStyle(ink.opacity(0.95))
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .padding(.top, 4)
    }

    // MARK: - Reveal Overlay

    private var revealOverlay: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                OakTreeView(progress: treeProgress)
                    .frame(maxWidth: 360)
                    .frame(height: 290)
                    .padding(.horizontal, 8)

                if revealStep > 0 || showFullMsg {
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
                    .transition(.opacity)

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
            .animation(.easeOut(duration: 0.6), value: revealStep > 0)
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
        isAnimating  = true
        revealStep   = 0
        showFullMsg  = false
        treeProgress = 0
        withAnimation(.easeIn(duration: 0.55)) { showReveal = true }
        Task {
            try? await Task.sleep(nanoseconds: 550_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 3.8)) { treeProgress = 1.0 }
            }
            try? await Task.sleep(nanoseconds: 3_900_000_000)
            for step in 1...Civilization.all.count {
                try? await Task.sleep(nanoseconds: 700_000_000)
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
