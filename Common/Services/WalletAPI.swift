//
//  WalletAPI.swift
//  451Wallet
//
//  Created by User451 on 4/25/25.
//
//  ✅ CANONICAL VERSION - This is the only WalletAPI file you should keep
//  🗑️ DELETE: WalletAPI 2.swift, WalletAPI 3.swift, WalletAPI 4.swift
//
//  NOTE: This file contains legacy/deprecated API methods.
//  For current document workflow, use DocumentSigningService.uploadDocument()
//  which posts to /api/document/publish and lets the server handle all signing logic.
//
import Foundation
import CryptoKit

// MARK: - WalletAPI Main Struct

struct WalletAPI {
    static var serverBaseURL: URL { 
        URL(string: ServerConfig.baseURL)!
    }
    
    enum WalletAPIError: Error {
        case invalidResponse
        case serverError(statusCode: Int)
        case deprecated(message: String)
    }
}

// MARK: - Utility Functions

/// Best-effort MIME type resolver used by callers to pick a sane Content-Type
func mimeType(forFileExtension ext: String) -> String {
    switch ext.lowercased() {
    case "pdf": return "application/pdf"
    case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    case "doc": return "application/msword"
    case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    case "xls": return "application/vnd.ms-excel"
    case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    case "ppt": return "application/vnd.ms-powerpoint"
    case "txt": return "text/plain"
    case "rtf": return "application/rtf"
    case "csv": return "text/csv"
    case "json": return "application/json"
    default: return "application/octet-stream"
    }
}

// MARK: - DEPRECATED METHODS
// These methods are kept for reference but should not be used in new code.
// Use DocumentSigningService.uploadDocument() instead.

extension WalletAPI {
    
    /// DEPRECATED: Use DocumentSigningService.uploadDocument() instead.
    /// This method used a 2-step draft flow that is no longer needed.
    @available(*, deprecated, message: "Use DocumentSigningService.uploadDocument() which posts to /api/document/publish")
    static func submitSignedDocument(
        documentData: Data,
        metadataJSON: Data
    ) async throws {
        throw WalletAPIError.deprecated(message: "Use DocumentSigningService.uploadDocument() instead")
    }
    
    /// DEPRECATED: Use DocumentSigningService.uploadDocument() instead.
    /// This method used client-side signing which has been moved to the server.
    @available(*, deprecated, message: "Use DocumentSigningService.uploadDocument() - server now handles all signing")
    static func submitSignedDocument(payload: SignedDocumentPayload) async throws {
        throw WalletAPIError.deprecated(message: "Use DocumentSigningService.uploadDocument() instead")
    }
    
    /// DEPRECATED: Use DocumentSigningService.uploadDocument() instead.
    /// This method used a different metadata structure that is no longer needed.
    @available(*, deprecated, message: "Use DocumentSigningService.uploadDocument() which posts to /api/document/publish")
    static func submitDocument(document: Data, metadata: LegacyDocumentMetadata) async throws {
        throw WalletAPIError.deprecated(message: "Use DocumentSigningService.uploadDocument() instead")
    }
}

// MARK: - Legacy Free Functions (Deprecated)

/// DEPRECATED: Use DocumentSigningService.completeSigningWorkflow() instead.
/// Server now handles all signing logic.
@available(*, deprecated, message: "Use DocumentSigningService.completeSigningWorkflow() - server handles signing")
func submitSignedDocumentFlowLegacy(
    documentData: Data,
    privateKey: P256.Signing.PrivateKey,
    personaDid: String,
    personaPublicKey: String
) async throws {
    throw WalletAPI.WalletAPIError.deprecated(message: "Use DocumentSigningService.completeSigningWorkflow() instead")
}

// MARK: - Legacy Type Definitions (kept for compilation compatibility)

/// Legacy document metadata - DO NOT USE in new code
/// Use DocumentMetadata451 from DocumentMetadata451.swift instead
struct LegacyDocumentMetadata: Codable {
    let documentId: String?
    let title: String?
    let authors: [String]
    let participants: [String]?
    let witnesses: [String]?
    let fileType: String?
    let documentHash: String?
}

/// Legacy document submission request - DO NOT USE
struct DocumentSubmissionRequest: Codable {
    let document: Data
    let metadata: LegacyDocumentMetadata
    
    enum CodingKeys: String, CodingKey {
        case document
        case metadata
    }
    
    init(document: Data, metadata: LegacyDocumentMetadata) {
        self.document = document
        self.metadata = metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let documentString = try container.decode(String.self, forKey: .document)
        guard let documentData = Data(base64Encoded: documentString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .document,
                in: container,
                debugDescription: "Invalid base64 string"
            )
        }
        self.document = documentData
        self.metadata = try container.decode(LegacyDocumentMetadata.self, forKey: .metadata)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(document.base64EncodedString(), forKey: .document)
        try container.encode(metadata, forKey: .metadata)
    }
}

