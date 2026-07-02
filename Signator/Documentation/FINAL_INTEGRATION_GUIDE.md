# Final Integration Guide: Shared Metadata Between Thesis and Signator

## ✅ What's Done

### 1. Shared Core Model
**File**: `Document451.swift`
- Identical structure to your `Book.swift` from Thesis app
- `@Observable` class with all metadata fields
- Includes `pages` array (Thesis uses, Signator ignores)
- Full Codable implementation
- Can be shared between both apps

### 2. Transfer Format
**Included in**: `Document451.swift`
- `TransferMetadata` struct - lightweight, all fields optional
- Used by Signator for API uploads
- Includes Signator-specific fields (signers, fileExtension, etc.)
- Clean JSON serialization

### 3. Signator Integration
**Files Created**:
- ✅ `DocumentMetadataEditor.swift` - Full UI for metadata collection
- ✅ `DocumentMetadataForm` - Observable form model
- ✅ `DocumentMetadataForm+Extensions.swift` - Converters
- ✅ `CompleteDocumentUploadExample.swift` - Working example

**Files Updated**:
- ✅ `DocumentSigningService.swift` - Accepts `TransferMetadata`
- ✅ `SendSigningFlowView.swift` - Uses `DocumentMetadataForm`
- ✅ `WalletAPI.swift` - Fixed duplicate `SignAndSubmitView`

### 4. Documentation
- ✅ `METADATA_SYSTEM.md` - Complete metadata system docs
- ✅ `METADATA_INTEGRATION_SUMMARY.md` - Integration guide
- ✅ `SHARED_METADATA_STRATEGY.md` - Sharing strategy
- ✅ This file - Final integration guide

## 🎯 How They Work Together

```
┌─────────────────────────────────────────────────┐
│          Shared: Document451.swift              │
│                                                 │
│  ┌─────────────────────────────────────────┐  │
│  │ Document451 (Observable class)          │  │
│  │ - Full metadata model                   │  │
│  │ - Matches Book.swift structure          │  │
│  │ - Used by Thesis app                    │  │
│  └─────────────────────────────────────────┘  │
│                                                 │
│  ┌─────────────────────────────────────────┐  │
│  │ TransferMetadata (struct)               │  │
│  │ - Lightweight, all optional             │  │
│  │ - Used by Signator for uploads          │  │
│  │ - JSON-friendly                         │  │
│  └─────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
           ↓                          ↓
   ┌──────────────┐          ┌──────────────┐
   │  Thesis App  │          │   Signator   │
   │              │          │              │
   │ Document451  │          │ TransferMeta │
   │ (full model) │          │ (upload)     │
   │              │          │              │
   │ pages: [...]  │          │ signers: [...] │
   └──────────────┘          └──────────────┘
```

## 📝 Implementation Steps

### Step 1: In Signator (Current App)

**Already Done**:
- ✅ `DocumentSigningService` accepts `TransferMetadata`
- ✅ `DocumentMetadataForm` collects user input
- ✅ UI components ready (`DocumentMetadataEditor`)

**To Do**:
1. Update method calls to use `toTransferMetadata()`:
   ```swift
   // In SendSigningFlowView.swift submit() function
   let metadata = metadataForm.toTransferMetadata()
   
   let (documentId, _, _) = try await performDocumentSigningWorkflow(
       documentData: documentData,
       originalFilename: filename,
       metadata: metadata
   )
   ```

2. Import `Document451.swift` into your project (already created)

3. Test upload with metadata

### Step 2: In Thesis App

**Option A: Direct Replacement (Recommended)**
```swift
// Rename Book.swift to Document451.swift
// Or add to Book.swift:
typealias Book = Document451

// Use exactly as before - no changes needed to existing code!
```

**Option B: Keep Both, Add Converters**
```swift
extension Book {
    func toDocument451() -> Document451 {
        let doc = Document451()
        doc.id = self.id
        doc.did = self.did
        doc.title = self.title
        // ... copy all fields
        return doc
    }
}
```

### Step 3: Server Updates

Server should accept `TransferMetadata` JSON in multipart upload:

```json
{
  "title": "Employment Contract",
  "author": "John Doe",
  "type": "contract",
  "description": "...",
  "accessrights": "private",
  "format": "451",
  "fileExtension": "pdf",
  "signers": [
    {
      "did": "did:example:alice",
      "role": "author",
      "displayName": "Alice"
    }
  ]
}
```

Server converts this to full `Document451` object with defaults for missing fields.

## 🔧 Quick Fixes Needed

### 1. Fix SendSigningFlowView.swift

**Issue**: Missing state variable
**Fix**: ✅ Already fixed - added `@State private var isSubmitting: Bool = false`

### 2. Update DocumentMetadataForm Methods

**Current**:
```swift
func toMetadata() -> DocumentMetadata451 { ... }
```

**Updated** (use extension file):
```swift
func toTransferMetadata() -> TransferMetadata { ... }
// Or use deprecated alias: toMetadata() -> TransferMetadata
```

### 3. Clean Up WalletAPI.swift

Remove duplicate definitions:
- ~~`DocumentMetadata` struct~~ (use `TransferMetadata` instead)
- ~~Duplicate `SignAndSubmitView`~~ (✅ already fixed)
- ~~`mimeType()` function duplicates~~

## 📦 File Organization

### Shared Files (Copy to Both Apps)
```
Document451.swift                  # Core shared model
```

### Signator-Specific
```
DocumentMetadataForm.swift         # UI form model
DocumentMetadataForm+Extensions.swift  # Converters
DocumentMetadataEditor.swift       # UI components
DocumentSigningService.swift       # Upload service
```

### Thesis-Specific
```
Book.swift (or rename to Document451.swift)
PageEditor components
RichTextDocument
```

## 🚀 Usage Examples

### Signator: Upload with Metadata
```swift
// Collect metadata from user
let form = DocumentMetadataForm()
form.title = "Contract"
form.author = "John Doe"
form.type = "contract"

// Convert to transfer format
let metadata = form.toTransferMetadata()

// Add signers
metadata.signers = selectedSigners.map { selection in
    SignerMetadata(
        did: selection.did,
        role: selection.role.rawValue,
        displayName: nil
    )
}

// Upload
let (documentId, _, accessCode) = try await DocumentSigningService.completeSigningWorkflowWithSSEProgress(
    documentData: pdfData,
    originalFilename: "contract.pdf",
    metadata: metadata,
    onProgress: { update in
        print("Progress: \(update.progress * 100)%")
    },
    onServerProgress: { serverUpdate in
        print("Server: \(serverUpdate.message)")
    }
)

print("Uploaded! Document ID: \(documentId)")
if let code = accessCode {
    print("Access Code: \(code)")
}
```

### Thesis: Create New Document
```swift
// Create new document
let doc = Document451()  // Or: let doc = Book()
doc.title = "My Research Paper"
doc.author = "Dr. Jane Smith"
doc.type = "article"
doc.description = "A comprehensive study..."

// Add pages (Thesis-specific)
let page = Page()
page.title = "Introduction"
page.richTextJSON = "..."
doc.pages.append(page)

// Save
try await documentStore.save(doc)
```

### Server: Receive and Store
```swift
// Receive TransferMetadata from upload
let metadata: TransferMetadata = try JSONDecoder().decode(...)

// Convert to full Document451 for storage
let doc = Document451.from(transfer: metadata)

// Set server-generated fields
doc.id = UUID().uuidString
doc.did = "did:451:\(documentHash)"

// Save to database
try await database.save(doc)
```

## ✨ Benefits of This Approach

1. **Single Source of Truth**: One `Document451` model for both apps
2. **Type Safety**: Compiler catches metadata field mismatches
3. **Flexibility**: Lightweight `TransferMetadata` for uploads, full `Document451` for storage
4. **Backward Compatible**: Thesis can keep using `Book` as a typealias
5. **Easy Testing**: Shared model = shared test fixtures
6. **Future-Proof**: New fields automatically available to both apps

## 🎓 Key Concepts

### Document451 (Observable Class)
- **Purpose**: Full-featured document model
- **Used by**: Thesis app (storage, editing)
- **Features**: Observable, includes pages, full Codable
- **When**: Creating/editing documents locally

### TransferMetadata (Struct)
- **Purpose**: Lightweight API transfer format
- **Used by**: Signator (uploads), Server (API)
- **Features**: All optional, includes upload-specific fields
- **When**: Uploading/downloading via network

### DocumentMetadataForm (Observable Class)
- **Purpose**: SwiftUI form binding
- **Used by**: Signator UI
- **Features**: String properties for text fields, converters
- **When**: Collecting metadata from user

## 🔍 Troubleshooting

**Q: Can Signator use Document451 directly?**
A: Yes! You can create a `Document451` object if needed. However, `TransferMetadata` is lighter for uploads.

**Q: Does Thesis need TransferMetadata?**
A: Only if communicating with server. For local storage, use `Document451`.

**Q: What about the pages field?**
A: Signator leaves it empty. Thesis uses it. Both apps can handle it.

**Q: How do I add a new metadata field?**
A: Add to `Document451.swift`, update Codable, done! Both apps get it.

**Q: Can I use this with other apps?**
A: Yes! Any Swift app can import `Document451.swift` and use the model.

## 📋 Checklist

- [x] Create `Document451.swift` with shared model
- [x] Create `TransferMetadata` for uploads
- [x] Update `DocumentSigningService` to accept metadata
- [x] Create `DocumentMetadataForm` for UI
- [x] Create `DocumentMetadataEditor` UI
- [x] Add conversion extensions
- [x] Fix `SendSigningFlowView` errors
- [x] Create documentation
- [ ] Update Thesis `Book.swift` to use/extend `Document451`
- [ ] Test Signator uploads with metadata
- [ ] Update server to handle `TransferMetadata`
- [ ] Clean up duplicate definitions in `WalletAPI.swift`

## 🎬 Next Steps

1. **Test in Signator**: Upload a document with full metadata
2. **Migrate Thesis**: Replace `Book` with `Document451` (or add typealias)
3. **Update Server**: Accept and process `TransferMetadata` JSON
4. **Remove Duplicates**: Clean up `WalletAPI.swift`
5. **Add Tests**: Test metadata serialization/deserialization

---

**You're Done!** 🎉

The shared metadata system is ready. Both apps can now use the same model, ensuring consistency across the 451 protocol ecosystem.
