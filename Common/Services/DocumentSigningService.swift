import Foundation
import CryptoKit

// MARK: - APNs Token Registry (Client-side stub)
/// Simulates a tiny etcd-backed registry on the client for development/testing.
/// In production this is server-owned; the client only calls the register/unregister endpoints.
private enum APNSNotificationRegistry {
    /// In-memory map of persona DID -> APNs token string (dev-only stub)
    private static var tokens: [String: String] = [:]

    /// Register/update a token for a persona (used in previews/tests only)
    static func setToken(_ token: String, for personaDID: String) {
        tokens[personaDID] = token
    }

    /// Remove a token for a persona (used in previews/tests only)
    static func removeToken(for personaDID: String) {
        tokens.removeValue(forKey: personaDID)
    }

    /// Lookup a token for a single persona
    static func token(for personaDID: String) -> String? { tokens[personaDID] }

    /// Lookup tokens for a set of personas (deduped)
    static func tokens(for personaDIDs: [String]) -> [String] {
        Array(Set(personaDIDs.compactMap { tokens[$0] }))
    }
}

// MARK: - Document Signing Service
/// Implements the new multi-party document signing workflow with ledger entries (PROOF, SIGN, ATTEST)

public struct DocumentSigningService {
    
    // MARK: - Types
    
    public enum SignerRole: String, Codable {
        case author
        case contractParty
        case witness
        case notary
        case reviewer
    }
    
    public struct UploadResponse: Decodable {
        public let documentId: String
        public let folder: String?
        public let documentURL: String?
        public let didDocumentURL: String?
        public let metadataURL: String?
        public let documentHash: String?  // Optional - may not be returned by newer server versions
        public let ledgerProofEntryID: String?  // Optional - only present if ledger service is available
        public let ledgerProofIndex: String?  // Optional - only present if ledger is enabled
        public let accessCode: String?  // Human-readable access code for private documents
        public let taskId: String?  // SSE task ID for progress tracking

        // Server also returns these (not currently used by client)
        public let success: Bool?
        public let uploaded: Bool?
        public let draftId: String?
    }
    
    struct SignatureRequest: Encodable {
        let signerDID: String
        let signerPublicKey: String
        let signature: String
        let role: String
        let previousEntryID: String?
    }
    
    public struct SignatureResponse: Decodable {
        public let entryID: String  // Signature entry ID from signatures file
        public let signerDID: String
        public let role: String
        public let documentId: String
        public let success: Bool
        public let message: String
        public let timestamp: String?  // Optional - may not be returned by server

        // Legacy fields (no longer used by server, but kept for backward compatibility)
        public var ledgerIndex: Int? { nil }  // Always nil - ledger system deprecated

        // Legacy computed property for backward compatibility
        public var ledgerEntryID: String {
            return entryID
        }
    }
    
    /// Mirrors the server's `SignaturesDocument`, returned by
    /// `GET /api/documents/{documentId}/signatures`.
    struct SignatureStatus: Decodable {
        let documentId: String
        let documentHash: String
        let metadataHash: String
        let created: String
        let updated: String
        let requiredSignatures: Int
        let collectedSignatures: Int
        let status: String              // "pending", "signing", "complete"
        let completedAt: String?
        let signatures: [SignerInfo]

        /// One row per signer, written when the document is published and flipped to
        /// "verified" once that signer signs — so a row's presence is the roster,
        /// not evidence of a signature.
        struct SignerInfo: Decodable {
            let signer: String
            let role: String
            let signature: String?
            let documentHash: String?
            let metadataHash: String?
            let timestamp: String?
            let status: String          // "pending" or "verified"
            let blockchainBlockIndex: Int?
            let blockchainBlockHash: String?

            var hasSigned: Bool { status == "verified" }
        }

        /// Signatures actually collected, not the size of the roster.
        var totalSignatures: Int { collectedSignatures }

        /// Counts verified signatures only, so this sums to `collectedSignatures`.
        var signaturesByRole: [String: Int] {
            Dictionary(grouping: signatures.filter(\.hasSigned), by: \.role)
                .mapValues(\.count)
        }
    }
    
    struct AuditTrail: Decodable {
        let documentId: String
        let entries: [AuditEntry]
        
        struct AuditEntry: Decodable {
            let id: String
            let type: String // "PROOF", "SIGN", "ATTEST"
            let issuer: String
            let timestamp: String
            let previousEntryID: String?
            let documentHash: String?
            let signature: String?
            let role: String?
        }
    }
    
    // MARK: - Pending Documents
    
    /// Response wrapper for pending documents API endpoint
    private struct PendingDocumentsResponse: Codable {
        let documents: [PendingDocument]
        let personaDIDs: [String]
        let count: Int
    }
    
    /// Represents a document that requires signature from the current user
    public struct PendingDocument: Codable, Identifiable {
        public let id: String // documentId
        public let documentId: String
        public let title: String?
        public let originalFilename: String?
        public let documentHash: String
        public let documentURL: String?
        public let uploadedAt: String?
        public let uploadedBy: String // Author DID
        public let requiredRole: SignerRole
        public let status: String // "pending", "signed", "finalized"
        public let ledgerProofEntryID: String? // Optional - only present if ledger service is available
        public let existingSignatures: [SignerInfo]
        public let accessCode: String? // Human-readable access code (e.g., "451-7892")
        
        public struct SignerInfo: Codable {
            public let did: String
            public let role: String
            public let timestamp: String
            public let ledgerEntryID: String
        }
        
        // Helper computed properties
        public var hasSigned: Bool {
            status == "signed"
        }
        
        public var isFinalized: Bool {
            status == "finalized"
        }
        
        public var displayTitle: String {
            title ?? originalFilename ?? "Untitled Document"
        }
        
        public var displaySubtitle: String {
            let roleText = "Sign as \(requiredRole.rawValue.capitalized)"
            if let date = uploadedAt {
                return "\(roleText) • Uploaded \(date)"
            }
            return roleText
        }
        
        public var formattedAccessCode: String? {
            accessCode
        }
    }
    
    // MARK: - Notifications & Blockchain Hooks (client-visible shims)

    /// Returns any known APNs tokens for personas implicated in this operation.
    /// This is a client-side stub; the server should perform the authoritative lookup.
    private static func apnsTokensForPersonas(_ personaDIDs: [String]) -> [String] {
        APNSNotificationRegistry.tokens(for: personaDIDs)
    }

    /// Lightweight shim to log that a blockchain record should be written server-side.
    /// No-op on client other than debug logging.
    private static func noteBlockchainEvent(_ kind: String, documentId: String, extra: [String: String] = [:]) {
        let extras = extra.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        debugLog("⛓️  Blockchain event request -> kind=\(kind) doc=\(documentId) \(extras)")
    }
    
    // MARK: - Progress Reporting
    
    public enum SigningStep: String, Codable {
        case preparing = "Preparing document"
        case uploading = "Uploading to server"
        case creatingProof = "Creating PROOF ledger entry"
        case uploadingToS3 = "Uploading to secure storage"
        case creatingMetadata = "Creating metadata"
        case signingDocument = "Signing document"
        case creatingSignEntry = "Creating SIGN ledger entry"
        case complete = "Complete"
    }
    
    public struct ProgressUpdate {
        public let step: SigningStep
        public let message: String
        public let progress: Double // 0.0 to 1.0
        public let documentId: String?
        public let entryId: String?
        
        public init(step: SigningStep, message: String, progress: Double, documentId: String? = nil, entryId: String? = nil) {
            self.step = step
            self.message = message
            self.progress = progress
            self.documentId = documentId
            self.entryId = entryId
        }
    }
    
    // MARK: - Upload Document
    
    /// Step 1: Upload document to server and create PROOF ledger entry
    /// Returns the document ID and proof entry ID for use in subsequent signing
    ///
    /// **IMPORTANT**: Metadata should be embedded IN the document itself, not sent separately.
    /// Use `DocumentMetadataEmbedder.embed()` to embed metadata before calling this method.
    ///
    /// The `metadata` parameter is DEPRECATED and only kept for backward compatibility.
    /// Prefer embedding metadata in the document using one of these methods:
    /// - PDF: XMP metadata + PDF Info dictionary
    /// - JSON: Top-level @metadata field
    /// - Text/Markdown: Frontmatter block
    /// - Other formats: 451 wrapper format
    ///
    /// - Parameters:
    ///   - documentData: The document data WITH EMBEDDED METADATA (preferred)
    ///   - originalFilename: The filename (helps server detect format)
    ///   - metadata: DEPRECATED - Metadata to send separately (legacy mode)
    ///   - useEmbeddedMetadata: If true (default), assumes metadata is already in documentData
    ///   - onTransportProgress: Optional closure to report upload progress fraction (0..1)
    ///
    public static func uploadDocument(
        documentData: Data,
        originalFilename: String?,
        metadata: DocumentMetadata451? = nil,
        useEmbeddedMetadata: Bool = true,
        onTransportProgress: ((Double) -> Void)? = nil
    ) async throws -> UploadResponse {
        let baseURL = URL(string: ServerConfig.baseURL)!
        
        // Build upload URL - submit endpoint for finalized workflow
        let uploadURL = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("document")
            .appendingPathComponent("submit")
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        
        // Attach APNs recipient hints (client-provided; server may ignore)
        var hintedPersonas: [String] = []
        if let meta = metadata {
            // Best-effort extraction of persona DIDs from metadata without relying on specific type members.
            // Strategy: Encode to JSON, then look for common keys in a dictionary form.
            do {
                let data = try JSONEncoder().encode(meta)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Helper to collect DIDs from various value shapes
                    func collectDIDs(from value: Any) -> [String] {
                        var results: [String] = []
                        if let s = value as? String { results.append(s) }
                        else if let arr = value as? [Any] {
                            for item in arr {
                                results.append(contentsOf: collectDIDs(from: item))
                            }
                        } else if let dict = value as? [String: Any] {
                            // Common nested key name for DID
                            if let did = dict["did"] as? String { results.append(did) }
                            // Sometimes DIDs can be under keys like "id" with did: prefix
                            if let id = dict["id"] as? String, id.lowercased().hasPrefix("did:") { results.append(id) }
                        }
                        return results
                    }

                    // Candidate top-level keys that might contain author/participants/signers
                    let candidateKeys = [
                        // Author variations
                        "authorDID", "authorDid", "author",
                        // Participants variations
                        "participantDIDs", "participantDids", "participants",
                        // Signers variations
                        "signerDIDs", "signers"
                    ]

                    for key in candidateKeys {
                        if let value = json[key] {
                            hintedPersonas.append(contentsOf: collectDIDs(from: value))
                        }
                    }
                }
            } catch {
                debugLog("⚠️ Unable to extract persona hints from metadata: \(error)")
            }
        }
        let apnsIDs = apnsTokensForPersonas(hintedPersonas)
        if !apnsIDs.isEmpty {
            // Provide a compact, comma-separated hint header the server can read if desired
            request.setValue(apnsIDs.joined(separator: ","), forHTTPHeaderField: "X-APNS-Recipients")
        }
        
        if useEmbeddedMetadata {
            // ✅ PREFERRED: Metadata is embedded in the document
            // Send as simple binary upload
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            
            if let filename = originalFilename {
                request.setValue(filename, forHTTPHeaderField: "X-Original-Filename")
            }
            
            // Indicate that metadata is embedded
            request.setValue("embedded", forHTTPHeaderField: "X-Metadata-Location")
            
            request.httpBody = documentData
            
            debugLog("📤 Uploading document with EMBEDDED metadata (\(documentData.count) bytes)")
            
        } else if let metadata = metadata {
            // ⚠️ LEGACY: Send metadata separately (deprecated)
            debugLog("⚠️ Warning: Using deprecated separate metadata upload")
            debugLog("   Consider embedding metadata in document instead")
            
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            
            // Add document file
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"document\"; filename=\"\(originalFilename ?? "document.pdf")\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(documentData)
            body.append("\r\n".data(using: .utf8)!)
            
            // Add metadata as JSON
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"metadata\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
            if let metadataJSON = try? JSONEncoder().encode(metadata) {
                body.append(metadataJSON)
            }
            body.append("\r\n".data(using: .utf8)!)
            
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
            
            debugLog("📤 Uploading document with SEPARATE metadata (legacy mode)")
            
        } else {
            // Simple upload without any metadata
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            
            if let filename = originalFilename {
                request.setValue(filename, forHTTPHeaderField: "X-Original-Filename")
            }
            
            request.httpBody = documentData
            
            debugLog("📤 Uploading document with NO metadata (\(documentData.count) bytes)")
        }
        
        // Diagnostics: log request URL and key headers
        debugLog("🌐 Upload endpoint: \(uploadURL.absoluteString)")
        if let contentType = request.value(forHTTPHeaderField: "Content-Type") {
            debugLog("   ↪︎ Content-Type: \(contentType)")
        }
        if let originalName = request.value(forHTTPHeaderField: "X-Original-Filename") {
            debugLog("   ↪︎ X-Original-Filename: \(originalName)")
        }
        if let metadataLoc = request.value(forHTTPHeaderField: "X-Metadata-Location") {
            debugLog("   ↪︎ X-Metadata-Location: \(metadataLoc)")
        }
        if let apns = request.value(forHTTPHeaderField: "X-APNS-Recipients") {
            debugLog("   ↪︎ X-APNS-Recipients: \(apns)")
        }

        debugLog("📤 Uploading document (\(documentData.count) bytes)")
        
        // Use a custom URLSession with delegate to capture upload progress
        final class UploadDelegate: NSObject, URLSessionTaskDelegate {
            let progressHandler: ((Double) -> Void)?
            init(progressHandler: ((Double) -> Void)?) { self.progressHandler = progressHandler }
            func urlSession(_ session: URLSession, task: URLSessionTask,
                            didSendBodyData bytesSent: Int64,
                            totalBytesSent: Int64,
                            totalBytesExpectedToSend: Int64) {
                guard totalBytesExpectedToSend > 0 else { return }
                let fraction = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
                progressHandler?(fraction)
            }
        }

        let delegate = UploadDelegate(progressHandler: onTransportProgress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        // Create an upload task using the in-memory body
        var dataResult: Data?
        var urlResponse: URLResponse?
        var thrownError: Error?

        // Store body data before removing it from the request
        let bodyData = request.httpBody ?? Data()
        
        // Remove httpBody from request to avoid URLSession warning
        // When using uploadTask(with:from:), the body should be provided via the 'from' parameter
        request.httpBody = nil

        let semaphore = DispatchSemaphore(value: 0)
        let task = session.uploadTask(with: request, from: bodyData) { d, r, e in
            dataResult = d
            urlResponse = r
            thrownError = e
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        
        if let error = thrownError { throw error }
        guard let data = dataResult, let response = urlResponse else {
            throw DocumentSigningError.invalidResponse
        }
        
        debugLog("📥 Upload response status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        debugLog("   Response data size: \(data.count) bytes")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DocumentSigningError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            debugLog("❌ Upload failed: \(httpResponse.statusCode)")
            debugLog("   Error: \(errorBody)")
            throw DocumentSigningError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorBody
            )
        }
        
        // Check if we have data to decode
        if data.isEmpty {
            debugLog("⚠️ Warning: Upload response has empty body")
            throw DocumentSigningError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Server returned empty response body"
            )
        }
        
        // Log response body for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            debugLog("📄 Upload response body:")
            debugLog("   \(responseString)")
        }
        
        // Parse response to extract proof entry ID
        let uploadResponse: UploadResponse
        do {
            uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        } catch {
            debugLog("❌ Failed to decode upload response: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                debugLog("   Response was: \(responseString)")
            }
            throw DocumentSigningError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Failed to decode response: \(error.localizedDescription)"
            )
        }
        
        debugLog("✅ Document uploaded successfully")
        debugLog("   Document ID: \(uploadResponse.documentId)")
        if let documentHash = uploadResponse.documentHash {
            debugLog("   Document Hash: \(documentHash)")
        } else {
            debugLog("   ℹ️ Document hash not returned by server (will calculate locally)")
        }
        
        if let taskId = uploadResponse.taskId {
            debugLog("   Task ID: \(taskId) - SSE progress available at /api/progress/\(taskId)/stream")
        }
        
        // Informational: request server to write PROOF and dispatch notifications
        noteBlockchainEvent("PROOF", documentId: uploadResponse.documentId, extra: [
            "proofEntry": uploadResponse.ledgerProofEntryID ?? "",
            "taskId": uploadResponse.taskId ?? ""
        ])
        if let code = uploadResponse.accessCode { debugLog("🔔 APNs dispatch hint present (access code: \(code))") }
        
        return uploadResponse
    }

    // MARK: - Package Append

    /// Append a file to an existing document package.
    /// Endpoint: POST /api/document/{documentId}/package/append
    /// Headers: X-Uploader-DID, X-Asset-Path
    static func appendToDocumentPackage(
        documentId: String,
        uploaderDID: String,
        assetPath: String,
        assetData: Data,
        contentType: String = "application/octet-stream"
    ) async throws {
        let trimmedDID = uploaderDID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPath = assetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDID.isEmpty else { throw DocumentSigningError.missingRequiredHeader("X-Uploader-DID") }
        guard !trimmedPath.isEmpty else { throw DocumentSigningError.missingRequiredHeader("X-Asset-Path") }

        let baseURL = URL(string: ServerConfig.baseURL)!
        let appendURL = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("document")
            .appendingPathComponent(documentId)
            .appendingPathComponent("package")
            .appendingPathComponent("append")

        var request = URLRequest(url: appendURL)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(trimmedDID, forHTTPHeaderField: "X-Uploader-DID")
        request.setValue(trimmedPath, forHTTPHeaderField: "X-Asset-Path")

        debugLog("📤 Appending package asset:", trimmedPath, "bytes:", assetData.count)
        debugLog("   URL:", appendURL.absoluteString)

        let (_, response) = try await URLSession.shared.upload(for: request, from: assetData)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DocumentSigningError.invalidResponse
        }

        debugLog("📥 Append response status:", httpResponse.statusCode)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DocumentSigningError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Failed to append asset to document package"
            )
        }
    }
    
    // MARK: - Add Signature
    
    /// Step 2: Add a signature to the document (creates SIGN ledger entry)
    /// Can be called multiple times for different signers
    /// 🔐 SECURE ENCLAVE VERSION - Private key never leaves hardware
    static func addSignatureWithSecureEnclave(
        documentId: String,
        signerDID: String,
        signerPublicKey: String,
        documentHash: Data,
        role: SignerRole,
        previousEntryID: String?
    ) async throws -> SignatureResponse {
        let baseURL = URL(string: ServerConfig.baseURL)!
        
        // 🔐 Sign with Secure Enclave (private key never exposed)
        print("🔐 [DocumentSigning] Signing with Secure Enclave for: \(signerDID)")
        let signature = try SecureEnclaveKeyStore.sign(documentHash, for: signerDID)
        let signatureBase64 = signature.derRepresentation.base64EncodedString()
        print("✅ [DocumentSigning] Signature created in Secure Enclave")
        
        // Build signing request
        let signRequest = SignatureRequest(
            signerDID: signerDID,
            signerPublicKey: signerPublicKey,
            signature: signatureBase64,
            role: role.rawValue,
            previousEntryID: previousEntryID
        )
        
        let signURL = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("document")
            .appendingPathComponent(documentId)
            .appendingPathComponent("sign")
        
        var request = URLRequest(url: signURL)
        request.httpMethod = "POST"
        
        // Attach APNs recipient hints: include signer as a potential recipient
        let apnsHintRecipients = apnsTokensForPersonas([signerDID])
        if !apnsHintRecipients.isEmpty {
            request.setValue(apnsHintRecipients.joined(separator: ","), forHTTPHeaderField: "X-APNS-Recipients")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(signRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DocumentSigningError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            // Check if this is a LedgerService unavailable error
            if httpResponse.statusCode == 500 && errorMessage.contains("LedgerService not available") {
                print("⚠️ [DocumentSigning] LedgerService unavailable - document uploaded but signature failed")
                throw DocumentSigningError.ledgerServiceUnavailable(documentId: documentId)
            }
            
            throw DocumentSigningError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorMessage
            )
        }
        
        let signResponse = try JSONDecoder().decode(SignatureResponse.self, from: data)

        noteBlockchainEvent("SIGN", documentId: signResponse.documentId, extra: [
            "entryID": signResponse.entryID,
            "role": signResponse.role
        ])
        debugLog("🔔 Notification fanout requested for SIGN event (document: \(signResponse.documentId))")
        
        return signResponse
    }
    
    /// DEPRECATED: Use addSignatureWithSecureEnclave() instead
    /// Legacy method kept for backward compatibility
    @available(*, deprecated, message: "Use addSignatureWithSecureEnclave() for Secure Enclave protection")
    public static func addSignature(
        documentId: String,
        signerDID: String,
        signerPublicKey: String,
        documentHash: Data,
        privateKey: P256.Signing.PrivateKey,
        role: SignerRole,
        previousEntryID: String?
    ) async throws -> SignatureResponse {
        let baseURL = URL(string: ServerConfig.baseURL)!
        
        // Sign the document hash
        let signature = try privateKey.signature(for: documentHash)
        let signatureBase64 = signature.derRepresentation.base64EncodedString()
        
        // Build signing request
        let signRequest = SignatureRequest(
            signerDID: signerDID,
            signerPublicKey: signerPublicKey,
            signature: signatureBase64,
            role: role.rawValue,
            previousEntryID: previousEntryID
        )
        
        let signURL = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("document")
            .appendingPathComponent(documentId)
            .appendingPathComponent("sign")
        
        var request = URLRequest(url: signURL)
        request.httpMethod = "POST"
        
        // Attach APNs recipient hints: include signer as a potential recipient
        let apnsHintRecipients = apnsTokensForPersonas([signerDID])
        if !apnsHintRecipients.isEmpty {
            request.setValue(apnsHintRecipients.joined(separator: ","), forHTTPHeaderField: "X-APNS-Recipients")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(signRequest)
        
        debugLog("✍️ Adding signature for document: \(documentId)")
        debugLog("   Signer: \(signerDID)")
        debugLog("   Role: \(role.rawValue)")
        if let prevID = previousEntryID {
            debugLog("   Chaining to: \(prevID)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DocumentSigningError.invalidResponse
        }
        
        debugLog("📥 Signature response status: \(httpResponse.statusCode)")
        debugLog("   Response data size: \(data.count) bytes")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            debugLog("❌ Signature failed: \(httpResponse.statusCode)")
            debugLog("   Error: \(errorBody)")
            
            // Check if this is a LedgerService unavailable error
            if httpResponse.statusCode == 500 && errorBody.contains("LedgerService not available") {
                debugLog("⚠️ LedgerService unavailable - document uploaded but signature failed")
                throw DocumentSigningError.ledgerServiceUnavailable(documentId: documentId)
            }
            
            throw DocumentSigningError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorBody
            )
        }
        
        // Check if we have data to decode
        if data.isEmpty {
            debugLog("⚠️ Warning: Signature response has empty body")
            throw DocumentSigningError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Server returned empty response body"
            )
        }
        
        // Log response body for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            debugLog("📄 Signature response body:")
            debugLog("   \(responseString)")
        }
        
        let signResponse: SignatureResponse
        do {
            signResponse = try JSONDecoder().decode(SignatureResponse.self, from: data)
        } catch {
            debugLog("❌ Failed to decode signature response: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                debugLog("   Response was: \(responseString)")
            }
            throw DocumentSigningError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Failed to decode response: \(error.localizedDescription)"
            )
        }
        
        debugLog("✅ Signature added successfully")
        debugLog("   Entry ID: \(signResponse.ledgerEntryID)")
        debugLog("   Signer: \(signResponse.signerDID)")
        debugLog("   Role: \(signResponse.role)")
        if let timestamp = signResponse.timestamp {
            debugLog("   Timestamp: \(timestamp)")
        }
        if let ledgerIndex = signResponse.ledgerIndex {
            debugLog("   Ledger Index: \(ledgerIndex)")
        }
        debugLog("   Message: \(signResponse.message)")
        
        noteBlockchainEvent("SIGN", documentId: signResponse.documentId, extra: [
            "entryID": signResponse.entryID,
            "role": signResponse.role
        ])
        debugLog("🔔 Notification fanout requested for SIGN event (document: \(signResponse.documentId))")
        
        return signResponse
    }
    
    // MARK: - Query Status
    
    /// Get current signature status for a document
    static func getSignatureStatus(documentId: String) async throws -> SignatureStatus {
        let baseURL = URL(string: ServerConfig.baseURL)!
        
        let statusURL = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("documents")
            .appendingPathComponent(documentId)
            .appendingPathComponent("signatures")
        
        var request = URLRequest(url: statusURL)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DocumentSigningError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw DocumentSigningError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8) ?? ""
            )
        }
        
        return try JSONDecoder().decode(SignatureStatus.self, from: data)
    }
    
    /// Get complete audit trail for a document
    static func getAuditTrail(documentId: String) async throws -> AuditTrail {
        let baseURL = URL(string: ServerConfig.baseURL)!
        
        let auditURL = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("document")
            .appendingPathComponent(documentId)
            .appendingPathComponent("ledger")
        
        var request = URLRequest(url: auditURL)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DocumentSigningError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw DocumentSigningError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8) ?? ""
            )
        }
        
        return try JSONDecoder().decode(AuditTrail.self, from: data)
    }
    
    // MARK: - Finalize Document
    
    struct FinalizeResponse: Decodable {
        let status: String
        let ledgerAttestEntryID: String
        let finalizedAt: String?
    }

    /// Step 3: Finalize the document (creates ATTEST ledger entry)
    static func finalizeDocument(
        documentId: String,
        finalizedBy: String,
        signatureEntryIDs: [String]
    ) async throws -> FinalizeResponse {
        let baseURL = URL(string: ServerConfig.baseURL)!

        struct FinalizeRequest: Encodable {
            let finalizedBy: String
            let signatureEntryIDs: [String]
        }

        let finalizeURL = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("document")
            .appendingPathComponent(documentId)
            .appendingPathComponent("finalize")

        var request = URLRequest(url: finalizeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(FinalizeRequest(finalizedBy: finalizedBy, signatureEntryIDs: signatureEntryIDs))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DocumentSigningError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DocumentSigningError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8) ?? ""
            )
        }

        return try JSONDecoder().decode(FinalizeResponse.self, from: data)
    }
    
    // MARK: - Fetch Pending Documents
    
    /// Fetch documents that require signature from a specific DID
    /// This queries the search index for documents awaiting this signer's signature
    public static func fetchPendingDocuments(forSignerDID signerDID: String) async throws -> [PendingDocument] {
        let baseURL = URL(string: ServerConfig.baseURL)!
        
        // Endpoint: GET /api/documents/pending-signatures?signerDID=xxx
        // This endpoint will query the search index for documents requiring this DID's signature
        var components = URLComponents(url: baseURL.appendingPathComponent("api/documents/pending-signatures"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "signerDID", value: signerDID)
        ]
        
        guard let url = components.url else {
            throw DocumentSigningError.invalidDocumentId
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        debugLog("📥 Fetching pending documents for signer: \(signerDID)")
        debugLog("   URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DocumentSigningError.invalidResponse
        }
        
        debugLog("📥 Pending documents response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? ""
            debugLog("❌ Failed to fetch pending documents: \(errorMessage)")
            throw DocumentSigningError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorMessage
            )
        }
        
        // Log response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            debugLog("📄 Pending documents response: \(responseString)")
        }
        
        // Decode the wrapper response
        do {
            let response = try JSONDecoder().decode(PendingDocumentsResponse.self, from: data)
            debugLog("✅ Fetched \(response.documents.count) pending document(s) for \(signerDID)")
            return response.documents
        } catch {
            debugLog("❌ Failed to decode PendingDocumentsResponse for \(signerDID): \(error)")
            throw error
        }
    }
    
    /// Fetch documents that require signatures from multiple DIDs (useful for multi-persona users)
    /// Returns a dictionary mapping each DID to its pending documents
    public static func fetchPendingDocuments(forSignerDIDs signerDIDs: [String]) async throws -> [String: [PendingDocument]] {
        debugLog("📥 Fetching pending documents for \(signerDIDs.count) persona(s)")
        
        var results: [String: [PendingDocument]] = [:]
        
        // Fetch documents for each DID concurrently
        do {
            try await withThrowingTaskGroup(of: (String, [PendingDocument]).self) { group in
                for did in signerDIDs {
                    group.addTask {
                        debugLog("🔄 Task started for DID: \(did)")
                        let documents = try await fetchPendingDocuments(forSignerDID: did)
                        debugLog("✅ Task completed for DID: \(did) with \(documents.count) document(s)")
                        return (did, documents)
                    }
                }
                
                for try await (did, documents) in group {
                    debugLog("📦 Collecting results for DID: \(did)")
                    results[did] = documents
                }
            }
        } catch {
            debugLog("❌ Error in task group: \(error)")
            throw error
        }
        
        let totalDocuments = results.values.flatMap { $0 }.count
        debugLog("✅ Fetched total of \(totalDocuments) pending document(s) across all personas")
        
        return results
    }
    
    /// Fetch all pending documents across multiple personas and return as a flat list
    /// Each document will include which persona should sign it
    public static func fetchAllPendingDocuments(forSignerDIDs signerDIDs: [String]) async throws -> [PendingDocument] {
        let documentsDict = try await fetchPendingDocuments(forSignerDIDs: signerDIDs)
        
        // Flatten all documents into a single array
        let allDocuments = documentsDict.values.flatMap { $0 }
        
        debugLog("✅ Returning \(allDocuments.count) total pending document(s)")
        return Array(allDocuments)
    }
    
    /// Fetch a document by access code
    /// This allows users to access documents via human-readable codes like "451-7892"
    public static func fetchDocumentByAccessCode(_ accessCode: String, signerDID: String) async throws -> PendingDocument {
        let baseURL = URL(string: ServerConfig.baseURL)!
        
        // Endpoint: GET /api/documents/by-access-code/:code?signerDID=xxx
        var components = URLComponents(
            url: baseURL
                .appendingPathComponent("api")
                .appendingPathComponent("documents")
                .appendingPathComponent("by-access-code")
                .appendingPathComponent(accessCode),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "signerDID", value: signerDID)
        ]
        
        guard let url = components.url else {
            throw DocumentSigningError.invalidDocumentId
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        debugLog("🔐 Fetching document by access code: \(accessCode) for signer: \(signerDID)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DocumentSigningError.invalidResponse
        }
        
        debugLog("📥 Access code lookup response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? ""
            debugLog("❌ Failed to fetch document by access code: \(errorMessage)")
            
            // Provide user-friendly error messages
            if httpResponse.statusCode == 404 {
                throw DocumentSigningError.serverError(
                    statusCode: 404,
                    message: "Document not found with access code: \(accessCode)"
                )
            } else if httpResponse.statusCode == 403 {
                throw DocumentSigningError.serverError(
                    statusCode: 403,
                    message: "You are not authorized to access this document"
                )
            }
            
            throw DocumentSigningError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorMessage
            )
        }
        
        // Log response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            debugLog("📄 Document by access code response: \(responseString)")
        }
        
        let document = try JSONDecoder().decode(PendingDocument.self, from: data)
        debugLog("✅ Fetched document via access code: \(document.displayTitle)")
        return document
    }
    
    // MARK: - Complete Workflow Helper
    
    /// Complete workflow: Upload only (signing removed from client)
    /// This is a convenience method for the new simplified case
    public static func completeSigningWorkflow(
        documentData: Data,
        originalFilename: String?,
        metadata: DocumentMetadata451? = nil
    ) async throws -> (documentId: String, attestEntryID: String) {
        
        debugLog("🚀 Starting simplified complete signing workflow")
        
        // Step 1: Upload document only
        let uploadResponse = try await uploadDocument(
            documentData: documentData,
            originalFilename: originalFilename,
            metadata: metadata
        )
        
        debugLog("✅ Upload complete (signing removed from client workflow)")
        debugLog("   Document ID: \(uploadResponse.documentId)")
        
        // Return documentId and ledgerProofEntryID as attestEntryID for compatibility
        return (uploadResponse.documentId, uploadResponse.ledgerProofEntryID ?? "")
    }
    
    /// Complete workflow with progress reporting (signing removed)
    /// Use this version to get real-time updates on the upload process only
    public static func completeSigningWorkflowWithProgress(
        documentData: Data,
        originalFilename: String?,
        metadata: DocumentMetadata451? = nil,
        onProgress: @escaping @Sendable (ProgressUpdate) -> Void
    ) async throws -> (documentId: String, attestEntryID: String, accessCode: String?) {
        
        debugLog("🚀 Starting simplified complete signing workflow with progress reporting")
        
        // Step 1: Report preparing
        onProgress(ProgressUpdate(step: .preparing, message: "Preparing document for upload...", progress: 0))
        
        // Step 2: Upload document
        onProgress(ProgressUpdate(step: .uploading, message: "Uploading document to server (\(documentData.count) bytes)...", progress: 0.3))
        
        let uploadResponse = try await uploadDocument(
            documentData: documentData,
            originalFilename: originalFilename,
            metadata: metadata,
            onTransportProgress: { fraction in
                // Map raw transport fraction (0..1) into the existing uploading step range (0.1..0.55 approx)
                let clamped = max(0.0, min(1.0, fraction))
                let interpolated = 0.10 + (0.45 * clamped)
                onProgress(ProgressUpdate(step: .uploading, message: "Uploading document to server...", progress: interpolated))
            }
        )
        
        // Step 3: PROOF entry created
        onProgress(ProgressUpdate(step: .creatingProof, message: "✅ PROOF ledger entry created", progress: 0.6, documentId: uploadResponse.documentId, entryId: uploadResponse.ledgerProofEntryID))
        
        // Step 4: Complete step
        onProgress(ProgressUpdate(step: .complete, message: "🎉 Document upload complete (signing removed from client)", progress: 1.0, documentId: uploadResponse.documentId, entryId: uploadResponse.ledgerProofEntryID))
        
        debugLog("✅ Upload phase complete")
        debugLog("   Document ID: \(uploadResponse.documentId)")
        if let code = uploadResponse.accessCode {
            debugLog("   Access Code: \(code)")
        }
        
        return (uploadResponse.documentId, uploadResponse.ledgerProofEntryID ?? "", uploadResponse.accessCode)
    }
    
    /// Complete workflow with REAL server-side SSE progress tracking (signing removed)
    /// This version subscribes to the server's SSE stream for detailed upload progress only
    public static func completeSigningWorkflowWithSSEProgress(
        documentData: Data,
        originalFilename: String?,
        metadata: DocumentMetadata451? = nil,
        onProgress: @escaping @Sendable (ProgressUpdate) -> Void,
        onServerProgress: @escaping @Sendable (ProgressStep) -> Void
    ) async throws -> (documentId: String, attestEntryID: String, accessCode: String?) {
        
        debugLog("🚀 Starting simplified workflow with SSE progress tracking")
        
        // Step 1: Upload document
        onProgress(ProgressUpdate(step: .uploading, message: "Uploading document...", progress: 0.1))
        
        let uploadResponse = try await uploadDocument(
            documentData: documentData,
            originalFilename: originalFilename,
            metadata: metadata,
            onTransportProgress: { fraction in
                let clamped = max(0.0, min(1.0, fraction))
                let interpolated = 0.10 + (0.45 * clamped)
                onProgress(ProgressUpdate(step: .uploading, message: "Uploading document...", progress: interpolated))
            }
        )
        
        // Step 2: Connect to SSE stream if taskId is available
        var sseClient: ProductionSSEClient? = nil
        if let taskId = uploadResponse.taskId {
            debugLog("🔌 Task ID received: \(taskId)")
            debugLog("   Subscribing to SSE at: \(ServerConfig.baseURL)/api/progress/\(taskId)/stream")
            
            sseClient = ProductionSSEClient()
            
            Task.detached(priority: .userInitiated) {
                await sseClient?.connectToProgressStream(
                    baseURL: ServerConfig.baseURL,
                    taskId: taskId,
                    onProgress: { progressStep in
                        onServerProgress(progressStep)
                        let update = ProgressUpdate(
                            step: .uploadingToS3,
                            message: progressStep.message,
                            progress: progressStep.progress,
                            documentId: uploadResponse.documentId,
                            entryId: nil
                        )
                        onProgress(update)
                    },
                    onComplete: { completion in
                        debugLog("✅ SSE reported completion: \(completion.message)")
                    },
                    onError: { error in
                        debugLog("⚠️ SSE error: \(error.message)")
                    },
                    onStreamClosed: {
                        debugLog("⚠️ SSE stream closed without completion event")
                    }
                )
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        } else {
            debugLog("⚠️ No taskId in upload response - SSE progress not available")
        }
        
        onProgress(ProgressUpdate(step: .creatingProof, message: "PROOF entry created", progress: 0.3, documentId: uploadResponse.documentId))
        
        // Step 3: Complete step
        onProgress(ProgressUpdate(step: .complete, message: "🎉 Document upload complete (signing removed from client)", progress: 1.0, documentId: uploadResponse.documentId, entryId: uploadResponse.ledgerProofEntryID))
        
        debugLog("✅ Upload phase complete")
        debugLog("   Document ID: \(uploadResponse.documentId)")
        if let code = uploadResponse.accessCode {
            debugLog("   Access Code: \(code)")
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        sseClient?.disconnect()
        
        return (uploadResponse.documentId, uploadResponse.ledgerProofEntryID ?? "", uploadResponse.accessCode)
    }

    
    // MARK: - Helpers
    
    /// Enhanced logging that works in both DEBUG and RELEASE builds
    /// Set ClientLogger.isEnabled = false to disable all logging
    private static func debugLog(_ items: Any...) {
        let message = items.map { "\($0)" }.joined(separator: " ")
        ClientLogger.debug(component: LogComponent.documentService, message)
    }
    
    // MARK: - Build helpers (stubs)
    /// Best-effort verify that a document has been indexed. Client cannot verify server index; this is a no-op with debug log.
    @discardableResult
    static func verifyIndexing(documentId: String, timeout: TimeInterval = 2.0) async -> Bool {
        debugLog("🧪 verifyIndexing(doc: \(documentId)) - client stub waiting \(timeout)s")
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        return true
    }

    /// Attempt to rollback a publication on error. Client cannot rollback server state; this is a no-op with debug log.
    static func rollbackPublication(documentId: String, reason: String) async {
        debugLog("↩️ rollbackPublication(doc: \(documentId)) - reason: \(reason) [client stub]")
    }
}

// MARK: - Errors

enum DocumentSigningError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case missingRequiredHeader(String)
    case invalidDocumentId
    case ledgerServiceUnavailable(documentId: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .missingRequiredHeader(let header):
            return "Missing required header: \(header)"
        case .invalidDocumentId:
            return "Invalid document ID format"
        case .ledgerServiceUnavailable(let documentId):
            return "Document uploaded successfully, but automatic signing is unavailable. You can sign the document manually from the Sign tab. (Document ID: \(documentId))"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .ledgerServiceUnavailable:
            return "The server's ledger service is not currently available for automatic signing."
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .ledgerServiceUnavailable:
            return "The document has been uploaded successfully. You can manually sign it later from the 'Sign' tab, or wait for the server configuration to be updated."
        default:
            return nil
        }
    }
}

// MARK: - Migration Guide
/*
 
 MIGRATION FROM OLD WORKFLOW TO NEW:
 
 OLD WAY (DocumentSubmissionService.swift):
 ```swift
 try await submitSignedDocumentFlow(
     documentData: data,
     privateKey: key,
     personaDid: did,
     personaPublicKey: publicKey,
     isPublic: false,
     documentId: docId,
     originalFilename: filename
 )
*/
