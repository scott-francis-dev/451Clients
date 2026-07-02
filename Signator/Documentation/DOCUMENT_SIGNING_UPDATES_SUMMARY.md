# Document Signing Workflow Updates - Summary

## Latest Updates (Progress Tracking)

### ✅ Fixed Progress Calculation
- Progress now correctly reports 0-100% (was showing 133%)
- Major steps properly counted: Upload (33%), Author Sign (66%), Finalize (100%)
- Sub-steps don't increment counter, providing accurate progress

### ✅ Enhanced Verbose Logging
- Real-time progress updates in UI with progress bar
- Detailed step-by-step console logging
- Document ID and Entry IDs displayed immediately
- All server operations visible to user

### ✅ New Progress-Aware API
```swift
// Use this for real-time progress updates
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

See `PROGRESS_TRACKING_GUIDE.md` for complete documentation.

---

# Document Signing Workflow Updates - Summary

## What Was Changed

The client has been updated to support the new multi-party document signing workflow introduced on the server. This enables formal ledger-based document signing with roles and audit trails.

## New Files Created

### 1. `DocumentSigningService.swift`
A comprehensive service implementing the new workflow:

**Key Features:**
- ✅ Upload documents with required author DID (creates PROOF ledger entry)
- ✅ Add signatures with roles: author, participant, witness, notary, reviewer (creates SIGN entries)
- ✅ Finalize documents with collected signature IDs (creates ATTEST entry)
- ✅ Query signature status by role
- ✅ View complete audit trail
- ✅ Convenience method for complete workflow

**Main Functions:**
```swift
// Step-by-step workflow
uploadDocument(documentData:authorDID:originalFilename:)
addSignature(documentId:signerDID:signerPublicKey:documentHash:privateKey:role:previousEntryID:)
finalizeDocument(documentId:finalizedBy:signatureEntryIDs:)

// Query functions
getSignatureStatus(documentId:)
getAuditTrail(documentId:)

// Convenience method
completeSigningWorkflow(documentData:authorDID:authorPrivateKey:authorPublicKey:originalFilename:additionalSigners:)
```

### 2. `MultiPartySigningView.swift`
An example SwiftUI view demonstrating the complete workflow:

**Features:**
- Interactive document upload
- Add multiple signers with roles
- Real-time signature tracking
- View signature status
- View audit trail
- Finalize workflow

**Use for testing:**
```swift
NavigationView {
    MultiPartySigningView()
}
```

### 3. `DOCUMENT_SIGNING_MIGRATION.md`
Complete migration guide with:
- Before/after code examples
- Detailed API endpoint documentation
- Error handling guidance
- Best practices
- Real-world examples

## Updated Files

### `DocumentSubmissionService.swift`
- ✅ Deprecated old `submitSignedDocumentFlow()` function
- ✅ Added backward compatibility wrapper (uses new workflow internally)
- ✅ Created new `submitSignedDocumentFlowV2()` with multi-signer support

**Migration Path:**
```swift
// Old code still works (deprecated)
try await submitSignedDocumentFlow(...)

// New code (recommended)
try await submitSignedDocumentFlowV2(..., additionalSigners: [...])

// Or use service directly
try await DocumentSigningService.completeSigningWorkflow(...)
```

## Key Changes from Server Requirements

### 1. Author DID Now Required ✅
```swift
// ❌ OLD: Optional, could be "unknown"
X-Author-DID: unknown

// ✅ NEW: Required, must be real DID
X-Author-DID: did:persona:alice@company
```

### 2. Multi-Step Workflow ✅
```swift
// OLD: Single upload
Upload → Done

// NEW: Multi-party signing
Upload (PROOF) → Sign (author) → Sign (participant) → Finalize (ATTEST)
```

### 3. Role-Based Signatures ✅
Every signature must specify a role:
- `author` - Document creator
- `participant` - Party to agreement
- `witness` - Attestation
- `notary` - Official certification
- `reviewer` - Approval/review

### 4. Ledger Entry Tracking ✅
Client must track and chain entry IDs:
```swift
// Upload returns proof entry ID
let upload = try await uploadDocument(...)
print(upload.ledgerProofEntryID)

// Each signature returns entry ID
let sig1 = try await addSignature(..., previousEntryID: upload.ledgerProofEntryID)
let sig2 = try await addSignature(..., previousEntryID: sig1.ledgerEntryID)

// Finalize requires all entry IDs
try await finalizeDocument(
    signatureEntryIDs: [sig1.ledgerEntryID, sig2.ledgerEntryID]
)
```

### 5. Audit Trail Access ✅
```swift
// Check signature status
let status = try await DocumentSigningService.getSignatureStatus(documentId: docId)
print("Total: \(status.totalSignatures)")
print("By role: \(status.signaturesByRole)")

// View complete audit trail
let audit = try await DocumentSigningService.getAuditTrail(documentId: docId)
for entry in audit.entries {
    print("\(entry.type): \(entry.issuer) at \(entry.timestamp)")
}
```

## Server API Endpoints Used

| Endpoint | Method | Purpose | Ledger Entry |
|----------|--------|---------|--------------|
| `/api/document/draft/:id/content` | PUT | Upload document | PROOF |
| `/api/document/:id/sign` | POST | Add signature | SIGN |
| `/api/document/:id/finalize` | POST | Complete workflow | ATTEST |
| `/api/document/:id/signatures` | GET | Query status | - |
| `/api/document/:id/ledger` | GET | Audit trail | - |

## Backward Compatibility

✅ **Old code continues to work** through the deprecated `submitSignedDocumentFlow()` function
✅ **Documents still uploaded** to S3
✅ **Search still works** via MeiliSearch
✅ **PROOF entry created** automatically

⚠️ **But you won't get:**
- Multi-party signing
- Role-based tracking
- Complete audit trail
- ATTEST finalization

## Quick Start

### Simple Single-Signer (Backward Compatible)
```swift
// Existing code works with real DID
try await submitSignedDocumentFlow(
    documentData: data,
    privateKey: key,
    personaDid: "did:persona:alice@company",  // ✅ Real DID required now
    personaPublicKey: publicKey,
    isPublic: false,
    documentId: docId,
    originalFilename: filename
)
```

### Multi-Party Signing (New)
```swift
let (docId, attestID) = try await DocumentSigningService.completeSigningWorkflow(
    documentData: data,
    authorDID: "did:persona:alice@company",
    authorPrivateKey: authorKey,
    authorPublicKey: authorPubKey,
    originalFilename: filename,
    additionalSigners: [
        (did: "did:persona:bob@law", publicKey: bobKey, privateKey: bobPrivate, role: .participant),
        (did: "did:persona:charlie@notary", publicKey: charlieKey, privateKey: charliePrivate, role: .notary)
    ]
)
```

### Manual Control (Advanced)
```swift
// 1. Upload
let upload = try await DocumentSigningService.uploadDocument(...)

// 2. Add signatures
let sig1 = try await DocumentSigningService.addSignature(..., role: .author)
let sig2 = try await DocumentSigningService.addSignature(..., role: .participant)

// 3. Check status
let status = try await DocumentSigningService.getSignatureStatus(...)

// 4. Finalize
let finalized = try await DocumentSigningService.finalizeDocument(
    signatureEntryIDs: [sig1.ledgerEntryID, sig2.ledgerEntryID]
)

// 5. View audit
let audit = try await DocumentSigningService.getAuditTrail(...)
```

## Testing

Run the interactive example:
```swift
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            MultiPartySigningView()
        }
    }
}
```

## Documentation

See `DOCUMENT_SIGNING_MIGRATION.md` for:
- Complete API reference
- Migration examples
- Error handling
- Best practices
- Real-world use cases

## Benefits of New Workflow

✅ **Formal audit trail** - Every action tracked in ledger
✅ **Role-based signing** - Track who signed as what role
✅ **Multi-party support** - Multiple signers with different roles
✅ **Verification** - Complete chain of custody
✅ **Compliance** - Meets legal requirements for e-signatures
✅ **Flexibility** - Async signing workflow (don't need all signers at once)

## Example: Contract with Multiple Parties

```swift
// Upload contract
let upload = try await DocumentSigningService.uploadDocument(
    documentData: contractData,
    authorDID: "did:persona:attorney@lawfirm",
    originalFilename: "service-agreement.pdf"
)

let hash = Data(SHA256.hash(data: contractData))

// Attorney signs as author
let attorney = try await DocumentSigningService.addSignature(
    documentId: upload.documentId,
    signerDID: "did:persona:attorney@lawfirm",
    signerPublicKey: attorneyPubKey,
    documentHash: hash,
    privateKey: attorneyKey,
    role: .author,
    previousEntryID: upload.ledgerProofEntryID
)

// Company A signs as participant
let companyA = try await DocumentSigningService.addSignature(
    documentId: upload.documentId,
    signerDID: "did:persona:companyA@business",
    signerPublicKey: companyAPubKey,
    documentHash: hash,
    privateKey: companyAKey,
    role: .participant,
    previousEntryID: attorney.ledgerEntryID
)

// Company B signs as participant
let companyB = try await DocumentSigningService.addSignature(
    documentId: upload.documentId,
    signerDID: "did:persona:companyB@corp",
    signerPublicKey: companyBPubKey,
    documentHash: hash,
    privateKey: companyBKey,
    role: .participant,
    previousEntryID: companyA.ledgerEntryID
)

// Witness attests
let witness = try await DocumentSigningService.addSignature(
    documentId: upload.documentId,
    signerDID: "did:persona:witness@neutral",
    signerPublicKey: witnessPubKey,
    documentHash: hash,
    privateKey: witnessKey,
    role: .witness,
    previousEntryID: companyB.ledgerEntryID
)

// Check status
let status = try await DocumentSigningService.getSignatureStatus(
    documentId: upload.documentId
)
print("Authors: \(status.signaturesByRole["author"] ?? 0)")
print("Participants: \(status.signaturesByRole["participant"] ?? 0)")
print("Witnesses: \(status.signaturesByRole["witness"] ?? 0)")

// Finalize
let finalized = try await DocumentSigningService.finalizeDocument(
    documentId: upload.documentId,
    finalizedBy: "did:persona:attorney@lawfirm",
    signatureEntryIDs: [
        attorney.ledgerEntryID,
        companyA.ledgerEntryID,
        companyB.ledgerEntryID,
        witness.ledgerEntryID
    ]
)

print("✅ Contract finalized with complete audit trail")
print("   Attest entry: \(finalized.ledgerAttestEntryID)")

// View complete history
let audit = try await DocumentSigningService.getAuditTrail(
    documentId: upload.documentId
)
// Shows: PROOF → SIGN(author) → SIGN(participant) → SIGN(participant) → SIGN(witness) → ATTEST
```

## Next Steps

1. ✅ Review `DocumentSigningService.swift` for implementation details
2. ✅ Test with `MultiPartySigningView.swift` 
3. ✅ Read `DOCUMENT_SIGNING_MIGRATION.md` for complete guide
4. ✅ Update existing code to provide real author DIDs
5. ✅ Consider migrating to new workflow for multi-party scenarios

## Questions or Issues?

- See migration guide for detailed examples
- Check error messages for specific requirements
- Test with interactive view before production use
