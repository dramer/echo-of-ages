// JournalView.swift
// EchoOfAges

import SwiftUI

struct JournalView: View {
    @EnvironmentObject var gameState: GameState
    @State private var expandedEntryId: Int? = nil

    // All possible entries from all levels
    private let allEntries = Level.allLevels.map(\.journalEntry)

    var body: some View {
        ZStack {
            // Background
            Color.stoneDark.ignoresSafeArea()
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.4)],
                center: .center,
                startRadius: 150,
                endRadius: 450
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()
                    .background(Color.goldDark.opacity(0.5))
                    .padding(.horizontal)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(allEntries) { entry in
                            entryRow(entry)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
        .onAppear {
            // Auto-expand the spotlight entry if set
            if let spotId = gameState.spotlightJournalId {
                expandedEntryId = spotId
                gameState.spotlightJournalId = nil
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            Button(action: { gameState.closeJournal() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Return")
                        .font(EgyptFont.title(13))
                }
                .foregroundStyle(Color.goldMid)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.stoneMid.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.stoneLight.opacity(0.4), lineWidth: 0.7)
                        )
                )
            }

            Spacer()

            VStack(spacing: 2) {
                Text("𓏠")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.goldMid)
                Text("THE JOURNAL")
                    .font(EgyptFont.title(15))
                    .foregroundStyle(Color.goldBright)
                    .tracking(3)
            }

            Spacer()

            // Balance the back button
            Color.clear.frame(width: 80, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: Entry Row

    @ViewBuilder
    private func entryRow(_ entry: JournalEntry) -> some View {
        let isUnlocked = gameState.unlockedJournalEntries.contains(entry.id)
        let isExpanded = expandedEntryId == entry.id

        VStack(spacing: 0) {
            // Row header
            Button(action: {
                guard isUnlocked else { return }
                withAnimation(.easeInOut(duration: 0.28)) {
                    expandedEntryId = isExpanded ? nil : entry.id
                }
                HapticFeedback.tap()
            }) {
                HStack(spacing: 14) {
                    Text(isUnlocked ? entry.artifact : "𓎟")
                        .font(.system(size: 28))
                        .foregroundStyle(isUnlocked ? Color.goldBright : Color.stoneLight)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(isUnlocked ? entry.title : "Sealed Inscription \(entry.id)")
                            .font(EgyptFont.titleBold(15))
                            .foregroundStyle(isUnlocked ? Color.goldBright : Color.stoneLight)
                        Text(isUnlocked ? "Chamber \(entry.id)" : "— Complete chamber \(entry.id) to unlock —")
                            .font(EgyptFont.bodyItalic(13))
                            .foregroundStyle(isUnlocked ? Color.papyrus.opacity(0.7) : Color.stoneLight.opacity(0.6))
                    }

                    Spacer()

                    if isUnlocked {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.goldDark)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.stoneLight.opacity(0.5))
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }

            // Expanded body
            if isUnlocked && isExpanded {
                Divider()
                    .background(Color.goldDark.opacity(0.3))
                    .padding(.horizontal, 16)

                Text(entry.body)
                    .font(EgyptFont.body(16))
                    .foregroundStyle(Color.papyrus)
                    .lineSpacing(5)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isUnlocked
                      ? LinearGradient(colors: [Color.stoneMid, Color(red: 0.20, green: 0.15, blue: 0.09)],
                                       startPoint: .top, endPoint: .bottom)
                      : LinearGradient(colors: [Color.stoneDark, Color.stoneDark],
                                       startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isUnlocked ? Color.goldDark.opacity(0.5) : Color.stoneLight.opacity(0.2),
                                lineWidth: isUnlocked ? 1 : 0.5)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 3)
    }
}

#Preview {
    JournalView()
        .environmentObject({
            let gs = GameState()
            gs.unlockedJournalEntries = [1, 2]
            return gs
        }())
}
