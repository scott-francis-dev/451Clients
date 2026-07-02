// PlatformCompat.swift
// Cross-platform shims so the Signator target builds and runs on iOS, macOS, and visionOS.
//
// Signator's UI was originally written iOS-only. macOS has no UIKit, and several
// SwiftUI modifiers (navigationBarTitleDisplayMode, keyboardType, textInputAutocapitalization,
// fullScreenCover, the UIColor-backed system colors, …) are unavailable there.
// Prefer the helpers in this file over UIKit types or iOS-only modifiers directly.
//
// Note: thesis has an equivalent `Color+Platform.swift`. These could later be hoisted
// into the shared Core451 package to dedupe across both apps.

import SwiftUI

// `PlatformImage` (UIImage / NSImage) is defined once in PlatformImage.swift.
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - System colors

extension Color {
#if canImport(UIKit)
    static let platformBackground                 = Color(UIColor.systemBackground)
    static let platformSecondaryBackground        = Color(UIColor.secondarySystemBackground)
    static let platformGroupedBackground          = Color(UIColor.systemGroupedBackground)
    static let platformSecondaryGroupedBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let platformGray6                      = Color(UIColor.systemGray6)
    static let platformGray5                      = Color(UIColor.systemGray5)
    static let platformGray4                      = Color(UIColor.systemGray4)
    static let platformGray                       = Color(UIColor.systemGray)
#elseif canImport(AppKit)
    static let platformBackground                 = Color(NSColor.windowBackgroundColor)
    static let platformSecondaryBackground        = Color(NSColor.underPageBackgroundColor)
    static let platformGroupedBackground          = Color(NSColor.controlBackgroundColor)
    static let platformSecondaryGroupedBackground = Color(NSColor.windowBackgroundColor)
    static let platformGray6                      = Color(NSColor.systemGray).opacity(0.18)
    static let platformGray5                      = Color(NSColor.systemGray).opacity(0.30)
    static let platformGray4                      = Color(NSColor.systemGray).opacity(0.45)
    static let platformGray                       = Color(NSColor.systemGray)
#endif
}

// MARK: - Images

extension Image {
    /// Build a SwiftUI `Image` from a `PlatformImage` (UIImage on iOS/visionOS, NSImage on macOS).
    init(platformImage: PlatformImage) {
#if canImport(UIKit)
        self.init(uiImage: platformImage)
#elseif canImport(AppKit)
        self.init(nsImage: platformImage)
#endif
    }
}

extension PlatformImage {
    /// Load an image by asset name, falling back to a bundled file (jpg/jpeg/png).
    static func named(_ name: String) -> PlatformImage? {
#if canImport(UIKit)
        if let assetImage = UIImage(named: name) { return assetImage }
#elseif canImport(AppKit)
        if let assetImage = NSImage(named: name) { return assetImage }
#endif
        for ext in ["jpg", "jpeg", "png"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
#if canImport(UIKit)
                if let image = UIImage(contentsOfFile: url.path) { return image }
#elseif canImport(AppKit)
                if let image = NSImage(contentsOfFile: url.path) { return image }
#endif
            }
        }
        return nil
    }
}

// MARK: - Navigation title display mode

extension View {
    /// Applies `.navigationBarTitleDisplayMode(.inline)` on platforms that support it; no-op on macOS.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
#if os(iOS) || os(visionOS)
        self.navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }
}

// MARK: - Text input modifiers

enum PlatformKeyboardType {
    case `default`, emailAddress, url, numberPad, numbersAndPunctuation, decimalPad, phonePad
}

enum PlatformTextCase {
    case never, characters, words, sentences
}

enum PlatformTextContentType {
    case none, name, emailAddress, url
}

extension View {
    /// Cross-platform `keyboardType`; no-op on macOS.
    @ViewBuilder
    func platformKeyboardType(_ type: PlatformKeyboardType) -> some View {
#if os(iOS) || os(visionOS)
        switch type {
        case .default:               self.keyboardType(.default)
        case .emailAddress:          self.keyboardType(.emailAddress)
        case .url:                   self.keyboardType(.URL)
        case .numberPad:             self.keyboardType(.numberPad)
        case .numbersAndPunctuation: self.keyboardType(.numbersAndPunctuation)
        case .decimalPad:            self.keyboardType(.decimalPad)
        case .phonePad:              self.keyboardType(.phonePad)
        }
#else
        self
#endif
    }

    /// Cross-platform `textInputAutocapitalization`; no-op on macOS.
    @ViewBuilder
    func platformAutocapitalization(_ textCase: PlatformTextCase) -> some View {
#if os(iOS) || os(visionOS)
        switch textCase {
        case .never:     self.textInputAutocapitalization(.never)
        case .characters: self.textInputAutocapitalization(.characters)
        case .words:     self.textInputAutocapitalization(.words)
        case .sentences: self.textInputAutocapitalization(.sentences)
        }
#else
        self
#endif
    }

    /// Cross-platform `textContentType`; no-op on macOS.
    @ViewBuilder
    func platformTextContentType(_ type: PlatformTextContentType) -> some View {
#if os(iOS) || os(visionOS)
        switch type {
        case .none:         self.textContentType(.none)
        case .name:         self.textContentType(.name)
        case .emailAddress: self.textContentType(.emailAddress)
        case .url:          self.textContentType(.URL)
        }
#else
        self
#endif
    }
}

// MARK: - Full screen cover

extension View {
    /// `fullScreenCover` on platforms that support it; falls back to `sheet` on macOS.
    @ViewBuilder
    func platformFullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
#if os(iOS) || os(visionOS)
        self.fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
#else
        self.sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
#endif
    }
}

// MARK: - Pasteboard

enum PlatformPasteboard {
    /// Copy a string to the general pasteboard.
    static func copy(_ string: String) {
#if canImport(UIKit)
        UIPasteboard.general.string = string
#elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
#endif
    }

    /// The current string on the general pasteboard, if any.
    static var string: String? {
#if canImport(UIKit)
        return UIPasteboard.general.string
#elseif canImport(AppKit)
        return NSPasteboard.general.string(forType: .string)
#endif
    }
}

// MARK: - Open URL

enum PlatformURLOpener {
    /// Open a URL using the platform's default handler.
    @MainActor
    static func open(_ url: URL) {
#if canImport(UIKit)
        UIApplication.shared.open(url)
#elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
#endif
    }
}

// MARK: - Haptics

/// Cross-platform haptic feedback. No-ops on platforms without a Taptic Engine (macOS).
struct PlatformHaptics {
    enum Impact { case light, medium, heavy, soft, rigid }
    enum Notification { case success, warning, error }

    init() {}

    func impact(_ style: Impact = .light) {
#if os(iOS)
        let uiStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light:  uiStyle = .light
        case .medium: uiStyle = .medium
        case .heavy:  uiStyle = .heavy
        case .soft:   uiStyle = .soft
        case .rigid:  uiStyle = .rigid
        }
        UIImpactFeedbackGenerator(style: uiStyle).impactOccurred()
#endif
    }

    func notify(_ type: Notification) {
#if os(iOS)
        let uiType: UINotificationFeedbackGenerator.FeedbackType
        switch type {
        case .success: uiType = .success
        case .warning: uiType = .warning
        case .error:   uiType = .error
        }
        UINotificationFeedbackGenerator().notificationOccurred(uiType)
#endif
    }
}
