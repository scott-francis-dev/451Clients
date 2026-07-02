# Document Signing Persistence Implementation

## Summary

This document describes the implementation of persistent document signing in the app, including both **initiated signing requests** (documents you send for signing) and **pending signature requests** (documents you need to sign), plus the new **access code system** for secure document sharing.

## What Has Been Implemented

### 1. Client-Side Persistence for Initiated Requests ✅

**Location:** `InitiatedSigningStore.swift` + `SendSigningFlowView.swift`

When a user initiates a document signing request, the app now:
- Saves the document locally to `~/Documents/InitiatedSignings/documents/{uuid}/`
- Creates an index record with metadata in `~/Documents/InitiatedSignings/index.json`
- Stores participants, authors, title, and all metadata
- Persists the document UUID returned from the server
- **NEW:** Stores the access code for private documents

**This is already working!** When you submit a document through the Send tab, it's saved locally with its access code.

### 2. Access Code System ✅

**Location:** Multiple files

**New Features:**
- **Access Code Entry UI** (`AccessCodeEntryView.swift`) - Users can enter 7-digit codes (XXX-XXXX format)
- **Auto-formatting** - Automatically formats codes as users type
- **Access Code Display** - Shows codes in document detail views with copy button
- **API Integration** - `fetchDocumentByAccessCode()` method to retrieve documents by code
- **Persistence** - Access codes stored in `InitiatedSigningRecord` and `PendingDocument`

**How it works:**
1. Server generates access code when document is uploaded (private documents only)
2. Code is returned in upload response and saved locally
3. Sender can share the code via SMS, phone call, or other out-of-band means
4. Recipient enters code in "Enter Access Code" screen
5. App validates recipient's DID is authorized for the document
6. If authorized, document details are shown and can be signed

### 3. Pending Documents Retrieval ✅

**Location:** `DocumentSigningService.swift`

Added new types and methods:
- `PendingDocument` struct - Represents documents awaiting your signature (includes `accessCode` field)
- `fetchPendingDocuments(forSignerDID:)` - Fetches documents from server
- `fetchDocumentByAccessCode()` - Fetches a specific document by access code

### 4. Updated Sign Tab (DocumentListView) ✅

**Location:** `DocumentListView.swift`

The Sign tab now:
- Fetches real documents from the server on load
- Shows pending signature requests
- Displays documents you've already signed
- Falls back to test data if server doesn't respond
- Supports pull-to-refresh
- **NEW:** "Enter Code" button in header to access documents via access code
- **NEW:** Displays access codes for documents with them

### 5. New Document Signing Interface ✅

**Location:** `DocumentListView.swift` - `RealDocumentSigningView`

Created a complete signing interface that:
- Downloads and displays document details
- **NEW:** Shows access code prominently if available
- Shows existing signatures
- Allows the user to sign documents
- Displays signature status
- Creates SIGN ledger entries

### 6. Updated Detail Views ✅

**Location:** `InitiatedRequestDetailView.swift`

The initiated request detail view now:
- Displays the access code prominently
- Provides a "Copy" button to copy code to clipboard
- Shows copy confirmation feedback
- Includes format guidance (XXX-XXXX)

## Server Requirements

### ⚠️ Required Server Endpoints

#### 1. Pending Documents Endpoint

**Endpoint:** `GET /api/documents/pending-signatures?signerDID={did}`

**Response Format:**
```json
[
  {
    "id": "doc-abc123",
    "documentId": "doc-abc123",
    "title": "Employment Contract",
    "originalFilename": "contract.pdf",
    "documentHash": "sha256-...",
    "documentURL": "http://localhost:9000/binary451/privatedocuments/abc123/contract.pdf",
    "uploadedAt": "2025-10-30T12:00:00Z",
    "uploadedBy": "author.did@example.com",
    "requiredRole": "participant",
    "status": "pending",
    "ledgerProofEntryID": "entry:sha256-...",
    "accessCode": "451-7892",
    "existingSignatures": [
      {
        "did": "author.did@example.com",
        "role": "author",
        "timestamp": "2025-10-30T12:00:00Z",
        "ledgerEntryID": "entry:sha256-..."
      }
    ]
  }
]
```

**Query Parameters:**
- `signerDID` (required) - The DID of the person who needs to sign

**How to implement on the server:**

1. Query MeiliSearch for documents where:
   - The ledger contains PROOF and SIGN entries
   - The document metadata lists this DID in participants/authors/witnesses/etc.
   - No ATTEST entry exists yet (not finalized)
   - The signer hasn't already signed (no SIGN entry with their DID)

2. For each matching document:
   - Fetch the PROOF entry to get document details (including access code)
   - Fetch existing SIGN entries
   - Determine what role the signer needs to fulfill
   - Return the response in the format above

#### 2. Access Code Lookup Endpoint ✅

**Endpoint:** `GET /api/documents/by-access-code/:code?signerDID={did}`

**Response Format:** (Same as PendingDocument above)

**Path Parameters:**
- `code` (required) - The 7-digit access code (e.g., "451-7892")

**Query Parameters:**
- `signerDID` (required) - The DID of the person requesting access

**How to implement on the server:**

1. Find the PROOF ledger entry with the matching access code
2. Check if the signerDID is in the authorized list (participants, authors, witnesses, etc.)
3. If authorized:
   - Return document details with existing signatures
   - Status 200 OK
4. If not authorized:
   - Return error: "You are not authorized to access this document"
   - Status 403 Forbidden
5. If code not found:
   - Return error: "Document not found with access code"
   - Status 404 Not Found

**Security Notes:**
- Access codes are NOT encrypted (they're meant to be shareable)
- Authorization is enforced by checking the DID against the authorized signers list
- The actual document content remains encrypted/protected
- Access codes are only generated for private documents

### Alternative Endpoint Names

If you prefer a different endpoint structure, you can update line 533 in `DocumentSigningService.swift`:

```swift
var components = URLComponents(url: baseURL.appendingPathComponent("api/documents/pending-signatures"), resolvingAgainstBaseURL: false)!
```

Possible alternatives:
- `/api/documents/for-signer/{did}`
- `/api/signer/{did}/pending-documents`
- `/api/ledger/pending-signatures?signer={did}`

## How It Works Now

### Send Tab Flow (Already Working)
1. User selects document
2. User adds participants and authors
3. User submits → Document is uploaded to server
4. **Server generates access code** (for private documents) 🆕
5. **Document is saved to `InitiatedSigningStore` with access code** ✅
6. **Record appears in "Your Initiated Signing Requests" list** ✅
7. **User can view access code in detail view and copy it** 🆕

### Sign Tab Flow (Needs Server Endpoint)

**Method 1: Automatic Discovery**
1. App loads → Fetches current persona DID
2. Calls `fetchPendingDocuments(forSignerDID:)` 
3. **Needs:** Server returns documents awaiting signature ⚠️
4. User sees list of pending documents
5. User taps document → Downloads and views details
6. User taps "Sign Document" → Creates SIGN ledger entry
7. Document moves to "Signed Documents" section

**Method 2: Access Code Entry** 🆕
1. User taps "Code" button in Sign tab header
2. User enters 7-digit access code (XXX-XXXX format)
3. App calls `fetchDocumentByAccessCode(code, signerDID:)`
4. Server validates:
   - Access code exists
   - User's DID is authorized
5. If authorized → Document details shown
6. User signs → Creates SIGN ledger entry

### Sharing Documents

**Sender's perspective:**
1. Upload document with participants
2. Receive access code (e.g., "451-7892")
3. Share code via:
   - SMS/text message
   - Phone call
   - Email (if needed)
   - In-person communication
4. Participants enter code in their app to access document

**Recipient's perspective:**
1. Receive access code from sender
2. Open Sign tab in app
3. Tap "Code" button
4. Enter 7-digit code
5. View document details
6. Sign document

## Testing the Implementation

### Test Pending Documents (Once Server Endpoint Exists)

1. From one persona, send a document with another persona as participant
2. Switch to the second persona
3. Open Sign tab
4. You should see the document in "Requests for signatures"
5. Tap the document and sign it
6. Verify SIGN entry is created in ledger

### Test Initiated Requests (Already Works)

1. Open Send tab
2. Select a document
3. Add participants/authors
4. Submit
5. Check "Your Initiated Signing Requests" section
6. Tap the request to see details
7. Close and reopen app → Requests persist ✅

## Viewing Persisted Data

### Initiated Signing Requests
Location: `~/Documents/InitiatedSignings/`
- `index.json` - List of all initiated requests
- `documents/{uuid}/` - Actual document files

### Debugging in Xcode
```swift
let store = InitiatedSigningStore.shared
let records = store.load()
print("Initiated requests: \(records.count)")
records.forEach { print("- \($0.title) (\($0.documentUUID))") }
```

## Next Steps

1. **Server-side:** Implement `/api/documents/pending-signatures` endpoint
2. **Server-side:** Index ledger entries in MeiliSearch with searchable signer DIDs
3. **Test:** Send document from Persona A to Persona B
4. **Test:** Switch to Persona B and verify it appears in Sign tab
5. **Test:** Sign the document and verify SIGN entry is created
6. **Optional:** Add document preview/viewer in `RealDocumentSigningView`
7. **Optional:** Add notification system for new signature requests

## API Debugging

Enable debug logging by checking console for lines starting with:
- `[DocumentSigningService]` - Signing operations
- `[Progress]` - Upload/signing progress
- `[Submit]` - Document submission

The `fetchPendingDocuments` method includes detailed logging:
```
📥 Fetching pending documents for signer: {did}
📥 Pending documents response status: {code}
📄 Pending documents response: {json}
✅ Fetched {count} pending document(s)
```

## Code Locations

| Feature | File | Lines |
|---------|------|-------|
| Pending Documents API | `DocumentSigningService.swift` | 91-150 (types), 530-592 (fetch) |
| Sign Tab UI | `DocumentListView.swift` | 1-190 |
| Document Signing Interface | `DocumentListView.swift` | 225-415 (RealDocumentSigningView) |
| Persistence Store | `InitiatedSigningStore.swift` | All |
| Send Flow Persistence | `SendSigningFlowView.swift` | 920-990 |

## Notes

- The app gracefully falls back to test data if the server endpoint doesn't exist yet
- All signing operations create proper ledger chain entries (PROOF → SIGN → ATTEST)
- Document hashes are verified during signing
- The system supports multiple roles: author, participant, witness, notary, reviewer
