//
//  Persona.swift
//  451Wallet
//
//  Created by User451 on 4/25/25.
//

import Foundation
import CryptoKit

struct Persona: Identifiable, Codable, Equatable {
    // 🆔 Core
    enum Visibility: String, Codable, Equatable {
        case `public`
        case `private`
    }
    
    var id: String   // Full DID
    var controller: String
    
    // 🧑‍💼 Persona Info
    var name: String
    var handle: String             // ATProtocol: human-readable identifier (e.g., sara.silver.silver.publishing.451.info)
    var displayName: String?       // Human-readable name part (e.g., "Sam Sooner")
    var displayPublisher: String?  // Human-readable publisher part (e.g., "Sooner Publishing")
    var address: String?
    var email: String?
    var emailVerified: Bool = false
    var orcid: String?             // Optional: ORCID identifier (format: 0000-0002-1825-0097)
    var orcidVerified: Bool = false
    var affiliations: String?
    var socialLinks: String?
    var status: String = "active" // Possible values: "active", "archived", etc.
    var visibility: Visibility = .public
    
    // 🔑 Verification
    var publicKeyBase64: String
    
    // 🛠️ Services (storage)
    var storageEndpoints: [StorageEndpoint]?
    
    // 📅 Metadata
    var createdAt: String
    var updatedAt: String?
    var eTag: String?
    
    init(
        id: String,
        controller: String,
        name: String,
        handle: String,
        displayName: String? = nil,
        displayPublisher: String? = nil,
        address: String? = nil,
        email: String? = nil,
        emailVerified: Bool = false,
        orcid: String? = nil,
        orcidVerified: Bool = false,
        affiliations: String? = nil,
        socialLinks: String? = nil,
        publicKeyBase64: String,
        storageEndpoints: [StorageEndpoint]? = nil,
        createdAt: String,
        updatedAt: String? = nil,
        eTag: String? = nil,
        visibility: Visibility = .public,
        status: String = "active"
    ) {
        self.id = id
        self.controller = controller
        self.name = name
        self.handle = handle
        self.displayName = displayName
        self.displayPublisher = displayPublisher
        self.address = address
        self.email = email
        self.emailVerified = emailVerified
        self.orcid = orcid
        self.orcidVerified = orcidVerified
        self.affiliations = affiliations
        self.socialLinks = socialLinks
        self.publicKeyBase64 = publicKeyBase64
        self.storageEndpoints = storageEndpoints
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.eTag = eTag
        self.status = status
        self.visibility = visibility
    }
    
    // 📂 Nested Types
    struct StorageEndpoint: Codable, Identifiable, Equatable {
        var did: String
        var providerName: String
        var url: String
        var eTag: String?
        
        var id: String { did }
    }
}

extension Persona {
    // A stable, non-PII short identifier derived from the DID
    // Uses the first 8 hex characters of SHA-256(id)
    var shortID: String {
        let digest = SHA256.hash(data: Data(id.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(8)).uppercased()
    }

    // Display short ID like a phone number: first 3, a dash, then last 4
    var shortIDPhoneStyle: String {
        let s = shortID
        guard s.count >= 7 else { return s }
        let first3 = s.prefix(3)
        let last4 = s.suffix(4)
        return "\(first3)-\(last4)"
    }
    
    // MARK: - ORCID Validation
    
    /// Validates ORCID format: 0000-0002-1825-0097 (16 digits with hyphens, last char can be X)
    var isOrcidFormatValid: Bool {
        guard let orcid = orcid else { return true } // nil is valid (optional field)
        let orcidPattern = #"^\d{4}-\d{4}-\d{4}-\d{3}[0-9X]$"#
        return orcid.range(of: orcidPattern, options: .regularExpression) != nil
    }
    
    /// Formats ORCID for display (if present)
    var formattedOrcid: String? {
        guard let orcid = orcid else { return nil }
        return "ORCID: \(orcid)"
    }
    
    // MARK: - Display Helpers
    
    /// Primary display name for UI (left side of blue sphere)
    /// Returns displayName if set, otherwise falls back to name field
    var effectiveDisplayName: String {
        if let displayName = displayName, !displayName.isEmpty {
            return displayName
        }
        return name
    }
    
    /// Publisher name for UI (right side of blue sphere)
    /// Returns displayPublisher if set, otherwise nil
    var effectiveDisplayPublisher: String? {
        if let displayPublisher = displayPublisher, !displayPublisher.isEmpty {
            return displayPublisher
        }
        return nil
    }
    
    /// Display handle with better formatting
    var displayHandle: String {
        handle
    }
    
    /// Display DID (truncated for readability)
    var displayDID: String {
        // Show first 12 and last 8 characters of DID
        guard id.count > 20 else { return id }
        let start = id.prefix(12)
        let end = id.suffix(8)
        return "\(start)...\(end)"
    }
    
    /// Credential badges for display
    var credentialBadges: [String] {
        var badges: [String] = []
        if emailVerified { badges.append("📧 Verified Email") }
        if orcidVerified { badges.append("🎓 ORCID Verified") }
        return badges
    }
    
    /// Full credential display text
    var credentialDisplay: String {
        let badges = credentialBadges
        return badges.isEmpty ? "No verified credentials" : badges.joined(separator: " • ")
    }
}

// MARK: - ORCID Validation Helper
extension String {
    /// Validates and formats an ORCID string
    /// Returns formatted ORCID if valid, nil otherwise
    static func validateAndFormatOrcid(_ input: String) -> String? {
        // Remove whitespace and convert to uppercase for X
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Check format: XXXX-XXXX-XXXX-XXXZ where Z is digit or X
        let pattern = #"^\d{4}-\d{4}-\d{4}-\d{3}[0-9X]$"#
        guard cleaned.range(of: pattern, options: .regularExpression) != nil else {
            return nil
        }
        
        return cleaned
    }
    
    /// Formats partial ORCID input as user types
    /// Automatically adds hyphens at correct positions
    static func formatOrcidInput(_ input: String) -> String {
        // Remove all non-digit and non-X characters
        let cleaned = input.uppercased().filter { $0.isNumber || $0 == "X" }
        
        // Limit to 16 characters
        let limited = String(cleaned.prefix(16))
        
        // Add hyphens at positions 4, 8, 12
        var formatted = ""
        for (index, char) in limited.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += "-"
            }
            formatted.append(char)
        }
        
        return formatted
    }
}


