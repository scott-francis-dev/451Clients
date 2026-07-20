//
//  ActionDeckCard.swift
//  Common
//
//  A single selectable action rendered as a full-screen, swipeable "TikTok"
//  card. Both apps (Signator's Create tab, thesis's action surface) supply their
//  own `[ActionDeckCard]`; the deck (`ActionCardDeck`) is shared. Each card can show
//  a looping bundled video (reusing the onboarding videos) as its visual.
//

import SwiftUI

/// Describes one action the user can flick to and start. Pure data — selection
/// is handled by the deck's `onActivate` callback so this stays UI-agnostic.
public struct ActionDeckCard: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    /// Bundled looping video shown behind the card (e.g. "onboarding1"). When
    /// `nil`, a `tint` gradient is used instead.
    public let videoName: String?
    /// SF Symbol accent shown above the title.
    public let systemImage: String
    /// Accent color for the CTA button and the gradient fallback.
    public let tint: Color
    /// Call-to-action label (e.g. "Start", "Create", "Choose template").
    public let actionLabel: String

    public init(
        id: String,
        title: String,
        subtitle: String,
        videoName: String? = nil,
        systemImage: String = "square.stack.3d.up.fill",
        tint: Color = .blue,
        actionLabel: String = "Start"
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.videoName = videoName
        self.systemImage = systemImage
        self.tint = tint
        self.actionLabel = actionLabel
    }
}
