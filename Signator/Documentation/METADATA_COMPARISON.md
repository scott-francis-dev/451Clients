# Document Metadata: Separate vs. Embedded

## TL;DR

**❌ WRONG (What you had):**
```
Upload Request:
├─ document.pdf (binary)
└─ metadata.json (separate file)
```

**✅ RIGHT (What you should have):**
```
Upload Request:
└─ document.pdf (binary with embedded metadata)
```

## Why Embedded Metadata is Correct

### The Industry Standard

Every professional document format embeds metadata:

| Format | Standard |
|--------|----------|
| PDF | XMP + PDF Info Dictionary |
| JPEG/PNG | EXIF + XMP |
| Office Docs | Office Open XML metadata |
| JSON | Top-level metadata object |
| Markdown | YAML/JSON frontmatter |
| HTML | `<meta>` tags + JSON-LD |

### Real-World Examples

**Adobe PDF:**
```bash
# View PDF metadata
mdls document.pdf
# Shows: Author, Title, Keywords, etc.
```

**Image Files:**
```bash
# View photo metadata
exiftool photo.jpg
# Shows: Camera, GPS, Author, Copyright, etc.
```

**Office Documents:**
```bash
# Word doc metadata
unzip document.docx
cat docProps/core.xml
# Shows: Author, Title, Subject, etc.
```

All of these have metadata **embedded in the file itself**.

## What You Were Doing (Incorrect)

```swift
// Old approach: Separate metadata
let documentData = loadFile()
let metadata = createMetadata()

// Upload as multipart with two pieces
uploadMultipart(
    parts: [
        ("document", documentData),
        ("metadata", metadataJSON)  // ← SEPARATE
    ]
)
```

**Problems:**
1. Download just the file → lose all metadata
2. Two objects to manage on server
3. Can become desynchronized
4. Not how standard tools work
5. Not portable across systems

## What You Should Do (Correct)

```swift
// New approach: Embedded metadata
let documentData = loadFile()
let metadata = createMetadata()

// EMBED metadata into the document
let documentWithMetadata = DocumentMetadataEmbedder.embed(
    metadata: metadata,
    into: documentData,
    filename: "document.pdf"
)

// Upload single self-contained document
upload(documentWithMetadata)
```

**Benefits:**
1. ✅ File is self-contained
2. ✅ Portable across systems
3. ✅ Single object to manage
4. ✅ Standard tools can read it
5. ✅ Works offline
6. ✅ Can verify integrity

## How to Fix Your Code

### Step 1: Use the Embedder

```swift
import PDFKit
import Foundation

// Create your metadata
var metadata = DocumentMetadata451()
metadata.title = "Sales Contract"
metadata.author = "John Doe"
metadata.documentHash = "sha256:abc123..."

// Load document
let pdfData = try Data(contentsOf: pdfURL)

// EMBED metadata
let pdfWithMetadata = try DocumentMetadataEmbedder.embed(
    metadata: metadata,
    into: pdfData,
    filename: "contract.pdf"
)
```

### Step 2: Upload the Enhanced Document

```swift
// Upload (no separate metadata!)
let response = try await DocumentSigningService.uploadDocument(
    documentData: pdfWithMetadata,  // ← Has embedded metadata
    originalFilename: "contract.pdf",
    metadata: nil,  // ← No separate metadata needed
    useEmbeddedMetadata: true
)
```

### Step 3: Server Extracts Metadata

```typescript
// Server receives the document
app.post('/api/document/publish', async (req, res) => {
  const documentData = req.body;
  const filename = req.headers['x-original-filename'];
  
  // Extract metadata FROM the document
  const metadata = extractMetadata(documentData, filename);
  
  // Store just the document (metadata is in it)
  const id = await storage.save(documentData);
  
  res.json({ documentId: id, metadata });
});
```

## Migration Path

Your updated `DocumentSigningService` now supports both:

```swift
// ✅ NEW: Embedded metadata (recommended)
await uploadDocument(
    documentData: documentWithEmbeddedMetadata,
    originalFilename: "doc.pdf",
    metadata: nil,
    useEmbeddedMetadata: true  // ← Default
)

// ⚠️ OLD: Separate metadata (still works, but deprecated)
await uploadDocument(
    documentData: rawDocument,
    originalFilename: "doc.pdf",
    metadata: separateMetadata,
    useEmbeddedMetadata: false
)
```

## Quick Reference

### For PDFs
```swift
let pdfWithMetadata = try DocumentMetadataEmbedder.embed(
    metadata: metadata,
    into: pdfData,
    filename: "document.pdf"
)
```
Creates PDF with XMP metadata packet + Info dictionary.

### For JSON
```swift
let jsonWithMetadata = try DocumentMetadataEmbedder.embed(
    metadata: metadata,
    into: jsonData,
    filename: "data.json"
)
```
Adds `@metadata` field to JSON object.

### For Markdown
```swift
let mdWithMetadata = try DocumentMetadataEmbedder.embed(
    metadata: metadata,
    into: markdownData,
    filename: "document.md"
)
```
Adds frontmatter block at top of file.

### For Images
```swift
let imageWithMetadata = try DocumentMetadataEmbedder.embed(
    metadata: metadata,
    into: imageData,
    filename: "photo.jpg"
)
```
Wraps in 451 container format with metadata header.

### For Unknown Formats
```swift
let wrappedData = try DocumentMetadataEmbedder.embed(
    metadata: metadata,
    into: data,
    filename: "file.xyz"
)
```
Uses 451 wrapper format: `[451M][length][metadata][length][data]`

## Complete Example

```swift
func uploadDocumentCorrectly() async throws {
    // 1. Pick a file
    let url = // ... user selected file
    let data = try Data(contentsOf: url)
    
    // 2. Create metadata
    var metadata = DocumentMetadata451()
    metadata.title = "Important Contract"
    metadata.author = "Legal Team"
    metadata.type = "contract"
    
    let hash = SHA256.hash(data: data)
    metadata.documentHash = hash.compactMap { 
        String(format: "%02x", $0) 
    }.joined()
    
    // 3. Embed metadata INTO document
    let documentWithMetadata = try DocumentMetadataEmbedder.embed(
        metadata: metadata,
        into: data,
        filename: url.lastPathComponent
    )
    
    // 4. Upload self-contained document
    let response = try await DocumentSigningService.uploadDocument(
        documentData: documentWithMetadata,
        originalFilename: url.lastPathComponent,
        metadata: nil,  // No separate metadata!
        useEmbeddedMetadata: true
    )
    
    print("✅ Uploaded: \(response.documentId)")
    
    // 5. Later, extract metadata from downloaded file
    if let extracted = try DocumentMetadataEmbedder.extract(
        from: documentWithMetadata,
        filename: url.lastPathComponent
    ) {
        print("📖 Title: \(extracted.title ?? "N/A")")
        print("📖 Hash: \(extracted.documentHash ?? "N/A")")
    }
}
```

## Key Takeaways

1. **Metadata belongs IN the document**, not alongside it
2. **Use industry standards**: XMP for PDFs/images, frontmatter for text, JSON fields for JSON
3. **Self-contained files** are portable and work everywhere
4. **Your new code** should always use `DocumentMetadataEmbedder`
5. **The old way** (separate metadata) is deprecated but still supported for migration

## Files You Should Use

- ✅ `DocumentMetadataEmbedding.swift` - Embeds/extracts metadata
- ✅ `DocumentSigningService.swift` - Updated to support both modes
- ✅ `SignatorUploadMetadata.swift` - Helper for building metadata
- ✅ `EMBEDDED_METADATA_GUIDE.md` - Complete guide

## Next Steps

1. Update your upload flows to embed metadata first
2. Test with PDFs, JSON, and Markdown files
3. Verify metadata persists through download/upload cycles
4. Update server to extract embedded metadata
5. Eventually remove support for separate metadata
