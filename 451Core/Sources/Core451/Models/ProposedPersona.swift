import Foundation

/// A persona proposed by a trusted party (e.g., a law firm) for client review.
/// This is not yet an active Persona on-device until the client accepts and signs.
struct ProposedPersona: Codable, Identifiable, Equatable {
    // Use proposalID as stable id
    let id: String                 // proposalID
    let name: String
    let handle: String?
    let displayName: String?
    let displayPublisher: String?
    let address: String?
    let email: String?
    let affiliations: String?

    // Provenance / metadata
    let proposer: String?          // DID or identifier of proposing party
    let issuedAt: String?          // ISO-8601 timestamp
}

/// Parsed payload extracted from a signed token (JWT/JWS) pointing to a Proposed Persona.
/// This is not a full JWT implementation — signature verification is handled by the service.
struct ProposedPersonaTokenPayload: Codable, Equatable {
    let iss: String            // issuer (law firm DID)
    let sub: String            // subject, should be "proposed-persona"
    let proposalID: String
    let tokenID: String?
    let objectKey: String?
    let proposalHash: String?  // sha256 of canonical fields (optional)
    let recipientEmailHash: String? // optional binding
    let nonce: String?
    let iat: Int               // issued-at (epoch seconds)
    let exp: Int               // expiry (epoch seconds)
    let kid: String?           // optional key id (may also be in header)
}

/// Convenience wrapper representing a parsed token and raw components.
struct ProposedPersonaToken: Equatable {
    let headerJSON: [String: String]
    let payload: ProposedPersonaTokenPayload
    let signatureBase64URL: String
}
