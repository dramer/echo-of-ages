// Theme.swift
// EchoOfAges
//
// Add these font files to the Xcode project and list them under
// "Fonts provided by application" in Info.plist:
//   Cinzel-Regular.ttf, Cinzel-Bold.ttf
//   CrimsonText-Regular.ttf, CrimsonText-Italic.ttf, CrimsonText-SemiBold.ttf
// Download from: https://fonts.google.com/specimen/Cinzel
//                https://fonts.google.com/specimen/Crimson+Text

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
    static func title(_ size: CGFloat) -> Font {
        .custom("Cinzel-Regular", size: size)
    }
    static func titleBold(_ size: CGFloat) -> Font {
        .custom("Cinzel-Bold", size: size)
    }
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
    static func tap() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
    }
    static func heavy() {
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.impactOccurred()
    }
    static func success() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
    }
    static func error() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.error)
    }
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
