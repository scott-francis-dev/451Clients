//
//  ActionCardDeck.swift
//  Common
//
//  A vertically-paging, full-screen deck of `ActionDeckCard`s — flick up/down
//  (TikTok-style) through your options; each card plays its video and offers a
//  single call-to-action. Shared by Signator (Create tab) and thesis.
//
//  Native vertical paging via ScrollView + `.scrollTargetBehavior(.paging)` and
//  `.containerRelativeFrame`, so it works on iOS, visionOS and macOS.
//

import SwiftUI

public struct ActionCardDeck: View {
    private let cards: [ActionDeckCard]
    private let onActivate: (ActionDeckCard) -> Void

    public init(cards: [ActionDeckCard], onActivate: @escaping (ActionDeckCard) -> Void) {
        self.cards = cards
        self.onActivate = onActivate
    }

    public var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(cards) { card in
                    ActionCardView(card: card) { onActivate(card) }
                        .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .background(Color.black)
        .ignoresSafeArea()
    }
}

/// One full-screen card: looping video (or tint gradient) behind a bottom-anchored
/// title / subtitle / CTA, with a subtle "swipe for more" hint.
private struct ActionCardView: View {
    let card: ActionDeckCard
    let onActivate: () -> Void

    var body: some View {
        ZStack {
            // Visual: looping muted video, or a tint gradient fallback.
            if let videoName = card.videoName {
                OnboardingVideoPlayer(videoName: videoName)
            } else {
                LinearGradient(
                    colors: [card.tint, card.tint.opacity(0.45)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }

            // Legibility scrim so white text reads over any video.
            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.15), .black.opacity(0.65)],
                startPoint: .center, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 12) {
                Spacer()

                Image(systemName: card.systemImage)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(radius: 6)

                Text(card.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .shadow(radius: 8)

                Text(card.subtitle)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(radius: 8)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onActivate) {
                    Text(card.actionLabel)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(card.tint, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)

                Label("Swipe for more", systemImage: "chevron.up")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }
            .padding(28)
        }
        .clipped()
    }
}

#Preview("Action deck") {
    ActionCardDeck(
        cards: [
            ActionDeckCard(id: "sign", title: "Sign a Document",
                       subtitle: "Review and cryptographically sign what's addressed to you.",
                       videoName: "onboarding3", systemImage: "signature", tint: .blue,
                       actionLabel: "Start signing"),
            ActionDeckCard(id: "witness", title: "Witness Capture",
                       subtitle: "Timestamp and archive an event with verifying info.",
                       videoName: "onboarding4", systemImage: "camera.viewfinder", tint: .purple,
                       actionLabel: "Capture"),
            ActionDeckCard(id: "template", title: "Templates",
                       subtitle: "Start from a ready-made document for this kind of contract.",
                       videoName: "onboarding5", systemImage: "doc.on.doc.fill", tint: .teal,
                       actionLabel: "Choose template"),
        ],
        onActivate: { _ in }
    )
}
