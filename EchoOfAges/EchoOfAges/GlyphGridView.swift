// GlyphGridView.swift
// EchoOfAges
//
// Contains the full game screen (GameView) and the puzzle grid sub-view (GlyphGridView).

import SwiftUI

// MARK: - Game Screen

struct GameView: View {
    @EnvironmentObject var gameState: GameState
    @State private var inscriptionsExpanded = false

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBar
                    levelHeader
                    Spacer(minLength: 18)
                    GlyphGridView(geo: geo)
                    Spacer(minLength: 20)
                    palette
                    Spacer(minLength: 22)
                    inscriptionsPanel
                    Spacer(minLength: 22)
                    actionButtons
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
            }
        }
        .background(stoneBackground)
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { gameState.openJournal() }) {
                HStack(spacing: 6) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 14, weight: .medium))
                    Text("Journal")
                        .font(EgyptFont.title(13))
                }
                .foregroundStyle(Color.goldMid)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.stoneMid.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.stoneLight.opacity(0.5), lineWidth: 0.7)
                        )
                )
            }
            Spacer()
            Text("Chamber \(gameState.currentLevel.romanNumeral) / V")
                .font(EgyptFont.body(13))
                .foregroundStyle(Color.stoneSurface)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: Level Header

    private var levelHeader: some View {
        VStack(spacing: 6) {
            Text("· \(gameState.currentLevel.romanNumeral) ·")
                .font(EgyptFont.title(14))
                .foregroundStyle(Color.goldDark)
                .tracking(4)
            Text(gameState.currentLevel.title.uppercased())
                .font(EgyptFont.titleBold(26))
                .foregroundStyle(Color.goldBright)
                .tracking(3)
                .shadow(color: .goldDark.opacity(0.5), radius: 4, x: 0, y: 2)
            Text(gameState.currentLevel.subtitle)
                .font(EgyptFont.bodyItalic(16))
                .foregroundStyle(Color.papyrus.opacity(0.8))
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 4)
    }

    // MARK: Glyph Palette

    private var palette: some View {
        VStack(spacing: 10) {
            Text("Select a Glyph")
                .font(EgyptFont.body(13))
                .foregroundStyle(Color.stoneSurface)

            HStack(spacing: 10) {
                ForEach(gameState.currentLevel.availableGlyphs) { glyph in
                    PaletteButton(glyph: glyph, isSelected: gameState.selectedGlyph == glyph) {
                        gameState.selectGlyph(glyph)
                    }
                }
            }
        }
    }

    // MARK: Inscriptions Panel

    private var inscriptionsPanel: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    inscriptionsExpanded.toggle()
                }
                HapticFeedback.tap()
            }) {
                HStack {
                    Image(systemName: "text.quote")
                        .font(.system(size: 13))
                    Text("Inscriptions")
                        .font(EgyptFont.title(14))
                    Spacer()
                    Image(systemName: inscriptionsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.goldMid)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.stoneMid)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.stoneLight.opacity(0.5), lineWidth: 0.8)
                        )
                )
            }

            if inscriptionsExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(gameState.currentLevel.inscriptions.enumerated()), id: \.offset) { _, inscription in
                        HStack(alignment: .top, spacing: 10) {
                            Text("𓏲")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.goldDark)
                            Text(inscription)
                                .font(EgyptFont.bodyItalic(15))
                                .foregroundStyle(Color.papyrus.opacity(0.9))
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.stoneDark.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.stoneLight.opacity(0.3), lineWidth: 0.5)
                        )
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { gameState.verifyPlacement() }) {
                StoneButton(title: "Decipher", icon: "eye", style: .gold)
            }
            Button(action: { gameState.resetCurrentLevel() }) {
                StoneButton(title: "Reset", icon: "arrow.counterclockwise", style: .muted)
            }
        }
    }

    // MARK: Background

    private var stoneBackground: some View {
        ZStack {
            Color.stoneDark.ignoresSafeArea()
            // Subtle vignette
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.35)],
                center: .center,
                startRadius: 200,
                endRadius: 500
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Glyph Grid

struct GlyphGridView: View {
    @EnvironmentObject var gameState: GameState
    let geo: GeometryProxy

    private var level: Level { gameState.currentLevel }

    private var cellSize: CGFloat {
        let usableWidth = geo.size.width - 32 // 16pt padding each side
        let spacing = CGFloat(level.cols - 1) * 6
        return (usableWidth - spacing) / CGFloat(level.cols)
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<level.rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<level.cols, id: \.self) { col in
                        let pos = GridPosition(row: row, col: col)
                        GlyphCellView(
                            glyph: gameState.playerGrid[row][col],
                            isFixed: level.isFixed(pos),
                            isError: gameState.errorCells.contains(pos),
                            isComplete: gameState.isAnimatingCompletion,
                            size: cellSize,
                            onTap: { gameState.tapCell(at: pos) },
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
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.goldDark.opacity(0.35), lineWidth: 1)
                )
        )
        // Completion border glow
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.goldBright, lineWidth: 2.5)
                .opacity(gameState.isAnimatingCompletion ? 1 : 0)
                .animation(
                    .easeInOut(duration: 0.5).repeatCount(3, autoreverses: true),
                    value: gameState.isAnimatingCompletion
                )
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
                Text(glyph.rawValue)
                    .font(.system(size: 28))
                Text(glyph.displayName.replacingOccurrences(of: "The ", with: ""))
                    .font(EgyptFont.body(10))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.stoneDark : Color.goldMid)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected
                          ? LinearGradient(colors: [.goldBright, .goldMid], startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [.stoneMid, .stoneDark], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(isSelected ? Color.goldBright : Color.stoneLight.opacity(0.4), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
            .scaleEffect(isSelected ? 1.06 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
        }
    }
}
