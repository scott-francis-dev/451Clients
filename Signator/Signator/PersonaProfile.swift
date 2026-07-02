// PersonaProfile.swift
// Model for persona profiles, matching the backend API

import Foundation

struct PersonaProfile: Codable, Hashable {
    let dID: String
    let controller: String
    let backgroundCheckRequired: Bool
    var guid: String?
    var shortId: String?
    var isPublic: Bool?
    var handle: String  // ATProtocol: human-readable identifier

    var name: String?
    var displayName: String?        // Human-readable name (e.g., "Hal Linden")
    var displayPublisher: String?   // Human-readable publisher (e.g., "Soho House")
    var email: String?
    var address: PostalAddress?
    var affiliations: String?
    var socialLinks: String?
    var verified: Bool?
    var requestedDomain: String?
    var requestedDnsChallenge: String?
    var backgroundValidated: Bool?
    var validatedDomains: [String]?
    var type: String?
    var hash: String?
    var storageEndpoints: [StorageEndpoint]?
    var resourceFolders: [ResourceFolder]?
    var metadata: [String: String]?
    var privateData: PrivatePersonaData? // Encrypted private information
    var createdAt: String?
    var updatedAt: String?
    var eTag: String?
    let verificationMethod: [VerificationMethod]
    let service: [Service]?
    var previousBlock: String?
    var relatedBlock: String?
    var signature: String?
    
    // Custom coding keys to map dID (Swift) to did (JSON)
    enum CodingKeys: String, CodingKey {
        case dID = "did"
        case controller
        case backgroundCheckRequired
        case guid
        case shortId
        case isPublic
        case handle
        case name
        case displayName
        case displayPublisher
        case email
        case address
        case affiliations
        case socialLinks
        case verified
        case requestedDomain
        case requestedDnsChallenge
        case backgroundValidated
        case validatedDomains
        case type
        case hash
        case storageEndpoints
        case resourceFolders
        case metadata
        case privateData
        case createdAt
        case updatedAt
        case eTag
        case verificationMethod
        case service
        case previousBlock
        case relatedBlock
        case signature
    }

    struct VerificationMethod: Codable, Hashable {
        let id: String
        let type: String
        let controller: String
        let publicKeyBase64: String
    }
    struct Service: Codable, Hashable {
        let id: String
        let type: String
        let serviceEndpoint: [String]
        let metadata: [String: String]?
    }
    struct StorageEndpoint: Codable, Hashable {
        let providerName: String
        let url: String
        let eTag: String
        let lastVerified: String?
    }
    struct ResourceFolder: Codable, Hashable {
        let providerName: String
        let folderPath: String
        let type: String
        let eTag: String
        let lastVerified: String?
    }
    struct PostalAddress: Codable, Hashable {
        var street: String?
        var city: String?
        var state: String?
        var postalCode: String?
        var country: String?
    }
    
    struct PrivatePersonaData: Codable, Hashable {
        var givenName: String?
        var aliases: String?
        var privateEmail: String?
        var socialSecurityNumber: String?
        var privateAddress: PostalAddress?
        // This will be stored encrypted on the client and only decrypted when needed for document signing
    }
}
