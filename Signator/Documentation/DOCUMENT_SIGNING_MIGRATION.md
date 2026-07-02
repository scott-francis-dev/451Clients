# Document Signing Workflow Migration Guide

## Overview

The server has introduced a new multi-party document signing workflow with formal ledger entries (PROOF, SIGN, ATTEST). This guide helps you migrate from the old single-step upload workflow to the new multi-step signing workflow.

## What Changed?

### Old Workflow (Deprecated)
```
┌─────────────────────┐
│  Upload Document    │
│  + Optional         │
│    Signature        │
└─────────────────────┘
          ↓
    [Document Stored]
```

### New Workflow (Recommended)
```
┌─────────────────────┐
│  1. Upload          │ → Creates PROOF entry
│     (X-Author-DID)  │   (Author DID required)
└─────────────────────┘
          ↓
┌─────────────────────┐
│  2. Add Signatures  │ → Creates SIGN entries
│     (with roles)    │   (author, participant, etc.)
└─────────────────────┘
          ↓
┌─────────────────────┐
│  3. Finalize        │ → Creates ATTEST entry
│     (collect IDs)   │   (Complete workflow)
└─────────────────────┘
```

## Key Changes

| Aspect | Old Behavior | New Behavior |
|--------|--------------|--------------|
| **Author DID** | Optional, defaults to "unknown" | ❌ **Required** - must be a real DID |
| **Workflow** | Single upload with optional signature | ✅ Multi-step: Upload → Sign → Finalize |
| **Roles** | Not tracked | ✅ Must specify: `author`, `participant`, `witness`, `notary`, `reviewer` |
| **Ledger Entries** | Not tracked | ✅ PROOF (upload), SIGN (each signature), ATTEST (finalization) |
| **Entry IDs** | Not exposed | ✅ Client must track for chaining and finalization |
| **Audit Trail** | Not available | ✅ Full history via `/api/document/:id/ledger` |
| **Status Check** | Not available | ✅ Status by role via `/api/document/:id/signatures` |

## Migration Steps

### Step 1: Update Imports

Add the new service:
```swift
import DocumentSigningService
```

### Step 2: Replace Old Calls

#### Before (Deprecated):
```swift
try await submitSignedDocumentFlow(
    documentData: data,
    privateKey: authorKey,
    personaDid: "unknown",  // ❌ Not allowed anymore
    personaPublicKey: publicKey,
    isPublic: false,
    documentId: docId,
    originalFilename: "contract.pdf"
)
```

#### After (Simple Migration):
```swift
// Option A: Use legacy wrapper (auto-migrated internally)
try await submitSignedDocumentFlow(
    documentData: data,
    privateKey: authorKey,
    personaDid: "did:persona:alice@company",  // ✅ Real DID required
    personaPublicKey: publicKey,
    isPublic: false,
    documentId: docId,
    originalFilename: "contract.pdf"
)
```

#### After (Full New Workflow):
```swift
// Option B: Use new multi-party workflow
let (documentId, attestEntryID) = try await DocumentSigningService.completeSigningWorkflow(
    documentData: data,
    authorDID: "did:persona:alice@company",
    authorPrivateKey: authorKey,
    authorPublicKey: authorPublicKey,
    originalFilename: "contract.pdf",
    additionalSigners: [
        (
            did: "did:persona:bob@lawfirm",
            publicKey: bobPublicKey,
            privateKey: bobPrivateKey,
            role: .participant
        ),
        (
            did: "did:persona:charlie@notary",
            publicKey: charliePublicKey,
            privateKey: charliePrivateKey,
            role: .notary
        )
    ]
)

print("Document finalized: \(documentId)")
print("Attest entry: \(attestEntryID)")
```

### Step 3: Manual Multi-Step Workflow (Advanced)

For more control over the signing process:

```swift
// 1. Upload document
let uploadResponse = try await DocumentSigningService.uploadDocument(
    documentData: documentData,
    authorDID: "did:persona:alice@company",
    originalFilename: "contract.pdf"
)

print("Document ID: \(uploadResponse.documentId)")
print("Proof Entry: \(uploadResponse.ledgerProofEntryID)")

// 2. Author signs first
let documentHash = Data(SHA256.hash(data: documentData))

let authorSig = try await DocumentSigningService.addSignature(
    documentId: uploadResponse.documentId,
    signerDID: "did:persona:alice@company",
    signerPublicKey: alicePublicKey,
    documentHash: documentHash,
    privateKey: alicePrivateKey,
    role: .author,
    previousEntryID: uploadResponse.ledgerProofEntryID  // Chain to PROOF
)

// 3. Participant signs (chains to author's signature)
let participantSig = try await DocumentSigningService.addSignature(
    documentId: uploadResponse.documentId,
    signerDID: "did:persona:bob@lawfirm",
    signerPublicKey: bobPublicKey,
    documentHash: documentHash,
    privateKey: bobPrivateKey,
    role: .participant,
    previousEntryID: authorSig.ledgerEntryID  // Chain to previous SIGN
)

// 4. Check signature status (optional)
let status = try await DocumentSigningService.getSignatureStatus(
    documentId: uploadResponse.documentId
)

print("Total signatures: \(status.totalSignatures)")
print("By role: \(status.signaturesByRole)")
print("Authors: \(status.signaturesByRole["author"] ?? 0)")
print("Participants: \(status.signaturesByRole["participant"] ?? 0)")

// 5. Finalize document
let finalizeResponse = try await DocumentSigningService.finalizeDocument(
    documentId: uploadResponse.documentId,
    finalizedBy: "did:persona:alice@company",
    signatureEntryIDs: [
        authorSig.ledgerEntryID,
        participantSig.ledgerEntryID
    ]
)

print("Finalized at: \(finalizeResponse.finalizedAt)")
print("Attest entry: \(finalizeResponse.ledgerAttestEntryID)")

// 6. View complete audit trail (optional)
let audit = try await DocumentSigningService.getAuditTrail(
    documentId: uploadResponse.documentId
)

for entry in audit.entries {
    print("\(entry.type): \(entry.issuer) at \(entry.timestamp)")
    if let role = entry.role {
        print("  Role: \(role)")
    }
}
```

## New API Endpoints

### Upload Document
```
PUT /api/document/draft/:draftId/content
Headers:
  X-Document-Id: doc-abc-123
  X-Author-DID: did:persona:alice@company  // ✅ Required
  X-Original-Filename: contract.pdf

Body: <binary data>
```

**Response:**
```json
{
  "documentId": "doc-abc-123",
  "ledgerProofEntryID": "uuid-proof-entry",
  "documentHash": "base64-hash"
}
```

### Add Signature
```
POST /api/document/:documentId/sign
Content-Type: application/json

{
  "signerDID": "did:persona:bob@lawfirm",
  "signerPublicKey": "base64-encoded-P256-key",
  "signature": "base64-encoded-signature",
  "role": "participant",
  "previousEntryID": "uuid-from-previous-entry"
}
```

**Response:**
```json
{
  "ledgerEntryID": "uuid-sign-entry",
  "signerDID": "did:persona:bob@lawfirm",
  "role": "participant",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

### Finalize Document
```
POST /api/document/:documentId/finalize
Content-Type: application/json

{
  "finalizedBy": "did:persona:alice@company",
  "signatureEntryIDs": [
    "uuid-sign-1",
    "uuid-sign-2",
    "uuid-sign-3"
  ]
}
```

**Response:**
```json
{
  "status": "finalized",
  "ledgerAttestEntryID": "uuid-attest-entry",
  "finalizedAt": "2025-01-15T11:00:00Z"
}
```

### Check Signature Status
```
GET /api/document/:documentId/signatures
```

**Response:**
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

### View Audit Trail
```
GET /api/document/:documentId/ledger
```

**Response:**
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
      "timestamp": "2025-01-15T10:15:00Z",
      "previousEntryID": "uuid-1",
      "role": "author",
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

## Signer Roles

The new workflow requires specifying a role for each signer:

| Role | Purpose | Example Use Case |
|------|---------|------------------|
| `author` | Original creator/drafter | Contract author, document creator |
| `participant` | Active party to the agreement | Contract signatory, party to agreement |
| `witness` | Attests to the signing | Legal witness, observer |
| `notary` | Official certification | Notary public, official certifier |
| `reviewer` | Reviews for approval | Legal review, compliance check |

## Error Handling

### Common Errors

**Missing Author DID:**
```swift
// ❌ Old way (no longer works)
X-Author-DID: unknown

// ✅ New way (required)
X-Author-DID: did:persona:alice@company
```

**Missing Role:**
```swift
// ❌ Missing role
try await DocumentSigningService.addSignature(
    documentId: docId,
    signerDID: did,
    // ... other params
    role: nil  // Error!
)

// ✅ Always specify role
try await DocumentSigningService.addSignature(
    documentId: docId,
    signerDID: did,
    // ... other params
    role: .participant  // Required
)
```

**Missing Entry IDs for Finalization:**
```swift
// ❌ Empty or wrong IDs
try await DocumentSigningService.finalizeDocument(
    documentId: docId,
    finalizedBy: did,
    signatureEntryIDs: []  // Error!
)

// ✅ Collect all signature entry IDs
var entryIDs: [String] = []
let sig1 = try await addSignature(...)
entryIDs.append(sig1.ledgerEntryID)

let sig2 = try await addSignature(...)
entryIDs.append(sig2.ledgerEntryID)

try await DocumentSigningService.finalizeDocument(
    documentId: docId,
    finalizedBy: did,
    signatureEntryIDs: entryIDs
)
```

## Backward Compatibility

The old `submitSignedDocumentFlow` function is **deprecated but still functional**. It now internally uses the new workflow:

- ✅ Upload still works
- ✅ Documents still stored in S3
- ✅ Documents still searchable in MeiliSearch
- ✅ Single-signer workflow supported

**However, you won't get:**
- ❌ Multi-party signing capability
- ❌ Role-based signature tracking
- ❌ Complete audit trail with all signatures
- ❌ ATTEST entry for formal finalization

## Testing

Use the `MultiPartySigningView` for testing the new workflow:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        MultiPartySigningView()
    }
}
```

## Best Practices

1. **Always provide real DIDs**: No more "unknown" or placeholder DIDs
2. **Track entry IDs**: Save ledger entry IDs from each step for finalization
3. **Specify roles accurately**: Use appropriate roles for each signer
4. **Chain entries properly**: Use `previousEntryID` to maintain audit trail
5. **Verify before finalizing**: Check signature status before calling finalize
6. **Handle errors gracefully**: Each step can fail independently

## Example: Contract Signing Flow

```swift
// Complete contract signing with attorney, client, and witness

let contract = try Data(contentsOf: contractURL)

// 1. Attorney uploads and signs as author
let upload = try await DocumentSigningService.uploadDocument(
    documentData: contract,
    authorDID: "did:persona:attorney@lawfirm",
    originalFilename: "service-agreement.pdf"
)

let hash = Data(SHA256.hash(data: contract))

let attorneySig = try await DocumentSigningService.addSignature(
    documentId: upload.documentId,
    signerDID: "did:persona:attorney@lawfirm",
    signerPublicKey: attorneyPubKey,
    documentHash: hash,
    privateKey: attorneyPrivateKey,
    role: .author,
    previousEntryID: upload.ledgerProofEntryID
)

// 2. Client signs as participant
let clientSig = try await DocumentSigningService.addSignature(
    documentId: upload.documentId,
    signerDID: "did:persona:client@business",
    signerPublicKey: clientPubKey,
    documentHash: hash,
    privateKey: clientPrivateKey,
    role: .participant,
    previousEntryID: attorneySig.ledgerEntryID
)

// 3. Witness attests
let witnessSig = try await DocumentSigningService.addSignature(
    documentId: upload.documentId,
    signerDID: "did:persona:witness@neutral",
    signerPublicKey: witnessPubKey,
    documentHash: hash,
    privateKey: witnessPrivateKey,
    role: .witness,
    previousEntryID: clientSig.ledgerEntryID
)

// 4. Check all signatures are collected
let status = try await DocumentSigningService.getSignatureStatus(
    documentId: upload.documentId
)

guard status.totalSignatures == 3 else {
    throw SigningError.incompleteSignatures
}

// 5. Finalize
let finalized = try await DocumentSigningService.finalizeDocument(
    documentId: upload.documentId,
    finalizedBy: "did:persona:attorney@lawfirm",
    signatureEntryIDs: [
        attorneySig.ledgerEntryID,
        clientSig.ledgerEntryID,
        witnessSig.ledgerEntryID
    ]
)

print("✅ Contract finalized with full audit trail")
print("   Attest entry: \(finalized.ledgerAttestEntryID)")
```

## Questions?

For more details, see:
- `DocumentSigningService.swift` - Complete API implementation
- `MultiPartySigningView.swift` - Interactive example
- Server API documentation for endpoint details
