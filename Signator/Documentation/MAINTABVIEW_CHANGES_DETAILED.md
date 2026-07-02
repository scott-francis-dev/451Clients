# MainTabView.swift Changes Summary

## Import Added
```swift
import SwiftUI
import CryptoKit  // ← Added for signature operations
```

## SignRequestsView Enhancements

### Header Button Addition
```swift
// Added access code button before refresh button
Button(action: { showingAccessCodeEntry = true }) {
    Image(systemName: "number")
        .font(.title3)
}
.buttonStyle(.plain)
```

### New State Variable
```swift
@State private var showingAccessCodeEntry = false
```

### New Sheet Presentation
```swift
.sheet(isPresented: $showingAccessCodeEntry) {
    AccessCodeEntryView(personaManager: personaManager) { document in
        let newRequest = SignRequest(
            id: document.id,
            title: document.displayTitle,
            subtitle: document.displaySubtitle,
            status: document.hasSigned ? .signed : .pending,
            documentId: document.documentId,
            pendingDocument: document
        )
        requests.insert(newRequest, at: 0)
    }
}
```

## SignRequestRow Enhancements

### Made Entire Row Tappable
```swift
// Before: Just HStack
// After: Button wrapping HStack
Button {
    showingSigningSheet = true
} label: {
    HStack(alignment: .center, spacing: 12) {
        // ... existing content
        
        // Added chevron indicator
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
.buttonStyle(.plain)
```

### Added Sheet Presentation
```swift
@State private var showingSigningSheet = false

.sheet(isPresented: $showingSigningSheet) {
    if let pendingDoc = request.pendingDocument {
        DocumentSigningDetailView(pendingDocument: pendingDoc)
    }
}
```

## New Views Added

### 1. AccessCodeEntryView
**Purpose:** Allow users to enter document access codes

**Key Features:**
- Text field for access code input
- Persona picker
- Search button with loading state
- Error handling
- Opens DocumentSigningDetailView on success

**Code Structure:**
```swift
struct AccessCodeEntryView: View {
    let personaManager: PersonaManager
    let onDocumentFound: (DocumentSigningService.PendingDocument) -> Void
    
    @State private var accessCode: String = ""
    @State private var selectedPersonaDID: String?
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var foundDocument: DocumentSigningService.PendingDocument?
    
    var body: some View {
        // Form with sections for code entry and persona selection
    }
    
    private func searchByAccessCode() async {
        // Calls DocumentSigningService.fetchDocumentByAccessCode()
    }
}
```

### 2. DocumentSigningDetailView
**Purpose:** Complete interface for reviewing and signing documents

**Key Features:**
- Document details display
- Existing signatures list
- Persona selection
- Sign button with full workflow
- Success/error messaging
- Auto-dismiss on success

**Code Structure:**
```swift
struct DocumentSigningDetailView: View {
    let pendingDocument: DocumentSigningService.PendingDocument
    @StateObject private var personaManager = PersonaManager()
    
    @State private var selectedPersonaDID: String?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        Form {
            // Document Details Section
            // Existing Signatures Section
            // Persona Selection Section
            // Sign Button Section
            // Status Messages Section
        }
    }
    
    private func signDocument() async {
        // Complete signing workflow:
        // 1. Get persona's private key
        // 2. Determine previous entry ID
        // 3. Call DocumentSigningService.addSignature()
        // 4. Show success and auto-dismiss
    }
}
```

## Help View Update

### SignRequestsHelpView
Added new section about access codes:
```swift
Section {
    VStack(alignment: .leading, spacing: 12) {
        Text("Access Codes")
            .font(.headline)
        Text("If someone shares a document access code with you (like '451-7892'), tap the # button at the top to enter it and access the document directly.")
            .font(.body)
            .foregroundColor(.secondary)
    }
    .padding(.vertical, 4)
}
```

Updated status description:
```
Before: "blue indicator → green indicator"
After: "blue indicator → orange indicator → green indicator"
```

## API Integration

### Methods Used from DocumentSigningService

#### Existing (already in use):
```swift
DocumentSigningService.fetchPendingDocuments(forSignerDID:)
DocumentSigningService.fetchAllPendingDocuments(forSignerDIDs:)
```

#### New Usage:
```swift
// Access code lookup
DocumentSigningService.fetchDocumentByAccessCode(_:signerDID:)

// Signature creation
DocumentSigningService.addSignature(
    documentId: String,
    signerDID: String,
    signerPublicKey: String,
    documentHash: Data,
    privateKey: P256.Signing.PrivateKey,
    role: SignerRole,
    previousEntryID: String?
)
```

## Data Flow Changes

### Before:
```
Server → fetchPendingDocuments() → SignRequestsView (display only)
```

### After:
```
Server → fetchPendingDocuments() → SignRequestsView (display)
                                           ↓ (tap)
                                  DocumentSigningDetailView
                                           ↓ (sign)
                                  addSignature() → Server

Alternative Path:
User → AccessCodeEntryView → fetchDocumentByAccessCode() → Server
                     ↓
           DocumentSigningDetailView
                     ↓
           addSignature() → Server
```

## File Size Impact

**Before:** ~400 lines  
**After:** ~700 lines  

**Added:**
- AccessCodeEntryView: ~100 lines
- DocumentSigningDetailView: ~150 lines
- SignRequestRow modifications: ~10 lines
- SignRequestsView modifications: ~20 lines
- Help view updates: ~10 lines

## Backwards Compatibility

✅ All existing functionality preserved  
✅ No breaking changes  
✅ All existing views still work  
✅ No API changes required  
✅ No data migration needed  

## Performance Considerations

- Sheet presentations are lazy (only loaded when shown)
- Signing operations happen asynchronously
- UI remains responsive during network calls
- Progress indicators prevent double-taps
- Auto-dismiss prevents memory buildup

## Security Considerations

✅ Private keys never leave device  
✅ Persona selection required before signing  
✅ Access code validation on server  
✅ Cryptographic signatures use P256  
✅ No credentials stored in view state  

## Edge Cases Handled

1. **No personas available** - Shows warning message
2. **Invalid access code** - Shows error message
3. **Network failure** - Shows error with retry option
4. **Empty document hash** - Throws error before signing
5. **Missing previous entry** - Uses proof entry as fallback
6. **Concurrent signing attempts** - Button disabled during processing

## What's Next?

Possible future enhancements:
- [ ] Document preview (PDF/image viewer)
- [ ] Audit trail viewing
- [ ] Push notifications
- [ ] Batch signing
- [ ] Biometric confirmation
- [ ] Signature templates
