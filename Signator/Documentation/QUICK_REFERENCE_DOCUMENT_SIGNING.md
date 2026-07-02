# Document Signing - Quick Reference Card

## 🚀 Quick Start

### Simple Upload & Sign (Single Signer)
```swift
import DocumentSigningService

let (docId, attestID) = try await DocumentSigningService.completeSigningWorkflow(
    documentData: myDocumentData,
    authorDID: "did:persona:alice@company",  // ✅ Real DID required
    authorPrivateKey: myPrivateKey,
    authorPublicKey: myPublicKey,
    originalFilename: "contract.pdf",
    additionalSigners: []  // Just author for now
)
```

### Multi-Party Signing (Multiple Signers)
```swift
let (docId, attestID) = try await DocumentSigningService.completeSigningWorkflow(
    documentData: myDocumentData,
    authorDID: "did:persona:alice@company",
    authorPrivateKey: aliceKey,
    authorPublicKey: alicePubKey,
    originalFilename: "contract.pdf",
    additionalSigners: [
        (did: "did:persona:bob@law", publicKey: bobKey, privateKey: bobPrivate, role: .participant),
        (did: "did:persona:charlie@notary", publicKey: charlieKey, privateKey: charliePrivate, role: .notary)
    ]
)
```

## 🔑 Key Changes

| Old | New |
|-----|-----|
| Author DID optional ("unknown") | ❌ Author DID **required** |
| Single upload | ✅ Upload → Sign → Finalize |
| No roles | ✅ Roles required (author, participant, witness, notary, reviewer) |
| No tracking | ✅ Track ledger entry IDs |
| No audit trail | ✅ Full audit trail available |

## 📋 Manual Workflow (Step-by-Step)

```swift
// 1️⃣ UPLOAD
let upload = try await DocumentSigningService.uploadDocument(
    documentData: data,
    authorDID: "did:persona:alice@company",
    originalFilename: "contract.pdf"
)
// Returns: documentId, ledgerProofEntryID, documentHash

// 2️⃣ SIGN (Author)
let sig1 = try await DocumentSigningService.addSignature(
    documentId: upload.documentId,
    signerDID: "did:persona:alice@company",
    signerPublicKey: alicePubKey,
    documentHash: Data(SHA256.hash(data: data)),
    privateKey: alicePrivateKey,
    role: .author,
    previousEntryID: upload.ledgerProofEntryID  // ← Chain to PROOF
)
// Returns: ledgerEntryID, signerDID, role, timestamp

// 3️⃣ SIGN (Participant)
let sig2 = try await DocumentSigningService.addSignature(
    documentId: upload.documentId,
    signerDID: "did:persona:bob@company",
    signerPublicKey: bobPubKey,
    documentHash: Data(SHA256.hash(data: data)),
    privateKey: bobPrivateKey,
    role: .participant,
    previousEntryID: sig1.ledgerEntryID  // ← Chain to previous SIGN
)

// 4️⃣ CHECK STATUS (Optional)
let status = try await DocumentSigningService.getSignatureStatus(
    documentId: upload.documentId
)
print("Total: \(status.totalSignatures)")
print("By role: \(status.signaturesByRole)")

// 5️⃣ FINALIZE
let finalized = try await DocumentSigningService.finalizeDocument(
    documentId: upload.documentId,
    finalizedBy: "did:persona:alice@company",
    signatureEntryIDs: [sig1.ledgerEntryID, sig2.ledgerEntryID]
)
// Returns: status, ledgerAttestEntryID, finalizedAt

// 6️⃣ AUDIT TRAIL (Optional)
let audit = try await DocumentSigningService.getAuditTrail(
    documentId: upload.documentId
)
// Returns: documentId, entries[]
```

## 🎭 Signer Roles

| Role | Usage | Example |
|------|-------|---------|
| `.author` | Document creator | Contract drafter, original author |
| `.participant` | Party to agreement | Contract signatory, involved party |
| `.witness` | Attests to signing | Legal witness, observer |
| `.notary` | Official certification | Notary public, official seal |
| `.reviewer` | Reviews/approves | Legal review, compliance check |

## 🔗 API Endpoints

### Upload
```http
PUT /api/document/draft/:id/content
Headers: X-Document-Id, X-Author-DID (required), X-Original-Filename
```

### Sign
```http
POST /api/document/:id/sign
Body: { signerDID, signerPublicKey, signature, role, previousEntryID }
```

### Finalize
```http
POST /api/document/:id/finalize
Body: { finalizedBy, signatureEntryIDs[] }
```

### Status
```http
GET /api/document/:id/signatures
```

### Audit
```http
GET /api/document/:id/ledger
```

## 📦 Ledger Entries

| Type | When Created | Purpose |
|------|--------------|---------|
| **PROOF** | Upload | Document verified, hash recorded |
| **SIGN** | Each signature | Party signs with role |
| **ATTEST** | Finalize | Workflow complete, all signatures collected |

## ⚠️ Common Errors

### ❌ Missing Author DID
```swift
// DON'T:
X-Author-DID: unknown

// DO:
X-Author-DID: did:persona:alice@company
```

### ❌ Missing Role
```swift
// DON'T:
try await addSignature(..., role: nil)

// DO:
try await addSignature(..., role: .participant)
```

### ❌ Empty Signature List
```swift
// DON'T:
try await finalizeDocument(..., signatureEntryIDs: [])

// DO:
try await finalizeDocument(..., signatureEntryIDs: [sig1.ledgerEntryID, sig2.ledgerEntryID])
```

### ❌ Breaking Chain
```swift
// DON'T:
try await addSignature(..., previousEntryID: nil)

// DO:
try await addSignature(..., previousEntryID: lastEntry.ledgerEntryID)
```

## 📊 Status Response

```json
{
  "documentId": "doc-abc-123",
  "totalSignatures": 3,
  "signaturesByRole": {
    "author": 1,
    "participant": 2
  },
  "signers": [
    {
      "did": "did:persona:alice@company",
      "role": "author",
      "timestamp": "2025-01-15T10:15:00Z",
      "ledgerEntryID": "uuid-1"
    }
  ]
}
```

## 📜 Audit Trail Response

```json
{
  "documentId": "doc-abc-123",
  "entries": [
    {
      "id": "uuid-1",
      "type": "PROOF",
      "issuer": "did:persona:alice@company",
      "timestamp": "2025-01-15T10:00:00Z",
      "documentHash": "base64-hash"
    },
    {
      "id": "uuid-2",
      "type": "SIGN",
      "issuer": "did:persona:alice@company",
      "role": "author",
      "timestamp": "2025-01-15T10:15:00Z",
      "previousEntryID": "uuid-1",
      "signature": "base64-sig"
    },
    {
      "id": "uuid-3",
      "type": "ATTEST",
      "issuer": "did:persona:alice@company",
      "timestamp": "2025-01-15T11:00:00Z",
      "previousEntryID": "uuid-2"
    }
  ]
}
```

## 🧪 Testing

### Interactive Test
```swift
import SwiftUI

@main
struct TestApp: App {
    var body: some Scene {
        WindowGroup {
            MultiPartySigningView()  // Built-in example
        }
    }
}
```

### Unit Tests
```bash
swift test
# Or in Xcode: Cmd+U
```

## 📚 Files to Reference

| File | Purpose |
|------|---------|
| `DocumentSigningService.swift` | Main service |
| `MultiPartySigningView.swift` | Interactive example |
| `DocumentSigningIntegrationExamples.swift` | Integration patterns |
| `DOCUMENT_SIGNING_MIGRATION.md` | Full migration guide |
| `README_DOCUMENT_SIGNING.md` | Complete documentation |

## 💡 Use Case Examples

### Contract (2 parties)
```swift
Author (attorney) → Participant (client) → Finalize
```

### Notarized Agreement (3 parties)
```swift
Author (attorney) → Participant (client) → Notary → Finalize
```

### Multi-Party (5 roles)
```swift
Author → Participant → Participant → Witness → Reviewer → Finalize
```

### Async Signing
```swift
// Day 1: Author uploads
let upload = try await uploadDocument(...)
let authorSig = try await addSignature(..., role: .author)

// Day 2: Participant signs (different session)
let participantSig = try await addSignature(..., role: .participant)

// Day 3: Finalize
try await finalizeDocument(signatureEntryIDs: [authorSig.ledgerEntryID, participantSig.ledgerEntryID])
```

## 🎯 Best Practices

1. ✅ **Always use real DIDs** (no "unknown")
2. ✅ **Track all entry IDs** (needed for finalization)
3. ✅ **Specify accurate roles** (affects audit trail)
4. ✅ **Chain entries properly** (maintains integrity)
5. ✅ **Check status before finalizing** (verify completeness)
6. ✅ **Handle errors gracefully** (each step can fail)

## 🔄 Migration

### Old Code
```swift
try await submitSignedDocumentFlow(
    documentData: data,
    privateKey: key,
    personaDid: "unknown",  // ❌
    personaPublicKey: publicKey,
    isPublic: false,
    documentId: docId,
    originalFilename: filename
)
```

### New Code
```swift
let (docId, attestID) = try await DocumentSigningService.completeSigningWorkflow(
    documentData: data,
    authorDID: "did:persona:alice@company",  // ✅
    authorPrivateKey: key,
    authorPublicKey: publicKey,
    originalFilename: filename
)
```

## 🆘 Troubleshooting

| Error | Cause | Solution |
|-------|-------|----------|
| "Author DID required" | Missing or "unknown" DID | Use real DID: `did:persona:name@domain` |
| "Role required" | Missing role in signature | Specify: `.author`, `.participant`, etc. |
| "Empty signature list" | No signatures for finalization | Collect all `ledgerEntryID` values |
| "Invalid document ID" | Wrong document ID | Use ID from upload response |
| "Chain broken" | Missing previousEntryID | Chain to PROOF or previous SIGN |

---

**Quick Tip:** Keep this card handy while integrating the new workflow! 📌

**Status:** ✅ Ready to Use

**Version:** 1.0.0
