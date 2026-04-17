// EgyptWinnerScene.swift
// EchoOfAges
//
// Progressive 7-image tomb scene revealed one layer per Egyptian puzzle solved.
// Pass completedLevelIndex (0–4); all layers for 0..completedLevelIndex are shown,
// and the layer(s) for exactly completedLevelIndex animate in on appear.
//
// Image–level mapping
//   Level 0 (Puzzle 1): egypt_arch                              — The Entrance Revealed
//   Level 1 (Puzzle 2): egypt_Hieroglyph_wall_panel             — The Inscriptions Emerge
//   Level 2 (Puzzle 3): egypt_scarab_beetle                     — The Sacred Scarab Discovered
//   Level 3 (Puzzle 4): egypt_ankh + egypt_alter                — The Inner Sanctuary Opens
//   Level 4 (Puzzle 5): egypt_osiris + egypt_eye_of_ra          — Osiris Awakens

import SwiftUI

struct EgyptWinnerScene: View {

    /// 0-based index of the Egyptian level just completed (0 = Puzzle 1 … 4 = Puzzle 5).
    let completedLevelIndex: Int

    @State private var newLayerVisible = false

    // MARK: - Scene layer descriptors

    private struct Layer: Identifiable {
        let id: Int
        let imageName: String
        let revealLevel: Int   // first shown on completing this 0-based level index
        let w: CGFloat         // frame width
        let h: CGFloat         // frame height
        let dx: CGFloat        // offset from ZStack center (+ = right)
        let dy: CGFloat        // offset from ZStack center (+ = down)
        let zOrder: Int        // painter order (higher = in front)
    }

    // Coordinates are tuned for a 240 pt tall scene.
    // Horizontal positions stay within ±150 pt of centre for all phone widths.
    private let layers: [Layer] = [
        Layer(id: 0, imageName: "egypt_arch",
              revealLevel: 0, w: 300, h: 85,  dx:   0, dy:  82, zOrder: 0),
        Layer(id: 1, imageName: "egypt_Hieroglyph_wall_panel",
              revealLevel: 1, w: 130, h: 100, dx: -80, dy:  15, zOrder: 1),
        Layer(id: 2, imageName: "egypt_scarab_beetle",
              revealLevel: 2, w:  85, h:  85, dx:  55, dy:  10, zOrder: 2),
        Layer(id: 3, imageName: "egypt_alter",
              revealLevel: 3, w:  85, h:  75, dx:  90, dy:  52, zOrder: 1),
        Layer(id: 4, imageName: "egypt_ankh",
              revealLevel: 3, w:  55, h:  80, dx: -95, dy: -30, zOrder: 2),
        Layer(id: 5, imageName: "egypt_osiris",
              revealLevel: 4, w:  90, h: 130, dx: -60, dy: -35, zOrder: 3),
        Layer(id: 6, imageName: "egypt_eye_of_ra",
              revealLevel: 4, w: 115, h:  70, dx:  50, dy: -78, zOrder: 3),
    ]

    private let captions = [
        "The Entrance Revealed",
        "The Inscriptions Emerge",
        "The Sacred Scarab Discovered",
        "The Inner Sanctuary Opens",
        "Osiris Awakens · The Eye of Ra Shines",
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            caption

            scene

            progressDots
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { newLayerVisible = true }
            }
        }
    }

    // MARK: - Sub-views

    private var caption: some View {
        Text(captions[min(completedLevelIndex, captions.count - 1)])
            .font(EgyptFont.bodyItalic(15))
            .foregroundStyle(Color.goldBright.opacity(0.88))
            .tracking(0.5)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
    }

    private var scene: some View {
        ZStack {
            // Background stone
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.08, green: 0.05, blue: 0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.goldDark.opacity(0.55), lineWidth: 1.5)
                )

            // Subtle "TOMB OF KHA" watermark at top
            Text("𓉐  TOMB OF KHA  𓉐")
                .font(EgyptFont.title(9))
                .foregroundStyle(Color.goldMid.opacity(0.14))
                .tracking(4)
                .offset(y: -95)

            // Images, back-to-front by zOrder
            ForEach(layers.sorted { $0.zOrder < $1.zOrder }) { layer in
                layerImage(layer)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipped()
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func layerImage(_ layer: Layer) -> some View {
        let isVisible = layer.revealLevel <= completedLevelIndex
        let isNew     = layer.revealLevel == completedLevelIndex

        if isVisible {
            Image(layer.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: layer.w, height: layer.h)
                .offset(x: layer.dx, y: layer.dy)
                // Gold halo pulses briefly on the newly revealed image(s)
                .shadow(
                    color: isNew
                        ? Color.goldBright.opacity(newLayerVisible ? 0.65 : 0)
                        : Color.black.opacity(0.45),
                    radius: isNew ? 18 : 6, x: 0, y: 0
                )
                .scaleEffect(isNew ? (newLayerVisible ? 1.0 : 0.5) : 1.0)
                .opacity(isNew ? (newLayerVisible ? 1.0 : 0) : 1.0)
                .animation(
                    isNew
                        ? .spring(response: 0.65, dampingFraction: 0.68)
                            .delay(Double(layer.id) * 0.12 + 0.4)
                        : .none,
                    value: newLayerVisible
                )
        }
    }

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
}
