# Shared Metadata Model Strategy

## Problem

You have two apps that need to share metadata:
1. **Thesis App** - Uses `Book.swift` with `@Observable` class and `pages` array
2. **Signator Wallet** - Needs lightweight metadata for document uploads

## Solution: Three-Layer Architecture

### Layer 1: Shared Core Model (`Document451.swift`)
**Purpose**: Single source of truth that both apps can use
**Location**: Shared Swift package or file included in both targets
**Type**: `@Observable class` (matches your Book.swift pattern)

```swift
@Observable
class Document451: Codable, Identifiable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var did: String = "did:local:\(UUID().uuidString)"
    var title: String = ""
    var author: String = ""
    // ... all metadata fields ...
    var pages: [Page] = []  // Thesis uses this, Signator ignores it
}
```

**Key Features**:
- Identical to your `Book.swift` structure
- Includes all Dublin Core fields
- Has `pages` array (Thesis uses, Signator leaves empty)
- Full Codable implementation
- Observable for SwiftUI binding

### Layer 2: Transfer Format (`TransferMetadata` in Document451.swift)
**Purpose**: Lightweight struct for API communication
**Type**: Simple `struct` with all optional fields

```swift
struct TransferMetadata: Codable {
    var id: String?
    var title: String?
    var author: String?
    // ... all fields optional ...
    var signers: [SignerMetadata]?  // Signator-specific
    var fileExtension: String?      // Signator-specific
}
```

**Key Features**:
- All fields optional
- Only send what you have
- Includes Signator-specific fields (signers, fileExtension, etc.)
- Can convert to/from `Document451`

### Layer 3: App-Specific Extensions
**Thesis App**: Uses `Document451` directly (rename `Book` to `Document451`)
**Signator**: Uses `TransferMetadata` for uploads, can create `Document451` if needed

## Migration Path

### Option A: Direct Replacement (Recommended)
Replace `Book.swift` with `Document451.swift` in both apps.

**Thesis App**:
```swift
// Before
class Book: Codable { ... }

// After (just rename file and class)
// Book.swift becomes Document451.swift
typealias Book = Document451  // For backward compatibility
```

**Signator App**:
```swift
// Use TransferMetadata for uploads
let metadata = TransferMetadata(
    title: "Contract",
    author: "John Doe",
    type: "contract"
)

// Upload
try await DocumentSigningService.uploadDocument(
    documentData: data,
    originalFilename: filename,
    metadata: metadata
)
```

### Option B: Keep Both, Add Converters
Keep `Book.swift` in Thesis, use `Document451.swift` as shared format.

**Conversion**:
```swift
extension Book {
    func toDocument451() -> Document451 {
        let doc = Document451()
        doc.id = self.id
        doc.did = self.did
        doc.title = self.title
        // ... copy all fields ...
        return doc
    }
    
    static func from(_ doc: Document451) -> Book {
        let book = Book()
        book.id = doc.id
        book.did = doc.did
        // ... copy all fields ...
        return book
    }
}
```

## Recommended File Structure

### Shared Package (Ideal)
```
451Protocol (Swift Package)
├── Sources/
│   └── 451Protocol/
│       ├── Document451.swift       // Core model
│       ├── TransferMetadata.swift  // Transfer format
│       └── SignerMetadata.swift    // Signer info
```

Both apps add this package as a dependency.

### Copy-Paste Approach (Simple)
```
ThesisApp/
└── Models/
    └── Document451.swift  // Copied from shared

SignatorWallet/
└── Models/
    └── Document451.swift  // Same file, copied
```

Keep files in sync manually or with a script.

### Git Submodule Approach (Medium)
```
451-protocol-models/   // Separate repo
└── Document451.swift

ThesisApp/
└── Models/ -> ../451-protocol-models/

SignatorWallet/
└── Models/ -> ../451-protocol-models/
```

## Current State & Next Steps

### What Exists Now
- ✅ `Document451.swift` - Comprehensive shared model
- ✅ `TransferMetadata` - Lightweight transfer format
- ✅ `DocumentMetadata451.swift` - Signator-specific (can be replaced)
- ✅ `DocumentMetadataForm` - SwiftUI form model
- ✅ `DocumentMetadataEditor` - UI components

### Cleanup Steps

1. **Decide on strategy**: Option A (recommended) or Option B

2. **Update Signator to use shared model**:
   ```swift
   // Replace this type alias in Signator
   typealias DocumentMetadata451 = TransferMetadata
   ```

3. **Update Thesis to use shared model**:
   ```swift
   // Rename Book.swift to Document451.swift
   // Or add type alias
   typealias Book = Document451
   ```

4. **Update server** to accept `TransferMetadata` JSON format

5. **Remove duplicates**:
   - Clean up `WalletAPI.swift` duplicates
   - Consolidate metadata types

## Usage Examples

### Thesis App
```swift
@Observable
class BookStore {
    var books: [Document451] = []  // Or use typealias: var books: [Book]
    
    func createNew() -> Document451 {
        let doc = Document451()
        doc.title = "New Document"
        doc.format = "451"
        return doc
    }
}
```

### Signator App
```swift
// Simple upload
let metadata = TransferMetadata(
    title: "Contract",
    author: "John Doe",
    type: "contract",
    accessrights: "private"
)

try await DocumentSigningService.uploadDocument(
    documentData: pdfData,
    originalFilename: "contract.pdf",
    metadata: metadata
)

// Or convert from form
let formData = DocumentMetadataForm()
formData.title = "Contract"
formData.author = "John Doe"

let metadata = formData.toTransferMetadata()  // New method needed
```

### Server Receives
```json
{
  "title": "Contract",
  "author": "John Doe",
  "type": "contract",
  "accessrights": "private",
  "format": "451",
  "fileExtension": "pdf"
}
```

Server can create full `Document451` object with defaults for missing fields.

## Implementation Recommendation

### Immediate Action (Today)
1. Use `Document451.swift` as your shared model file
2. Keep it identical in both apps (copy or package)
3. Update Signator's `DocumentMetadataForm` to output `TransferMetadata`
4. Update Thesis's `Book` to be a typealias of `Document451`

### Code Changes Needed

**In Signator** (`DocumentMetadataForm`):
```swift
@Observable
class DocumentMetadataForm {
    // ... existing fields ...
    
    func toTransferMetadata() -> TransferMetadata {
        var metadata = TransferMetadata()
        if !title.isEmpty { metadata.title = title }
        if !author.isEmpty { metadata.author = author }
        // ... set other fields ...
        return metadata
    }
}
```

**In DocumentSigningService**:
```swift
// Already done - accepts TransferMetadata
static func uploadDocument(
    documentData: Data,
    originalFilename: String?,
    metadata: TransferMetadata? = nil
) async throws -> UploadResponse
```

**In Thesis** (`Book.swift`):
```swift
// Option 1: Rename to Document451.swift and keep class name
class Document451: Codable, Identifiable { ... }
typealias Book = Document451  // For backward compatibility

// Option 2: Keep Book.swift, add conformance
extension Book {
    func toTransferMetadata() -> TransferMetadata {
        // Convert Book to TransferMetadata for API calls
    }
}
```

## Benefits

✅ **Single source of truth** for metadata structure
✅ **Type-safe** sharing between apps
✅ **Flexible** - Thesis uses full model, Signator uses lightweight transfer
✅ **Backward compatible** - Use typealiases during migration
✅ **Server-friendly** - TransferMetadata is clean JSON
✅ **Future-proof** - Easy to extend with new fields

## File Checklist

- [ ] `Document451.swift` - Shared core model (already created)
- [ ] `TransferMetadata` - Transfer format (already in Document451.swift)
- [ ] Update `DocumentMetadataForm.toMetadata()` to `toTransferMetadata()`
- [ ] Update Thesis `Book.swift` to use or extend `Document451`
- [ ] Remove old `DocumentMetadata451` nested struct definitions
- [ ] Clean up `WalletAPI.swift` duplicates
- [ ] Update server to handle `TransferMetadata` JSON
- [ ] Update documentation

---

**Bottom Line**: Use `Document451.swift` as your shared file. It's already structured exactly like your `Book.swift`, so the migration is straightforward. Signator uploads using `TransferMetadata`, Thesis uses full `Document451` class.
