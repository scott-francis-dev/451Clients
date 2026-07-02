# API Comparison: Old vs New

## Old Deprecated APIs (Don't use these!)

### From WalletAPI.swift - All marked @deprecated

```swift
// ❌ DEPRECATED - Throws error immediately
static func submitSignedDocument(
    documentData: Data,
    metadataJSON: Data
) async throws {
    throw WalletAPIError.deprecated(
        message: "Use DocumentSigningService.uploadDocument() instead"
    )
}

// ❌ DEPRECATED - Throws error immediately  
static func submitSignedDocument(
    payload: SignedDocumentPayload
) async throws {
    throw WalletAPIError.deprecated(
        message: "Use DocumentSigningService.uploadDocument() instead"
    )
}

// ❌ DEPRECATED - Throws error immediately
static func submitDocument(
    document: Data, 
    metadata: DocumentMetadata
) async throws {
    throw WalletAPIError.deprecated(
        message: "Use DocumentSigningService.uploadDocument() instead"
    )
}

// ❌ DEPRECATED - Throws error immediately
func submitSignedDocumentFlowLegacy(
    documentData: Data,
    privateKey: P256.Signing.PrivateKey,
    personaDid: String,
    personaPublicKey: String
) async throws {
    throw WalletAPI.WalletAPIError.deprecated(
        message: "Use DocumentSigningService.completeSigningWorkflow() instead"
    )
}
```

## New Modern APIs (Use these!)

### From DocumentSigningService.swift

```swift
// ✅ MODERN - Upload document, server handles signing
static func uploadDocument(
    documentData: Data,
    originalFilename: String?
) async throws -> UploadResponse

// ✅ MODERN - Upload with convenience wrapper
public static func completeSigningWorkflow(
    documentData: Data,
    originalFilename: String?
) async throws -> (documentId: String, attestEntryID: String)

// ✅ MODERN - Upload with progress callbacks
public static func completeSigningWorkflowWithSSEProgress(
    documentData: Data,
    originalFilename: String?,
    onProgress: @escaping @Sendable (ProgressUpdate) -> Void,
    onServerProgress: @escaping @Sendable (ProgressStep) -> Void
) async throws -> (documentId: String, attestEntryID: String, accessCode: String?)
```

## Response Structures

### Old Deprecated Structure
```swift
// ❌ Don't use - only for backward compatibility
struct DocumentMetadata: Codable {
    let documentId: String?
    let title: String?
    let authors: [String]
    let participants: [String]?
    let witnesses: [String]?
    let fileType: String?
    let documentHash: String?
}
```

### New Modern Structure
```swift
// ✅ Use this - returned from uploadDocument()
struct UploadResponse: Decodable {
    let documentId: String                  // Always present
    let folder: String?                     // S3 folder path
    let documentURL: String?                // Public URL to document
    let didDocumentURL: String?             // DID document URL
    let metadataURL: String?                // Metadata URL
    let documentHash: String?               // SHA-256 hash
    let ledgerProofEntryID: String?         // Ledger proof entry
    let ledgerProofIndex: String?           // Ledger index
    let accessCode: String?                 // Human-readable code (e.g., "451-7892")
    let taskId: String?                     // For SSE progress tracking
    let success: Bool?                      // Success flag
    let uploaded: Bool?                     // Upload status
    let draftId: String?                    // Draft ID if applicable
}
```

## Key Differences

| Aspect | Old API | New API |
|--------|---------|---------|
| **Signing** | Client-side with Secure Enclave | Server-side |
| **Complexity** | Multi-step (sign → metadata → submit) | Single upload call |
| **Parameters** | personaDid, personaPublicKey, private keys | Just data + filename |
| **Endpoint** | Multiple endpoints | Single `/api/document/publish` |
| **Status** | Deprecated, throws errors | Active, production-ready |
| **Response** | Minimal metadata | Rich response with IDs, URLs, codes |
| **Progress** | None | Optional SSE streaming |
| **Error Handling** | Poor | Comprehensive |

## Migration Examples

### Example 1: Basic Document Upload

#### Old (Broken)
```swift
// ❌ This throws an error immediately
let metadata = DocumentMetadata(
    documentId: nil,
    title: nil,
    authors: [personaDid],
    participants: nil,
    witnesses: nil,
    fileType: "pdf",
    documentHash: hash.base64EncodedString()
)

try await WalletAPI.submitDocument(
    document: documentData, 
    metadata: metadata
)
```

#### New (Working)
```swift
// ✅ Simple and works
let response = try await DocumentSigningService.uploadDocument(
    documentData: documentData,
    originalFilename: "Contract.pdf"
)

print("Document ID: \(response.documentId)")
print("Access Code: \(response.accessCode ?? "N/A")")
```

### Example 2: Sign and Submit Flow

#### Old (Broken)
```swift
// ❌ Multi-step client-side signing (deprecated)
let (hash, signature) = try SignerService.signDocumentWithSecureEnclave(
    data: documentData,
    personaDid: personaDid
)

let metadata = DocumentMetadata(...)
try await WalletAPI.submitDocument(
    document: documentData,
    metadata: metadata
)
```

#### New (Working)
```swift
// ✅ Single call, server handles everything
let response = try await DocumentSigningService.uploadDocument(
    documentData: documentData,
    originalFilename: filename
)

// Server automatically:
// - Generates document hash
// - Creates PROOF ledger entry
// - Handles signing workflow
// - Returns access code for sharing
```

### Example 3: With Progress Tracking

#### Old (Impossible)
```swift
// ❌ No progress tracking available
try await WalletAPI.submitDocument(...)
// User sees nothing during upload
```

#### New (Working)
```swift
// ✅ Real-time progress via SSE
let result = try await DocumentSigningService.completeSigningWorkflowWithSSEProgress(
    documentData: documentData,
    originalFilename: filename,
    onProgress: { update in
        print("Progress: \(update.progress)")
        print("Step: \(update.step)")
    },
    onServerProgress: { step in
        print("Server: \(step.message)")
    }
)
```

## Why the Change?

### Security
- **Old**: Private keys exposed to client code
- **New**: Keys stay on server, never exposed

### Reliability
- **Old**: Multi-step process, many failure points
- **New**: Single atomic operation

### Simplicity
- **Old**: Client must understand crypto, hashing, signing
- **New**: Client just uploads data

### Functionality
- **Old**: No access codes, limited tracking
- **New**: Access codes, URLs, ledger proofs, progress tracking

### Maintenance
- **Old**: Complex client-side crypto maintenance
- **New**: Server controls entire workflow

## Server Endpoint

The new API uses a single endpoint:

```
POST /api/document/publish
Content-Type: application/octet-stream
X-Original-Filename: Contract.pdf

[binary document data]
```

Server responds with:
```json
{
  "documentId": "uuid-here",
  "accessCode": "451-7892",
  "ledgerProofEntryID": "proof-uuid",
  "documentURL": "https://s3.../document",
  "documentHash": "sha256-hash",
  "success": true
}
```

## Bottom Line

**Stop using anything in WalletAPI.swift for document submission.**  
**Use DocumentSigningService.uploadDocument() exclusively.**

The old APIs literally throw errors on purpose to force migration. Your code won't work if you use them.
