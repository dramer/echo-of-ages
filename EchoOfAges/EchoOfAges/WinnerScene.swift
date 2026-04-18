// WinnerScene.swift
// EchoOfAges
//
// Generic progressive-unblur winner image shown in every civilization's
// level-complete overlay. Pass the image asset name and the 0-based index
// of the just-completed level (0 = Puzzle 1 … 4 = Puzzle 5).
// Tap the image to view it full screen at the current blur level.

import SwiftUI

struct WinnerScene: View {

    let imageName:          String
    let completedLevelIndex: Int

    @State private var blurRevealed   = false
    @State private var showFullScreen = false

    // MARK: - Blur levels (puzzle 1 → 5)

    private var targetBlur: CGFloat {
        let levels: [CGFloat] = [22, 16, 10, 4, 0]
        return levels[min(completedLevelIndex, levels.count - 1)]
    }

    private var startBlur: CGFloat {
        completedLevelIndex == 0 ? 30 : [22, 16, 10, 4, 0][completedLevelIndex - 1]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            imageCard
            progressDots
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            fullScreenView
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                blurRevealed = true
            }
        }
    }

    // MARK: - Image Card

    private var imageCard: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .blur(radius: blurRevealed ? targetBlur : startBlur)
            .animation(.easeOut(duration: 1.4), value: blurRevealed)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.goldDark.opacity(0.50), lineWidth: 1.5)
            )
            .overlay(expandHint, alignment: .bottomTrailing)
            .shadow(color: Color.goldDark.opacity(0.22), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 24)
            .onTapGesture {
                HapticFeedback.tap()
                showFullScreen = true
            }
    }

    private var expandHint: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.goldBright.opacity(0.75))
            .padding(7)
            .background(Circle().fill(Color.black.opacity(0.45)))
            .padding(10)
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i <= completedLevelIndex
                          ? Color.goldBright
                          : Color.goldDark.opacity(0.22))
                    .frame(
                        width:  i == completedLevelIndex ? 9 : 5,
                        height: i == completedLevelIndex ? 9 : 5
                    )
            }
        }
    }

    // MARK: - Full Screen View

    private var fullScreenView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(imageName)
                .resizable()
                .scaledToFit()
                .blur(radius: targetBlur)
                .ignoresSafeArea(edges: .horizontal)

            VStack {
                HStack {
                    Spacer()
                    Button { showFullScreen = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .padding(20)
                    }
                }
                Spacer()
            }
        }
        .onTapGesture { showFullScreen = false }
    }
}
