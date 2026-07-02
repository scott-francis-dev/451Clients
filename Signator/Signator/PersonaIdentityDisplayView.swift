//
//  PersonaIdentityDisplayView.swift
//  Signator
//
//  Created on 1/31/26.
//
//  Displays persona identity with proper visual hierarchy:
//  - Label (most prominent, human-readable)
//  - DID (subtle, underneath label)
//  - ORCID (bigger than DID, optional)
//  - Credential badges
//

import SwiftUI

/// Displays persona identity information with proper visual hierarchy
struct PersonaIdentityDisplayView: View {
    let persona: Persona
    var showCredentials: Bool = true
    var showFullDID: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Primary display: Name · Publisher (most readable)
            let name = persona.effectiveDisplayName
            let publisher = persona.effectiveDisplayPublisher
            
            if let publisher = publisher {
                Text("\(name) · \(publisher)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            } else {
                Text(name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            // DID (subtle, underneath)
            HStack(spacing: 4) {
                Text("DID:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(showFullDID ? persona.id : persona.displayDID)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
            
            // ORCID (if present, bigger than DID)
            if let orcid = persona.orcid {
                HStack(spacing: 6) {
                    Image(systemName: persona.orcidVerified ? "checkmark.seal.fill" : "person.text.rectangle")
                        .font(.caption)
                        .foregroundColor(persona.orcidVerified ? .green : .orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ORCID: \(orcid)")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                        
                        if persona.orcidVerified {
                            Text("Verified")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else {
                            Text("Pending verification")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Email verification status (if present)
            if let email = persona.email, showCredentials {
                HStack(spacing: 6) {
                    Image(systemName: persona.emailVerified ? "envelope.badge.shield.half.filled" : "envelope")
                        .font(.caption)
                        .foregroundColor(persona.emailVerified ? .blue : .gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        if persona.emailVerified {
                            Text("Verified")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        } else {
                            Text("Not verified")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            // Credential badges
            if showCredentials && !persona.credentialBadges.isEmpty {
                HStack(spacing: 8) {
                    ForEach(persona.credentialBadges, id: \.self) { badge in
                        Text(badge)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

/// Compact version for list rows
struct PersonaIdentityCompactView: View {
    let persona: Persona
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Name · Publisher
            let name = persona.effectiveDisplayName
            let publisher = persona.effectiveDisplayPublisher
            
            if let publisher = publisher {
                Text("\(name) · \(publisher)")
                    .font(.headline)
                    .foregroundColor(.primary)
            } else {
                Text(name)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // DID (very subtle)
            Text(persona.displayDID)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
            
            // ORCID if present
            if let orcid = persona.orcid {
                HStack(spacing: 4) {
                    Image(systemName: "graduationcap.fill")
                        .font(.caption2)
                        .foregroundColor(persona.orcidVerified ? .green : .orange)
                    Text(orcid)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            
            // Badges (inline)
            if !persona.credentialBadges.isEmpty {
                Text(persona.credentialDisplay)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Card-style display with background
struct PersonaIdentityCardView: View {
    let persona: Persona
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with blue sphere avatar
            HStack(spacing: 12) {
                // Blue sphere avatar (gradient)
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    // Person icon in white
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .shadow(color: .blue.opacity(0.3), radius: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Persona Identity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Show "Name · Publisher" format
                    let name = persona.effectiveDisplayName
                    let publisher = persona.effectiveDisplayPublisher
                    
                    if let publisher = publisher {
                        Text("\(name) · \(publisher)")
                            .font(.headline)
                    } else {
                        Text(name)
                            .font(.headline)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // Full identity display
            PersonaIdentityDisplayView(persona: persona)
        }
        .padding()
        .background(Color.platformSecondaryBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview("Full Display") {
    VStack(spacing: 20) {
        PersonaIdentityDisplayView(
            persona: Persona(
                id: "did:451:a4a360afd06844da8d939131f3dd2631",
                controller: "did:451:a4a360afd06844da8d939131f3dd2631",
                name: "Jane Wu",
                handle: "jane.wu.university.wisconsin.department.biology",
                email: "jane.wu@wisc.edu",
                emailVerified: true,
                orcid: "0000-0002-1825-0097",
                orcidVerified: true,
                publicKeyBase64: "mockKey123",
                createdAt: "2026-01-31T00:00:00Z"
            )
        )
        .padding()
        
        Divider()
        
        PersonaIdentityDisplayView(
            persona: Persona(
                id: "did:451:b5b471bge17955eb9e040242g4ee3742",
                controller: "did:451:b5b471bge17955eb9e040242g4ee3742",
                name: "John Doe",
                handle: "john.doe.freelance.writer",
                email: "john@example.com",
                emailVerified: false,
                publicKeyBase64: "mockKey456",
                createdAt: "2026-01-31T00:00:00Z"
            )
        )
        .padding()
    }
}

#Preview("Compact List") {
    List {
        PersonaIdentityCompactView(
            persona: Persona(
                id: "did:451:a4a360afd06844da8d939131f3dd2631",
                controller: "did:451:a4a360afd06844da8d939131f3dd2631",
                name: "Jane Wu",
                handle: "jane.wu.university.wisconsin.department.biology",
                email: "jane.wu@wisc.edu",
                emailVerified: true,
                orcid: "0000-0002-1825-0097",
                orcidVerified: true,
                publicKeyBase64: "mockKey123",
                createdAt: "2026-01-31T00:00:00Z"
            )
        )
        
        PersonaIdentityCompactView(
            persona: Persona(
                id: "did:451:b5b471bge17955eb9e040242g4ee3742",
                controller: "did:451:b5b471bge17955eb9e040242g4ee3742",
                name: "John Doe",
                handle: "john.doe.freelance.writer",
                publicKeyBase64: "mockKey456",
                createdAt: "2026-01-31T00:00:00Z"
            )
        )
    }
}

#Preview("Card Style") {
    PersonaIdentityCardView(
        persona: Persona(
            id: "did:451:a4a360afd06844da8d939131f3dd2631",
            controller: "did:451:a4a360afd06844da8d939131f3dd2631",
            name: "Jane Wu",
            handle: "jane.wu.university.wisconsin.department.biology",
            email: "jane.wu@wisc.edu",
            emailVerified: true,
            orcid: "0000-0002-1825-0097",
            orcidVerified: true,
            publicKeyBase64: "mockKey123",
            createdAt: "2026-01-31T00:00:00Z"
        )
    )
    .padding()
}
