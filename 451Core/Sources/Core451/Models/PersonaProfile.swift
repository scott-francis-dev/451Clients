// PersonaProfile.swift
// Model for persona profiles, matching the backend API

import Foundation

public struct PersonaProfile: Codable, Hashable {
    public let dID: String
    public let controller: String
    public let backgroundCheckRequired: Bool
    public var guid: String?
    public var shortId: String?
    public var isPublic: Bool?
    public var handle: String  // ATProtocol: human-readable identifier

    public var name: String?
    public var displayName: String?        // Human-readable name (e.g., "Hal Linden")
    public var displayPublisher: String?   // Human-readable publisher (e.g., "Soho House")
    public var email: String?
    public var address: PostalAddress?
    public var affiliations: String?
    public var socialLinks: String?
    public var verified: Bool?
    public var requestedDomain: String?
    public var requestedDnsChallenge: String?
    public var backgroundValidated: Bool?
    public var validatedDomains: [String]?
    public var type: String?
    public var hash: String?
    public var storageEndpoints: [StorageEndpoint]?
    public var resourceFolders: [ResourceFolder]?
    public var metadata: [String: String]?
    public var privateData: PrivatePersonaData? // Encrypted private information
    public var createdAt: String?
    public var updatedAt: String?
    public var eTag: String?
    public let verificationMethod: [VerificationMethod]
    public let service: [Service]?
    public var previousBlock: String?
    public var relatedBlock: String?
    public var signature: String?

    public init(
        dID: String,
        controller: String,
        backgroundCheckRequired: Bool,
        guid: String? = nil,
        shortId: String? = nil,
        isPublic: Bool? = nil,
        handle: String,
        name: String? = nil,
        displayName: String? = nil,
        displayPublisher: String? = nil,
        email: String? = nil,
        address: PostalAddress? = nil,
        affiliations: String? = nil,
        socialLinks: String? = nil,
        verified: Bool? = nil,
        requestedDomain: String? = nil,
        requestedDnsChallenge: String? = nil,
        backgroundValidated: Bool? = nil,
        validatedDomains: [String]? = nil,
        type: String? = nil,
        hash: String? = nil,
        storageEndpoints: [StorageEndpoint]? = nil,
        resourceFolders: [ResourceFolder]? = nil,
        metadata: [String: String]? = nil,
        privateData: PrivatePersonaData? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        eTag: String? = nil,
        verificationMethod: [VerificationMethod],
        service: [Service]? = nil,
        previousBlock: String? = nil,
        relatedBlock: String? = nil,
        signature: String? = nil
    ) {
        self.dID = dID
        self.controller = controller
        self.backgroundCheckRequired = backgroundCheckRequired
        self.guid = guid
        self.shortId = shortId
        self.isPublic = isPublic
        self.handle = handle
        self.name = name
        self.displayName = displayName
        self.displayPublisher = displayPublisher
        self.email = email
        self.address = address
        self.affiliations = affiliations
        self.socialLinks = socialLinks
        self.verified = verified
        self.requestedDomain = requestedDomain
        self.requestedDnsChallenge = requestedDnsChallenge
        self.backgroundValidated = backgroundValidated
        self.validatedDomains = validatedDomains
        self.type = type
        self.hash = hash
        self.storageEndpoints = storageEndpoints
        self.resourceFolders = resourceFolders
        self.metadata = metadata
        self.privateData = privateData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.eTag = eTag
        self.verificationMethod = verificationMethod
        self.service = service
        self.previousBlock = previousBlock
        self.relatedBlock = relatedBlock
        self.signature = signature
    }

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

    public struct VerificationMethod: Codable, Hashable {
        public let id: String
        public let type: String
        public let controller: String
        public let publicKeyBase64: String

        public init(id: String, type: String, controller: String, publicKeyBase64: String) {
            self.id = id
            self.type = type
            self.controller = controller
            self.publicKeyBase64 = publicKeyBase64
        }
    }
    public struct Service: Codable, Hashable {
        public let id: String
        public let type: String
        public let serviceEndpoint: [String]
        public let metadata: [String: String]?

        public init(id: String, type: String, serviceEndpoint: [String], metadata: [String: String]? = nil) {
            self.id = id
            self.type = type
            self.serviceEndpoint = serviceEndpoint
            self.metadata = metadata
        }
    }
    public struct StorageEndpoint: Codable, Hashable {
        public let providerName: String
        public let url: String
        public let eTag: String
        public let lastVerified: String?

        public init(providerName: String, url: String, eTag: String, lastVerified: String? = nil) {
            self.providerName = providerName
            self.url = url
            self.eTag = eTag
            self.lastVerified = lastVerified
        }
    }
    public struct ResourceFolder: Codable, Hashable {
        public let providerName: String
        public let folderPath: String
        public let type: String
        public let eTag: String
        public let lastVerified: String?

        public init(providerName: String, folderPath: String, type: String, eTag: String, lastVerified: String? = nil) {
            self.providerName = providerName
            self.folderPath = folderPath
            self.type = type
            self.eTag = eTag
            self.lastVerified = lastVerified
        }
    }
    public struct PostalAddress: Codable, Hashable {
        public var street: String?
        public var city: String?
        public var state: String?
        public var postalCode: String?
        public var country: String?

        public init(street: String? = nil, city: String? = nil, state: String? = nil, postalCode: String? = nil, country: String? = nil) {
            self.street = street
            self.city = city
            self.state = state
            self.postalCode = postalCode
            self.country = country
        }
    }

    public struct PrivatePersonaData: Codable, Hashable {
        public var givenName: String?
        public var aliases: String?
        public var privateEmail: String?
        public var socialSecurityNumber: String?
        public var privateAddress: PostalAddress?
        // This will be stored encrypted on the client and only decrypted when needed for document signing

        public init(givenName: String? = nil, aliases: String? = nil, privateEmail: String? = nil, socialSecurityNumber: String? = nil, privateAddress: PostalAddress? = nil) {
            self.givenName = givenName
            self.aliases = aliases
            self.privateEmail = privateEmail
            self.socialSecurityNumber = socialSecurityNumber
            self.privateAddress = privateAddress
        }
    }
}
