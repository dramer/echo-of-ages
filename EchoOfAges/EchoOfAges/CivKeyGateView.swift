// CivKeyGateView.swift
// EchoOfAges
//
// Shown the first time a player enters a civilization that requires a key
// from the previous one. The player taps a cycling cell to step through
// candidate symbols and identify the mark that was left behind.
//
// The correct answer is hinted at in the Field Journal — specifically the
// key-discovery entry written when the source civilization's Level 5 was solved.
//
// Interaction:
//   • Tap the mystery cell → cycles through candidate symbols
//   • Gold border + glow appears when the correct symbol is selected
//   • "Begin Deciphering" button activates once all slots are correct
//   • China needs two slots (Maya mark + Celtic mark) — both happen to be ᚅ

import SwiftUI

struct CivKeyGateView: View {
    let civId: CivilizationID
    @EnvironmentObject var gameState: GameState

    @State private var slot1Index: Int = 0
    @State private var slot2Index: Int = 0   // China only
    @State private var showAha:   Bool = false

    // MARK: - Helpers

    private var civ: Civilization? { Civilization.all.first { $0.id == civId } }
    private var isChina: Bool { civId == .chinese }

    private var choices1: [String] {
        isChina ? TreeOfLifeKeys.chinaSlot1Choices : TreeOfLifeKeys.choices(for: civId)
    }

    private var slot1Symbol: String { choices1[slot1Index] }
    private var slot2Symbol: String { TreeOfLifeKeys.chinaSlot2Choices[slot2Index] }

    private var slot1Correct: Bool {
        let required = isChina ? TreeOfLifeKeys.maya : (TreeOfLifeKeys.required(by: civId) ?? "")
        return slot1Symbol == required
    }

    private var slot2Correct: Bool {
        slot2Symbol == TreeOfLifeKeys.celtic
    }

    private var allCorrect: Bool {
        isChina ? (slot1Correct && slot2Correct) : slot1Correct
    }

    private var accentColor: Color { civ?.accentColor ?? .goldMid }

    // MARK: - Body

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer(minLength: 16)
                    headerSection
                    contextCard
                    if isChina { chinaSlotsSection } else { singleSlotSection }
                    if isChina && showAha { ahaCard.transition(.scale.combined(with: .opacity)) }
                    actionSection
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .onChange(of: allCorrect) { _, correct in
            if correct && isChina {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) { showAha = true }
                HapticFeedback.success()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            Text(civ?.emblem ?? "")
                .font(.system(size: 64))
                .foregroundStyle(accentColor)
                .shadow(color: accentColor.opacity(0.55), radius: 22)

            Text((civ?.name ?? "").uppercased())
                .font(EgyptFont.titleBold(22))
                .tracking(3)
                .foregroundStyle(Color.goldBright)

            Text("A Discovery Awaits")
                .font(EgyptFont.bodyItalic(17))
                .foregroundStyle(Color.stoneLight.opacity(0.60))
        }
    }

    // MARK: - Context Card

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(TreeOfLifeKeys.gateSourceLabel(for: civId),
                  systemImage: "magnifyingglass")
                .font(EgyptFont.title(13))
                .tracking(1)
                .foregroundStyle(Color.goldMid.opacity(0.70))

            Text(TreeOfLifeKeys.gateIntroText(for: civId))
                .font(EgyptFont.bodyItalic(17))
                .foregroundStyle(Color.stoneLight.opacity(0.82))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.stoneMid.opacity(0.28))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.goldDark.opacity(0.22), lineWidth: 1))
        )
    }

    // MARK: - Single Slot (all civs except China)

    private var singleSlotSection: some View {
        VStack(spacing: 16) {
            cyclingCell(symbol: slot1Symbol, isCorrect: slot1Correct) {
                slot1Index = (slot1Index + 1) % choices1.count
                HapticFeedback.tap()
            }
            Text("Tap the symbol to cycle through candidates")
                .font(EgyptFont.bodyItalic(15))
                .foregroundStyle(Color.stoneLight.opacity(0.40))
        }
    }

    // MARK: - Two Slots (China)

    private var chinaSlotsSection: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 10) {
                    Text("From Maya ruins")
                        .font(EgyptFont.title(12))
                        .tracking(1)
                        .foregroundStyle(Color.stoneLight.opacity(0.48))
                    cyclingCell(symbol: slot1Symbol, isCorrect: slot1Correct) {
                        slot1Index = (slot1Index + 1) % choices1.count
                        HapticFeedback.tap()
                    }
                }

                Text("&")
                    .font(EgyptFont.titleBold(26))
                    .foregroundStyle(Color.stoneLight.opacity(0.22))
                    .padding(.top, 30)

                VStack(spacing: 10) {
                    Text("From Celtic grove")
                        .font(EgyptFont.title(12))
                        .tracking(1)
                        .foregroundStyle(Color.stoneLight.opacity(0.48))
                    cyclingCell(symbol: slot2Symbol, isCorrect: slot2Correct) {
                        slot2Index = (slot2Index + 1) % TreeOfLifeKeys.chinaSlot2Choices.count
                        HapticFeedback.tap()
                    }
                }
            }

            Text("Tap each symbol to cycle through candidates")
                .font(EgyptFont.bodyItalic(15))
                .foregroundStyle(Color.stoneLight.opacity(0.40))
        }
    }

    // MARK: - Cycling Cell

    private func cyclingCell(symbol: String, isCorrect: Bool, onTap: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.12)) { onTap() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(isCorrect ? accentColor.opacity(0.18) : Color.stoneMid.opacity(0.38))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isCorrect ? accentColor : Color.stoneLight.opacity(0.18),
                                    lineWidth: isCorrect ? 2.0 : 1.0)
                    )
                    .shadow(color: isCorrect ? accentColor.opacity(0.45) : .clear, radius: 14)

                VStack(spacing: 8) {
                    Text(symbol)
                        .font(.system(size: 54))
                        .foregroundStyle(isCorrect ? accentColor : Color.stoneLight.opacity(0.88))
                        .contentTransition(.numericText())

                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.stoneLight.opacity(isCorrect ? 0.0 : 0.28))
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 22)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 140)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCorrect)
    }

    // MARK: - Aha Moment Card (China only)

    private var ahaCard: some View {
        VStack(spacing: 10) {
            Text("These are the same mark.")
                .font(EgyptFont.titleBold(20))
                .foregroundStyle(Color.goldBright)
                .tracking(1)
            Text("Maya and Celtic — half a world apart —\nleft the same symbol behind.\n\nThis was not a coincidence.")
                .font(EgyptFont.bodyItalic(17))
                .foregroundStyle(Color.stoneLight.opacity(0.80))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.goldDark.opacity(0.14))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.goldMid.opacity(0.42), lineWidth: 1.5))
        )
    }

    // MARK: - Action Buttons

    private var actionSection: some View {
        VStack(spacing: 12) {
            if allCorrect {
                Button { gameState.passKeyGate(for: civId) } label: {
                    StoneButton(title: "Begin Deciphering", icon: "arrow.right", style: .gold)
                }
                .transition(.scale.combined(with: .opacity))
            }

            Button {
                HapticFeedback.tap()
                gameState.currentScreen = .journal
            } label: {
                StoneButton(title: "Check Field Journal", icon: "book.pages", style: .muted)
            }

            Button {
                HapticFeedback.tap()
                gameState.currentScreen = .title
            } label: {
                StoneButton(title: "Return to Expedition", icon: "chevron.left", style: .muted)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: allCorrect)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color.stoneDark
            RadialGradient(
                colors: [accentColor.opacity(0.12), .clear],
                center: .top, startRadius: 40, endRadius: 340
            )
        }
    }
}

// MARK: - Preview

#Preview {
    CivKeyGateView(civId: .chinese)
        .environmentObject(GameState())
}
