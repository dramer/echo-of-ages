// GlyphGridView.swift
// EchoOfAges
//
// Game screen with standard header bar matching all other civilizations.
// Field Notes and Known Glyphs open as large modal sheets.
// Decipher and Reset live in the bottom action row.

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
    @State private var showHelp:         Bool   = false

    // Egyptian Nudge — shown once on Level 1, first play ever
    @State private var showNudge:    Bool   = false
    @State private var paletteFrame: CGRect = .zero
    @State private var gridFrame:    CGRect = .zero
    @State private var decipherFrame: CGRect = .zero

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                stoneBackground

                VStack(spacing: 0) {
                    headerBar

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            levelTitle
                                .padding(.horizontal, 16)

                            GlyphGridView(availableWidth: geo.size.width - 32,
                                          availableHeight: 600)
                                .padding(.horizontal, 16)
                                .background(GeometryReader { g in
                                    Color.clear.onAppear {
                                        gridFrame = g.frame(in: .global)
                                    }
                                })

                            palette
                                .padding(.horizontal, 16)
                                .background(GeometryReader { g in
                                    Color.clear.onAppear {
                                        paletteFrame = g.frame(in: .global)
                                    }
                                })

                            actionRow
                                .padding(.horizontal, 16)
                                .background(GeometryReader { g in
                                    Color.clear.onAppear {
                                        let f = g.frame(in: .global)
                                        // Spotlight just the Decipher button (right half)
                                        decipherFrame = CGRect(x: f.midX, y: f.minY,
                                                               width: f.width / 2, height: f.height)
                                    }
                                })

                            secondaryRow
                                .padding(.horizontal, 16)
                                .padding(.bottom, 24)
                        }
                        .padding(.top, 14)
                    }
                }

                // Help overlay
                if showHelp {
                    Color.black.opacity(0.55).ignoresSafeArea()
                        .onTapGesture { withAnimation { showHelp = false } }
                        .transition(.opacity).zIndex(9)
                    egyptHelpDialog
                        .transition(.scale(scale: 0.93).combined(with: .opacity))
                        .zIndex(10)
                }

                // First-play Egyptian nudge — level 1 only, fires once ever
                if showNudge && !paletteFrame.isEmpty && !gridFrame.isEmpty && !decipherFrame.isEmpty {
                    EgyptianNudge(
                        isVisible: $showNudge,
                        paletteFrame:  paletteFrame,
                        gridFrame:     gridFrame,
                        decipherFrame: decipherFrame
                    )
                    .transition(.opacity)
                    .zIndex(20)
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
        .onChange(of: gameState.egyptPenaltyMessage) { _, message in
            guard let msg = message else { return }
            showToast(msg, duration: 6.0)
            gameState.egyptPenaltyMessage = nil
        }
        .onAppear {
            // Show the nudge on Level 1 first play, with a small delay so
            // the GeometryReaders have time to capture their frames.
            if gameState.currentLevelIndex == 0 && shouldShowEgyptNudge() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeIn(duration: 0.3)) { showNudge = true }
                }
            }
        }
    }

    // MARK: Header Bar

    private var headerBar: some View {
        HStack {
            Button {
                HapticFeedback.tap()
                gameState.goToTitle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Return")
                        .font(EgyptFont.titleBold(15))
                }
                .foregroundStyle(Color.goldBright)
            }
            .frame(minWidth: 80, alignment: .leading)

            Spacer()

            Text("𓂀  Egyptian Inscription")
                .font(EgyptFont.titleBold(16))
                .foregroundStyle(Color.goldBright)
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            HStack(spacing: 10) {
                Text(gameState.currentLevel.romanNumeral)
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(Color.goldBright.opacity(0.75))

                Button {
                    HapticFeedback.tap()
                    withAnimation { showHelp = true }
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.goldBright)
                }
            }
            .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.stoneMid.opacity(0.5)
                .overlay(
                    Rectangle()
                        .fill(Color.goldDark.opacity(0.3))
                        .frame(height: 0.8),
                    alignment: .bottom
                )
        )
    }

    // MARK: Action Row (Decipher + Reset)

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                HapticFeedback.tap()
                gameState.resetCurrentLevel()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(Color.papyrus.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.stoneMid)
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(Color.stoneLight.opacity(0.3), lineWidth: 1))
                    )
            }

            Button {
                HapticFeedback.tap()
                handleDecipher()
            } label: {
                Label("Decipher", systemImage: "checkmark.seal")
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(Color.stoneDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.goldMid)
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(Color.goldBright.opacity(0.5), lineWidth: 1))
                    )
            }
        }
    }

    // MARK: Secondary Row (Notes · Glyphs · Journal)

    private var secondaryRow: some View {
        HStack(spacing: 12) {
            secondaryButton("Notes", icon: "pencil")         { showFieldNotes = true }
            secondaryButton("Glyphs", icon: "magnifyingglass") { showKnownGlyphs = true }
            secondaryButton("Journal", icon: "book.fill")    { gameState.openJournal() }
        }
    }

    private func secondaryButton(_ label: String,
                                  icon: String,
                                  action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.tap()
            action()
        } label: {
            Label(label, systemImage: icon)
                .font(EgyptFont.body(13))
                .foregroundStyle(Color.goldMid)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.stoneMid.opacity(0.5))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.goldDark.opacity(0.3), lineWidth: 0.8))
                )
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
            // Rule description — changes per puzzle variant
            Text(gameState.currentLevel.variant.ruleDescription)
                .font(EgyptFont.body(12))
                .foregroundStyle(Color.goldDark.opacity(0.85))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.top, 1)
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

    // MARK: Help Dialog

    private var egyptHelpDialog: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("𓂀  How to Play")
                    .font(EgyptFont.titleBold(20))
                    .foregroundStyle(Color.goldBright)
                Spacer()
                Button { withAnimation { showHelp = false } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.goldBright.opacity(0.70))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 14)

            helpRow(number: "1", title: "Read the fixed glyphs",
                    body: "Pre-placed symbols are carved in stone — they cannot be moved. Use them as anchor points to reason about the rest.")
            helpRow(number: "2", title: "No repeats in any row or column",
                    body: "Each glyph appears exactly once per row and once per column. If a symbol already appears in the same row or column, it cannot go in that cell.")
            helpRow(number: "3", title: "Arm and place",
                    body: "Tap a glyph in the palette to arm it, then tap any empty cell to place it. Tap the same glyph again to disarm. Long-press a cell to clear it.")
            helpRow(number: "4", title: "Decipher",
                    body: "Tap Decipher to check your work. Wrong cells flash red — the correct answer is never shown, so use the logic to find it yourself.")

            Button { withAnimation { showHelp = false } } label: {
                Text("Got it")
                    .font(EgyptFont.titleBold(17))
                    .foregroundStyle(Color.stoneDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.goldBright))
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.stoneDark)
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.goldDark.opacity(0.55), lineWidth: 1.5))
        )
        .padding(.horizontal, 20)
    }

    private func helpRow(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(EgyptFont.titleBold(16))
                .foregroundStyle(Color.goldBright)
                .frame(width: 22, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(EgyptFont.titleBold(15))
                    .foregroundStyle(Color.papyrus)
                Text(body)
                    .font(EgyptFont.body(13))
                    .foregroundStyle(Color.papyrus.opacity(0.75))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 12)
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
                            isFixed:  gameState.isEgyptianFixed(pos),
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
                    let acrostic = TreeOfLifeKeys.acrosticLetter(for: .egyptian, levelIndex: gameState.currentLevelIndex)
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(gameState.currentLevel.inscriptions.enumerated()), id: \.offset) { _, note in
                            HStack(alignment: .top, spacing: 16) {
                                Text("𓏲")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Color.goldDark)
                                    .padding(.top, 4)
                                Text(acrosticUnderlined(note, letter: acrostic))
                                    .font(EgyptFont.bodyItalic(30))
                                    .foregroundStyle(Color.papyrus)
                                    .lineSpacing(10)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
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
