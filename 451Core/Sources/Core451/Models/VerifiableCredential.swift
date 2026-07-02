// VerifiableCredential.swift
// W3C Verifiable Credential data model for institution-issued role credentials.
// https://www.w3.org/TR/vc-data-model/

import Foundation
import CryptoKit

// MARK: - Verifiable Credential

struct VerifiableCredential: Codable, Identifiable, Equatable {

    // W3C standard fields
    var context: [String]       // "@context" in JSON
    var id: String              // "id" in JSON — unique URI for this credential (satisfies Identifiable)
    var type: [String]          // e.g. ["VerifiableCredential", "InstitutionRoleCredential"]
    var issuer: String          // issuer DID (e.g. "did:web:hillsborohospital.org")
    var issuanceDate: String    // ISO 8601
    var expirationDate: String? // ISO 8601, optional
    var credentialSubject: CredentialSubject
    var proof: CredentialProof? // nil until signed

    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case id
        case type
        case issuer
        case issuanceDate
        case expirationDate
        case credentialSubject
        case proof
    }

    init(
        context: [String] = [
            "https://www.w3.org/2018/credentials/v1",
            "https://451.info/credentials/v1"
        ],
        id: String,
        type: [String] = ["VerifiableCredential", "InstitutionRoleCredential"],
        issuer: String,
        issuanceDate: String,
        expirationDate: String? = nil,
        credentialSubject: CredentialSubject,
        proof: CredentialProof? = nil
    ) {
        self.context = context
        self.id = id
        self.type = type
        self.issuer = issuer
        self.issuanceDate = issuanceDate
        self.expirationDate = expirationDate
        self.credentialSubject = credentialSubject
        self.proof = proof
    }

    // MARK: - Subject

    struct CredentialSubject: Codable, Equatable {
        var id: String              // subject DID
        var role: String            // e.g. "Physician", "Nurse", "Admin"
        var department: String?     // e.g. "Internal Medicine"
        var accessLevel: String     // e.g. "provider", "admin", "viewer"
        var institution: String     // e.g. "Hillsboro Hospital"
        var institutionDomain: String // e.g. "hillsborohospital.org"
        var npi: String?            // National Provider Identifier (optional)
        var handle: String?         // e.g. "dr.john.smith.hillsborohospital.org"
    }

    // MARK: - Proof

    struct CredentialProof: Codable, Equatable {
        var type: String                // "JsonWebSignature2020"
        var created: String             // ISO 8601
        var verificationMethod: String  // e.g. "did:web:hillsborohospital.org#key-1"
        var proofPurpose: String        // "assertionMethod"
        var jws: String                 // raw ES256 sig over unsigned credential JSON, base64url
    }
}

// MARK: - Helpers

extension VerifiableCredential {

    /// "did:web:hillsborohospital.org" → "hillsborohospital.org"
    var issuerDomain: String? {
        guard issuer.hasPrefix("did:web:") else { return nil }
        return String(issuer.dropFirst("did:web:".count))
    }

    var isExpired: Bool {
        guard let expStr = expirationDate,
              let expDate = ISO8601DateFormatter().date(from: expStr) else { return false }
        return expDate < Date()
    }

    var isSigned: Bool { proof != nil }

    /// Returns the canonical JSON bytes to sign (credential without the proof field).
    func unsignedJSON() throws -> Data {
        var copy = self
        copy.proof = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(copy)
    }
}

// MARK: - VC Factory

extension VerifiableCredential {

    /// Builds an unsigned InstitutionRoleCredential.
    static func make(
        issuerDID: String,
        subjectDID: String,
        subjectHandle: String?,
        role: String,
        department: String?,
        accessLevel: String,
        institution: String,
        institutionDomain: String,
        npi: String?,
        validForYears: Int = 1
    ) -> VerifiableCredential {
        let now = ISO8601DateFormatter().string(from: Date())
        let expiry = ISO8601DateFormatter().string(
            from: Calendar.current.date(byAdding: .year, value: validForYears, to: Date()) ?? Date()
        )
        let uid = UUID().uuidString.lowercased()
        let credID = "https://\(institutionDomain)/credentials/\(uid)"

        return VerifiableCredential(
            id: credID,
            issuer: issuerDID,
            issuanceDate: now,
            expirationDate: expiry,
            credentialSubject: CredentialSubject(
                id: subjectDID,
                role: role,
                department: department,
                accessLevel: accessLevel,
                institution: institution,
                institutionDomain: institutionDomain,
                npi: npi,
                handle: subjectHandle
            )
        )
    }

    /// Signs the credential using the issuer's P256 Secure Enclave key.
    /// Proof jws is a raw (r‖s) 64-byte ES256 signature, base64url-encoded.
    func signed(
        using privateKey: P256.Signing.PrivateKey,
        verificationMethod: String
    ) throws -> VerifiableCredential {
        let payload = try unsignedJSON()
        let sig = try privateKey.signature(for: SHA256.hash(data: payload))
        let jwsB64 = Data(sig.rawRepresentation).base64URLEncoded

        var result = self
        result.proof = CredentialProof(
            type: "JsonWebSignature2020",
            created: ISO8601DateFormatter().string(from: Date()),
            verificationMethod: verificationMethod,
            proofPurpose: "assertionMethod",
            jws: jwsB64
        )
        return result
    }

    /// Verifies the proof signature against the issuer's P256 public key.
    func verifySignature(using publicKey: P256.Signing.PublicKey) -> Bool {
        guard let proof = proof,
              let jwsData = Data(base64URLEncoded: proof.jws),
              let payload = try? unsignedJSON() else { return false }
        do {
            let sig = try P256.Signing.ECDSASignature(rawRepresentation: jwsData)
            return publicKey.isValidSignature(sig, for: SHA256.hash(data: payload))
        } catch {
            return false
        }
    }
}

// MARK: - Base64URL (private)

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var b64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = b64.count % 4
        if rem > 0 { b64 += String(repeating: "=", count: 4 - rem) }
        self.init(base64Encoded: b64)
    }
}

// MARK: - Institution Access Request

/// A request from a staff member's Signator for institutional role access.
/// Sent to S451; polled by the institution admin in InstitutionAdminView.
struct InstitutionAccessRequest: Codable, Identifiable, Equatable {
    let id: String              // server-assigned UUID
    let subjectDID: String
    let subjectName: String
    let subjectHandle: String
    let subjectPublicKeyBase64: String
    let npi: String?
    let requestedRole: String
    let institutionDomain: String
    let message: String?        // optional personal note
    let createdAt: String
    var status: String          // "pending" | "approved" | "rejected"
}
