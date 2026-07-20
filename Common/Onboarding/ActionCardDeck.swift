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
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct ActionCardDeck: View {
    private let cards: [ActionDeckCard]
    private let onActivate: (ActionDeckCard) -> Void

    @State private var showHint = false

    public init(cards: [ActionDeckCard], onActivate: @escaping (ActionDeckCard) -> Void) {
        self.cards = cards
        self.onActivate = onActivate
    }

    public var body: some View {
        // Capture the bottom safe-area inset (tab bar + home indicator) BEFORE the
        // ScrollView ignores it, so card content can be padded to clear the tab bar
        // while the artwork still runs full-screen underneath it.
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(cards) { card in
                        ActionCardView(card: card, bottomSafeInset: bottomInset) { onActivate(card) }
                            .containerRelativeFrame([.horizontal, .vertical])
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .background(Color.black)
            // Full-screen, edge-to-edge — cards run under the tab bar so paging is clean.
            .ignoresSafeArea()
            .overlay(alignment: .center) {
                if showHint { swipeHint }
            }
            .onAppear(perform: maybeShowHint)
        }
    }

    private func maybeShowHint() {
        // Show the hint each time the deck appears (re-entrancy guard only).
        // TODO: gate to first-run-only via @AppStorage for production.
        guard !showHint else { return }
        withAnimation(.easeIn(duration: 0.2)) { showHint = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000) // ~1.2s visible, then fade
            withAnimation(.easeOut(duration: 0.45)) { showHint = false }
        }
    }

    /// Brief first-run overlay teaching the up/down swipe gesture.
    private var swipeHint: some View {
        VStack(spacing: 14) {
            Image(systemName: "chevron.up")
            Text("Swipe up & down\nto browse")
                .multilineTextAlignment(.center)
                .font(.headline)
            Image(systemName: "chevron.down")
        }
        .font(.title2.weight(.semibold))
        .foregroundStyle(.white)
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .shadow(radius: 20)
    }
}

/// One full-screen card: looping video (or tint gradient) behind a bottom-anchored
/// title / subtitle / CTA, with a subtle "swipe for more" hint.
private struct ActionCardView: View {
    let card: ActionDeckCard
    let bottomSafeInset: CGFloat
    let onActivate: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Background: still image, else looping video, else a tint gradient.
                // Forced to EXACTLY the card size and clipped so a large photo can't
                // overflow and drag the layout horizontally.
                backgroundView
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                // Legibility scrim so white text reads over any photo/video.
                LinearGradient(
                    colors: [.black.opacity(0.0), .black.opacity(0.25), .black.opacity(0.72)],
                    startPoint: .center, endPoint: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.height)

                // Content, anchored bottom-leading, constrained to the card width.
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: card.systemImage)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 6)

                    Text(card.title)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .shadow(radius: 8)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(card.subtitle)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(radius: 8)
                        .fixedSize(horizontal: false, vertical: true)

                    // Subtle affordance — the WHOLE card is tappable (see onTapGesture),
                    // so this is a gentle hint rather than a loud button.
                    HStack(spacing: 6) {
                        Text(card.actionLabel)
                        Image(systemName: "arrow.forward")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .shadow(radius: 6)
                    .padding(.top, 2)

                    Label("Tap to start · swipe for more", systemImage: "hand.tap.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(24)
                // Clear the tab bar / home indicator, since the card now runs
                // full-screen underneath them.
                .padding(.bottom, bottomSafeInset + 16)
                .frame(width: geo.size.width, alignment: .leading)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { onActivate() }
        }
    }

    /// Background for a card: still image, else looping video, else a tint gradient.
    @ViewBuilder
    private var backgroundView: some View {
        if let imageName = card.imageName, let img = ActionCardView.loadImage(named: imageName) {
            img.resizable().scaledToFill()
        } else if let videoName = card.videoName {
            OnboardingVideoPlayer(videoName: videoName)
        } else {
            LinearGradient(
                colors: [card.tint, card.tint.opacity(0.45)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    /// Load a still image by asset name or loose bundle file (jpg/jpeg/png/heic), cross-platform.
    static func loadImage(named name: String) -> Image? {
        #if canImport(UIKit)
        if let ui = UIImage(named: name) { return Image(uiImage: ui) }
        for ext in ["jpg", "jpeg", "png", "heic"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let ui = UIImage(contentsOfFile: url.path) { return Image(uiImage: ui) }
        }
        #elseif canImport(AppKit)
        if let ns = NSImage(named: name) { return Image(nsImage: ns) }
        for ext in ["jpg", "jpeg", "png", "heic"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let ns = NSImage(contentsOfFile: url.path) { return Image(nsImage: ns) }
        }
        #endif
        return nil
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
