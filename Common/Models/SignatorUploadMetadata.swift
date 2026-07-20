//
//  SignatorUploadMetadata.swift
//  451Wallet
//
//  Created by User451 on 1/23/26.
//
//  Signator-specific metadata handling for external document uploads
//  Handles the reality that most binary documents won't have full metadata
//

import Foundation
import CryptoKit

// Optional shim to decouple this file from concrete embedder signatures.
// If your project wants to provide a custom adapter (e.g., to build DocumentMetadata451),
// define a type conforming to this protocol elsewhere and assign it to `DocumentMetadataEmbedderEmbedShim`.
protocol DocumentMetadataEmbedderEmbedShimProtocol {
    func embed(metadata: DocumentMetadata451, into data: Data, filename: String) throws -> Data
}

// Optional converter to build a typed metadata object without importing its type here.
public typealias DocumentMetadataBuilder = (_ fields: [String: Any]) -> DocumentMetadata451
var DocumentMetadata451Builder: DocumentMetadataBuilder? = nil

// Set this from elsewhere if you need a custom bridge; otherwise the default path will call DocumentMetadataEmbedder.embed(fields:...)
var DocumentMetadataEmbedderEmbedShim: (any DocumentMetadataEmbedderEmbedShimProtocol)? = nil

/// Signator-specific upload metadata builder
/// Handles external documents with minimal metadata
struct SignatorUploadMetadata {
    
    // MARK: - Tier 1: Automatic (Always Present)
    // These are extracted from the file itself
    
    var filename: String
    var mimeType: String
    var fileSize: Int
    var documentHash: String?  // Optional until we compute it
    
    // MARK: - Tier 2: Basic User-Provided (Optional but Encouraged)
    // Quick 3-field dialog before upload
    
    var title: String?
    var documentType: String?
    var accessLevel: String?
    
    // MARK: - Tier 3: Full Metadata (Advanced, Optional)
    // Only filled if user taps "More Details"
    
  
    
    // MARK: - Convenience Initializer
    
    init(
        filename: String,
        mimeType: String,
        fileSize: Int,
        documentHash: String? = nil,
        title: String? = nil,
        documentType: String? = nil,
        accessLevel: String? = nil
    ) {
        self.filename = filename
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.documentHash = documentHash
        self.title = title
        self.documentType = documentType
        self.accessLevel = accessLevel
    }
    
    /// Create from picked file URL and data
    static func from(fileURL: URL, data: Data) -> SignatorUploadMetadata {
        let filename = fileURL.lastPathComponent
        let mimeType = Self.mimeType(for: fileURL)
        let fileSize = data.count
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // Suggest title from filename (without extension)
        let suggestedTitle = (filename as NSString).deletingPathExtension
        
        return SignatorUploadMetadata(
            filename: filename,
            mimeType: mimeType,
            fileSize: fileSize,
            documentHash: hashString,
            title: suggestedTitle,
            documentType: Self.suggestType(from: filename),
            accessLevel: "private"  // Default to private
        )
    }
    
    
    /// Compute SHA-256 hex string for given data
    private static func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // Local adapter to call the project embedder without leaking TransferMetadata/DocumentMetadata451 here.
    // Update this to match your actual embedder API (e.g., if it expects a typed metadata object).
    private static func embedFields(_ fields: [String: Any], into data: Data, filename: String) throws -> Data {
        // If a shim is provided and we can build typed metadata, use it.
        if let builder = DocumentMetadata451Builder, let embedShim = DocumentMetadataEmbedderEmbedShim {
            let typed = builder(fields)
            return try embedShim.embed(metadata: typed, into: data, filename: filename)
        }
        
        // If the project exposes a typed embedder directly, try to build and call it.
        if let builder = DocumentMetadata451Builder {
            let typed = builder(fields)
            return try DocumentMetadataEmbedder.embed(metadata: typed, into: data, filename: filename)
        }
        
        // No typed builder available; we cannot call a metadata-based embedder with a dictionary.
        // As a safe fallback, return the original data unchanged.
        // Consider logging or asserting here if desired.
        return data
    }
    
    // MARK: - Upload with Embedded Metadata (RECOMMENDED)
    
    /// Embed metadata into document and upload
    /// This is the CORRECT way to handle document metadata
    func uploadWithEmbeddedMetadata(documentData: Data) async throws -> String {
    
        
        // Prepare metadata fields for embedding directly (no TransferMetadata)
        let computedHash = documentHash ?? Self.sha256Hex(of: documentData)
        var fields: [String: Any] = [
            "filename": filename,
            "mimeType": mimeType,
            "fileSize": fileSize,
            "documentHash": computedHash,
            "format": "451"
        ]
        
        // Prefer values provided by the user/input screen when available
        if let title = title, !title.isEmpty { fields["title"] = title }
        else { fields["title"] = (filename as NSString).deletingPathExtension }
        
        if let docType = documentType, !docType.isEmpty { fields["documentType"] = docType }
        if let access = accessLevel, !access.isEmpty { fields["accessRights"] = access } else { fields["accessRights"] = "private" }
        
        // Add publication/upload date in ISO8601
        let formatter = ISO8601DateFormatter()
        fields["publicationDate"] = formatter.string(from: Date())
        
        // Embed metadata directly into the document using a local adapter wrapper
        let documentWithMetadata = try Self.embedFields(
            fields,
            into: documentData,
            filename: filename
        )
        
        // Upload the self-contained document
        let response = try await DocumentSigningService.uploadDocument(
            documentData: documentWithMetadata,
            originalFilename: filename,
            metadata: nil,  // No separate metadata!
            useEmbeddedMetadata: true
        )
        
        return response.documentId
    }
    
    // MARK: - Utility Methods
    
    /// Guess MIME type from file extension
    static func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "txt": return "text/plain"
        case "rtf": return "application/rtf"
        case "csv": return "text/csv"
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "html", "htm": return "text/html"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "zip": return "application/zip"
        default: return "application/octet-stream"
        }
    }
    
    /// Suggest document type from filename patterns
    static func suggestType(from filename: String) -> String? {
        let lower = filename.lowercased()
        
        if lower.contains("contract") { return "contract" }
        if lower.contains("agreement") { return "agreement" }
        if lower.contains("invoice") { return "invoice" }
        if lower.contains("receipt") { return "receipt" }
        if lower.contains("report") { return "report" }
        if lower.contains("proposal") { return "proposal" }
        if lower.contains("letter") { return "letter" }
        if lower.contains("memo") { return "memo" }
        
        return nil
    }
}

// MARK: - Usage Examples

/*
 
 // ✅ RECOMMENDED: Upload with Embedded Metadata
 
 // Example 1: User picks a file and uploads with embedded metadata (BEST PRACTICE)
 func handlePickedDocument(url: URL) async throws {
     guard url.startAccessingSecurityScopedResource() else { return }
     defer { url.stopAccessingSecurityScopedResource() }
     
     let data = try Data(contentsOf: url)
     let uploadMetadata = SignatorUploadMetadata.from(fileURL: url, data: data)
     
     // Upload with embedded metadata (RECOMMENDED)
     let documentId = try await uploadMetadata.uploadWithEmbeddedMetadata(documentData: data)
     print("✅ Uploaded with embedded metadata: \(documentId)")
 }
 
 // Example 2: Quick upload with embedded metadata
 func uploadImmediately(url: URL, data: Data) async throws {
     let uploadMetadata = SignatorUploadMetadata.from(fileURL: url, data: data)
     
     // Embed metadata in document before upload
     let documentId = try await uploadMetadata.uploadWithEmbeddedMetadata(documentData: data)
     print("✅ Document uploaded: \(documentId)")
 }
 
 // Example 3: User provides basic info, then embeds and uploads
 func uploadWithBasicInfo(url: URL, data: Data, title: String, type: String, access: String) async throws {
     var uploadMetadata = SignatorUploadMetadata.from(fileURL: url, data: data)
     
     // Override with user input
     uploadMetadata.title = title
     uploadMetadata.documentType = type
     uploadMetadata.accessLevel = access
     
     // Upload with embedded metadata
     let documentId = try await uploadMetadata.uploadWithEmbeddedMetadata(documentData: data)
     print("✅ Document with custom metadata: \(documentId)")
 }
 
 */

