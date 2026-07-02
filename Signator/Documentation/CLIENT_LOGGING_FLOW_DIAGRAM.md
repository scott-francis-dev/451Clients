# Client-Server Document Upload Flow

## Successful Upload Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                          CLIENT SIDE                                 │
└─────────────────────────────────────────────────────────────────────┘

User Action: Selects document and taps Submit
                 │
                 ▼
┌────────────────────────────────────────────────────────────────────┐
│ DocumentSubmissionView                                             │
│                                                                    │
│ 📝 [Submit] Document URL: .../nda-confidentiality.pdf            │
│ 📝 [Submit] Document size: 148173 bytes                          │
│ 📝 [Submit] Embedded XMP metadata into PDF                       │
│ 📝 [Submit] Using persona: john-grubner — DID: did:451:qn9n...  │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────────┐
│ DocumentSigningService.uploadDocument()                            │
│                                                                    │
│ 📝 [ DEBUG ] 🚀 Starting workflow with SSE progress tracking      │
│ 📝 [Progress] [10.00%] Uploading document...                      │
│ 📝 [ DEBUG ] 📤 Uploading document: doc-0e0fcba3-...              │
│ 📝 [ DEBUG ]    Author DID: did:451:qn9nhu6rncquict7             │
│ 📝 [ DEBUG ]    Size: 192038 bytes                                │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
        HTTP PUT /api/document/draft/{docId}/content
        Headers:
          X-Document-Id: doc-0e0fcba3-...
          X-Author-DID: did:451:qn9n...
          X-Original-Filename: nda-confidentiality.pdf
          Content-Type: application/octet-stream
        Body: [PDF bytes]
                 │
                 │

════════════════════════════════════════════════════════════════════════
                            NETWORK BOUNDARY
════════════════════════════════════════════════════════════════════════

                 │
                 ▼

┌─────────────────────────────────────────────────────────────────────┐
│                          SERVER SIDE                                 │
└─────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│ DocumentController receives PUT request                            │
│                                                                    │
│ 🖥️ [ INFO ] [UPLOAD] Starting document upload                     │
│ 🖥️ [ INFO ] Document ID: doc-0e0fcba3-...                         │
│ 🖥️ [ INFO ] Author DID: did:451:qn9n...                           │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────────┐
│ Upload to S3 Providers (Backblaze B2 + Cloudflare R2)             │
│                                                                    │
│ 🖥️ 🔄 Uploading binary451/privatedocuments/.../document.pdf       │
│ 🖥️ ✅ Upload successful for B2                                     │
│ 🖥️ ✅ Upload successful for R2                                     │
│ 🖥️ ✅ Document uploaded to 2 provider(s)                           │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────────┐
│ Upload Metadata (DID Document + Document Metadata)                │
│                                                                    │
│ 🖥️ 🔄 Uploading DIDDocument.json                                   │
│ 🖥️ ✅ DID document uploaded to 2 provider(s)                       │
│ 🖥️ 🔄 Uploading DocumentMetadata.json                              │
│ 🖥️ ✅ Document metadata uploaded to 2 provider(s)                  │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────────┐
│ Calculate Document Hash                                           │
│                                                                    │
│ 🖥️🔐 [UPLOAD] Calculating document hash...                        │
│ 🖥️   Hash: ea89e919cc891b5f7863582276b08f48f9d008a3...           │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────────┐
│ Create Blockchain Entry                                            │
│                                                                    │
│ 🖥️⛓️  [BLOCKCHAIN] Creating blockchain entry                       │
│ 🖥️ 📊 Current blockchain index: 31                                 │
│ 🖥️ 🔢 Etcd assigned index: 32                                      │
│ 🖥️ ✅ Block #32 created and cached                                 │
│ 🖥️ 🔍 Indexing block #32 in Meilisearch                            │
│ 🖥️ ✅ Block #32 indexed                                            │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────────┐
│ Ledger Service (Optional)                                          │
│                                                                    │
│ 🖥️ℹ️ [LEDGER] Skipping PROOF entry build/sign/store because      │
│   LedgerService does not expose required APIs in this build       │
│                                                                    │
│   ⚠️ This is OK! Document is still uploaded successfully.         │
│   The ledger is an additional audit layer, not required.          │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────────┐
│ Prepare Response                                                   │
│                                                                    │
│ 🖥️ 📊 [UPLOAD] Preparing response...                              │
│ 🖥️ ✅ [UPLOAD] Document upload completed successfully!            │
│    Document ID: doc-0e0fcba3-...                                  │
│    Files uploaded: Document, DID, Metadata                        │
│    Blockchain block created: Yes                                  │
│    Ledger entry: No (service not available)                       │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
        HTTP 200 Response
        Body:
        {
          "success": true,
          "documentHash": "ea89e919...",
          "taskId": "AABFF53B-...",
          "documentURL": "https://s3.../document.pdf",
          "documentId": "doc-0e0fcba3-...",
          "uploaded": true,
          "draftId": "doc-0e0fcba3-...",
          "folder": "binary451/privatedocuments",
          "didDocumentURL": ".../DIDDocument.json",
          "metadataURL": ".../DocumentMetadata.json"
          
          // ⚠️ Note: No ledgerProofEntryID when ledger unavailable
          // Client handles this gracefully (it's optional)
        }
                 │
                 │

════════════════════════════════════════════════════════════════════════
                            NETWORK BOUNDARY
════════════════════════════════════════════════════════════════════════

                 │
                 ▼

┌─────────────────────────────────────────────────────────────────────┐
│                          CLIENT SIDE                                 │
└─────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│ DocumentSigningService receives response                           │
│                                                                    │
│ 📝 [ DEBUG ] 📥 Upload response status: 200                        │
│ 📝 [ DEBUG ]    Response data size: 660 bytes                      │
│ 📝 [ DEBUG ] 📄 Upload response body:                              │
│    {"success":true,"documentHash":"ea89e919...","taskId":...}     │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────────┐
│ Decode UploadResponse (with optional ledgerProofEntryID)          │
│                                                                    │
│ 📝 [ DEBUG ] ✅ Document uploaded successfully                     │
│ 📝 [ DEBUG ]    Document ID: doc-0e0fcba3-...                     │
│ 📝 [ DEBUG ]    Document Hash: ea89e919...                        │
│ 📝 [ DEBUG ]    Task ID: AABFF53B-... (SSE progress available)    │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────────┐
│ UI Update                                                          │
│                                                                    │
│ ✅ Success sheet shown to user                                     │
│ ✅ Document appears in "My Documents"                              │
│ ✅ Signing workflow can proceed                                    │
└────────────────────────────────────────────────────────────────────┘
```

## Key Points

### What Gets Created on Server
- ✅ **S3 Storage**: Document file uploaded to 2 providers (Backblaze B2 + Cloudflare R2)
- ✅ **Metadata**: DID document and document metadata uploaded
- ✅ **Document Hash**: SHA-256 hash calculated
- ✅ **Blockchain Entry**: Block created and indexed in Meilisearch
- ⚠️ **Ledger Entry**: Optional - only created if LedgerService is available

### What Client Expects
- ✅ **documentId**: Always required
- ✅ **documentHash**: Always required
- ⚠️ **ledgerProofEntryID**: Optional (gracefully handles absence)
- ⚠️ **taskId**: Optional (for SSE progress tracking)

### Success Criteria
A document upload is **successful** even without the ledger proof entry because:
1. Document is safely stored in redundant S3 providers ✅
2. Blockchain entry provides immutable audit trail ✅
3. Document hash ensures integrity ✅
4. Ledger is an **additional layer** of verification, not required for core functionality

## Error Scenarios

### Before the Fix (ledgerProofEntryID was required)
```
Server: ✅ Upload successful (but no ledger entry)
        ↓
Client: ❌ Decode failed: keyNotFound("ledgerProofEntryID")
        ↓
User:   ❌ Sees error message
        ❌ Document appears "lost"
```

### After the Fix (ledgerProofEntryID is optional)
```
Server: ✅ Upload successful (but no ledger entry)
        ↓
Client: ✅ Decode successful (handles optional field)
        ↓
User:   ✅ Sees success message
        ✅ Document appears in UI
        ℹ️ (Warning logged for developers)
```

## Timeline View

```
Time    Client                          Server
─────   ──────────────────────────────  ──────────────────────────────
00:00   User selects document
00:01   Embed XMP metadata
00:02   Start upload (192KB)           
00:03   Send PUT request               → Receive upload request
00:04                                    Upload to B2 (start)
00:05                                    Upload to R2 (start)
00:06                                  ✅ B2 upload complete
00:07                                  ✅ R2 upload complete
00:08                                    Upload DID document
00:09                                    Upload metadata
00:10                                    Calculate hash
00:11                                    Create blockchain block #32
00:12                                    Index in Meilisearch
00:13                                    Skip ledger (not available)
00:14                                    Prepare response
00:15                                  ← Return 200 OK + JSON
00:16   Receive 200 response
00:17   Decode response ✅
00:18   Show success to user
00:19   Update UI with document
─────   ──────────────────────────────  ──────────────────────────────
```

## Troubleshooting Guide

### Issue: Upload succeeds but client shows error

**Check client logs for:**
```
❌ Failed to decode upload response: keyNotFound(...)
```

**Solution:** Make sure `ledgerProofEntryID` is optional in `UploadResponse`

### Issue: Server returns 500 "Failed to upload to any S3 provider"

**Check server environment:**
- AWS_ACCESS_KEY_ID configured?
- AWS_SECRET_ACCESS_KEY configured?
- S3 bucket exists?
- Network can reach S3 endpoints?

**Solution:** Configure S3 credentials or use local storage for development

### Issue: Ledger entries not created

**Check server logs for:**
```
ℹ️ [LEDGER] Skipping PROOF entry build/sign/store...
```

**This is expected** when LedgerService is not deployed. To enable:
1. Deploy LedgerService
2. Configure service endpoints
3. Server will automatically create ledger entries

---

**This flow works correctly even without the ledger service!**



```
┌─────────────────────────────────────────────────────────────────────┐
│                          CLIENT SIDE                                 │
└─────────────────────────────────────────────────────────────────────┘

User Action: Taps Refresh Button
                 │
                 ▼
┌────────────────────────────────────────────────────────────────────┐
│ SignRequestsView.loadPendingDocuments()                            │
│                                                                    │
│ 📝 [ INFO ] Starting loadPendingDocuments()                       │
│ 📝 [ INFO ] Found 3 persona(s)                                    │
│ 📝 [ DEBUG ] Persona[0]: alice@example.com                        │
│ 📝 [ DEBUG ] Persona[1]: bob@example.com                          │
│ 📝 [ DEBUG ] Persona[2]: charlie@example.com                      │
│ 📝 [ INFO ] Calling DocumentSigningService.fetchAllPendingDocuments() │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────────┐
│ DocumentSigningService.fetchAllPendingDocuments()                  │
│                                                                    │
│ 📝 [ DEBUG ] 📥 Fetching pending documents for 3 persona(s)       │
│ 📝 [ DEBUG ] 🔄 Task started for DID: alice@example.com           │
│ 📝 [ DEBUG ] 🔄 Task started for DID: bob@example.com             │
│ 📝 [ DEBUG ] 🔄 Task started for DID: charlie@example.com         │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ├─────────────────────────────────────────┐
                 │                                         │
                 ▼                                         ▼
┌──────────────────────────────────┐   ┌──────────────────────────────────┐
│ Task 1: alice@example.com        │   │ Task 2: bob@example.com          │
│                                  │   │                                  │
│ 📝 [ DEBUG ] Fetching for alice  │   │ 📝 [ DEBUG ] Fetching for bob    │
│ 📝 [ DEBUG ] URL: /api/...       │   │ 📝 [ DEBUG ] URL: /api/...       │
└──────────────────────────────────┘   └──────────────────────────────────┘
                 │                                         │
                 │                                         │
                 ▼                                         ▼
        HTTP GET Request                          HTTP GET Request
        (with request-id)                         (with request-id)
                 │                                         │
                 │                                         │

════════════════════════════════════════════════════════════════════════
                            NETWORK BOUNDARY
════════════════════════════════════════════════════════════════════════

                 │                                         │
                 ▼                                         ▼

┌─────────────────────────────────────────────────────────────────────┐
│                          SERVER SIDE                                 │
└─────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│ Server receives requests                                           │
│                                                                    │
│ 🖥️ [ INFO ] GET /api/documents/pending-signatures                 │
│ 🖥️ [ INFO ] [request-id: ABC123] Using legacy 'signerDID' param   │
│ 🖥️ [ INFO ] [request-id: ABC123] Searching for: alice@example.com │
│ 🖥️ [ INFO ] [request-id: ABC123] Querying for persona: alice...   │
│ 🖥️ [ INFO ] [request-id: ABC123] ✅ Returning 2 documents         │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
        HTTP Response with JSON
                 │
                 │

════════════════════════════════════════════════════════════════════════
                            NETWORK BOUNDARY
════════════════════════════════════════════════════════════════════════

                 │
                 ▼

┌─────────────────────────────────────────────────────────────────────┐
│                          CLIENT SIDE                                 │
└─────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│ Task 1 completes                                                   │
│                                                                    │
│ 📝 [ DEBUG ] Response status: 200                                  │
│ 📝 [ DEBUG ] Response body: { "documents": [...] }                 │
│ 📝 [ INFO ] ✅ Fetched 2 pending document(s) for alice             │
│ 📝 [ DEBUG ] ✅ Task completed for alice with 2 document(s)        │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ├─────────────────────────────────────────┐
                 │                                         │
                 ▼                                         ▼
         Collect Results                          All Tasks Complete
                 │                                         │
                 └────────────────┬────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│ DocumentSigningService returns to SignRequestsView                 │
│                                                                    │
│ 📝 [ DEBUG ] 📦 Collecting results for DID: alice@example.com      │
│ 📝 [ DEBUG ] 📦 Collecting results for DID: bob@example.com        │
│ 📝 [ DEBUG ] 📦 Collecting results for DID: charlie@example.com    │
│ 📝 [ DEBUG ] ✅ Returning 5 total pending document(s)              │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────────┐
│ SignRequestsView processes results                                 │
│                                                                    │
│ 📝 [ INFO ] ✅ Received 5 pending document(s) from service         │
│ 📝 [ DEBUG ] Document[0]: 'Contract.pdf' - Status: pending        │
│ 📝 [ DEBUG ] Document[1]: 'Agreement.pdf' - Status: signed        │
│ 📝 [ DEBUG ] Document[2]: 'Invoice.pdf' - Status: pending         │
│ 📝 [ DEBUG ] Document[3]: 'NDA.pdf' - Status: pending             │
│ 📝 [ DEBUG ] Document[4]: 'License.pdf' - Status: finalized       │
│ 📝 [ INFO ] ✅ Updated UI with 5 request(s)                        │
│ 📝 [ INFO ] Status: 3 pending, 1 signed, 1 finalized              │
│ 📝 [ INFO ] Finished loadPendingDocuments()                        │
└────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
             UI Updates
       (User sees 5 documents)
```

## Log Correlation Example

### Finding a Specific Request Across Client and Server

**Client logs:**
```
[ INFO ] [SignRequestsView] [request-id: A2FC6EBC-585C] Starting loadPendingDocuments()
[ DEBUG ] [SignRequestsView] [request-id: A2FC6EBC-585C] Persona[0]: alice@example.com
[ DEBUG ] [DocumentSigningService] 📥 Fetching pending documents for signer: alice@example.com
```

**Server logs:**
```
[ INFO ] GET /api/documents/pending-signatures [request-id: 87690075-B060]
[ INFO ] [ROUTE] GET /api/documents/pending-signatures [request-id: 87690075-B060]
[ INFO ] [PENDING SIGNATURES] Searching for: alice@example.com [request-id: 87690075-B060]
[ INFO ] [PENDING SIGNATURES] ✅ Returning 2 documents [request-id: 87690075-B060]
```

**Back to client:**
```
[ DEBUG ] [DocumentSigningService] 📥 Pending documents response status: 200
[ INFO ] [DocumentSigningService] ✅ Fetched 2 pending document(s) for alice@example.com
[ INFO ] [SignRequestsView] [request-id: A2FC6EBC-585C] ✅ Received 2 document(s)
[ INFO ] [SignRequestsView] [request-id: A2FC6EBC-585C] ✅ Updated UI with 2 request(s)
```

## Log Levels at Each Layer

```
┌─────────────────────────────────────────────────────────────────────┐
│                        LOGGING PYRAMID                               │
└─────────────────────────────────────────────────────────────────────┘

                              ERROR
                          ▲ ▲ ▲ ▲ ▲
                         /           \
                        /   WARNING   \
                       /   ▲ ▲ ▲ ▲ ▲   \
                      /   /           \   \
                     /   /     INFO    \   \
                    /   /   ▲ ▲ ▲ ▲ ▲   \   \
                   /   /   /           \   \   \
                  /   /   /    DEBUG    \   \   \
                 /_  /_  /_  ▲ ▲ ▲ ▲ ▲  _\  _\  _\
                ═══════════════════════════════════

DEBUG:   Detailed flow, variable values, internal state
INFO:    Major operations start/end, counts, success confirmations
WARNING: Unusual conditions, retries, deprecated API usage
ERROR:   Failures, exceptions, validation errors
```

## Component Interaction Map

```
┌──────────────────────┐
│   SignRequestsView   │  📝 INFO: User actions, UI updates
└──────────┬───────────┘     📝 DEBUG: Persona lists, document details
           │
           │ calls
           ▼
┌──────────────────────┐
│ DocumentSigningService│ 📝 INFO: API calls, responses
└──────────┬───────────┘     📝 DEBUG: URLs, payloads, status codes
           │
           │ uses
           ▼
┌──────────────────────┐
│    URLSession        │  (System framework - no custom logging)
└──────────┬───────────┘
           │
           │ network
           ▼
┌──────────────────────┐
│       Server         │  🖥️ INFO: Routes, queries, results
└──────────────────────┘     🖥️ WARNING: Missing indexes, retries
                              🖥️ ERROR: Database failures, auth errors
```

## Key Correlation Points

1. **Client Request ID** ➡️ **Multiple Server Request IDs**
   - One client operation spawns multiple concurrent server requests
   - Use personas DIDs and timestamps to correlate

2. **Persona DID** ➡️ **Server Query Parameter**
   - Track: "Persona[N]: alice@example.com" (client)
   - Matches: "Searching for: alice@example.com" (server)

3. **Document Count** ➡️ **UI Update**
   - Track: "✅ Returning X documents" (server)
   - Matches: "✅ Received X document(s)" (client)
   - Confirms: "✅ Updated UI with X request(s)" (client)

## Timeline View

```
Time    Client                          Server
─────   ──────────────────────────      ──────────────────────────────
00:00   User taps refresh
00:01   Start loadPendingDocuments()
00:02   Found 3 personas
00:03   Call service with 3 DIDs
00:04   Task 1 starts (alice)
00:04   Task 2 starts (bob)           
00:04   Task 3 starts (charlie)
00:05   HTTP GET alice                  → Received alice request
00:05   HTTP GET bob                    → Received bob request  
00:05   HTTP GET charlie                → Received charlie request
00:06                                     Query index for alice
00:07                                     Query index for bob
00:07                                     Query index for charlie
00:08                                   ← Return alice results (2 docs)
00:08   Receive alice response (200)
00:09                                   ← Return bob results (0 docs)
00:09   Receive bob response (200)
00:10                                   ← Return charlie results (3 docs)
00:10   Receive charlie response (200)
00:11   Collect all results (5 docs)
00:12   Convert to SignRequest models
00:13   Update UI with 5 requests
00:14   UI renders 5 document cards
─────   ──────────────────────────────  ──────────────────────────────
```

## Troubleshooting Flow

```
Issue: "Client shows no documents but server says it returned some"

Step 1: Check client start
  ✓ [ INFO ] Starting loadPendingDocuments()
  
Step 2: Check personas
  ✓ [ INFO ] Found 3 persona(s)
  ✓ [ DEBUG ] Persona[0]: alice@example.com
  ? Are these the expected personas?
  
Step 3: Check service call
  ✓ [ INFO ] Calling DocumentSigningService...
  
Step 4: Check server received correct DID
  Server: [ INFO ] Searching for: alice@example.com
  ? Does this match client persona?
  
Step 5: Check server returned data
  Server: [ INFO ] ✅ Returning 2 documents
  
Step 6: Check client received data
  ✓ [ INFO ] ✅ Received 2 pending document(s)
  ? If 0, network issue. If 2, continue...
  
Step 7: Check status filtering
  ✓ [ DEBUG ] Document[0]: 'Contract.pdf' - Status: signed
  ? Status might be wrong (user expects "pending")
  
Step 8: Check UI update
  ✓ [ INFO ] ✅ Updated UI with 2 request(s)
  ✓ [ INFO ] Status: 0 pending, 2 signed, 0 finalized
  
Solution: Documents are signed, not pending!
  User is looking at wrong tab/filter.
```

This visual flow helps you understand:
- Where each log statement appears in the process
- How client and server logs correlate
- Where to look when debugging specific issues
- The timing and sequence of operations
