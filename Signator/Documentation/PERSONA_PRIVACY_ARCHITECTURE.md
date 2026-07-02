# Persona Public/Private Data Architecture

## Overview

The persona system has been refactored to support a clear separation between **public** and **private** data. This architecture ensures that sensitive information is encrypted locally (AES-256-GCM) and only included with documents when absolutely necessary for legal compliance.

## Data Structure

### Core Identity (Always Required)
- **DID**: `name@publishing.house` - Always public and viewable
- **Name**: Display name for the persona
- **Publishing House**: Organization identifier

### Public Fields (Optional, Visible in Metadata)
These fields are visible to anyone who views the persona profile:

- **Public Affiliations**: Organizations, institutions, memberships
- **Social Media Links**: Twitter, LinkedIn, website, etc.
- **Public Email**: Contact email for general communication

### Private Fields (Optional, Encrypted Locally)
These fields are encrypted with AES-256-GCM and stored locally. They are **never** sent to the server in plain text:

- **Given Name**: Legal first name
- **Aliases**: Alternative names or nicknames
- **Private Email**: Confidential email address
- **Social Security Number**: Government ID (encrypted)
- **Full Address**: Street, City, State, Zip, Country (all private)

## Encryption Architecture

### Local Encryption (Client-Side)
1. **Key Generation**: Each DID gets a unique AES-256 encryption key stored in the iOS Keychain
2. **Data Encryption**: Private data is encrypted using AES-GCM before any storage
3. **Secure Storage**: Encrypted data is stored locally; keys never leave the device

### Key Management
- Keys are generated using `SymmetricKey(size: .bits256)`
- Stored in iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Keys are tied to specific DIDs via identifier: `com.signator.privatedata.<DID>`
- Keys are deleted when persona is deleted

### Document Signing Workflow

When signing a document that requires private information (contracts, wills, legal documents):

1. **Validation Check**: Verify the persona is validated (background check if required)
2. **Local Decryption**: Decrypt private data using the DID's encryption key
3. **Package Creation**: Create a signing package containing:
   - The document (Base64-encoded)
   - Private persona data (decrypted)
   - DID and timestamp
4. **Package Encryption**: Encrypt the entire package using AES-256-GCM
5. **Template Injection**: If using a template, private data is injected into placeholders
6. **Storage**: Package is zipped and stored encrypted in S3
7. **Signature**: Document is signed with the persona's private key

### Security Model

```
┌─────────────────────────────────────────────────────┐
│                   PERSONA PROFILE                    │
├─────────────────────────────────────────────────────┤
│  PUBLIC DATA (Metadata)                             │
│  ✓ DID (always visible)                             │
│  ✓ Public Email                                     │
│  ✓ Public Affiliations                              │
│  ✓ Social Media Links                               │
│  ✓ Verification Method (public key)                 │
├─────────────────────────────────────────────────────┤
│  PRIVATE DATA (Encrypted Locally)                   │
│  🔒 Given Name                [AES-256-GCM]          │
│  🔒 Aliases                   [AES-256-GCM]          │
│  🔒 Private Email             [AES-256-GCM]          │
│  🔒 Social Security Number    [AES-256-GCM]          │
│  🔒 Full Address              [AES-256-GCM]          │
├─────────────────────────────────────────────────────┤
│  ENCRYPTION KEY                                     │
│  🔐 Stored in iOS Keychain                          │
│  🔐 Never leaves device                             │
│  🔐 Tied to DID                                     │
└─────────────────────────────────────────────────────┘
```

## Implementation Details

### PersonaProfile Model Updates

```swift
struct PersonaProfile: Codable, Hashable {
    // ... existing fields ...
    
    var metadata: [String: String]?  // Public data goes here
    var privateData: PrivatePersonaData? // Encrypted private data
    
    struct PrivatePersonaData: Codable, Hashable {
        var givenName: String?
        var aliases: String?
        var privateEmail: String?
        var socialSecurityNumber: String?
        var privateAddress: PostalAddress?
    }
}
```

### PrivateDataManager API

```swift
// Encrypt private data
let encrypted = try PrivateDataManager.encrypt(privateData, for: did)

// Decrypt private data
let decrypted = try PrivateDataManager.decrypt(encryptedBase64, for: did)

// Create signing package (document + private data, encrypted)
let package = try PrivateDataManager.packageForSigning(
    documentData: documentData,
    privateData: privateData,
    for: did
)

// Extract private data from package for verification
let privateData = try PrivateDataManager.extractPrivateData(
    from: encryptedPackage,
    for: did
)

// Delete key when persona is removed
try PrivateDataManager.deleteEncryptionKey(for: did)
```

### UI Changes

The `PersonaCreationView` now has three distinct sections:

1. **Persona Identity (Required)**
   - Name, Publishing House, DID
   - Footer: "The DID is always public and viewable"

2. **Public Information (Optional)**
   - Public Affiliations, Social Media Links, Public Email
   - Footer: "Public fields are visible in your persona's metadata"

3. **Private Information (Optional)**
   - Given Name, Aliases, Address, SSN, Private Email
   - Footer: "Private fields are encrypted (AES-256) and only included with signed documents"

## Server Communication

### What Gets Sent to Server

**Public Data** (in `metadata` field):
```json
{
  "metadata": {
    "publicKey": "...",
    "publicAffiliations": "University of Example",
    "socialMediaLinks": "https://twitter.com/example",
    "publicEmail": "public@example.com"
  }
}
```

**Private Data**: 
- **NEVER** sent to server in plain text
- Only stored locally, encrypted
- Only included with documents when signing requires it
- Included as encrypted package stored alongside document in S3

### Document Signing Protocol

When a document requires private information:

1. Client checks if persona is validated (if `backgroundCheckRequired: true`)
2. Client decrypts private data locally
3. For templates: Private data is injected into template fields
4. Document + Private data + Metadata → Create package
5. Package is encrypted with AES-256-GCM
6. Package is zipped and uploaded to S3 (encrypted)
7. Document is signed with persona's P-256 key
8. S3 URL + signature returned to client

### Storage Format in S3

```
document-package-<timestamp>/
├── document.pdf (or original format)
├── private-data.json.encrypted (AES-256-GCM encrypted)
├── signature.der (P-256 signature)
└── metadata.json (public metadata)
```

All files are zipped together and the entire archive is encrypted again before S3 upload.

## Security Considerations

### Threat Model

**Protected Against:**
- ✅ Server compromise (private data never reaches server)
- ✅ Network interception (private data encrypted in transit when with document)
- ✅ Unauthorized access (Keychain protection + device unlock required)
- ✅ Storage compromise (data at rest is encrypted)

**Requires Trust:**
- Device security (device must be secure, passcode enabled)
- iOS Keychain (relies on Apple's Keychain security)
- User validation (background check for sensitive documents)

### Best Practices

1. **Minimal Private Data**: Only collect what's legally required
2. **User Control**: Users choose what private fields to fill
3. **Validation Required**: For sensitive documents, require `backgroundValidated: true`
4. **Template Safety**: Never log or cache decrypted private data
5. **Key Rotation**: Consider implementing key rotation for long-lived personas
6. **Backup Strategy**: Keychain items with `ThisDeviceOnly` don't sync - document this to users

## Migration Notes

### For Existing Personas

If you have existing personas with `address` or `email` fields in the old structure:

1. Old `address` field → Move to `privateData.privateAddress`
2. Old `email` field → Determine if public or private
   - If meant to be public → Move to `metadata.publicEmail`
   - If meant to be private → Move to `privateData.privateEmail`
3. Encrypt `privateData` using `PrivateDataManager`
4. Update persona profile on server

### For Document Templates

Templates should use special placeholders for private data:

- `{{PRIVATE.GIVEN_NAME}}` → Filled from `privateData.givenName`
- `{{PRIVATE.SSN}}` → Filled from `privateData.socialSecurityNumber`
- `{{PRIVATE.ADDRESS}}` → Filled from `privateData.privateAddress`
- `{{PUBLIC.AFFILIATIONS}}` → Filled from `metadata.publicAffiliations`

The template engine should only decrypt private data when actively filling a template, and should clear decrypted values from memory immediately after use.

## Testing

### Unit Tests

```swift
@Test("Encrypt and decrypt private data")
func testPrivateDataEncryption() async throws {
    let privateData = PersonaProfile.PrivatePersonaData(
        givenName: "John",
        aliases: "Johnny",
        privateEmail: "john@private.com",
        socialSecurityNumber: "123-45-6789",
        privateAddress: PersonaProfile.PostalAddress(
            street: "123 Main St",
            city: "Anytown",
            state: "CA",
            postalCode: "12345",
            country: "USA"
        )
    )
    
    let did = "test@example.com"
    let encrypted = try PrivateDataManager.encrypt(privateData, for: did)
    let decrypted = try PrivateDataManager.decrypt(encrypted, for: did)
    
    #expect(decrypted.givenName == "John")
    #expect(decrypted.socialSecurityNumber == "123-45-6789")
}

@Test("Signing package creation")
func testSigningPackage() async throws {
    let documentData = "Sample Document".data(using: .utf8)!
    let privateData = PersonaProfile.PrivatePersonaData(
        givenName: "Jane",
        privateEmail: "jane@private.com"
    )
    
    let did = "jane@example.com"
    let package = try PrivateDataManager.packageForSigning(
        documentData: documentData,
        privateData: privateData,
        for: did
    )
    
    let extracted = try PrivateDataManager.extractPrivateData(
        from: package,
        for: did
    )
    
    #expect(extracted.givenName == "Jane")
}
```

### Integration Tests

Test the full flow:
1. Create persona with private data
2. Store encrypted locally
3. Create document requiring signature
4. Package document with private data
5. Upload encrypted package to S3
6. Verify signature and private data extraction

## Future Enhancements

1. **Key Rotation**: Implement periodic key rotation for long-lived personas
2. **Biometric Unlock**: Require Face ID/Touch ID before decrypting private data
3. **Selective Disclosure**: Allow users to choose which private fields to include per document
4. **Audit Log**: Log when private data is decrypted (locally only)
5. **Data Expiration**: Option to set expiration on private data fields
6. **Multi-Device Sync**: Explore secure multi-device sync via iCloud Keychain

## FAQ

**Q: What if I lose my device?**
A: Private data is encrypted with a key stored in the device's Keychain with `ThisDeviceOnly` protection. If the device is lost, the private data cannot be recovered unless you have a backup. Consider implementing a secure recovery mechanism.

**Q: Can the server access private data?**
A: No. Private data is never sent to the server in plain text. The server only receives public metadata and encrypted packages when documents are signed.

**Q: Do I need to fill in private fields?**
A: No. Private fields are completely optional. You can create a persona with just a DID and public information.

**Q: When should I use background check validation?**
A: For documents with legal significance (contracts, wills, deeds), set `backgroundCheckRequired: true`. This ensures the persona is validated before private data can be used in signing.

**Q: How do I edit private data later?**
A: The PersonaEditView should follow the same pattern - decrypt existing private data, allow editing, re-encrypt with the same key.
