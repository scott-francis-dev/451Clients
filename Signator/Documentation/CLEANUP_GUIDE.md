# WalletAPI Consolidation - Cleanup Guide

## ✅ What I Just Did

I consolidated **4 duplicate WalletAPI files** into **1 canonical version**.

### Files Status:

| File | Status | Action Needed |
|------|--------|---------------|
| **WalletAPI.swift** | ✅ **CANONICAL** | **KEEP THIS** |
| WalletAPI 2.swift | 🗑️ Empty stub | **DELETE** |
| WalletAPI 3.swift | 🗑️ Empty stub | **DELETE** |
| WalletAPI 4.swift | 🗑️ Empty stub | **DELETE** |
| WalletAPI_CONSOLIDATED.swift | 📦 Backup | Optional - delete after cleanup |

## 🔧 How to Complete the Cleanup in Xcode

### Step 1: Remove Duplicate Files from Xcode Project

1. Open **Xcode**
2. In the **Project Navigator** (left sidebar), find these files:
   - `WalletAPI 2.swift`
   - `WalletAPI 3.swift`  
   - `WalletAPI 4.swift`

3. **Right-click each file** → Select **"Delete"**
4. Choose **"Move to Trash"** (not just "Remove Reference")

### Step 2: Clean Build Folder

1. In Xcode menu: **Product** → **Clean Build Folder** (or press ⇧⌘K)
2. This ensures old compiled code is removed

### Step 3: Rebuild

1. **Product** → **Build** (or press ⌘B)
2. All the redeclaration errors should now be **GONE** ✅

## 📋 What's in the Canonical WalletAPI.swift

The consolidated file contains:

### ✅ Core Structure
```swift
struct WalletAPI {
    static var serverBaseURL: URL
    enum WalletAPIError: Error { ... }
}
```

### ✅ Utility Functions
```swift
func mimeType(forFileExtension:) -> String
```

### ✅ Deprecated Methods (Properly Marked)
```swift
@available(*, deprecated)
extension WalletAPI {
    static func submitSignedDocument(...)
    static func submitDocument(...)
}

@available(*, deprecated)
func submitSignedDocumentFlowLegacy(...)
```

### ✅ Legacy Types (For Compatibility)
```swift
struct LegacyDocumentMetadata: Codable
struct DocumentSubmissionRequest: Codable
struct LegacySignAndSubmitView: View
```

**Key Changes:**
- Renamed `DocumentMetadata` → `LegacyDocumentMetadata` (to avoid conflicts with DocumentMetadata451)
- Removed duplicate `SignAndSubmitView` (it's in SignAndSubmitView_CLEAN.swift)
- All deprecated methods properly marked and throw errors
- Proper Codable conformance with encoding/decoding

## 🎯 Why This Happened

You likely had multiple editors/AI tools creating duplicate files during refactoring. Common causes:
- Copy/paste gone wrong
- File versioning without deleting old versions
- Multiple "Save As" operations
- Git merge conflicts that created numbered duplicates

## ✅ Verification Checklist

After cleanup, verify:

- [ ] Build succeeds with no errors
- [ ] No "Invalid redeclaration" errors
- [ ] No "Ambiguous type lookup" errors  
- [ ] Only **1** WalletAPI file in project
- [ ] Deprecated methods show proper warnings when called
- [ ] DocumentSigningService still works correctly

## 📝 Future Prevention

To avoid this in the future:

1. **Before creating a new file**, check if it already exists
2. **Use version control** (Git) to track changes instead of duplicating files
3. **Delete old versions** immediately after refactoring
4. **Use Xcode's rename refactoring** instead of creating new files

## 🆘 If Something Breaks

If you encounter issues after cleanup:

1. **Check imports**: Make sure other files import the right types
2. **Search for type names**: 
   ```bash
   # In Terminal, from your project root:
   grep -r "DocumentMetadata" . --include="*.swift"
   grep -r "SignAndSubmitView" . --include="*.swift"
   ```
3. **Rename references**:
   - `DocumentMetadata` → `LegacyDocumentMetadata` (if using old type)
   - `SignAndSubmitView` → `LegacySignAndSubmitView` (if still using it)
   - Or better: **Use the new APIs** from `DocumentSigningService`

## 🚀 Recommended Next Steps

Now that WalletAPI is clean, consider:

1. **Migrate away from deprecated APIs**:
   - Replace `WalletAPI.submitDocument()` with `DocumentSigningService.uploadDocument()`
   - See `API_COMPARISON.md` for migration examples

2. **Clean up SignAndSubmitView**:
   - If you have duplicate SignAndSubmitView files, consolidate them too
   - Use the version from `SignAndSubmitView_CLEAN.swift`

3. **Update DocumentMetadata usage**:
   - Replace `LegacyDocumentMetadata` with `DocumentMetadata451`
   - See `DocumentMetadata451.swift` for the modern structure

## 📚 Reference Documentation

- `API_COMPARISON.md` - Old vs. New API comparison
- `MIGRATION_SUMMARY.md` - Migration guide and philosophy
- `DocumentMetadata451.swift` - Modern metadata structure
- `SignAndSubmitView_CLEAN.swift` - Modern submission view

---

**Bottom Line**: Delete the 3 duplicate files, rebuild, and you're done! ✅
