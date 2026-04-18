// EgyptWinnerScene.swift
// EchoOfAges
//
// Egyptian puzzle win scene — wraps the generic WinnerScene with the
// egypt_final image and a civilization-specific caption above the image.

import SwiftUI

struct EgyptWinnerScene: View {

    /// 0-based index of the Egyptian level just completed (0 = Puzzle 1 … 4 = Puzzle 5).
    let completedLevelIndex: Int

    private let captions = [
        "A shadow stirs in the sand…",
        "Ancient forms take shape…",
        "The vision grows clearer…",
        "The sacred image emerges…",
        "The truth is revealed.",
    ]

    var body: some View {
        VStack(spacing: 6) {
            Text(captions[min(completedLevelIndex, captions.count - 1)])
                .font(EgyptFont.bodyItalic(15))
                .foregroundStyle(Color.goldBright.opacity(0.88))
                .tracking(0.5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            WinnerScene(imageName: "egypt_final",
                        completedLevelIndex: completedLevelIndex)
        }
    }
}
