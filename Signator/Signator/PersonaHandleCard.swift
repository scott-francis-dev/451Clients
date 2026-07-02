//
//  PersonaHandleCard.swift
//  451Wallet
//
//  The Signator Calling Card - Persona Handle Display Component
//
//  This is the consistent visual representation of a persona handle throughout the app.
//  It uses the "blue sphere" (Liquid Glass) design to create a recognizable identity marker.
//
//  Usage:
//  - Document signing views
//  - Persona lists
//  - Identity verification
//  - Anywhere a persona handle needs to be displayed
//
//  The handle is constructed from: [name].[publishing.house].451.info
//  - Name: Can be 1-5 parts (e.g., "Ron John Flabber Egassi III")
//  - Publishing House: Can be 1-5 parts (e.g., "Flabber Egassi Design Studio")
//  - Both are normalized: lowercased, spaces → periods, collapsed periods
//

import SwiftUI

/// Display size variants for the persona handle card
enum PersonaHandleCardSize {
    case compact    // Small, for lists
    case standard   // Medium, for detail views
    case prominent  // Large, for signing/verification
    
    var padding: CGFloat {
        switch self {
        case .compact: return 12
        case .standard: return 16
        case .prominent: return 20
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .compact: return 12
        case .standard: return 16
        case .prominent: return 20
        }
    }
    
    var handleFont: Font {
        switch self {
        case .compact: return .subheadline
        case .standard: return .title3
        case .prominent: return .title2
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .compact: return 16
        case .standard: return 20
        case .prominent: return 24
        }
    }
}

/// The Signator Calling Card - Consistent persona handle display with Liquid Glass effect
struct PersonaHandleCard: View {
    let handle: String
    let isPublic: Bool
    let size: PersonaHandleCardSize
    let showCopyButton: Bool
    
    init(handle: String, isPublic: Bool = true, size: PersonaHandleCardSize = .standard, showCopyButton: Bool = false) {
        self.handle = handle
        self.isPublic = isPublic
        self.size = size
        self.showCopyButton = showCopyButton
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "at")
                .font(.system(size: size.iconSize))
                .foregroundColor(isPublic ? .blue : .purple)
            
            Text(handle)
                .font(size.handleFont)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            if showCopyButton {
                Spacer()
                Button {
                    copyToClipboard(handle)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: size.iconSize - 4))
                        .foregroundColor(isPublic ? .blue : .purple)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(size.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PersonaCardGlassEffect(isPublic: isPublic, cornerRadius: size.cornerRadius))
    }
    
    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

/// Persona Handle Card with full details (handle, name, DID)
struct PersonaHandleDetailCard: View {
    let persona: Persona
    let size: PersonaHandleCardSize
    let showDID: Bool
    let showCopyButton: Bool
    
    init(persona: Persona, size: PersonaHandleCardSize = .standard, showDID: Bool = true, showCopyButton: Bool = false) {
        self.persona = persona
        self.size = size
        self.showDID = showDID
        self.showCopyButton = showCopyButton
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Name · Publisher (co-equal display)
            let displayName = persona.effectiveDisplayName
            let displayPublisher = persona.effectiveDisplayPublisher
            
            if let publisher = displayPublisher {
                Text("\(displayName) · \(publisher)")
                    .font(size == .prominent ? .title : .headline)
                    .fontWeight(.medium)
            } else if !persona.name.isEmpty && persona.name != persona.handle {
                Text(persona.name)
                    .font(size == .prominent ? .title : .headline)
                    .fontWeight(.medium)
            }
            
            // Handle (the calling card) - only show if we don't have displayName + displayPublisher
            // When we show "Name · Publisher" above, the technical handle is redundant
            if displayPublisher == nil {
                HStack(spacing: 8) {
                    Image(systemName: "at")
                        .font(.system(size: size.iconSize))
                        .foregroundColor(persona.visibility == .public ? .blue : .purple)
                    
                    Text(persona.handle)
                        .font(size.handleFont)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                    
                    if showCopyButton {
                        Spacer()
                        Button {
                            copyToClipboard(persona.handle)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: size.iconSize - 4))
                                .foregroundColor(persona.visibility == .public ? .blue : .purple)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // DID (abbreviated, technical reference)
            if showDID {
                HStack(spacing: 6) {
                    Image(systemName: "key.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(persona.id.suffix(24)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(size.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PersonaCardGlassEffect(isPublic: persona.visibility == .public, cornerRadius: size.cornerRadius))
    }
    
    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

/// Glass effect with iOS version fallback
private struct PersonaCardGlassEffect: ViewModifier {
    let isPublic: Bool
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular
                        .tint(isPublic ? .blue : .purple)
                        .interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            // Fallback for current iOS versions - ultra-thin material with color overlay
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(isPublic ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1))
                        }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(isPublic ? Color.blue.opacity(0.3) : Color.purple.opacity(0.3), lineWidth: 1)
                }
                .shadow(color: (isPublic ? Color.blue : Color.purple).opacity(0.15), radius: 8)
        }
    }
}

// MARK: - Preview

#Preview("Compact Size") {
    VStack(spacing: 16) {
        PersonaHandleCard(
            handle: "sara.silver.silver.publishing.451.info",
            isPublic: true,
            size: .compact
        )
        
        PersonaHandleCard(
            handle: "123-4567.451.info",
            isPublic: false,
            size: .compact
        )
    }
    .padding()
}

#Preview("Standard Size") {
    VStack(spacing: 16) {
        PersonaHandleCard(
            handle: "ron.john.flabber.egassi.iii.flabber.egassi.design.studio.451.info",
            isPublic: true,
            size: .standard,
            showCopyButton: true
        )
        
        PersonaHandleCard(
            handle: "456-7890.451.info",
            isPublic: false,
            size: .standard,
            showCopyButton: true
        )
    }
    .padding()
}

#Preview("Prominent Size") {
    VStack(spacing: 16) {
        PersonaHandleCard(
            handle: "gary-lutz.lutz-publishing.451.info",
            isPublic: true,
            size: .prominent,
            showCopyButton: true
        )
    }
    .padding()
}

#Preview("Detail Card") {
    let samplePersona = Persona(
        id: "did:451:a8k7m4p9n2q1x5z3w6y9",
        controller: "controller-id",
        name: "Ron John Flabber Egassi III",
        handle: "ron.john.flabber.egassi.iii.flabber.egassi.design.studio.451.info",
        address: nil,
        email: nil,
        emailVerified: false,
        orcid: nil,
        orcidVerified: false,
        affiliations: nil,
        socialLinks: nil,
        publicKeyBase64: "",
        storageEndpoints: nil,
        createdAt: "2026-02-02",
        updatedAt: nil,
        eTag: nil,
        visibility: .public,
        status: "active"
    )
    
    return VStack(spacing: 20) {
        PersonaHandleDetailCard(
            persona: samplePersona,
            size: .standard,
            showDID: true,
            showCopyButton: true
        )
        
        PersonaHandleDetailCard(
            persona: samplePersona,
            size: .prominent,
            showDID: true,
            showCopyButton: true
        )
    }
    .padding()
}
