# Embedded Metadata: The Right Way to Handle Document Metadata

## The Problem with Separate Metadata

### ❌ WRONG: Sending Metadata Separately

```swift
// DON'T DO THIS
let documentData = loadPDF()
let metadata = createMetadata()

// Upload document and metadata as SEPARATE pieces
try await uploadDocument(
    document: documentData,
    metadata: metadata  // ← Separate metadata
)
```

**Why this is wrong:**

1. **Metadata is not part of the document** - If someone downloads just the file, they lose all metadata
2. **Two separate objects** - Document and metadata can become desynchronized
3. **Server has to manage both** - Extra complexity, storage, and potential for mismatch
4. **Not portable** - Document file alone is meaningless without its metadata file

### ✅ CORRECT: Embedding Metadata in the Document

```swift
// DO THIS INSTEAD
let documentData = loadPDF()
let metadata = createMetadata()

// Embed metadata INTO the document
let documentWithMetadata = try DocumentMetadataEmbedder.embed(
    metadata: metadata,
    into: documentData,
    filename: "contract.pdf"
)

// Upload just the enhanced document
try await uploadDocument(
    document: documentWithMetadata,
    metadata: nil  // ← No separate metadata needed!
)
```

**Why this is right:**

1. **Self-contained** - Document carries its own metadata
2. **Portable** - Download the file anywhere and metadata travels with it
3. **Standard practice** - How PDFs, images, and most professional documents work
4. **Server simplicity** - Just store one object, not two

## Industry Standards for Metadata Embedding

### PDF Documents

PDFs have TWO standard places for metadata:

1. **PDF Info Dictionary** (legacy but still used)
2. **XMP (Extensible Metadata Platform)** - Adobe's standard

Our implementation uses both:

```swift
let pdfWithMetadata = try DocumentMetadataEmbedder.embed(
    metadata: metadata,
    into: pdfData,
    filename: "document.pdf"
)
```

This creates:
- Standard PDF metadata fields (Title, Author, Subject, Keywords)
- XMP packet with full 451 metadata as structured data

**Viewing embedded PDF metadata:**
- macOS: Get Info → More Info
- Adobe Acrobat: File → Properties → Description
- PDFKit: `pdfDocument.documentAttributes`

### Image Files (JPEG, PNG, etc.)

Images use **EXIF** and **XMP** metadata:

```swift
// For images, we wrap them with metadata
let imageWithMetadata = try DocumentMetadataEmbedder.embed(
    metadata: metadata,
    into: imageData,
    filename: "photo.jpg"
)
```

**Standard EXIF fields:**
- Author → EXIF Artist
- Description → EXIF ImageDescription
- Keywords → EXIF Keywords
- Copyright → EXIF Copyright

### JSON Documents

JSON documents should have a top-level metadata field:

```swift
let jsonWithMetadata = try DocumentMetadataEmbedder.embed(
    metadata: metadata,
    into: jsonData,
    filename: "data.json"
)
```

Creates structure like:

```json
{
  "@format": "451",
  "@version": "1.0",
  "@metadata": {
    "title": "Sales Report Q4",
    "author": "Jane Smith",
    "type": "report",
    "accessrights": "internal",
    "documentHash": "sha256:abc123...",
    "publicationDate": "2026-01-23T10:30:00Z"
  },
  "data": {
    "revenue": 1000000,
    "expenses": 500000
  }
}
```

### Text/Markdown Documents

Text files use **frontmatter** - metadata block at the beginning:

```markdown
---
format: 451
metadata: {
  "title": "Project Proposal",
  "author": "John Doe",
  "type": "proposal",
  "documentHash": "sha256:def456..."
}
---

# Project Proposal

This is the actual document content...
```

### Unknown/Binary Formats

For formats without standard metadata support, we use a **451 wrapper format**:

```
[4 bytes: "451M" magic number]
[4 bytes: metadata length]
[N bytes: JSON metadata]
[4 bytes: document length]
[M bytes: original document data]
```

This creates a self-contained package that can be unwrapped to get both metadata and original document.

## Migration Path: From Separate to Embedded Metadata

### Phase 1: Support Both (Current)

```swift
static func uploadDocument(
    documentData: Data,
    originalFilename: String?,
    metadata: DocumentMetadata451? = nil,
    useEmbeddedMetadata: Bool = true  // ← Default to embedded
) async throws -> UploadResponse {
    if useEmbeddedMetadata {
        // ✅ Preferred: Metadata is in the document
        uploadSimple(documentData)
    } else {
        // ⚠️ Legacy: Metadata sent separately
        uploadMultipart(documentData, metadata)
    }
}
```

### Phase 2: Embed Before Upload (Recommended)

```swift
// Client-side: Always embed before upload
func uploadWithMetadata(
    documentData: Data,
    filename: String,
    metadata: DocumentMetadata451
) async throws {
    // Step 1: Embed metadata
    let documentWithMetadata = try DocumentMetadataEmbedder.embed(
        metadata: metadata,
        into: documentData,
        filename: filename
    )
    
    // Step 2: Upload enhanced document
    try await DocumentSigningService.uploadDocument(
        documentData: documentWithMetadata,
        originalFilename: filename,
        metadata: nil,  // No separate metadata
        useEmbeddedMetadata: true
    )
}
```

### Phase 3: Server Extracts Metadata (Future)

```typescript
// Server-side: Extract metadata from uploaded document
app.post('/api/document/publish', async (req, res) => {
  const documentData = req.body;
  const filename = req.headers['x-original-filename'];
  
  // Extract metadata from the document itself
  const metadata = extractMetadata(documentData, filename);
  
  if (!metadata) {
    return res.status(400).json({
      error: "No metadata found in document"
    });
  }
  
  // Store just the document - metadata is already in it
  const documentId = await storeDocument(documentData);
  
  res.json({ documentId, metadata });
});
```

## Usage Examples

### Example 1: Upload PDF with Embedded Metadata

```swift
func uploadContract() async throws {
    // Load PDF
    let pdfData = try Data(contentsOf: contractURL)
    
    // Create metadata
    var metadata = DocumentMetadata451()
    metadata.title = "Employment Contract"
    metadata.author = "HR Department"
    metadata.type = "contract"
    metadata.accessrights = "confidential"
    
    // Embed metadata into PDF
    let pdfWithMetadata = try DocumentMetadataEmbedder.embed(
        metadata: metadata,
        into: pdfData,
        filename: "contract.pdf"
    )
    
    // Upload (metadata is already embedded)
    let response = try await DocumentSigningService.uploadDocument(
        documentData: pdfWithMetadata,
        originalFilename: "contract.pdf",
        metadata: nil
    )
    
    print("✅ Uploaded: \(response.documentId)")
}
```

### Example 2: Upload JSON Data with Metadata

```swift
func uploadReport() async throws {
    // Create JSON data
    let reportData: [String: Any] = [
        "quarter": "Q4 2025",
        "revenue": 1000000,
        "expenses": 500000
    ]
    
    let jsonData = try JSONSerialization.data(withJSONObject: reportData)
    
    // Create metadata
    var metadata = DocumentMetadata451()
    metadata.title = "Q4 Financial Report"
    metadata.author = "Finance Team"
    metadata.type = "report"
    metadata.publicationDate = ISO8601DateFormatter().string(from: Date())
    
    // Embed metadata as @metadata field
    let jsonWithMetadata = try DocumentMetadataEmbedder.embed(
        metadata: metadata,
        into: jsonData,
        filename: "report.json"
    )
    
    // Upload
    let response = try await DocumentSigningService.uploadDocument(
        documentData: jsonWithMetadata,
        originalFilename: "report.json",
        metadata: nil
    )
    
    print("✅ Uploaded: \(response.documentId)")
}
```

### Example 3: Upload Markdown with Frontmatter

```swift
func uploadProposal() async throws {
    let markdownText = """
    # Project Proposal
    
    ## Overview
    This project aims to...
    """
    
    let markdownData = markdownText.data(using: .utf8)!
    
    var metadata = DocumentMetadata451()
    metadata.title = "Project Alpha Proposal"
    metadata.author = "Product Team"
    metadata.type = "proposal"
    
    // Add frontmatter
    let markdownWithFrontmatter = try DocumentMetadataEmbedder.embed(
        metadata: metadata,
        into: markdownData,
        filename: "proposal.md"
    )
    
    let response = try await DocumentSigningService.uploadDocument(
        documentData: markdownWithFrontmatter,
        originalFilename: "proposal.md",
        metadata: nil
    )
    
    print("✅ Uploaded: \(response.documentId)")
}
```

### Example 4: Extract Metadata from Downloaded Document

```swift
func readDownloadedDocument(url: URL) throws {
    let documentData = try Data(contentsOf: url)
    let filename = url.lastPathComponent
    
    // Extract metadata from the document
    if let metadata = try DocumentMetadataEmbedder.extract(
        from: documentData,
        filename: filename
    ) {
        print("📖 Document Metadata:")
        print("   Title: \(metadata.title ?? "N/A")")
        print("   Author: \(metadata.author ?? "N/A")")
        print("   Type: \(metadata.type ?? "N/A")")
        print("   Hash: \(metadata.documentHash ?? "N/A")")
        
        // Verify integrity
        let actualHash = SHA256.hash(data: documentData)
        let actualHashString = actualHash.compactMap { 
            String(format: "%02x", $0) 
        }.joined()
        
        if actualHashString == metadata.documentHash {
            print("✅ Document hash verified")
        } else {
            print("❌ Document hash mismatch - may be tampered")
        }
    } else {
        print("⚠️ No embedded metadata found")
    }
}
```

### Example 5: Batch Upload with Embedded Metadata

```swift
func batchUploadDocuments(files: [URL]) async throws {
    for fileURL in files {
        let documentData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        
        // Auto-generate metadata
        var metadata = DocumentMetadata451()
        metadata.title = (filename as NSString).deletingPathExtension
        metadata.fileExtension = (filename as NSString).pathExtension
        metadata.fileSize = documentData.count
        
        let hash = SHA256.hash(data: documentData)
        metadata.documentHash = hash.compactMap { 
            String(format: "%02x", $0) 
        }.joined()
        
        // Embed metadata
        let documentWithMetadata = try DocumentMetadataEmbedder.embed(
            metadata: metadata,
            into: documentData,
            filename: filename
        )
        
        // Upload
        let response = try await DocumentSigningService.uploadDocument(
            documentData: documentWithMetadata,
            originalFilename: filename,
            metadata: nil
        )
        
        print("✅ Uploaded \(filename): \(response.documentId)")
    }
}
```

## Benefits of Embedded Metadata

### 1. **Portability**
Documents can be shared, downloaded, and moved without losing their metadata. The file itself is complete.

### 2. **Integrity**
Metadata and document travel together. No risk of mismatch or orphaned metadata.

### 3. **Standard Compliance**
Follows industry standards (XMP, EXIF, JSON-LD, frontmatter) that other tools understand.

### 4. **Simplified Architecture**
Server stores one object instead of two. No need for separate metadata database.

### 5. **Offline Access**
Users can view metadata even when offline or outside your app.

### 6. **Verification**
Hash in metadata can verify document hasn't been altered since creation.

## Backward Compatibility

The current implementation supports both approaches:

```swift
// ✅ New way (embedded)
try await uploadDocument(
    documentData: documentWithEmbeddedMetadata,
    originalFilename: "doc.pdf",
    metadata: nil,
    useEmbeddedMetadata: true  // Default
)

// ⚠️ Old way (separate) - still works but deprecated
try await uploadDocument(
    documentData: rawDocumentData,
    originalFilename: "doc.pdf",
    metadata: separateMetadata,
    useEmbeddedMetadata: false
)
```

Existing code continues to work while new code should use embedded metadata.

## Server Implementation Notes

### Detecting Embedded Metadata

```typescript
function hasEmbeddedMetadata(req: Request): boolean {
  return req.headers['x-metadata-location'] === 'embedded';
}

async function handleUpload(req: Request) {
  const documentData = await req.body();
  const filename = req.headers['x-original-filename'];
  
  if (hasEmbeddedMetadata(req)) {
    // Extract metadata from document
    const metadata = extractMetadata(documentData, filename);
    await storeDocument(documentData);
    
  } else {
    // Legacy: Parse multipart for separate metadata
    const { document, metadata } = await parseMultipart(req);
    await storeDocument(document);
  }
}
```

### Extracting Metadata Server-Side

```typescript
function extractMetadata(data: Buffer, filename: string): Metadata {
  const ext = path.extname(filename).toLowerCase();
  
  switch (ext) {
    case '.pdf':
      return extractPDFMetadata(data);
      
    case '.json':
      const json = JSON.parse(data.toString());
      return json['@metadata'];
      
    case '.md':
      return extractMarkdownFrontmatter(data);
      
    default:
      return extract451WrapperMetadata(data);
  }
}
```

## Migration Checklist

- [ ] Implement `DocumentMetadataEmbedder`
- [ ] Update `uploadDocument()` to support both modes
- [ ] Convert existing upload flows to use embedded metadata
- [ ] Update UI to show "Embedding metadata..." progress
- [ ] Test with all supported formats (PDF, JSON, Markdown, etc.)
- [ ] Update server to extract embedded metadata
- [ ] Add extraction to document download/view flows
- [ ] Add verification that hash in metadata matches document
- [ ] Deprecate separate metadata parameter
- [ ] Remove separate metadata support (future)

## Summary

**The Right Way™:**
1. Create your document data
2. Create your metadata
3. **Embed metadata INTO the document**
4. Upload the self-contained document
5. Server extracts metadata from document (or stores as-is)

**The document IS the single source of truth, containing both content and metadata.**
