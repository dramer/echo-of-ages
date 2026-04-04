// GlyphGridView.swift
// EchoOfAges
//
// Game screen with image-button toolbar at top.
// Field Notes and Known Glyphs open as large modal sheets.
// No scrolling — everything fits on one screen.

import SwiftUI

// MARK: - Game Screen

struct GameView: View {
    @EnvironmentObject var gameState: GameState

    // Modal state
    @State private var showFieldNotes  = false
    @State private var showKnownGlyphs = false

    // Toast state
    @State private var toastMessage:     String = ""
    @State private var toastVisible:     Bool   = false
    @State private var toastDismissTask: Task<Void, Never>? = nil
    @State private var idleHintTask:     Task<Void, Never>? = nil
    @State private var hasInteracted:    Bool   = false
    @State private var levelInitialGrid: [[Glyph?]] = []

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                stoneBackground

                if geo.size.width > geo.size.height {
                    landscapeLayout(geo: geo)
                } else {
                    portraitLayout(geo: geo)
                }

                // Centred toast overlay
                if toastVisible {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(9)
                    ToastView(message: toastMessage)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.88).combined(with: .opacity),
                            removal:   .opacity))
                        .zIndex(10)
                }
            }
        }
        .background(stoneBackground)
        .sheet(isPresented: $showFieldNotes) {
            FieldNotesModal().environmentObject(gameState)
        }
        .sheet(isPresented: $showKnownGlyphs) {
            KnownGlyphsModal().environmentObject(gameState)
        }
        .onAppear {
            levelInitialGrid = gameState.playerGrid
            hasInteracted    = false
            scheduleIdleHint()
        }
        .onChange(of: gameState.currentLevelIndex) { _, _ in
            levelInitialGrid = gameState.playerGrid
            hasInteracted    = false
            cancelIdleHint()
            scheduleIdleHint()
        }
        .onChange(of: gameState.playerGrid) { _, newGrid in
            guard !hasInteracted else { return }
            if newGrid != levelInitialGrid {
                hasInteracted = true
                cancelIdleHint()
            } else {
                hasInteracted = false
                cancelIdleHint()
                scheduleIdleHint()
            }
        }
    }

    // MARK: Portrait Layout

    @ViewBuilder
    private func portraitLayout(geo: GeometryProxy) -> some View {
        let barH:       CGFloat = 84
        let titleH:     CGFloat = 52
        let paletteH:   CGFloat = 78
        let spacing:    CGFloat = 8 * 4
        let safeBottom: CGFloat = 16
        let reserved  = barH + titleH + paletteH + spacing + safeBottom
        let gridAvailH = geo.size.height - reserved
        let gridAvailW = geo.size.width - 32

        VStack(spacing: 0) {
            imageButtonBar
                .padding(.horizontal, 12)
                .padding(.top, 10)

            Spacer(minLength: 8)
            levelTitle.padding(.horizontal, 16)
            Spacer(minLength: 8)

            GlyphGridView(availableWidth: gridAvailW,
                          availableHeight: max(gridAvailH, 100))
                .padding(.horizontal, 16)

            Spacer(minLength: 10)
            palette.padding(.horizontal, 16)
            Spacer(minLength: safeBottom)
        }
    }

    // MARK: Landscape Layout

    @ViewBuilder
    private func landscapeLayout(geo: GeometryProxy) -> some View {
        let leftW  = geo.size.width * 0.55
        let rightW = geo.size.width - leftW
        let barH:  CGFloat = 84
        let gridAvailW = leftW - 28
        let gridAvailH = geo.size.height - barH - 28

        VStack(spacing: 0) {
            imageButtonBar
                .padding(.horizontal, 12)
                .padding(.top, 10)

            HStack(spacing: 0) {
                // ── Left: grid ──
                VStack(spacing: 6) {
                    GlyphGridView(availableWidth: gridAvailW,
                                  availableHeight: max(gridAvailH, 80))
                        .padding(.horizontal, 14)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                .frame(width: leftW)

                Rectangle()
                    .fill(Color.goldDark.opacity(0.22))
                    .frame(width: 1)
                    .padding(.vertical, 16)

                // ── Right: title + palette ──
                VStack(spacing: 0) {
                    levelTitle
                    Spacer(minLength: 10)
                    palette
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(width: rightW)
            }
        }
    }

    // MARK: Image Button Bar

    private var imageButtonBar: some View {
        HStack(spacing: 0) {
            toolbarButton(asset: "open_journal",  fallback: "book.fill",
                          label: "Diary")       { gameState.openJournal() }
            toolbarButton(asset: "field_notes",   fallback: "pencil",
                          label: "Notes")       { showFieldNotes = true }
            toolbarButton(asset: "known_glypths", fallback: "magnifyingglass",
                          label: "Glyphs")      { showKnownGlyphs = true }
            toolbarButton(asset: "desipher",      fallback: "eye.fill",
                          label: "Decipher")    { handleDecipher() }
            toolbarButton(asset: "reset",         fallback: "arrow.counterclockwise",
                          label: "Reset")       { gameState.resetCurrentLevel() }
            toolbarButton(asset: "settings",      fallback: "gearshape.fill",
                          label: "Settings")    { gameState.openSettings() }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.stoneMid.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.goldDark.opacity(0.4), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
    }

    /// Single toolbar button: shows the image asset if it has artwork, otherwise the fallback SF symbol.
    private func toolbarButton(asset: String,
                               fallback: String,
                               label: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticFeedback.tap()
            action()
        }) {
            VStack(spacing: 4) {
                if UIImage(named: asset) != nil {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 44)
                } else {
                    Image(systemName: fallback)
                        .font(.system(size: 26))
                        .foregroundStyle(Color.goldMid)
                        .frame(height: 44)
                }
                Text(label)
                    .font(EgyptFont.body(11))
                    .foregroundStyle(Color.stoneSurface)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Level Title

    private var levelTitle: some View {
        VStack(spacing: 3) {
            Text("· \(gameState.currentLevel.romanNumeral) · \(gameState.currentLevel.title.uppercased())")
                .font(EgyptFont.titleBold(17))
                .foregroundStyle(Color.goldBright)
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(gameState.currentLevel.subtitle)
                .font(EgyptFont.bodyItalic(14))
                .foregroundStyle(Color.papyrus.opacity(0.75))
                .lineLimit(1)
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 2)
    }

    // MARK: Glyph Palette

    private var palette: some View {
        VStack(spacing: 8) {
            Text("Place a Glyph")
                .font(EgyptFont.body(13))
                .foregroundStyle(Color.stoneSurface)
            HStack(spacing: 8) {
                ForEach(gameState.currentLevel.availableGlyphs) { glyph in
                    PaletteButton(
                        glyph: glyph,
                        isSelected: gameState.selectedGlyph == glyph
                    ) { gameState.selectGlyph(glyph) }
                }
            }
        }
    }

    // MARK: Decipher action

    private func handleDecipher() {
        if isGridComplete {
            gameState.verifyPlacement()
        } else {
            HapticFeedback.error()
            showToast(
                "Every tile must be filled before deciphering. Tap the empty cells and place a glyph in each one.",
                duration: 5.0
            )
        }
    }

    private var isGridComplete: Bool {
        let level = gameState.currentLevel
        for row in 0..<level.rows {
            for col in 0..<level.cols {
                if gameState.playerGrid[row][col] == nil { return false }
            }
        }
        return true
    }

    // MARK: Toast

    private func showToast(_ message: String, duration: Double = 5.0) {
        toastDismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.45)) {
            toastMessage = message
            toastVisible = true
        }
        toastDismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            withAnimation(.easeIn(duration: 0.55)) { toastVisible = false }
        }
    }

    private func scheduleIdleHint() {
        idleHintTask?.cancel()
        idleHintTask = Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !hasInteracted else { return }
            showToast(idleHintText, duration: 6.5)
        }
    }

    private func cancelIdleHint() {
        idleHintTask?.cancel()
        idleHintTask = nil
    }

    private var idleHintText: String {
        let idx = gameState.currentLevelIndex
        if idx == 0 {
            return "Tap any empty cell, then choose a glyph from the palette below. Each glyph must appear exactly once in every row and column — no repeats anywhere."
        } else {
            let prev = Level.allLevels[idx - 1]
            return "You solved the \(prev.title) tablet — each glyph appeared once per row and column. This inscription follows the same sacred rule, but the arrangement is completely different. Study the fixed symbols first for your opening clues."
        }
    }

    // MARK: Background

    private var stoneBackground: some View {
        ZStack {
            Color.stoneDark.ignoresSafeArea()
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.35)],
                center: .center, startRadius: 200, endRadius: 500
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Glyph Grid

struct GlyphGridView: View {
    @EnvironmentObject var gameState: GameState
    let availableWidth:  CGFloat
    let availableHeight: CGFloat

    private var level: Level { gameState.currentLevel }

    private var cellSize: CGFloat {
        let hSpacing = CGFloat(level.cols - 1) * 6
        let vSpacing = CGFloat(level.rows - 1) * 6
        let pad: CGFloat = 20
        let byWidth  = (availableWidth  - hSpacing - pad) / CGFloat(level.cols)
        let byHeight = (availableHeight - vSpacing - pad) / CGFloat(level.rows)
        return min(byWidth, byHeight, 80)
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<level.rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<level.cols, id: \.self) { col in
                        let pos = GridPosition(row: row, col: col)
                        GlyphCellView(
                            glyph:    gameState.playerGrid[row][col],
                            isFixed:  level.isFixed(pos),
                            isError:  gameState.errorCells.contains(pos),
                            isComplete: gameState.isAnimatingCompletion,
                            size:     cellSize,
                            onTap:       { gameState.tapCell(at: pos) },
                            onLongPress: { gameState.clearCell(at: pos) }
                        )
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.stoneMid.opacity(0.4))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.goldDark.opacity(0.35), lineWidth: 1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.goldBright, lineWidth: 2.5)
                .opacity(gameState.isAnimatingCompletion ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true),
                           value: gameState.isAnimatingCompletion)
        )
    }
}

// MARK: - Palette Button

private struct PaletteButton: View {
    let glyph: Glyph
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(glyph.rawValue).font(.system(size: 26))
                Text(glyph.displayName.replacingOccurrences(of: "The ", with: ""))
                    .font(EgyptFont.body(10)).lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.stoneDark : Color.goldMid)
            .padding(.vertical, 7).padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected
                          ? LinearGradient(colors: [.goldBright, .goldMid], startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [.stoneMid, .stoneDark],  startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 9)
                        .stroke(isSelected ? Color.goldBright : Color.stoneLight.opacity(0.4), lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
            .scaleEffect(isSelected ? 1.06 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
        }
    }
}

// MARK: - Field Notes Modal

struct FieldNotesModal: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.stoneDark.ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.22, green: 0.14, blue: 0.05).opacity(0.5), .clear],
                center: .center, startRadius: 80, endRadius: 380
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                modalHeader(
                    icon:  "pencil",
                    title: "Field Notes",
                    subtitle: gameState.currentLevel.title
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(gameState.currentLevel.inscriptions.enumerated()), id: \.offset) { _, note in
                            HStack(alignment: .top, spacing: 16) {
                                Text("𓏲")
                                    .font(.system(size: 26))
                                    .foregroundStyle(Color.goldDark)
                                    .padding(.top, 3)
                                Text(note)
                                    .font(EgyptFont.bodyItalic(22))
                                    .foregroundStyle(Color.papyrus)
                                    .lineSpacing(8)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.stoneMid.opacity(0.35))
                                    .overlay(RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.goldDark.opacity(0.2), lineWidth: 0.8))
                            )
                        }
                    }
                    .padding(24)
                }

                closeButton
            }
        }
    }
}

// MARK: - Known Glyphs Modal

struct KnownGlyphsModal: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.stoneDark.ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.22, green: 0.14, blue: 0.05).opacity(0.5), .clear],
                center: .center, startRadius: 80, endRadius: 380
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                modalHeader(
                    icon:  "magnifyingglass",
                    title: "Known Glyphs",
                    subtitle: "\(gameState.codexGlyphs.count) recorded in your codex"
                )

                if gameState.codexGlyphs.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Text("𓂀")
                            .font(.system(size: 52))
                            .foregroundStyle(Color.goldDark.opacity(0.4))
                        Text("Your codex is empty.")
                            .font(EgyptFont.titleBold(22))
                            .foregroundStyle(Color.goldMid)
                        Text("Solve a puzzle to begin recording glyphs.")
                            .font(EgyptFont.bodyItalic(18))
                            .foregroundStyle(Color.papyrus.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            ForEach(gameState.codexGlyphs) { glyph in
                                HStack(spacing: 20) {
                                    Text(glyph.rawValue)
                                        .font(.system(size: 48))
                                        .foregroundStyle(Color.goldBright)
                                        .frame(width: 60)

                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(glyph.displayName)
                                            .font(EgyptFont.titleBold(20))
                                            .foregroundStyle(Color.goldBright)
                                        Text(glyph.meaning)
                                            .font(EgyptFont.bodyItalic(17))
                                            .foregroundStyle(Color.papyrus.opacity(0.8))
                                            .lineSpacing(4)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.stoneMid.opacity(0.4))
                                        .overlay(RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.goldDark.opacity(0.25), lineWidth: 0.8))
                                )
                            }
                        }
                        .padding(24)
                    }
                }

                closeButton
            }
        }
    }
}

// MARK: - Shared modal helpers

/// Consistent header used by both modals.
private func modalHeader(icon: String, title: String, subtitle: String) -> some View {
    VStack(spacing: 6) {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
            Text(title.uppercased())
                .font(EgyptFont.titleBold(22))
                .tracking(3)
        }
        .foregroundStyle(Color.goldBright)

        Text(subtitle)
            .font(EgyptFont.bodyItalic(16))
            .foregroundStyle(Color.papyrus.opacity(0.65))
    }
    .padding(.top, 28)
    .padding(.bottom, 18)
    .padding(.horizontal, 24)
    .frame(maxWidth: .infinity)
    .background(
        Color.stoneMid.opacity(0.5)
            .overlay(Rectangle()
                .fill(Color.goldDark.opacity(0.3))
                .frame(height: 0.8),
                     alignment: .bottom)
    )
}

/// Large, obvious "Done" button at the bottom of each modal.
private var closeButton: some View {
    // Access dismiss via environment — defined at call site using the @Environment trick
    EmptyView()
}

// Extend the modal views to inject the close button properly
extension FieldNotesModal {
    var closeButton: some View {
        Button(action: { dismiss() }) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                Text("Done")
                    .font(EgyptFont.titleBold(20))
            }
            .foregroundStyle(Color.stoneDark)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [.goldBright, .goldMid], startPoint: .top, endPoint: .bottom)
            )
        }
    }
}

extension KnownGlyphsModal {
    var closeButton: some View {
        Button(action: { dismiss() }) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                Text("Done")
                    .font(EgyptFont.titleBold(20))
            }
            .foregroundStyle(Color.stoneDark)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [.goldBright, .goldMid], startPoint: .top, endPoint: .bottom)
            )
        }
    }
}
