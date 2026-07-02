# Changes Summary: Public/Private Persona Data Implementation

## Files Modified

### 1. PersonaProfile.swift
**Changes:**
- Added `privateData: PrivatePersonaData?` property
- Added `PrivatePersonaData` struct with fields:
  - `givenName: String?`
  - `aliases: String?`
  - `privateEmail: String?`
  - `socialSecurityNumber: String?`
  - `privateAddress: PostalAddress?`

**Purpose:** Support encrypted private information that never leaves the device in plain text.

---

### 2. PersonaCreationView.swift
**Major Changes:**

#### State Variables Reorganized
**Removed:**
- `@State private var email` (ambiguous - now split into public/private)
- `@State private var affiliations` (renamed for clarity)
- `@State private var socialLinks` (renamed for clarity)
- `@ObservedObject private var store` (changed to `@State` to fix compiler error)

**Added Public Fields:**
- `@State private var publicAffiliations = ""`
- `@State private var socialMediaLinks = ""`
- `@State private var publicEmail = ""`

**Added Private Fields:**
- `@State private var givenName = ""`
- `@State private var aliases = ""`
- `@State private var privateEmail = ""`
- `@State private var socialSecurityNumber = ""`
- (Address fields remain: `street`, `city`, `stateRegion`, `postalCode`, `country`)

#### UI Changes
**New Form Structure:**
1. **Persona Identity (Required)** - DID creation
   - Footer explains DID is always public
2. **Public Information (Optional)** - Public fields
   - Footer explains these are visible in metadata
3. **Private Information (Optional)** - Private encrypted fields  
   - Footer explains encryption and usage for legal documents
4. **Background Check** - Toggle for validation requirement
5. **Create Button**

**Removed Sections:**
- Combined email/address/affiliations sections
- Now cleanly separated into public vs. private

#### Logic Changes

**`handleCreatePersona()`:**
- Constructs `PrivatePersonaData` if any private fields are filled
- Builds public `metadata` dictionary with public fields only
- Sets `address` to `nil` (now in `privateData`)
- Sets `email` to `publicEmail` (private email is in `privateData`)
- Private data is stored locally, encrypted after server response

**`sendPersonaCreationRequest()`:**
- Uses `persona.metadata` for public attributes
- Sets `address: nil` (not sent to server)
- Sets `isPublic: true` (DID is always viewable)
- Private data is NOT included in server request

**Post-Creation Storage:**
- Saves full persona with `privateData` to PersonaStore
- Encrypts `privateData` using `PrivateDataManager`
- Stores encrypted private data in UserDefaults with key `privateData.<DID>`

---

### 3. PrivateDataManager.swift (NEW FILE)
**Purpose:** Central encryption/decryption management for private data

#### Key Functions:

**Encryption/Decryption:**
```swift
static func encrypt(_ privateData: PersonaProfile.PrivatePersonaData, for did: String) throws -> String
static func decrypt(_ encryptedBase64: String, for did: String) throws -> PersonaProfile.PrivatePersonaData
```

**Key Management:**
- `getEncryptionKey(for:)` - Retrieves or generates AES-256 key
- Keys stored in iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Keys are per-DID: `com.signator.privatedata.<DID>`
- `deleteEncryptionKey(for:)` - Remove key when persona deleted

**Document Signing Support:**
```swift
static func packageForSigning(documentData: Data, privateData: PersonaProfile.PrivatePersonaData, for did: String) throws -> Data
static func extractPrivateData(from encryptedPackage: Data, for did: String) throws -> PersonaProfile.PrivatePersonaData
```

**Supporting Types:**
- `SigningPackage` - Combines document + private data + metadata
- `PrivateDataError` - Error enum with localized descriptions

---

### 4. PERSONA_PRIVACY_ARCHITECTURE.md (NEW FILE)
Comprehensive documentation covering:
- Architecture overview
- Data structure (public vs. private)
- Encryption details (AES-256-GCM)
- Key management (iOS Keychain)
- Document signing workflow
- Security model and threat analysis
- Server communication protocol
- S3 storage format for signed documents
- Migration notes for existing personas
- Template integration guidelines
- Testing examples
- FAQ

---

## Key Architectural Decisions

### 1. Client-Side Encryption Only
Private data is **never** sent to the server in plain text. The server only receives:
- Public metadata (affiliations, social links, public email)
- Public key for verification
- DID and verification method

### 2. Per-DID Encryption Keys
Each persona gets its own AES-256 encryption key, stored in the iOS Keychain. This provides:
- Isolation between personas
- Secure key storage with device-level protection
- Automatic cleanup when persona is deleted

### 3. Document-Time Decryption
Private data is only decrypted when:
- User is signing a document that requires it
- Persona is validated (if `backgroundCheckRequired: true`)
- User authenticates (could add Face ID/Touch ID)

### 4. Encrypted Document Packages
When a document requires private information:
1. Private data is decrypted locally
2. Combined with document and public metadata
3. Package is encrypted using persona's key
4. Encrypted package is zipped and uploaded to S3
5. Document is signed with P-256 key

### 5. Template Integration
Templates can reference private fields using special placeholders:
- `{{PRIVATE.GIVEN_NAME}}` → `privateData.givenName`
- `{{PRIVATE.SSN}}` → `privateData.socialSecurityNumber`
- `{{PRIVATE.ADDRESS}}` → `privateData.privateAddress.*`
- `{{PUBLIC.AFFILIATIONS}}` → `metadata.publicAffiliations`

Template engine decrypts only when filling template, clears immediately after.

---

## Migration Guide

### For Existing Code Using Old Structure

**Old Code:**
```swift
let persona = PersonaProfile(
    // ...
    email: "user@example.com",
    address: PostalAddress(street: "123 Main", city: "Town", ...),
    affiliations: "University",
    socialLinks: "twitter.com/user",
    // ...
)
```

**New Code:**
```swift
// Separate public and private
let publicMetadata: [String: String] = [
    "publicEmail": "public@example.com",
    "publicAffiliations": "University",
    "socialMediaLinks": "twitter.com/user"
]

let privateData = PersonaProfile.PrivatePersonaData(
    givenName: "John",
    privateEmail: "private@example.com",
    socialSecurityNumber: "123-45-6789",
    privateAddress: PostalAddress(street: "123 Main", city: "Town", ...)
)

let persona = PersonaProfile(
    // ...
    email: publicMetadata["publicEmail"], // Public email
    address: nil, // Now in privateData
    affiliations: publicMetadata["publicAffiliations"],
    socialLinks: publicMetadata["socialMediaLinks"],
    metadata: publicMetadata,
    privateData: privateData, // Will be encrypted locally
    // ...
)

// Encrypt private data before storage
let encrypted = try PrivateDataManager.encrypt(privateData, for: persona.dID)
UserDefaults.standard.set(encrypted, forKey: "privateData.\(persona.dID)")
```

### For Document Signing Code

**When preparing document for signing:**
```swift
// Check if document requires private info
if documentRequiresPrivateInfo {
    // Verify persona is validated
    guard persona.backgroundValidated == true || !persona.backgroundCheckRequired else {
        throw SigningError.personaNotValidated
    }
    
    // Retrieve and decrypt private data
    guard let encryptedString = UserDefaults.standard.string(forKey: "privateData.\(persona.dID)") else {
        throw SigningError.noPrivateData
    }
    
    let privateData = try PrivateDataManager.decrypt(encryptedString, for: persona.dID)
    
    // Create signing package
    let package = try PrivateDataManager.packageForSigning(
        documentData: documentData,
        privateData: privateData,
        for: persona.dID
    )
    
    // Upload encrypted package to S3
    try await uploadToS3(package, documentID: documentID)
    
    // Sign document
    let signature = try signDocument(documentData, with: privateKey)
}
```

---

## Security Considerations

### What's Protected
✅ Private data never reaches server  
✅ Private data encrypted at rest (AES-256-GCM)  
✅ Keys stored in iOS Keychain with device-unlock protection  
✅ Per-persona encryption keys (isolation)  
✅ Document packages encrypted before S3 upload  

### What Requires Trust
⚠️ Device security (user must enable passcode)  
⚠️ iOS Keychain (rely on Apple's security)  
⚠️ User validation (background check for sensitive docs)  
⚠️ App code security (code signing, no tampering)  

### Potential Improvements
1. **Biometric Authentication**: Require Face ID/Touch ID before decrypting private data
2. **Key Rotation**: Periodic re-encryption with new keys
3. **Selective Disclosure**: Per-document selection of which private fields to include
4. **Audit Logging**: Local log of when private data is accessed
5. **Secure Enclave**: Store keys in Secure Enclave on supported devices
6. **Data Expiration**: Optional TTL on private fields

---

## Testing Checklist

### Unit Tests
- [x] Encrypt private data with `PrivateDataManager`
- [x] Decrypt private data with `PrivateDataManager`
- [x] Create signing package
- [x] Extract private data from package
- [x] Key generation and storage in Keychain
- [x] Key deletion from Keychain

### Integration Tests
- [ ] Create persona with private data
- [ ] Verify private data NOT sent to server
- [ ] Verify public metadata IS sent to server
- [ ] Sign document with private data
- [ ] Verify encrypted package structure
- [ ] Verify S3 upload format
- [ ] Edit persona and update private data
- [ ] Delete persona and verify key deletion

### UI Tests
- [ ] Fill out persona creation form with all fields
- [ ] Create persona with only DID (no optional fields)
- [ ] Create persona with public fields only
- [ ] Create persona with private fields only
- [ ] Verify form sections render correctly
- [ ] Verify validation messages
- [ ] Verify success/error alerts

---

## Next Steps

1. **PersonaEditView**: Create edit view following same public/private pattern
2. **Document Signing Flow**: Integrate `PrivateDataManager.packageForSigning()`
3. **Template Engine**: Add private field placeholder support
4. **S3 Upload Handler**: Implement encrypted package upload
5. **Persona Deletion**: Ensure `deleteEncryptionKey()` is called
6. **Keychain Migration**: Migrate any existing keys to new format
7. **Biometric Auth**: Add Face ID/Touch ID requirement for private data access
8. **Audit Log**: Log private data access events (locally only)

---

## API Summary

### PrivateDataManager

```swift
// Encrypt private data for storage
let encrypted: String = try PrivateDataManager.encrypt(privateData, for: did)

// Decrypt private data for use
let decrypted: PersonaProfile.PrivatePersonaData = try PrivateDataManager.decrypt(encrypted, for: did)

// Create encrypted package for document signing
let package: Data = try PrivateDataManager.packageForSigning(
    documentData: documentData,
    privateData: privateData,
    for: did
)

// Extract private data from package (verification)
let privateData: PersonaProfile.PrivatePersonaData = try PrivateDataManager.extractPrivateData(
    from: package,
    for: did
)

// Delete encryption key (persona deletion)
try PrivateDataManager.deleteEncryptionKey(for: did)
```

### Storage Pattern

```swift
// Store encrypted private data
let encrypted = try PrivateDataManager.encrypt(privateData, for: did)
UserDefaults.standard.set(encrypted, forKey: "privateData.\(did)")

// Retrieve encrypted private data
guard let encrypted = UserDefaults.standard.string(forKey: "privateData.\(did)") else {
    // No private data stored
    return
}
let privateData = try PrivateDataManager.decrypt(encrypted, for: did)
```

### Form Fields Mapping

| UI Field | Storage Location | Visibility |
|----------|------------------|------------|
| Name | `persona.name` | Public (DID component) |
| Publishing House | `persona.dID` | Public (DID component) |
| DID | `persona.dID` | Public (always visible) |
| Public Affiliations | `metadata["publicAffiliations"]` | Public |
| Social Media Links | `metadata["socialMediaLinks"]` | Public |
| Public Email | `persona.email` | Public |
| Given Name | `privateData.givenName` | Private (encrypted) |
| Aliases | `privateData.aliases` | Private (encrypted) |
| Street | `privateData.privateAddress.street` | Private (encrypted) |
| City | `privateData.privateAddress.city` | Private (encrypted) |
| State/Region | `privateData.privateAddress.state` | Private (encrypted) |
| Zip Code | `privateData.privateAddress.postalCode` | Private (encrypted) |
| Country | `privateData.privateAddress.country` | Private (encrypted) |
| SSN | `privateData.socialSecurityNumber` | Private (encrypted) |
| Private Email | `privateData.privateEmail` | Private (encrypted) |

---

## Questions & Answers

**Q: Why not use end-to-end encryption to the server?**  
A: Private data is so sensitive (SSN, full address) that we don't want it on the server at all, even encrypted. This eliminates server compromise risk entirely.

**Q: What if user gets a new device?**  
A: Keys are stored with `ThisDeviceOnly` flag, so they don't sync. User would need to re-enter private data on new device. Consider implementing secure backup/recovery mechanism.

**Q: Can we sync private data across user's devices?**  
A: Yes, using iCloud Keychain (remove `ThisDeviceOnly` flag), but this requires user consent and adds complexity. Implement as opt-in feature.

**Q: Why UserDefaults for encrypted data instead of Keychain?**  
A: Encrypted data can be relatively large (addresses, names, etc.). Keychain is best for keys/credentials. The encryption key is in Keychain, data can be in UserDefaults.

**Q: Should we implement key rotation?**  
A: For long-lived personas (years), yes. Implement background key rotation that re-encrypts private data with new key periodically.

**Q: How to handle template injection?**  
A: Template engine should:
1. Parse template for `{{PRIVATE.*}}` and `{{PUBLIC.*}}` placeholders
2. Decrypt private data only if private placeholders exist
3. Inject values
4. Clear decrypted data from memory immediately
5. Never log or cache decrypted values

---

## Deployment Notes

### Server Changes Required
None! The server doesn't need to know about private data. It only receives public metadata.

### Database Schema
No server database changes needed. `metadata` field already exists.

### Backwards Compatibility
- Old personas with `address` field: Migrate to `privateData.privateAddress`
- Old personas with `email` field: Determine if public or private
- Old personas without `metadata`: Create empty metadata dict
- Key migration: Generate keys for existing personas on first use

### Rollout Strategy
1. Deploy new client with private data support
2. Existing personas continue to work (no private data)
3. New personas can use private data
4. Migrate existing personas gradually (user-initiated)
5. Monitor encryption key creation in Keychain
6. Monitor private data storage usage
