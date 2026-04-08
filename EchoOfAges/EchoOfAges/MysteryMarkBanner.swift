// MysteryMarkBanner.swift
// EchoOfAges
//
// Shown at the top of Level 1 for every non-Egyptian civilization.
// One symbol from a PREVIOUS civilization's ruins was found here.
// The player taps to cycle through candidate symbols; only the one
// mentioned in their Field Diary will allow Level 1 to be solved.
//
// No hints, no glow, no lock/unlock feedback — the player must read
// the diary entry written when the source civ's Level 5 was completed.

import SwiftUI

struct MysteryMarkBanner: View {
    let civ: CivilizationID
    let accentColor: Color

    @EnvironmentObject var gameState: GameState

    var body: some View {
        VStack(spacing: 14) {
            header
            instructionText
            if civ == .chinese {
                chinaSlots
            } else {
                singleSlot
            }
            diaryHint
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(gameState.mysteryMarkWrongFlash
                      ? Color.rubyRed.opacity(0.15)
                      : accentColor.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(gameState.mysteryMarkWrongFlash
                                ? Color.rubyRed.opacity(0.70)
                                : accentColor.opacity(0.28),
                                lineWidth: gameState.mysteryMarkWrongFlash ? 1.5 : 1)
                )
        )
        .animation(.easeInOut(duration: 0.25), value: gameState.mysteryMarkWrongFlash)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 13, weight: .semibold))
            Text(TreeOfLifeKeys.gateSourceLabel(for: civ).uppercased())
                .font(EgyptFont.title(11))
                .tracking(1)
        }
        .foregroundStyle(
            gameState.mysteryMarkWrongFlash ? Color.rubyRed : accentColor.opacity(0.65)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Instruction

    private var instructionText: some View {
        Text(gameState.mysteryMarkWrongFlash
             ? "The mark was not recognized — consult your Field Diary"
             : "One symbol here doesn't belong to this civilization's script. Identify it.")
            .font(EgyptFont.bodyItalic(14))
            .foregroundStyle(
                gameState.mysteryMarkWrongFlash
                ? Color.rubyRed.opacity(0.85)
                : Color.stoneLight.opacity(0.72)
            )
            .multilineTextAlignment(.leading)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Single slot (all civs except China)

    private var singleSlot: some View {
        cycleCell(
            symbol: gameState.mysteryMarkCurrent(for: civ)
        ) {
            gameState.cycleMysteryMark(for: civ)
        }
        .frame(maxWidth: 140)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Two slots (China)

    private var chinaSlots: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(spacing: 8) {
                Text("From Maya ruins")
                    .font(EgyptFont.title(11))
                    .tracking(1)
                    .foregroundStyle(accentColor.opacity(0.50))
                cycleCell(symbol: gameState.mysteryMarkCurrent(for: .chinese)) {
                    gameState.cycleMysteryMark(for: .chinese)
                }
            }

            Text("&")
                .font(EgyptFont.titleBold(22))
                .foregroundStyle(Color.stoneLight.opacity(0.22))
                .padding(.top, 28)

            VStack(spacing: 8) {
                Text("From Celtic grove")
                    .font(EgyptFont.title(11))
                    .tracking(1)
                    .foregroundStyle(accentColor.opacity(0.50))
                cycleCell(symbol: gameState.chinaMysteryMarkCurrent2) {
                    gameState.cycleChinaMysteryMark2()
                }
            }

            Spacer()
        }
    }

    // MARK: - Cycling cell

    private func cycleCell(symbol: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.stoneMid.opacity(0.38))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(accentColor.opacity(0.32), lineWidth: 1)
                    )

                VStack(spacing: 6) {
                    Text(symbol)
                        .font(.system(size: 46))
                        .foregroundStyle(accentColor)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.12), value: symbol)

                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.stoneLight.opacity(0.32))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Diary hint

    private var diaryHint: some View {
        Label("The Field Diary records this discovery", systemImage: "book.pages")
            .font(EgyptFont.body(12))
            .foregroundStyle(Color.stoneLight.opacity(0.38))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
