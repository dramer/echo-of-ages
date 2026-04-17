// Theme.swift
// EchoOfAges
//
// Centralised design system — colors, fonts, reusable UI components, and
// haptic feedback helpers used across the entire app.
//
// Colors (Color extensions):
//   stoneDark / stoneMid / stoneLight / stoneSurface — dark earthy stone palette
//   goldDark / goldMid / goldBright                  — hieroglyphic gold accents
//   papyrus                                          — warm parchment background
//   rubyRed                                          — error / penalty highlight
//
// Fonts (EgyptFont):
//   Cinzel (title, titleBold) and Crimson Text (body, bodyItalic) are the
//   primary typefaces. The app silently falls back to the system font if the
//   .ttf files are absent. To install:
//     1. Download from https://fonts.google.com/specimen/Cinzel
//                  and https://fonts.google.com/specimen/Crimson+Text
//     2. Drag the .ttf files into Xcode (copy to bundle).
//     3. List each filename under "Fonts provided by application" in Info.plist.
//   Required files: Cinzel-Regular.ttf, Cinzel-Bold.ttf,
//                   CrimsonText-Regular.ttf, CrimsonText-Italic.ttf,
//                   CrimsonText-SemiBold.ttf
//
// Components:
//   StoneButton      — standard labelled button with stone/gold variants
//   HapticFeedback   — thin wrapper around UIImpactFeedbackGenerator
//   acrosticUnderlined(_:letter:) — returns an AttributedString with the first
//                                   matching letter underlined (acrostic hint)

import SwiftUI

extension Color {
    static let stoneDark    = Color(red: 0.14, green: 0.09, blue: 0.05)
    static let stoneMid     = Color(red: 0.25, green: 0.19, blue: 0.12)
    static let stoneLight   = Color(red: 0.42, green: 0.34, blue: 0.22)
    static let stoneSurface = Color(red: 0.57, green: 0.47, blue: 0.32)
    static let goldDark     = Color(red: 0.50, green: 0.36, blue: 0.06)
    static let goldMid      = Color(red: 0.72, green: 0.57, blue: 0.15)
    static let goldBright   = Color(red: 0.88, green: 0.73, blue: 0.28)
    static let papyrus      = Color(red: 0.87, green: 0.79, blue: 0.58)
    static let rubyRed      = Color(red: 0.60, green: 0.10, blue: 0.08)
}

enum EgyptFont {
    // Cinzel is a variable font (Cinzel-VariableFont_wght.ttf).
    // PostScript name is "Cinzel-Regular" for all weights;
    // bold weight is accessed via .bold() on the Font.
    static func title(_ size: CGFloat) -> Font {
        .custom("Cinzel-Regular", size: size)
    }
    static func titleBold(_ size: CGFloat) -> Font {
        .custom("Cinzel-Regular", size: size).bold()
    }
    // CrimsonText ships as separate weight files.
    static func body(_ size: CGFloat) -> Font {
        .custom("CrimsonText-Regular", size: size)
    }
    static func bodyItalic(_ size: CGFloat) -> Font {
        .custom("CrimsonText-Italic", size: size)
    }
    static func bodySemiBold(_ size: CGFloat) -> Font {
        .custom("CrimsonText-SemiBold", size: size)
    }
}

enum HapticFeedback {
    /// Set to false to silence all haptic feedback app-wide. Controlled by SoundManager.
    static var isEnabled: Bool = true

    static func tap() {
        guard isEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
    }
    static func heavy() {
        guard isEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.impactOccurred()
    }
    static func success() {
        guard isEnabled else { return }
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
    }
    static func error() {
        guard isEnabled else { return }
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.error)
    }
}

// MARK: - Toggle Style

struct GreenRedToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn
        RoundedRectangle(cornerRadius: 16)
            .fill(isOn ? Color(red: 0.18, green: 0.60, blue: 0.22) : Color(red: 0.75, green: 0.15, blue: 0.12))
            .frame(width: 56, height: 32)
            .overlay(
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                    .frame(width: 26, height: 26)
                    .offset(x: isOn ? 12 : -12)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isOn)
            )
            .onTapGesture {
                HapticFeedback.tap()
                configuration.isOn.toggle()
            }
    }
}

// MARK: - Toast

struct ToastView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Text("𓂀")               // Eye of Horus
                .font(.system(size: 38))
                .foregroundStyle(Color.goldBright)

            Text(message)
                .font(EgyptFont.bodyItalic(22))
                .foregroundStyle(Color.papyrus)
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .frame(maxWidth: 560)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.stoneMid)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.goldDark.opacity(0.85), lineWidth: 1.5)
                )
        )
        .shadow(color: .black.opacity(0.65), radius: 24, x: 0, y: 8)
        .padding(.horizontal, 28)
    }
}

// MARK: - Acrostic Underline Helper

/// Returns an AttributedString with every occurrence of `letter` (case-insensitive)
/// underlined. Use with `Text(acrosticUnderlined(...))` — apply font/color via modifiers.
func acrosticUnderlined(_ text: String, letter: Character) -> AttributedString {
    var result = AttributedString(text)
    let upperTarget = Character(String(letter).uppercased())
    let lowerTarget = Character(String(letter).lowercased())

    var idx = result.startIndex
    while idx < result.endIndex {
        let next = result.index(afterCharacter: idx)
        let ch = result.characters[idx]
        if ch == upperTarget || ch == lowerTarget {
            result[idx..<next].underlineStyle = .single
        }
        idx = next
    }
    return result
}

struct StoneButton: View {
    let title: String
    let icon: String
    var style: ButtonStyle = .gold

    enum ButtonStyle { case gold, muted }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(EgyptFont.title(15))
        }
        .foregroundColor(style == .gold ? .stoneDark : .goldMid)
        .padding(.vertical, 13)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            Group {
                if style == .gold {
                    LinearGradient(colors: [.goldBright, .goldMid],
                                   startPoint: .top, endPoint: .bottom)
                } else {
                    LinearGradient(colors: [.stoneMid, .stoneDark],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(style == .gold ? Color.goldDark : Color.stoneLight, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 3)
    }
}
