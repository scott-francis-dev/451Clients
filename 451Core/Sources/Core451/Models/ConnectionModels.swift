//
//  ConnectionModels.swift
//  451Wallet
//
//  Connection request and colleague management models
//

import Foundation

// MARK: - Connection Request States

enum ConnectionStatus: String, Codable, Equatable {
    case pending = "pending"           // Request sent, awaiting response
    case accepted = "accepted"         // Both parties agreed
    case rejected = "rejected"         // Request was declined
    case blocked = "blocked"           // User blocked this connection
    case expired = "expired"           // Request expired (optional)
}

// MARK: - Connection Request Model

struct ConnectionRequest: Identifiable, Codable, Equatable, Hashable {
    let id: String                     // Unique request ID (server-generated)
    let fromDID: String                // Person who initiated the request
    let toDID: String                  // Person receiving the request
    var status: ConnectionStatus
    let createdAt: Date
    var respondedAt: Date?
    var message: String?               // Optional message from requester
    
    // Limited profile info exposed during pending state
    var requesterPreview: ConnectionPreview?
    var recipientPreview: ConnectionPreview?
    
    enum CodingKeys: String, CodingKey {
        case id, fromDID, toDID, status, createdAt, respondedAt, message
        case requesterPreview, recipientPreview
    }
}

// MARK: - Connection Preview (Limited Info)

/// Limited profile information shown before connection is accepted
struct ConnectionPreview: Codable, Equatable, Hashable {
    let did: String
    let name: String                   // Always shown
    let shortId: String?               // Always shown
    let prettyDID: String?             // Always shown
    
    // These are only populated after connection is accepted
    let handle: String?
    let email: String?
    let address: String?
    let affiliations: String?
    let socialLinks: String?
    
    var displayName: String {
        if !name.isEmpty { return name }
        if let prettyDID, !prettyDID.isEmpty { return prettyDID }
        if let shortId, !shortId.isEmpty { return shortId }
        return did
    }
    
    /// Create a preview from a resolved profile (before acceptance - limited info)
    static func pending(from profile: PersonaResolvedProfile) -> ConnectionPreview {
        ConnectionPreview(
            did: profile.did,
            name: profile.name ?? "Unknown",
            shortId: profile.shortId,
            prettyDID: profile.prettyDID,
            handle: nil,
            email: nil,
            address: nil,
            affiliations: nil,
            socialLinks: nil
        )
    }
    
    /// Create a preview from a full persona (after acceptance - full info)
    static func accepted(from persona: Persona) -> ConnectionPreview {
        ConnectionPreview(
            did: persona.id,
            name: persona.name,
            shortId: nil, // Could add computed property to Persona
            prettyDID: nil,
            handle: nil, // Could add if Persona gets handle field
            email: persona.email,
            address: persona.address,
            affiliations: persona.affiliations,
            socialLinks: persona.socialLinks
        )
    }
    
    /// Create a preview from a resolved profile (after acceptance - full info)
    static func accepted(from profile: PersonaResolvedProfile, fullPersona: Persona?) -> ConnectionPreview {
        ConnectionPreview(
            did: profile.did,
            name: profile.name ?? fullPersona?.name ?? "Unknown",
            shortId: profile.shortId,
            prettyDID: profile.prettyDID,
            handle: profile.handle,
            email: fullPersona?.email,
            address: fullPersona?.address,
            affiliations: fullPersona?.affiliations,
            socialLinks: fullPersona?.socialLinks
        )
    }
}

// MARK: - Verification Status

enum VerificationStatus: String, Codable, Equatable {
    case unverified = "unverified"         // Added but not verified
    case pendingVerification = "pending"   // Verification request sent
    case verified = "verified"             // Mutually verified connection
    case rejected = "rejected"             // Verification rejected
}

// MARK: - Colleague Model (Accepted Connection)

/// A colleague is an accepted connection with full profile access
struct Colleague: Identifiable, Codable, Equatable, Hashable {
    let id: String                     // Connection ID
    let did: String                    // Their DID
    let name: String
    let handle: String?
    let email: String?
    let address: String?
    let affiliations: String?
    let socialLinks: String?
    let shortId: String?
    let prettyDID: String?
    
    let connectedAt: Date
    var lastInteractionAt: Date?
    var notes: String?                 // Private notes about this colleague
    var isFavorite: Bool = false
    var tags: [String]?                // Custom organization tags
    var verificationStatus: VerificationStatus = .unverified  // Verification state
    
    var displayName: String {
        if !name.isEmpty { return name }
        if let prettyDID, !prettyDID.isEmpty { return prettyDID }
        if let handle, !handle.isEmpty { return "@\(handle)" }
        if let shortId, !shortId.isEmpty { return shortId }
        return did
    }
    
    var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = String(components[0].prefix(1))
            let last = String(components[1].prefix(1))
            return "\(first)\(last)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
    
    /// Create a colleague from an accepted connection request
    static func from(request: ConnectionRequest, myDID: String) -> Colleague? {
        // Determine which preview to use (the other person's)
        let preview: ConnectionPreview?
        if request.fromDID == myDID {
            preview = request.recipientPreview
        } else {
            preview = request.requesterPreview
        }
        
        guard let preview = preview else { return nil }
        
        return Colleague(
            id: request.id,
            did: preview.did,
            name: preview.name,
            handle: preview.handle,
            email: preview.email,
            address: preview.address,
            affiliations: preview.affiliations,
            socialLinks: preview.socialLinks,
            shortId: preview.shortId,
            prettyDID: preview.prettyDID,
            connectedAt: request.respondedAt ?? request.createdAt,
            lastInteractionAt: nil,
            notes: nil,
            isFavorite: false,
            tags: nil
        )
    }
}

// MARK: - Connection Request Creation

struct CreateConnectionRequest: Codable {
    let toDID: String
    let message: String?
}

struct ConnectionRequestResponse: Codable {
    let request: ConnectionRequest
    let success: Bool
    let error: String?
}

// MARK: - Connection Response Actions

struct RespondToConnectionRequest: Codable {
    let requestId: String
    let accept: Bool                   // true = accept, false = reject
    let message: String?               // Optional response message
}

struct ConnectionResponseResult: Codable {
    let request: ConnectionRequest
    let success: Bool
    let error: String?
}
