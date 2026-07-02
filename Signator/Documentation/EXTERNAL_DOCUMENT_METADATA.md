# Handling External Documents with Minimal Metadata

## The Problem

**Signator Use Case**: Users upload existing binary documents (PDFs, DOCX, etc.) via `UIDocumentPickerViewController`
- These documents already exist
- Users may not know all the metadata
- Most fields will be empty/unknown
- Only basic metadata might be available

**Thesis Use Case**: Users create documents from scratch in the app
- Full metadata can be collected during creation
- All fields are relevant
- Rich editing experience

## The Solution: Multi-Tier Metadata System

### Tier 1: Bare Minimum (Always Available)
```swift
struct MinimalDocumentMetadata: Codable {
    let originalFilename: String
    let mimeType: String
    let fileSize: Int
    let documentHash: String
    let uploadDate: String  // ISO 8601
}
```

**Automatically extracted** from the picked file - no user input needed.

### Tier 2: Basic User-Provided (Optional but Encouraged)
```swift
struct BasicMetadata: Codable {
    var title: String?          // Prompt user, suggest filename
    var type: String?           // Contract, Agreement, Report, etc.
    var accessrights: String?   // Public, Private, Confidential
}
```

**Quick dialog** before upload - 3 fields max, pre-filled when possible.

### Tier 3: Full Protocol Metadata (Optional, Advanced)
```swift
// Use full TransferMetadata
// Only for users who want/need comprehensive metadata
```

**Advanced editor** - shown only if user taps "More Details".

## Implementation Strategy

### 1. Smart Defaults with Progressive Disclosure

```swift
/// Signator-specific upload metadata builder
struct SignatorUploadMetadata {
    // TIER 1: Automatic (always present)
    let filename: String
    let mimeType: String
    let fileSize: Int
    let documentHash: String
    
    // TIER 2: Basic (quick prompt)
    var title: String?
    var documentType: String?
    var accessLevel: String?
    
    // TIER 3: Full metadata (advanced, optional)
    var fullMetadata: TransferMetadata?
    
    /// Convert to TransferMetadata for upload
    func toTransferMetadata() -> TransferMetadata {
        var metadata = fullMetadata ?? TransferMetadata()
        
        // Set automatic fields
        metadata.fileExtension = (filename as NSString).pathExtension
        metadata.mimeType = mimeType
        metadata.fileSize = fileSize
        metadata.documentHash = documentHash
        metadata.format = "451"
        
        // Set basic fields (if not already in fullMetadata)
        if metadata.title == nil {
            metadata.title = title ?? filename  // Fallback to filename
        }
        if metadata.type == nil {
            metadata.type = documentType
        }
        if metadata.accessrights == nil {
            metadata.accessrights = accessLevel ?? "private"
        }
        
        return metadata
    }
}
```

### 2. UI Flow for External Document Upload

```
┌──────────────────────────────┐
│  User picks PDF via          │
│  UIDocumentPickerView        │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│  App extracts:               │
│  ✓ Filename: "contract.pdf"  │
│  ✓ MIME: application/pdf     │
│  ✓ Size: 524KB               │
│  ✓ Hash: sha256(...)         │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│  Quick Metadata Dialog       │
│  ┌────────────────────────┐  │
│  │ Title: [contract.pdf ] │  │ ← Pre-filled
│  │ Type:  [Contract ▼   ] │  │ ← Dropdown
│  │ Access:[Private ▼    ] │  │ ← Default private
│  │                        │  │
│  │ [ More Details... ]    │  │ ← Optional
│  │                        │  │
│  │ [Cancel]    [Upload]   │  │
│  └────────────────────────┘  │
└──────────────┬───────────────┘
               │
               ▼
    ┌──────────┴──────────┐
    │                     │
    ▼                     ▼
[Upload Now]      [More Details]
                         │
                         ▼
              ┌──────────────────┐
              │ Full Editor      │
              │ (All fields)     │
              └──────────────────┘
```

### 3. Code Implementation

#### Quick Upload Dialog
```swift
struct QuickMetadataDialog: View {
    let filename: String
    let suggestedType: String?
    
    @State private var title: String
    @State private var documentType: String
    @State private var accessLevel: String = "private"
    @State private var showFullEditor = false
    
    @Environment(\.dismiss) private var dismiss
    let onUpload: (SignatorUploadMetadata) -> Void
    
    init(filename: String, suggestedType: String? = nil, onUpload: @escaping (SignatorUploadMetadata) -> Void) {
        self.filename = filename
        self.suggestedType = suggestedType
        self.onUpload = onUpload
        
        // Pre-fill title with filename (without extension)
        let basename = (filename as NSString).deletingPathExtension
        _title = State(initialValue: basename)
        
        // Pre-select type if suggested
        _documentType = State(initialValue: suggestedType ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .textContentType(.name)
                    
                    Picker("Document Type", selection: $documentType) {
                        Text("Select type").tag("")
                        Text("Contract").tag("contract")
                        Text("Agreement").tag("agreement")
                        Text("Report").tag("report")
                        Text("Invoice").tag("invoice")
                        Text("Receipt").tag("receipt")
                        Text("Letter").tag("letter")
                        Text("Other").tag("other")
                    }
                    
                    Picker("Access Level", selection: $accessLevel) {
                        Text("Private").tag("private")
                        Text("Confidential").tag("confidential")
                        Text("Internal").tag("internal")
                        Text("Public").tag("public")
                    }
                } header: {
                    Text("Basic Information")
                } footer: {
                    Text("You can add more details later.")
                }
                
                Section {
                    Button {
                        showFullEditor = true
                    } label: {
                        Label("Add More Details", systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle("Quick Upload")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Upload") {
                        let metadata = SignatorUploadMetadata(
                            filename: filename,
                            mimeType: "", // Will be set by caller
                            fileSize: 0,  // Will be set by caller
                            documentHash: "",  // Will be set by caller
                            title: title.isEmpty ? nil : title,
                            documentType: documentType.isEmpty ? nil : documentType,
                            accessLevel: accessLevel,
                            fullMetadata: nil
                        )
                        onUpload(metadata)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showFullEditor) {
                FullMetadataEditorForExternalDoc(
                    basicTitle: title,
                    basicType: documentType,
                    basicAccess: accessLevel
                ) { fullMetadata in
                    let metadata = SignatorUploadMetadata(
                        filename: filename,
                        mimeType: "",
                        fileSize: 0,
                        documentHash: "",
                        title: nil,
                        documentType: nil,
                        accessLevel: nil,
                        fullMetadata: fullMetadata
                    )
                    onUpload(metadata)
                    dismiss()
                }
            }
        }
    }
}
```

#### Document Picker Integration
```swift
struct ExternalDocumentUploader: View {
    @State private var showDocumentPicker = false
    @State private var showQuickMetadata = false
    @State private var pickedDocument: URL?
    @State private var pickedDocumentData: Data?
    @State private var documentInfo: (filename: String, mimeType: String, size: Int)?
    
    var body: some View {
        Button("Upload External Document") {
            showDocumentPicker = true
        }
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.pdf, .plainText, .png, .jpeg],
            allowsMultipleSelection: false
        ) { result in
            handlePickedDocument(result)
        }
        .sheet(item: $documentInfo) { info in
            QuickMetadataDialog(
                filename: info.filename,
                suggestedType: suggestDocumentType(from: info.filename)
            ) { uploadMetadata in
                Task {
                    await uploadDocument(with: uploadMetadata)
                }
            }
        }
    }
    
    func handlePickedDocument(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result,
              let url = urls.first else { return }
        
        // Read document
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            let filename = url.lastPathComponent
            let mimeType = mimeTypeForFile(url)
            let size = data.count
            
            pickedDocumentData = data
            documentInfo = (filename, mimeType, size)
            
        } catch {
            print("Error reading document: \(error)")
        }
    }
    
    func suggestDocumentType(from filename: String) -> String? {
        let lower = filename.lowercased()
        if lower.contains("contract") { return "contract" }
        if lower.contains("agreement") { return "agreement" }
        if lower.contains("invoice") { return "invoice" }
        if lower.contains("receipt") { return "receipt" }
        if lower.contains("report") { return "report" }
        return nil
    }
    
    func uploadDocument(with uploadMetadata: SignatorUploadMetadata) async {
        guard let data = pickedDocumentData,
              let info = documentInfo else { return }
        
        // Calculate hash
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // Build complete metadata
        var completeMetadata = uploadMetadata
        completeMetadata.fileSize = info.size
        completeMetadata.mimeType = info.mimeType
        completeMetadata.documentHash = hashString
        
        // Convert to TransferMetadata
        let metadata = completeMetadata.toTransferMetadata()
        
        do {
            let (documentId, _, _) = try await DocumentSigningService.completeSigningWorkflow(
                documentData: data,
                originalFilename: info.filename,
                metadata: metadata
            )
            
            print("✅ Uploaded external document: \(documentId)")
            
        } catch {
            print("❌ Upload failed: \(error)")
        }
    }
    
    func mimeTypeForFile(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "txt": return "text/plain"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        default: return "application/octet-stream"
        }
    }
}

// Make documentInfo Identifiable for sheet binding
extension (filename: String, mimeType: String, size: Int): Identifiable {
    var id: String { filename }
}
```

### 4. Server-Side Handling

The server should handle sparse metadata gracefully:

```typescript
// Server receives TransferMetadata
interface ReceivedMetadata {
  // These are GUARANTEED (from file itself)
  fileExtension: string;
  mimeType: string;
  fileSize: number;
  documentHash: string;
  
  // These are OPTIONAL (user may not provide)
  title?: string;
  type?: string;
  accessrights?: string;
  author?: string;
  description?: string;
  // ... all other fields optional
}

function createDocument(data: Buffer, metadata: ReceivedMetadata): Document451 {
  const doc = new Document451();
  
  // Set guaranteed fields
  doc.id = generateUUID();
  doc.did = `did:451:${metadata.documentHash}`;
  doc.format = "451";
  
  // Set file info (always present)
  doc.fileExtension = metadata.fileExtension;
  doc.mimeType = metadata.mimeType;
  doc.fileSize = metadata.fileSize;
  doc.documentHash = metadata.documentHash;
  
  // Set user-provided fields (if available)
  doc.title = metadata.title || `Document ${doc.id.substring(0, 8)}`;
  doc.type = metadata.type || "unknown";
  doc.accessrights = metadata.accessrights || "private";
  doc.author = metadata.author || "";
  doc.description = metadata.description || "";
  
  // All other fields remain empty strings (from Document451 defaults)
  
  return doc;
}
```

## Best Practices for External Documents

### 1. Never Require Full Metadata
```swift
// ✅ Good - minimal required, rest optional
struct UploadRequest {
    let documentData: Data
    let filename: String
    var metadata: TransferMetadata?  // Optional!
}

// ❌ Bad - forces users to fill everything
struct UploadRequest {
    let documentData: Data
    let metadata: Document451  // Too much required!
}
```

### 2. Smart Pre-filling
```swift
// Extract from filename
func suggestMetadata(from filename: String) -> TransferMetadata {
    var metadata = TransferMetadata()
    
    // Use filename as title (without extension)
    metadata.title = (filename as NSString).deletingPathExtension
    
    // Guess type from filename patterns
    let lower = filename.lowercased()
    if lower.contains("contract") { metadata.type = "contract" }
    else if lower.contains("invoice") { metadata.type = "invoice" }
    else if lower.contains("receipt") { metadata.type = "receipt" }
    
    // Default to private for safety
    metadata.accessrights = "private"
    
    return metadata
}
```

### 3. Progressive Disclosure
```swift
// Start simple
QuickUploadDialog()  // 3 fields

// Advanced users can expand
if userTapsMoreDetails {
    FullMetadataEditor()  // All fields
}

// Power users can skip dialog entirely
if userHoldsOptionKey {
    uploadImmediately()  // Use filename as title
}
```

### 4. Metadata Enhancement Later
```swift
// Users can add metadata after upload
struct DocumentDetailView: View {
    let document: Document451
    
    var body: some View {
        VStack {
            if document.description.isEmpty {
                Button("Add Description") {
                    // Show editor
                }
            }
            
            if document.author.isEmpty {
                Button("Add Author") {
                    // Show editor
                }
            }
        }
    }
}
```

## Summary: The Right Approach

1. **Automatic Fields** (from file): Always capture
   - Filename, MIME type, size, hash
   
2. **Basic Fields** (quick prompt): Encourage but don't require
   - Title (pre-fill with filename)
   - Document type (dropdown)
   - Access level (default private)
   
3. **Full Metadata** (advanced): Make available but hide by default
   - Author, description, DOI, ISBN, etc.
   - Only for users who need it
   
4. **Server Handling**: Accept sparse metadata gracefully
   - Use sensible defaults for missing fields
   - Don't fail if fields are empty
   
5. **Enhancement Workflow**: Allow adding metadata later
   - Document detail view shows "Add X" buttons
   - Can enrich metadata over time

This approach respects that **external documents are fundamentally different** from authored documents, while still using the same underlying `TransferMetadata` structure.
