// PendingSignaturesService.swift
// Shared pending signatures API models and service.

import Foundation
import CryptoKit

// MARK: - Pending Signatures API Models

struct SignedSearchRequest: Codable {
    let personaDID: String
    let query: String
    let timestamp: String
    let signature: String
}

struct PendingSignaturesResponse: Codable {
    let personaDID: String
    let pendingCount: Int
    let documents: [PendingDocument]
}

struct PendingDocument: Codable, Identifiable {
    var id: String { documentDID }
    let documentDID: String
    let title: String?
    let type: String?
    let requiredSignatures: Int
    let currentSignatureCount: Int
    let createdAt: String?
    let authorizedSigners: [String]
    let documentHash: String?
}

// MARK: - Pending Signatures Service

enum PendingSignaturesService {
    static func makeTimestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    static func canonicalMessage(personaDID: String, query: String, timestamp: String) -> String {
        "\(personaDID)|\(query)|\(timestamp)"
    }

    static func signMessageBase64(_ message: String, privateKey: P256.Signing.PrivateKey) throws -> String {
        let data = Data(message.utf8)
        let signature = try privateKey.signature(for: data)
        return Data(signature.derRepresentation).base64EncodedString()
    }

    static func fetchPending(
        personaDID: String,
        query: String = "",
        privateKey: P256.Signing.PrivateKey,
        baseURLString: String
    ) async throws -> PendingSignaturesResponse {
        guard let baseURL = URL(string: baseURLString) else {
            throw URLError(.badURL)
        }
        let timestamp = makeTimestamp()
        let message = canonicalMessage(personaDID: personaDID, query: query, timestamp: timestamp)
        let signature = try signMessageBase64(message, privateKey: privateKey)
        let body = SignedSearchRequest(
            personaDID: personaDID,
            query: query,
            timestamp: timestamp,
            signature: signature
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("/search/pending-signatures"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            if statusCode == 404, bodyString.localizedCaseInsensitiveContains("not found") {
                return PendingSignaturesResponse(personaDID: personaDID, pendingCount: 0, documents: [])
            }
            throw NSError(domain: "PendingSignaturesService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(bodyString)"])
        }
        return try JSONDecoder().decode(PendingSignaturesResponse.self, from: data)
    }
}

// MARK: - Submit Signature Service

enum DocumentSignatureService {
    struct SubmitResponse: Codable { let status: String? }

    static func submitSignature(
        documentDID: String,
        signerPersonaDID: String,
        signatureBase64: String,
        signatureType: String = "P256-ES256",
        timestamp: String,
        documentHash: String?,
        baseURLString: String
    ) async throws -> SubmitResponse {
        guard let baseURL = URL(string: baseURLString) else { throw URLError(.badURL) }
        var request = URLRequest(url: baseURL.appendingPathComponent("/documents/\(documentDID)/sign"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: String] = [
            "signerPersonaDID": signerPersonaDID,
            "signature": signatureBase64,
            "signatureType": signatureType,
            "timestamp": timestamp
        ]
        if let documentHash = documentHash { body["documentHash"] = documentHash }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "DocumentSignatureService",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: "Server error: \(bodyString)"]
            )
        }
        return (try? JSONDecoder().decode(SubmitResponse.self, from: data)) ?? SubmitResponse(status: nil)
    }
}
