// GlyphCellView.swift
// EchoOfAges
//
// A single cell in the Egyptian Latin-square puzzle grid.
// Displays a Glyph (or blank), highlights fixed/locked positions,
// flashes errors red on a failed Decipher check, and plays a
// press animation on tap. Long-press clears a player-placed glyph.

import SwiftUI

struct GlyphCellView: View {
    let glyph: Glyph?
    let isFixed: Bool
    let isError: Bool
    let isComplete: Bool
    let size: CGFloat
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var isPressed = false

    var body: some View {
        ZStack {
            cellBackground
            glyphContent
            if isFixed { lockBadge }
            if isError { errorOverlay }
            if isComplete { completionGlow }
        }
        .frame(width: size, height: size)
        .scaleEffect(isPressed ? 0.90 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.55), value: isPressed)
        .onTapGesture { handleTap() }
        .onLongPressGesture(minimumDuration: 0.4) { onLongPress() }
    }

    // MARK: Sub-views

    private var cellBackground: some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(backgroundFill)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(color: .black.opacity(0.45), radius: 3, x: 2, y: 3)
            // Inset highlight to simulate carved depth
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    .padding(1)
            )
    }

    private var glyphContent: some View {
        Group {
            if let glyph {
                Text(glyph.rawValue)
                    .font(.system(size: size * 0.52))
                    .foregroundStyle(isFixed ? Color.goldBright : Color.goldMid)
                    .shadow(color: Color.goldDark.opacity(0.7), radius: 3, x: 0, y: 1)
            } else {
                // Empty slot marker
                Circle()
                    .fill(Color.stoneMid.opacity(0.45))
                    .frame(width: size * 0.14, height: size * 0.14)
            }
        }
    }

    private var lockBadge: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: max(size * 0.17, 8)))
                    .foregroundStyle(Color.goldDark.opacity(0.75))
                    .padding(4)
            }
            Spacer()
        }
    }

    private var errorOverlay: some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(Color.rubyRed.opacity(0.55))
            .animation(.easeInOut(duration: 0.15), value: isError)
    }

    private var completionGlow: some View {
        RoundedRectangle(cornerRadius: 9)
            .stroke(Color.goldBright, lineWidth: 2.5)
            .blur(radius: 3)
            .opacity(0.85)
    }

    // MARK: Computed Style Properties

    private var backgroundFill: LinearGradient {
        if isFixed {
            return LinearGradient(
                colors: [Color.stoneLight, Color.stoneMid],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if glyph != nil {
            return LinearGradient(
                colors: [Color(red: 0.22, green: 0.16, blue: 0.09), Color.stoneMid],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.stoneDark, Color(red: 0.18, green: 0.13, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderColor: Color {
        if isError   { return .rubyRed }
        if isComplete { return .goldBright }
        if isFixed   { return .goldMid }
        if glyph != nil { return .goldDark.opacity(0.7) }
        return .stoneLight.opacity(0.4)
    }

    private var borderWidth: CGFloat {
        if isFixed { return 1.5 }
        if glyph != nil { return 1.0 }
        return 0.7
    }

    // MARK: Interaction

    private func handleTap() {
        guard !isFixed else { return }
        isPressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            isPressed = false
        }
        onTap()
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 10) {
        GlyphCellView(glyph: .eye,   isFixed: true,  isError: false, isComplete: false, size: 72, onTap: {}, onLongPress: {})
        GlyphCellView(glyph: .owl,   isFixed: false, isError: false, isComplete: false, size: 72, onTap: {}, onLongPress: {})
        GlyphCellView(glyph: nil,    isFixed: false, isError: false, isComplete: false, size: 72, onTap: {}, onLongPress: {})
        GlyphCellView(glyph: .water, isFixed: false, isError: true,  isComplete: false, size: 72, onTap: {}, onLongPress: {})
        GlyphCellView(glyph: .lion,  isFixed: false, isError: false, isComplete: true,  size: 72, onTap: {}, onLongPress: {})
    }
    .padding()
    .background(Color.stoneDark)
}
