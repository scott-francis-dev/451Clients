# Handling Optional Metadata: Thesis vs. Signator

## The Key Difference

### Thesis App
- **Use Case**: Creating new documents from scratch
- **Metadata**: Rich, comprehensive, user-authored
- **Model**: `Document451` class (Observable, all fields available)
- **Reality**: User controls all metadata because they're creating the content

### Signator App  
- **Use Case**: Uploading existing binary documents (PDFs, DOCX, etc.)
- **Metadata**: Sparse, mostly unknown, file-based
- **Model**: `SignatorUploadMetadata` → `TransferMetadata` (all optional)
- **Reality**: User may only know filename and type

## Solution: TransferMetadata is Already Perfect

The `TransferMetadata` struct we created is **already designed for this**:

```swift
struct TransferMetadata: Codable {
    var id: String?
    var did: String?
    var title: String?          // ← OPTIONAL
    var subtitle: String?       // ← OPTIONAL
    var description: String?    // ← OPTIONAL
    var author: String?         // ← OPTIONAL
    // ... ALL fields optional
}
```

**All fields are optional** - exactly what Signator needs!

## Three-Tier Approach

### Tier 1: Automatic (Always Present)
Extracted from the file itself - **no user input needed**:
```swift
let metadata = SignatorUploadMetadata.from(fileURL: url, data: data)
// Sets: filename, mimeType, fileSize, documentHash
```

### Tier 2: Basic (Quick Dialog)
Ask user 3 simple questions - **30 seconds max**:
```swift
- Title: [contract.pdf    ] // Pre-filled with filename
- Type:  [Contract     ▼  ] // Dropdown with suggestions
- Access:[Private      ▼  ] // Default to private
```

### Tier 3: Full (Advanced Optional)
Show complete metadata editor - **only if user wants it**:
```swift
Button("More Details...") {
    // Show DocumentMetadataEditor
    // All 20+ fields available
}
```

## Code Structure

```
Document451.swift                 # Shared model (both apps)
├── Document451 class             # Thesis uses this
└── TransferMetadata struct       # Signator uses this

SignatorUploadMetadata.swift      # Signator-specific helper
├── Tier 1: Auto fields           # filename, mimeType, size, hash
├── Tier 2: Basic fields          # title, type, access
├── Tier 3: Full metadata         # optional DocumentMetadataForm
└── toTransferMetadata()          # Converts to upload format

DocumentMetadataForm              # UI binding (optional)
└── toTransferMetadata()          # For advanced users
```

## Usage in Signator

### Scenario 1: Quick Upload (Most Common)
```swift
// User picks file
let url = pickedFileURL
let data = try Data(contentsOf: url)

// Auto-extract metadata
var uploadMeta = SignatorUploadMetadata.from(fileURL: url, data: data)
// ✓ filename: "contract.pdf"
// ✓ mimeType: "application/pdf"
// ✓ fileSize: 524288
// ✓ hash: "abc123..."
// ✓ title: "contract" (suggested from filename)
// ✓ type: "contract" (guessed from filename pattern)
// ✓ access: "private" (default)

// Upload immediately
let metadata = uploadMeta.toTransferMetadata()
try await DocumentSigningService.uploadDocument(
    documentData: data,
    originalFilename: uploadMeta.filename,
    metadata: metadata
)
```

**Server receives**:
```json
{
  "title": "contract",
  "type": "contract",
  "accessrights": "private",
  "fileExtension": "pdf",
  "mimeType": "application/pdf",
  "fileSize": 524288,
  "documentHash": "abc123...",
  "format": "451"
}
```

All other fields are `null` or missing - **and that's perfectly fine!**

### Scenario 2: User Edits Basic Info
```swift
// Show quick dialog
QuickMetadataDialog(uploadMetadata: uploadMeta) { edited in
    // User changed:
    edited.title = "Employment Contract"
    edited.documentType = "contract"
    edited.accessLevel = "confidential"
    
    let metadata = edited.toTransferMetadata()
    uploadDocument(data, metadata)
}
```

### Scenario 3: Power User Adds Full Metadata
```swift
// User taps "More Details"
DocumentMetadataEditor(metadata: $metadataForm)

// User fills:
metadataForm.title = "Employment Contract"
metadataForm.author = "John Doe"
metadataForm.description = "Standard employment agreement..."
metadataForm.type = "contract"
metadataForm.publicationDate = "2026-01-23"

// Convert and upload
uploadMeta.fullMetadata = metadataForm.toTransferMetadata()
let metadata = uploadMeta.toTransferMetadata()
uploadDocument(data, metadata)
```

## Server Handling

Server receives `TransferMetadata` and creates `Document451`:

```typescript
function createDocumentFromUpload(
  data: Buffer, 
  metadata: TransferMetadata
): Document451 {
  const doc = new Document451();
  
  // Required fields (we generate these)
  doc.id = generateUUID();
  doc.did = `did:451:${metadata.documentHash}`;
  doc.format = "451";
  
  // File metadata (always present from Signator)
  doc.fileExtension = metadata.fileExtension || "";
  doc.mimeType = metadata.mimeType || "application/octet-stream";
  doc.fileSize = metadata.fileSize || 0;
  doc.documentHash = metadata.documentHash || "";
  
  // User metadata (may be missing - use defaults)
  doc.title = metadata.title || `Document ${doc.id.substring(0,8)}`;
  doc.type = metadata.type || "document";
  doc.accessrights = metadata.accessrights || "private";
  
  // Optional fields (leave empty if not provided)
  doc.author = metadata.author || "";
  doc.description = metadata.description || "";
  doc.subtitle = metadata.subtitle || "";
  // ... etc, all default to empty string
  
  // Thesis-specific fields
  doc.pages = [];  // Empty for Signator uploads
  
  return doc;
}
```

**Key principle**: Missing fields get sensible defaults, never fail.

## Comparison Table

| Field | Thesis | Signator External Doc |
|-------|--------|----------------------|
| **id** | Generated | Generated (server) |
| **did** | `did:local:...` | `did:451:hash...` |
| **title** | User creates | Filename or user edits |
| **author** | User enters | Often empty |
| **description** | User writes | Usually empty |
| **type** | User selects | Guessed or selected |
| **pages** | Rich content | Empty (N/A) |
| **fileExtension** | N/A | Always present |
| **mimeType** | N/A | Always present |
| **fileSize** | N/A | Always present |
| **documentHash** | Computed | Always present |

## Key Takeaways

1. ✅ **All fields optional** - `TransferMetadata` is already designed for this
2. ✅ **Signator-specific helper** - `SignatorUploadMetadata` handles the complexity
3. ✅ **Three-tier UX** - Auto → Basic → Full (progressive disclosure)
4. ✅ **Smart defaults** - Guess type from filename, default to private
5. ✅ **Server tolerant** - Handles missing fields gracefully
6. ✅ **Shared model** - Both apps use same `Document451` storage format
7. ✅ **No breaking changes** - Existing uploads without metadata still work

## Files to Use

- ✅ `Document451.swift` - Shared between apps
- ✅ `TransferMetadata` - Upload format (all optional)
- ✅ `SignatorUploadMetadata.swift` - Signator helper (NEW)
- ✅ `DocumentMetadataForm` - Optional advanced editor
- ✅ `EXTERNAL_DOCUMENT_METADATA.md` - Complete guide

**Bottom line**: Your external document uploads will work perfectly with minimal metadata. The system is designed to handle everything from "just the filename" to "full scholarly metadata" - whatever the user provides.
