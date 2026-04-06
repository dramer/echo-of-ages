// ManduTabletView.swift
// EchoOfAges
//
// The Tablet of Mandu — the final puzzle of Echo of Ages.
//
// The player places symbols from every civilization they have mastered
// into the 6×5 stone grid. Each cell shows its decoded word as a hint.
// When all 30 symbols are correctly placed, the Tree of Life is revealed.

import SwiftUI

// MARK: - ManduTabletView

struct ManduTabletView: View {
    @EnvironmentObject var gameState: GameState

    @State private var showReveal  = false
    @State private var revealStep  = 0      // 0=hidden, 1-6=civ lines one at a time
    @State private var showFullMsg = false
    @State private var isAnimating = false
    @State private var showContextBanner = false

    var body: some View {
        ZStack {
            sandBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if showContextBanner {
                            contextBanner
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        tabletTitle
                        tabletGrid
                        selectedHintBanner
                        paletteSection
                        actionRow
                        loreNote
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.4)) { showContextBanner = true }
            }
        }
    }

    // MARK: - Context Banner

    private var contextBannerContent: (icon: String, message: String, isWarning: Bool) {
        if gameState.isManduComplete {
            return (
                icon: "sparkles",
                message: "The stone is complete. Tap \"Read the Stone\" to reveal the final message.",
                isWarning: false
            )
        } else if gameState.allUnlockedCivsComplete {
            let remaining = TabletSlot.all.count - gameState.manduCorrectCount
            return (
                icon: "hand.tap",
                message: "All civilizations mastered. Tap a cell, then place its symbol from the palette below. \(remaining) symbol\(remaining == 1 ? "" : "s") remain.",
                isWarning: false
            )
        } else {
            let completedCount = gameState.civilizationsCompletedForMandu.count
            let totalUnlocked = Civilization.all.filter { $0.isUnlocked }.count
            return (
                icon: "lock.fill",
                message: "You must complete all civilization puzzles before the stone can be filled. \(completedCount) of \(totalUnlocked) unlocked civilizations finished.",
                isWarning: true
            )
        }
    }

    private var contextBanner: some View {
        let content = contextBannerContent
        let accent: Color = content.isWarning ? Color(red: 0.65, green: 0.35, blue: 0.10) : gold
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: content.icon)
                .font(.system(size: 18))
                .foregroundStyle(accent)
                .padding(.top, 1)
            Text(content.message)
                .font(EgyptFont.bodyItalic(19))
                .foregroundStyle(ink.opacity(0.85))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                withAnimation(.easeOut(duration: 0.3)) { showContextBanner = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.30))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(content.isWarning
                      ? Color(red: 0.65, green: 0.35, blue: 0.10).opacity(0.10)
                      : gold.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(accent.opacity(0.35), lineWidth: 1))
        )
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

    private var tabletTitle: some View {
        VStack(spacing: 12) {
            Text("Found on a nameless island. No map charts its location.")
                .font(EgyptFont.bodyItalic(20))
                .foregroundStyle(ink.opacity(0.75))
                .multilineTextAlignment(.center)

            // Progress dots — one per slot, gold when correct
            let correct = gameState.manduCorrectCount
            let total   = TabletSlot.all.count
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(7), spacing: 3), count: 15),
                      spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    Circle()
                        .fill(i < correct ? gold : ink.opacity(0.22))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.3).delay(Double(i) * 0.02), value: correct)
                }
            }
            .padding(.horizontal, 24)

            Text("\(correct) of \(total) correctly placed")
                .font(EgyptFont.body(19))
                .foregroundStyle(correct == total ? gold : ink.opacity(0.65))
        }
    }

    // MARK: - Stone Grid

    private var tabletGrid: some View {
        VStack(spacing: 4) {
            ForEach(Civilization.all) { civ in
                civRow(civ)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.78, green: 0.68, blue: 0.50).opacity(0.45))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(ink.opacity(0.30), lineWidth: 1.5))
        )
    }

    private func civRow(_ civ: Civilization) -> some View {
        let completed = gameState.civilizationsCompletedForMandu.contains(civ.id)
        let slots     = TabletSlot.all.filter { $0.civilization == civ.id }

        return HStack(spacing: 4) {
            VStack(spacing: 2) {
                Text(civ.emblem)
                    .font(.system(size: 18))
                    .foregroundStyle(completed ? civ.accentColor : ink.opacity(0.18))
                if !completed {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(ink.opacity(0.20))
                }
            }
            .frame(width: 26)

            ForEach(slots) { slot in
                stoneCell(slot, civ: civ, completed: completed)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(completed ? civ.accentColor.opacity(0.10) : ink.opacity(0.05))
        )
    }

    private func stoneCell(_ slot: TabletSlot, civ: Civilization, completed: Bool) -> some View {
        let placed     = gameState.manduPlayerGrid[slot.id]
        let isCorrect  = placed == slot.character
        let isSelected = gameState.manduSelectedSlotId == slot.id

        return Button {
            if completed { gameState.tapManduSlot(slot.id) }
            else { HapticFeedback.error() }
        } label: {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(stoneCellFill(completed: completed, correct: isCorrect, selected: isSelected))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(stoneCellBorder(civ: civ, correct: isCorrect,
                                                    selected: isSelected, completed: completed),
                                    lineWidth: isSelected ? 2.0 : 0.8)
                    )

                VStack(spacing: 1) {
                    if let placed {
                        Text(placed)
                            .font(.system(size: 20))
                            .foregroundStyle(isCorrect ? civ.accentColor : ink)
                            .minimumScaleFactor(0.5)
                    } else {
                        Spacer()
                    }
                    Text(slot.decoded)
                        .font(EgyptFont.body(10))
                        .foregroundStyle(completed
                                         ? (isCorrect ? civ.accentColor.opacity(0.80) : ink.opacity(0.60))
                                         : ink.opacity(0.10))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.bottom, 3)
                .padding(.top, placed != nil ? 4 : 2)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 48)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCorrect)
    }

    private func stoneCellFill(completed: Bool, correct: Bool, selected: Bool) -> Color {
        guard completed else { return ink.opacity(0.05) }
        if correct  { return Color(red: 0.93, green: 0.80, blue: 0.45).opacity(0.30) }
        if selected { return Color(red: 0.98, green: 0.93, blue: 0.78) }
        return Color(red: 0.85, green: 0.77, blue: 0.60)
    }

    private func stoneCellBorder(civ: Civilization, correct: Bool, selected: Bool, completed: Bool) -> Color {
        guard completed else { return ink.opacity(0.08) }
        if correct  { return civ.accentColor.opacity(0.75) }
        if selected { return ink.opacity(0.65) }
        return ink.opacity(0.22)
    }

    // MARK: - Selection Hint Banner

    @ViewBuilder
    private var selectedHintBanner: some View {
        if let slotId = gameState.manduSelectedSlotId,
           let slot = TabletSlot.all.first(where: { $0.id == slotId }),
           let civ  = Civilization.all.first(where: { $0.id == slot.civilization }) {
            HStack(spacing: 12) {
                Text(civ.emblem).font(.system(size: 24)).foregroundStyle(civ.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(civ.name)
                        .font(EgyptFont.title(17))
                        .tracking(1)
                        .foregroundStyle(civ.accentColor)
                    Text("Place the symbol that means \"\(slot.decoded)\"")
                        .font(EgyptFont.bodyItalic(19))
                        .foregroundStyle(ink.opacity(0.85))
                }
                Spacer()
                Button { gameState.manduSelectedSlotId = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ink.opacity(0.30))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(civ.accentColor.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(civ.accentColor.opacity(0.38), lineWidth: 1))
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Palette

    private var paletteSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("ALL SYMBOLS")
                    .font(EgyptFont.title(18))
                    .tracking(2)
                    .foregroundStyle(ink.opacity(0.70))
                Spacer()
                if gameState.manduSelectedSlotId == nil {
                    Text("tap a cell above first")
                        .font(EgyptFont.bodyItalic(18))
                        .foregroundStyle(ink.opacity(0.55))
                }
            }

            ForEach(Civilization.all) { civ in
                civPaletteRow(civ)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.86, green: 0.78, blue: 0.60).opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(ink.opacity(0.18), lineWidth: 1))
        )
    }

    private func civPaletteRow(_ civ: Civilization) -> some View {
        let completed = gameState.civilizationsCompletedForMandu.contains(civ.id)
        let isActive: Bool = {
            guard let sid = gameState.manduSelectedSlotId,
                  let s   = TabletSlot.all.first(where: { $0.id == sid }) else { return false }
            return s.civilization == civ.id
        }()

        return HStack(spacing: 5) {
            Text(civ.emblem)
                .font(.system(size: 19))
                .foregroundStyle(completed ? civ.accentColor : ink.opacity(0.14))
                .frame(width: 26)

            HStack(spacing: 4) {
                ForEach(civ.symbols) { sym in
                    if completed {
                        Button { gameState.placeManduSymbol(sym.character) } label: {
                            symButton(sym, accent: civ.accentColor, active: isActive)
                        }
                        .buttonStyle(.plain)
                        .disabled(gameState.manduSelectedSlotId == nil)
                    } else {
                        symLocked(sym)
                    }
                }
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? civ.accentColor.opacity(0.10) : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? civ.accentColor.opacity(0.32) : Color.clear, lineWidth: 1))
        )
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    private func symButton(_ sym: ScriptSymbol, accent: Color, active: Bool) -> some View {
        VStack(spacing: 4) {
            Text(sym.character).font(.system(size: 36)).foregroundStyle(accent)
            Text(sym.transliteration.uppercased())
                .font(EgyptFont.body(13)).foregroundStyle(accent.opacity(0.80))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(active ? accent.opacity(0.18) : ink.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(accent.opacity(active ? 0.50 : 0.22), lineWidth: 1))
        )
    }

    private func symLocked(_ sym: ScriptSymbol) -> some View {
        VStack(spacing: 4) {
            Text(sym.character).font(.system(size: 36)).foregroundStyle(ink.opacity(0.08))
            Text(sym.transliteration.uppercased())
                .font(EgyptFont.body(13)).foregroundStyle(ink.opacity(0.08))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ink.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(ink.opacity(0.08), lineWidth: 1))
        )
    }

    // MARK: - Action Row

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button { gameState.resetManduGrid() } label: {
                Label("Clear Stone", systemImage: "arrow.counterclockwise")
                    .font(EgyptFont.body(20))
                    .foregroundStyle(ink.opacity(0.80))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(ink.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(ink.opacity(0.22), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            if gameState.isManduComplete {
                Button { startReveal() } label: {
                    Label("Read the Stone", systemImage: "sparkles")
                        .font(EgyptFont.titleBold(21))
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
        Text("Thirty symbols. Six civilizations. One message. Solve every puzzle to unlock every symbol. Place each one where it belongs. The stone will speak.")
            .font(EgyptFont.bodyItalic(19))
            .foregroundStyle(ink.opacity(0.65))
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

    // MARK: - Colours

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
