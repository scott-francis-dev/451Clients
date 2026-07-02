# WalletAPI Migration Summary

## Overview

Consolidated all document submission functionality from multiple conflicting implementations into a single, server-driven workflow using `DocumentSigningService`.

## What Changed

### ✅ Files Updated

1. **`WalletAPI.swift`**
   - Marked all old submission methods as `@available(*, deprecated)`
   - Added deprecation errors that guide developers to new API
   - Kept utility functions like `mimeType(forFileExtension:)`
   - Kept `serverBaseURL` and `WalletAPIError` for compatibility

2. **`WalletAPI+DocumentSubmit.swift`**
   - Marked as deprecated file
   - Can be deleted once migration is complete
   - All code commented out with deprecation notice

3. **`SignAndSubmitView.swift`** ⭐ **ACTIVELY FIXED**
   - Removed deprecated `WalletAPI.submitDocument()` call
   - Removed client-side signing logic
   - Now uses `DocumentSigningService.uploadDocument()`
   - Server handles all signing/signature collection

### 🗑️ Deprecated Methods

All these methods now throw deprecation errors:

```swift
// ❌ DEPRECATED
WalletAPI.submitSignedDocument(documentData:metadataJSON:)
WalletAPI.submitSignedDocument(payload:)
WalletAPI.submitDocument(document:metadata:)
submitSignedDocumentFlowLegacy()
```

### ✅ Current Correct API

```swift
// ✅ USE THIS
let response = try await DocumentSigningService.uploadDocument(
    documentData: data,
    originalFilename: filename
)
// Posts to: /api/document/publish
// Server handles: signature collection, validation, ledger entries
```

### 🔄 API Endpoint Changes

| Old Endpoint | New Endpoint | Status |
|--------------|--------------|--------|
| `/api/document/draft` (POST+PUT) | `/api/document/publish` | Deprecated |
| `/api/documents/submit` (plural) | `/api/document/publish` | Deprecated |
| `/api/document/submit` | `/api/document/publish` | Deprecated |
| **`/api/document/publish`** | **CURRENT** | ✅ Active |

## Architecture Philosophy

### Before (Client-Side Signing)
```
Client                           Server
  ├─ Hash document              
  ├─ Sign document              
  ├─ Sign hash                  
  ├─ Build signatures payload   
  └─ POST to server             ├─ Validate
                                └─ Store
```

### After (Server-Side Signing) ✅
```
Client                           Server
  └─ POST document              ├─ Hash document
                                ├─ Collect signatures
                                ├─ Validate completeness
                                ├─ Create ledger entries
                                └─ Store & notify
```

## Benefits

1. **Single Source of Truth**: One method for document upload
2. **Server Authority**: Server determines signature requirements
3. **Simpler Client**: Client just uploads, server handles complexity
4. **Better Security**: Signature logic centralized and auditable
5. **Easier Testing**: One code path to test
6. **Future-Proof**: Server can change signature requirements without client updates

## Migration Checklist

- [x] Deprecate old `WalletAPI` methods
- [x] Update `SignAndSubmitView.swift` to use new API
- [x] Mark `WalletAPI+DocumentSubmit.swift` as deprecated
- [ ] Update any remaining documentation
- [ ] Remove old `SignerService` methods if unused elsewhere
- [ ] Delete deprecated files after grace period

## Next Steps

1. **Search for any remaining usages**:
   ```bash
   grep -r "submitSignedDocument" .
   grep -r "submitDocument" .
   grep -r "WalletAPI.submit" .
   ```

2. **Verify no compile errors** - All deprecated methods throw clear errors

3. **Test the new flow** - Ensure `SignAndSubmitView` works with server

4. **Delete deprecated file** when ready:
   - `WalletAPI+DocumentSubmit.swift`

## Questions Resolved

> "I think the server should be responsible for determining whether all of the correct signatures have been collected. Not this client."

✅ **CORRECT!** This is now the architecture. The server at `/api/document/publish` handles:
- Determining required signatures
- Collecting signatures from multiple parties
- Validating signature completeness
- Creating proof/sign/attest ledger entries

The client just uploads the document and gets back the document ID.
