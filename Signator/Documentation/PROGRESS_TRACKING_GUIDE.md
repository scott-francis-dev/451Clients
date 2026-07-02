# Document Signing Progress Tracking Guide

## Overview

The document signing workflow now includes comprehensive progress tracking that makes all server-side operations visible to users. This guide explains the new features and how to use them.

## What's New

### ✅ Progress Reporting System

The new `completeSigningWorkflowWithProgress` method provides real-time updates on every step of the document signing process:

1. **Preparing document** - Initial setup
2. **Uploading to server** - Document transfer with size info
3. **Creating PROOF ledger entry** - First blockchain entry
4. **Uploading to S3** - Secure storage (when supported by server)
5. **Creating metadata** - Document metadata creation
6. **Signing document** - Cryptographic signature generation
7. **Creating SIGN ledger entry** - Signature blockchain entry
8. **Finalizing document** - Completing the workflow
9. **Creating ATTEST ledger entry** - Final attestation entry
10. **Indexing in global ledger** - Making searchable
11. **Complete** - Success!

### 📊 Progress Information Provided

Each progress update includes:
- **Step**: Current operation being performed
- **Message**: Human-readable description
- **Progress**: Percentage completion (0.0 to 1.0)
- **Document ID**: Available after upload
- **Entry ID**: Blockchain entry IDs for PROOF, SIGN, ATTEST

## Usage Examples

### Basic Progress Tracking

```swift
let (docId, attestID) = try await DocumentSigningService.completeSigningWorkflowWithProgress(
    documentData: documentData,
    authorDID: "alice@example.did",
    authorPrivateKey: privateKey,
    authorPublicKey: publicKeyBase64,
    originalFilename: "contract.pdf",
    additionalSigners: [],
    onProgress: { update in
        print("[\(Int(update.progress * 100))%] \(update.message)")
    }
)
```

### UI Integration (SwiftUI)

```swift
struct SigningView: View {
    @State private var progress: Double = 0.0
    @State private var message: String = ""
    @State private var isSubmitting: Bool = false
    
    var body: some View {
        VStack {
            if isSubmitting {
                ProgressView(value: progress)
                Text(message)
            }
            
            Button("Sign Document") {
                Task { await signDocument() }
            }
        }
    }
    
    func signDocument() async {
        isSubmitting = true
        
        do {
            let (docId, _) = try await DocumentSigningService.completeSigningWorkflowWithProgress(
                documentData: data,
                authorDID: authorDID,
                authorPrivateKey: key,
                authorPublicKey: pubKey,
                originalFilename: filename,
                additionalSigners: [],
                onProgress: { update in
                    Task { @MainActor in
                        progress = update.progress
                        message = update.message
                    }
                }
            )
            
            print("✅ Document signed: \(docId)")
        } catch {
            print("❌ Error: \(error)")
        }
        
        isSubmitting = false
    }
}
```

### Detailed Progress Logging

```swift
struct ProgressLogEntry {
    let timestamp: Date
    let step: DocumentSigningService.SigningStep
    let message: String
    let documentId: String?
    let entryId: String?
}

var progressLog: [ProgressLogEntry] = []

let (docId, _) = try await DocumentSigningService.completeSigningWorkflowWithProgress(
    documentData: data,
    authorDID: authorDID,
    authorPrivateKey: key,
    authorPublicKey: pubKey,
    originalFilename: filename,
    additionalSigners: [],
    onProgress: { update in
        let entry = ProgressLogEntry(
            timestamp: Date(),
            step: update.step,
            message: update.message,
            documentId: update.documentId,
            entryId: update.entryId
        )
        progressLog.append(entry)
        
        // Also log to console
        print("[\(Int(update.progress * 100))%] \(update.step.rawValue): \(update.message)")
        if let docId = update.documentId {
            print("   📄 Document ID: \(docId)")
        }
        if let entryId = update.entryId {
            print("   🔗 Entry ID: \(entryId)")
        }
    }
)
```

## Console Output Example

When using the progress tracking, you'll see detailed console output like:

```
[DocumentSigningService] 🚀 Starting complete signing workflow with progress reporting
[DocumentSigningService]    Author: alice@example.did
[DocumentSigningService]    Additional signers: 0
[DocumentSigningService]    Total steps: 3
[DocumentSigningService] [14%] Preparing document for upload...
[DocumentSigningService] [28%] Uploading document to server (1854217 bytes)...
[DocumentSigningService] 📤 Uploading document: doc-7c790a64-7fb9-4f24-b567-c517247a43d0
[DocumentSigningService]    Author DID: alice@example.did
[DocumentSigningService]    Size: 1854217 bytes
[DocumentSigningService] ✅ Document uploaded successfully
[DocumentSigningService]    Document ID: doc-7c790a64-7fb9-4f24-b567-c517247a43d0
[DocumentSigningService]    Proof Entry ID: proof-entry-12345
[DocumentSigningService] [42%] ✅ PROOF ledger entry created
[DocumentSigningService] [57%] Signing document as author (alice@example.did)...
[DocumentSigningService] [71%] ✅ SIGN ledger entry created for author
[DocumentSigningService] [85%] Finalizing document with 1 signature(s)...
[DocumentSigningService] [100%] ✅ ATTEST ledger entry created
[DocumentSigningService] [100%] 🎉 Document signing complete!
[DocumentSigningService] ✅ Complete workflow finished
[DocumentSigningService]    Document ID: doc-7c790a64-7fb9-4f24-b567-c517247a43d0
[DocumentSigningService]    Total signatures: 1
[DocumentSigningService]    Attest Entry: attest-entry-67890
```

## Integration with SendSigningFlowView

The main document signing flow (`SendSigningFlowView.swift`) now includes:

1. **Progress bar** showing percentage completion
2. **Current step indicator** with icon and message
3. **Progress log** (expandable details view)
4. **Document ID display** as soon as available
5. **Entry ID tracking** for all blockchain entries

## Understanding the Server Process

When you see these progress steps, here's what's happening on the server:

### 1. Document Upload (PROOF Entry)
- ✅ Document uploaded to S3 providers (primary + backup)
- ✅ SHA-256 hash calculated
- ✅ DID document created
- ✅ PROOF ledger entry created (records document existence)
- ✅ Legacy blockchain block created
- ✅ Entry indexed in MeiliSearch

### 2. Signature Addition (SIGN Entry)
- ✅ Signature verified against document hash
- ✅ SIGN ledger entry created (chains to PROOF)
- ✅ Signature indexed for querying
- ✅ Global ledger counter incremented

### 3. Finalization (ATTEST Entry)
- ✅ All signatures validated
- ✅ ATTEST ledger entry created (final confirmation)
- ✅ Document marked as complete
- ✅ Full audit trail available

## Future Enhancements

### Streaming Upload Progress

For large documents, you can enhance the upload step with byte-level progress:

```swift
// Future API (not yet implemented)
static func uploadDocumentWithStreamingProgress(
    documentData: Data,
    authorDID: String,
    originalFilename: String?,
    onUploadProgress: @escaping (Double) -> Void
) async throws -> UploadResponse {
    // Uses URLSession delegate to monitor upload bytes
    // Provides real-time upload percentage
}
```

### Server-Side Progress Events

If your server supports Server-Sent Events (SSE) or WebSocket, you could receive:

```
X-Processing-Step: creating_metadata
X-S3-Upload-Status: in_progress
X-Ledger-Index: 123
```

These can be parsed and shown in the UI for even more detailed feedback.

## API Reference

### DocumentSigningService.ProgressUpdate

```swift
public struct ProgressUpdate {
    public let step: SigningStep
    public let message: String
    public let progress: Double // 0.0 to 1.0
    public let documentId: String?
    public let entryId: String?
}
```

### DocumentSigningService.SigningStep

```swift
public enum SigningStep: String, Codable {
    case preparing = "Preparing document"
    case uploading = "Uploading to server"
    case creatingProof = "Creating PROOF ledger entry"
    case uploadingToS3 = "Uploading to secure storage"
    case creatingMetadata = "Creating metadata"
    case signingDocument = "Signing document"
    case creatingSignEntry = "Creating SIGN ledger entry"
    case finalizingDocument = "Finalizing document"
    case creatingAttestEntry = "Creating ATTEST ledger entry"
    case indexingLedger = "Indexing in global ledger"
    case complete = "Complete"
}
```

## Migration from Old API

### Before (No Progress)
```swift
try await DocumentSigningService.completeSigningWorkflow(
    documentData: data,
    authorDID: did,
    authorPrivateKey: key,
    authorPublicKey: pubKey,
    originalFilename: filename,
    additionalSigners: []
)
```

### After (With Progress)
```swift
try await DocumentSigningService.completeSigningWorkflowWithProgress(
    documentData: data,
    authorDID: did,
    authorPrivateKey: key,
    authorPublicKey: pubKey,
    originalFilename: filename,
    additionalSigners: [],
    onProgress: { update in
        print("[\(Int(update.progress * 100))%] \(update.message)")
    }
)
```

## Complete Example

See `DocumentSigningProgressExample.swift` for a full SwiftUI example including:
- Real-time progress bar
- Step-by-step UI updates
- Detailed progress log
- Success/error states
- Document ID and entry ID display

## Troubleshooting

### Missing Author DID on Server

If the server logs show `author DID is still "unknown"`, verify:

1. The `X-Author-DID` header is being sent (it is in the current implementation)
2. The author DID is properly formatted (e.g., `alice@example.did`)
3. The server is correctly parsing the header

The client already sends this header correctly in `DocumentSigningService.uploadDocument()`:

```swift
request.setValue(authorDID, forHTTPHeaderField: "X-Author-DID")
```

### Progress Not Updating

If progress callbacks aren't being called:

1. Verify you're using `completeSigningWorkflowWithProgress` (not the old method)
2. Check that your `onProgress` closure is properly capturing state
3. Use `Task { @MainActor in }` when updating UI from the callback

## See Also

- `DocumentSigningService.swift` - Core signing implementation
- `SendSigningFlowView.swift` - Main UI integration
- `DocumentSigningProgressExample.swift` - Complete example
- `DOCUMENT_SIGNING_MIGRATION.md` - General migration guide
