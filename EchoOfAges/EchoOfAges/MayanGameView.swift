// MayanGameView.swift
// EchoOfAges
//
// Calendar pattern puzzle screen for the Maya civilization.
//
// Layout:
//   • Header bar — back, title, level numeral
//   • Level title / subtitle / lore
//   • Concentric ring wheel — one ring per cycle; cells arranged around the circumference
//   • Symbol palette — tap to arm a glyph, then tap a blank cell to place it
//   • Verify / Reset buttons
//   • Collapsible field inscriptions
//   • Level-complete overlay

import SwiftUI

struct MayanGameView: View {
    @EnvironmentObject var gameState: GameState

    @State private var showComplete    = false
    @State private var messageRevealed = false
    @State private var inscriptionsExpanded = false

    private var level: MayanLevel { gameState.mayanCurrentLevel }

    // MARK: - Body

    var body: some View {
        if level.usesWheelMechanic {
            MayanWheelView()
        } else {
            regularBody
        }
    }

    private var regularBody: some View {
        GeometryReader { geo in
            ZStack {
                jungleBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar
                    staticMainContent(geo: geo)
                }

                if showComplete {
                    Color.black.opacity(0.55).ignoresSafeArea()
                        .transition(.opacity).zIndex(9)
                    levelCompleteCard(maxHeight: geo.size.height * 0.88)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                        .zIndex(10)
                }
            }
        }
        .onChange(of: gameState.mayanPendingComplete) { _, newVal in
            if newVal {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    showComplete = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    withAnimation(.easeOut(duration: 0.6)) { messageRevealed = true }
                }
            }
        }
        .onDisappear {
            showComplete = false
            messageRevealed = false
        }
    }

    @ViewBuilder
    private func staticMainContent(geo: GeometryProxy) -> some View {
        if geo.size.width > geo.size.height && UIDevice.current.userInterfaceIdiom == .pad {
            staticLandscapeContent(geo)
        } else {
            staticPortraitContent(geo)
        }
    }

    private func staticPortraitContent(_ geo: GeometryProxy) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                levelHeader
                wheelView(geo: geo, isLandscape: false)
                palette
                actionRow
                inscriptionsSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private func staticLandscapeContent(_ geo: GeometryProxy) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Left column: static wheel only
            wheelView(geo: geo, isLandscape: true)
                .frame(maxHeight: .infinity, alignment: .center)

            // Right column: controls + inscriptions
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    levelHeader
                    palette
                    actionRow
                    inscriptionsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Button(action: { gameState.closeMayanGame() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Journal")
                        .font(EgyptFont.body(17))
                }
                .foregroundStyle(jadeColor)
            }
            Spacer()
            VStack(spacing: 1) {
                Text("MAYA")
                    .font(EgyptFont.titleBold(16))
                    .tracking(3)
                    .foregroundStyle(jadeColor)
                Text("Calendar Puzzles")
                    .font(EgyptFont.body(12))
                    .foregroundStyle(jadeColor.opacity(0.6))
            }
            Spacer()
            Text(level.romanNumeral)
                .font(EgyptFont.titleBold(22))
                .foregroundStyle(jadeColor)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Color(red: 0.06, green: 0.12, blue: 0.08)
                .overlay(
                    Rectangle()
                        .fill(jadeColor.opacity(0.3))
                        .frame(height: 0.8),
                    alignment: .bottom
                )
        )
    }

    // MARK: - Level Header

    private var levelHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(level.title)
                .font(EgyptFont.titleBold(20))
                .foregroundStyle(jadeColor)
            Text(level.subtitle)
                .font(EgyptFont.bodyItalic(14))
                .foregroundStyle(jadeColor.opacity(0.65))
            Text(level.lore)
                .font(EgyptFont.body(13))
                .foregroundStyle(Color.papyrus.opacity(0.80))
                .lineSpacing(3)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.14, blue: 0.10).opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(jadeColor.opacity(0.25), lineWidth: 0.8))
        )
    }

    // MARK: - Wheel View

    private func wheelView(geo: GeometryProxy, isLandscape: Bool) -> some View {
        let diam   = wheelDiameter(geo: geo, isLandscape: isLandscape)
        let radius = diam / 2
        let (innerR, spacing, cellSz) = ringGeometry(radius: radius)
        let outerR = innerR + CGFloat(max(0, level.cycles.count - 1)) * spacing

        let isKeyGate = gameState.mayanCurrentLevelIndex == 0 && gameState.needsKeyGate(for: .maya)
        let mysterySymbol: String? = isKeyGate ? gameState.mysteryMarkCurrent(for: .maya) : nil

        return VStack(spacing: 10) {
            ZStack {
                // Hub decoration — doubles as mystery mark selector on Level 1
                hubDecoration(innerRadius: innerR, mysterySymbol: mysterySymbol)

                // One ring per cycle
                ForEach(0..<level.cycles.count, id: \.self) { ci in
                    let cycle = level.cycles[ci]
                    let r     = innerR + CGFloat(ci) * spacing

                    // Ring track
                    Circle()
                        .stroke(jadeColor.opacity(0.15), lineWidth: 0.8)
                        .frame(width: r * 2, height: r * 2)

                    // Cells arranged clockwise from 12 o'clock
                    ForEach(0..<level.sequenceLength, id: \.self) { pos in
                        let angle = CGFloat(pos) / CGFloat(level.sequenceLength) * 2 * .pi - .pi / 2
                        wheelCell(cycleIdx: ci, pos: pos, cycle: cycle, size: cellSz)
                            .offset(x: cos(angle) * r, y: sin(angle) * r)
                    }
                }

                // Position-0 start indicator — small arrowhead at 12 o'clock
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(jadeColor.opacity(0.32))
                    .offset(y: -(outerR + cellSz / 2 + 7))
            }
            .frame(width: diam, height: diam)

            cycleLegend
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.05, green: 0.10, blue: 0.07))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(jadeColor.opacity(0.20), lineWidth: 0.8))
        )
    }

    // Hub: decorative bordered circle — becomes mystery mark cycling selector on Level 1
    private func hubDecoration(innerRadius r: CGFloat, mysterySymbol: String?) -> some View {
        let isWrong = gameState.mysteryMarkWrongFlash
        let isMystery = mysterySymbol != nil
        return ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        isMystery
                            ? Color(red: 0.28, green: 0.20, blue: 0.04).opacity(isWrong ? 0.6 : 1.0)
                            : jadeColor.opacity(0.22),
                        Color(red: 0.04, green: 0.08, blue: 0.05)
                    ],
                    center: .center, startRadius: 0, endRadius: r * 0.58
                ))
                .frame(width: r * 1.2, height: r * 1.2)
            Circle()
                .stroke(
                    isMystery
                        ? (isWrong ? Color.red.opacity(0.80) : Color(red: 0.90, green: 0.72, blue: 0.25).opacity(0.90))
                        : jadeColor.opacity(0.38),
                    lineWidth: isMystery ? 2.0 : 1.2
                )
                .frame(width: r * 1.2, height: r * 1.2)
                .animation(.easeInOut(duration: 0.25), value: isWrong)

            if let symbol = mysterySymbol {
                VStack(spacing: 2) {
                    Text(symbol)
                        .font(.system(size: max(24, r * 0.44)))
                        .foregroundStyle(isWrong
                            ? Color.red.opacity(0.85)
                            : Color(red: 0.95, green: 0.82, blue: 0.40))
                        .contentTransition(.numericText())
                    Image(systemName: "arrow.2.circlepath")
                        .font(.system(size: max(9, r * 0.16), weight: .semibold))
                        .foregroundStyle(Color(red: 0.90, green: 0.72, blue: 0.25).opacity(0.70))
                }
                .animation(.easeInOut(duration: 0.25), value: isWrong)
            } else {
                Image(systemName: level.artifact)
                    .font(.system(size: max(22, r * 0.32)))
                    .foregroundStyle(jadeColor.opacity(0.68))
            }
        }
        .onTapGesture {
            if isMystery { gameState.cycleMysteryMark(for: .maya) }
        }
    }

    // MARK: - Cycle Legend

    private var cycleLegend: some View {
        HStack(spacing: 20) {
            ForEach(Array(level.cycles.enumerated()), id: \.offset) { _, cycle in
                HStack(spacing: 5) {
                    Circle()
                        .stroke(jadeColor.opacity(0.70), lineWidth: 1.1)
                        .frame(width: 8, height: 8)
                    Text(cycle.label)
                        .font(EgyptFont.body(11))
                        .foregroundStyle(jadeColor.opacity(0.60))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Wheel Diameter

    private func wheelDiameter(geo: GeometryProxy, isLandscape: Bool) -> CGFloat {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        if isLandscape {
            // Left column takes ~50 % of width; wheel must also fit in available height
            let leftColW = geo.size.width * 0.50 - 64
            let availH   = geo.size.height - 36
            return min(leftColW, availH, 600)
        } else {
            let availW   = geo.size.width - 36
            let reserved: CGFloat = isPhone ? 380 : 540
            let maxFromH = geo.size.height - reserved
            let candidate = min(availW, max(maxFromH, 280))
            return isPhone ? candidate : min(candidate, 640)
        }
    }

    // MARK: - Ring Geometry
    //
    // All dimensions scale proportionally with the wheel radius so the puzzle
    // looks correct on every device and orientation.
    //
    //   innerFracs: inner-ring radius as a fraction of the wheel radius, by cycle count
    //   cellSize: sized to fill ~70 % of the arc per cell at the inner ring
    //   ringSpacing: remaining rings spread evenly to the wheel edge

    private func ringGeometry(radius: CGFloat) -> (innerRadius: CGFloat, ringSpacing: CGFloat, cellSize: CGFloat) {
        let n          = level.cycles.count
        let seqLen     = CGFloat(level.sequenceLength)
        let innerFracs = [CGFloat(0), 0.62, 0.40, 0.34]
        let innerR     = radius * (n < innerFracs.count ? innerFracs[n] : 0.34)
        let arcPerCell = (2 * .pi * innerR) / seqLen
        let cellSize   = max(28, min(54, arcPerCell * 0.70))
        let outerEdge  = radius - cellSize / 2 - 4
        let ringSpacing = n > 1 ? (outerEdge - innerR) / CGFloat(n - 1) : 0
        return (innerR, ringSpacing, cellSize)
    }

    // MARK: - Wheel Cell

    @ViewBuilder
    private func wheelCell(cycleIdx: Int, pos: Int, cycle: MayanCycle, size: CGFloat) -> some View {
        let isRevealed   = cycle.isRevealed(pos)
        let correctGlyph = cycle.symbol(at: pos)
        let playerGlyph: MayanGlyph? = {
            guard gameState.mayanPlayerGrid.indices.contains(cycleIdx),
                  gameState.mayanPlayerGrid[cycleIdx].indices.contains(pos)
            else { return nil }
            return gameState.mayanPlayerGrid[cycleIdx][pos]
        }()
        let coord        = MayanCellCoord(cycle: cycleIdx, position: pos)
        let isSelected   = gameState.mayanSelectedCell == coord
        let isError      = gameState.mayanErrorCells.contains(coord)
        let displayGlyph: MayanGlyph? = isRevealed ? correctGlyph : playerGlyph

        ZStack {
            Circle()
                .fill(isError    ? Color(red: 0.55, green: 0.06, blue: 0.06).opacity(0.85)
                      : isRevealed ? jadeColor.opacity(0.28)
                      : isSelected ? jadeColor.opacity(0.20)
                      : Color.white.opacity(0.06))
                .overlay(
                    Circle()
                        .stroke(isError    ? Color.red.opacity(0.7)
                                : isSelected ? jadeColor
                                : isRevealed ? jadeColor.opacity(0.50)
                                : jadeColor.opacity(0.20),
                                lineWidth: isSelected ? 1.5 : 0.8)
                )

            if let glyph = displayGlyph {
                Image(systemName: glyph.sfSymbol)
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(isRevealed ? jadeColor : Color.white)
            }
        }
        .frame(width: size, height: size)
        .onTapGesture {
            guard !isRevealed else { return }
            HapticFeedback.tap()
            if gameState.mayanSelectedCell == coord {
                gameState.mayanSelectedCell = nil
            } else if let armed = gameState.mayanArmedGlyph {
                gameState.placeMayanGlyph(armed, at: coord)
                gameState.mayanArmedGlyph = nil
                gameState.mayanSelectedCell = nil
            } else {
                gameState.mayanSelectedCell = coord
            }
        }
        .onLongPressGesture {
            guard !isRevealed else { return }
            HapticFeedback.tap()
            gameState.clearMayanCell(coord)
        }
    }

    // MARK: - Palette

    private var palette: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SYMBOLS")
                .font(EgyptFont.title(11))
                .foregroundStyle(jadeColor.opacity(0.55))
                .tracking(2)

            HStack(spacing: 10) {
                ForEach(MayanGlyph.allCases) { glyph in
                    Button(action: {
                        HapticFeedback.tap()
                        if gameState.mayanArmedGlyph == glyph {
                            gameState.mayanArmedGlyph = nil
                        } else {
                            gameState.mayanArmedGlyph = glyph
                            if let coord = gameState.mayanSelectedCell {
                                gameState.placeMayanGlyph(glyph, at: coord)
                                gameState.mayanArmedGlyph = nil
                                gameState.mayanSelectedCell = nil
                            }
                        }
                    }) {
                        VStack(spacing: 3) {
                            Image(systemName: glyph.sfSymbol)
                                .font(.system(size: 22))
                            Text(glyph.displayName)
                                .font(EgyptFont.body(9))
                                .foregroundStyle(jadeColor.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(gameState.mayanArmedGlyph == glyph
                                      ? jadeColor.opacity(0.35)
                                      : Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(gameState.mayanArmedGlyph == glyph
                                            ? jadeColor
                                            : jadeColor.opacity(0.20),
                                            lineWidth: gameState.mayanArmedGlyph == glyph ? 1.4 : 0.7))
                        )
                        .foregroundStyle(Color.white)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.05, green: 0.10, blue: 0.07))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(jadeColor.opacity(0.20), lineWidth: 0.8))
        )
    }

    // MARK: - Action Row

    private var actionRow: some View {
        let canDecipher = level.isFullyFilled(gameState.mayanPlayerGrid)
        return HStack(spacing: 12) {
            Button(action: {
                HapticFeedback.tap()
                gameState.verifyMayanPlacement()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 15))
                    Text("Decipher").font(EgyptFont.title(15))
                }
                .foregroundStyle(canDecipher ? jadeColor : jadeColor.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(jadeColor.opacity(canDecipher ? 0.12 : 0.05))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(jadeColor.opacity(canDecipher ? 0.45 : 0.18), lineWidth: 1))
                )
            }
            .disabled(!canDecipher)

            Button(action: {
                HapticFeedback.tap()
                gameState.resetMayanGrid()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 15))
                    Text("Reset").font(EgyptFont.title(15))
                }
                .foregroundStyle(Color(red: 0.75, green: 0.55, blue: 0.35))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.75, green: 0.55, blue: 0.35).opacity(0.35), lineWidth: 1))
                )
            }
        }
    }

    // MARK: - Inscriptions

    private var inscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                HapticFeedback.tap()
                withAnimation(.easeInOut(duration: 0.25)) {
                    inscriptionsExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: inscriptionsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                    Text("Field Inscriptions")
                        .font(EgyptFont.title(13))
                        .tracking(1)
                    Spacer()
                    Text("\(level.inscriptions.count) entries")
                        .font(EgyptFont.body(12))
                        .foregroundStyle(jadeColor.opacity(0.5))
                }
                .foregroundStyle(jadeColor.opacity(0.7))
                .padding(14)
            }

            if inscriptionsExpanded {
                let acrostic = TreeOfLifeKeys.acrosticLetter(for: .maya, levelIndex: gameState.mayanCurrentLevelIndex)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(level.inscriptions.enumerated()), id: \.offset) { _, note in
                        HStack(alignment: .top, spacing: 10) {
                            Text("–")
                                .font(EgyptFont.body(13))
                                .foregroundStyle(jadeColor.opacity(0.45))
                            Text(acrosticUnderlined(note, letter: acrostic))
                                .font(EgyptFont.bodyItalic(14))
                                .foregroundStyle(Color.papyrus.opacity(0.75))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.05, green: 0.10, blue: 0.07))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(jadeColor.opacity(0.20), lineWidth: 0.8))
        )
    }

    // MARK: - Level Complete Card

    private func levelCompleteCard(maxHeight: CGFloat) -> some View {
        let isLastLevel = gameState.mayanCurrentLevelIndex == MayanLevel.allLevels.count - 1
        let newCivs     = isLastLevel ? gameState.newlyUnlockedCivs(completingLevel5Of: .maya) : []

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer(minLength: 20)

                Image(systemName: level.artifact)
                    .font(.system(size: 60))
                    .foregroundStyle(jadeColor)
                    .shadow(color: jadeColor.opacity(0.7), radius: 12, x: 0, y: 0)

                VStack(spacing: 8) {
                    Text("Calendar Decoded")
                        .font(EgyptFont.titleBold(26))
                        .foregroundStyle(jadeColor)
                        .tracking(2)
                    Text(level.journalTitle)
                        .font(EgyptFont.bodyItalic(17))
                        .foregroundStyle(Color.papyrus)
                }

                if messageRevealed {
                    Text(level.decodedMessage)
                        .font(EgyptFont.bodyItalic(15))
                        .foregroundStyle(Color.papyrus.opacity(0.85))
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .transition(.opacity)

                    // Journal nudge
                    HStack(spacing: 8) {
                        Image(systemName: "book.fill").font(.system(size: 11))
                            .foregroundStyle(jadeColor.opacity(0.60))
                        Text("A new entry has been written in your Field Diary.")
                            .font(EgyptFont.bodyItalic(13))
                            .foregroundStyle(jadeColor.opacity(0.60))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .transition(.opacity)

                    // Level 5 — key earned + newly unlocked civs
                    if isLastLevel {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "key.fill").font(.system(size: 12))
                                    .foregroundStyle(jadeColor)
                                Text("The Maya key has been carved in your Field Diary.")
                                    .font(EgyptFont.bodyItalic(13))
                                    .foregroundStyle(jadeColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if !newCivs.isEmpty {
                                Text("NEW PATHS OPEN")
                                    .font(EgyptFont.title(11))
                                    .foregroundStyle(jadeColor.opacity(0.55))
                                    .tracking(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(newCivs) { civ in
                                    HStack(spacing: 12) {
                                        Text(civ.emblem).font(.system(size: 24))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(civ.name).font(EgyptFont.titleBold(14))
                                                .foregroundStyle(civ.accentColor)
                                            Text(civ.era).font(EgyptFont.bodyItalic(12))
                                                .foregroundStyle(Color.papyrus.opacity(0.55))
                                        }
                                        Spacer()
                                        Image(systemName: "lock.open.fill").font(.system(size: 12))
                                            .foregroundStyle(Color.goldMid)
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(red: 0.05, green: 0.10, blue: 0.07).opacity(0.8))
                                            .overlay(RoundedRectangle(cornerRadius: 8)
                                                .stroke(civ.accentColor.opacity(0.35), lineWidth: 1))
                                    )
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.04, green: 0.09, blue: 0.06).opacity(0.8))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(jadeColor.opacity(0.30), lineWidth: 1))
                        )
                        .transition(.opacity)
                    }
                }

                VStack(spacing: 10) {
                    if isLastLevel && gameState.allSixCivsComplete {
                        Button {
                            HapticFeedback.heavy()
                            gameState.mayanPendingComplete = false
                            withAnimation(.easeInOut(duration: 0.4)) { gameState.openManduTablet() }
                        } label: {
                            StoneButton(title: "Open the Mandu Tablet", icon: "seal.fill", style: .gold)
                        }
                    } else if isLastLevel {
                        Button {
                            HapticFeedback.heavy()
                            gameState.mayanPendingComplete = false
                            withAnimation(.easeInOut(duration: 0.4)) { gameState.startNewGame() }
                        } label: {
                            StoneButton(title: "Continue Expedition", icon: "arrow.right", style: .gold)
                        }
                    } else {
                        Button {
                            HapticFeedback.tap()
                            gameState.advanceMayanToNextLevel()
                        } label: {
                            StoneButton(title: "Next Tablet", icon: "arrow.right", style: .gold)
                        }
                    }
                    Button {
                        HapticFeedback.tap()
                        gameState.openJournal()
                    } label: {
                        StoneButton(title: "Open Field Diary", icon: "book.fill", style: .muted)
                    }
                }
                .padding(.horizontal, 8)

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.06, green: 0.12, blue: 0.08))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(jadeColor.opacity(0.5), lineWidth: 1.2))
        )
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
        .padding(.horizontal, 24)
        .frame(maxHeight: maxHeight)
    }

    // MARK: - Background & Colors

    private var jungleBackground: some View {
        ZStack {
            Color(red: 0.04, green: 0.08, blue: 0.05)
            RadialGradient(
                colors: [Color(red: 0.10, green: 0.22, blue: 0.12).opacity(0.6), .clear],
                center: .topLeading, startRadius: 60, endRadius: 420
            )
        }
    }

    private var jadeColor: Color {
        Color(red: 0.18, green: 0.72, blue: 0.42)
    }
}
