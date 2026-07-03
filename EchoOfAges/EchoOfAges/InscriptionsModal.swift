// InscriptionsModal.swift
// EchoOfAges
//
// Shared scrollable modal sheet for field inscriptions.
// Used by all civilization game views to replace inline expand/collapse panels.

import SwiftUI

struct FieldInscriptionsModal: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let levelName: String
    let icon: String
    let inscriptions: [String]
    let acrosticChar: Character
    let accentColor: Color
    let bulletChar: String
    let backgroundColor: Color
    let surfaceColor: Color
    let textColor: Color

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(title.uppercased())
                            .font(EgyptFont.titleBold(22))
                            .tracking(3)
                    }
                    .foregroundStyle(accentColor)

                    Text(levelName)
                        .font(EgyptFont.bodyItalic(16))
                        .foregroundStyle(textColor.opacity(0.65))
                }
                .padding(.top, 28)
                .padding(.bottom, 18)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .background(
                    surfaceColor.opacity(0.5)
                        .overlay(
                            Rectangle()
                                .fill(accentColor.opacity(0.3))
                                .frame(height: 0.8),
                            alignment: .bottom
                        )
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(inscriptions.enumerated()), id: \.offset) { _, note in
                            HStack(alignment: .top, spacing: 14) {
                                Text(bulletChar)
                                    .font(.system(size: 22))
                                    .foregroundStyle(accentColor)
                                    .frame(width: 28)
                                    .padding(.top, 2)

                                Text(acrosticUnderlined(note, letter: acrosticChar))
                                    .font(EgyptFont.bodyItalic(20))
                                    .foregroundStyle(textColor)
                                    .lineSpacing(7)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(surfaceColor.opacity(0.35))
                                    .overlay(RoundedRectangle(cornerRadius: 10)
                                        .stroke(accentColor.opacity(0.2), lineWidth: 0.8))
                            )
                        }
                    }
                    .padding(24)
                }

                // Done button
                Button(action: { dismiss() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                        Text("Done")
                            .font(EgyptFont.titleBold(20))
                    }
                    .foregroundStyle(backgroundColor)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.80)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
            }
        }
    }
}
