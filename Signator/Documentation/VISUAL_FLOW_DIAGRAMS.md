# Visual Flow Diagrams

## 1. Persona Creation Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    USER FILLS OUT FORM                       │
├─────────────────────────────────────────────────────────────┤
│  ✅ Required: DID (name@publishing.house)                   │
│  📢 Optional Public:                                         │
│     • Public Affiliations                                    │
│     • Social Media Links                                     │
│     • Public Email                                           │
│  🔒 Optional Private:                                        │
│     • Given Name                                             │
│     • Aliases                                                │
│     • Address (Street, City, State, Zip, Country)           │
│     • Social Security Number                                 │
│     • Private Email                                          │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ User taps "Create Persona"
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              handleCreatePersona() EXECUTION                 │
├─────────────────────────────────────────────────────────────┤
│  1. Generate P-256 key pair                                  │
│  2. Build public metadata dictionary                         │
│  3. Build private data struct (if fields filled)             │
│  4. Create PersonaProfile with:                              │
│     • Public data → metadata field                           │
│     • Private data → privateData field                       │
└─────────────────────────────────────────────────────────────┘
                           │
                ┌──────────┴──────────┐
                │                      │
                ▼                      ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│   SEND TO SERVER          │  │   STORE LOCALLY           │
├──────────────────────────┤  ├──────────────────────────┤
│ POST /api/persona        │  │ PersonaStore.addPersona  │
│                          │  │                          │
│ Request Body:            │  │ PrivateDataStore.save    │
│ {                        │  │   ↓                      │
│   "dID": "...",          │  │ PrivateDataManager       │
│   "name": "...",         │  │   .encrypt()             │
│   "metadata": {          │  │   ↓                      │
│     "publicEmail": "...", │  │ iOS Keychain             │
│     "publicAffiliations" │  │   (AES-256 key)          │
│   },                     │  │   ↓                      │
│   "verificationMethod":  │  │ UserDefaults             │
│   ...                    │  │   (encrypted data)       │
│ }                        │  │                          │
│                          │  │ PrivateKeyStore          │
│ ❌ NO PRIVATE DATA!      │  │   (P-256 key)            │
└──────────────────────────┘  └──────────────────────────┘
         │
         │ Server Response
         ▼
┌─────────────────────────────────────────────────────────────┐
│                   SUCCESS / PERSONA CREATED                  │
├─────────────────────────────────────────────────────────────┤
│  • Server persona stored                                     │
│  • Private data encrypted locally                            │
│  • Encryption key in Keychain                                │
│  • P-256 signing key stored                                  │
│  • Added to PersonaManager                                   │
│  • Set as active persona                                     │
└─────────────────────────────────────────────────────────────┘
```

## 2. Document Signing Flow (Without Private Data)

```
┌─────────────────────────────────────────────────────────────┐
│               USER SELECTS DOCUMENT TO SIGN                  │
│                  (Simple Document)                           │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│         signDocumentWithPrivateInfo()                        │
│         requiresPrivateData: false                           │
├─────────────────────────────────────────────────────────────┤
│  1. Load persona from PersonaStore                           │
│  2. Load P-256 signing key                                   │
│  3. Hash document (SHA-256)                                  │
│  4. Sign hash with private key                               │
│  5. Create public metadata                                   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              SIGNED DOCUMENT PACKAGE                         │
├─────────────────────────────────────────────────────────────┤
│  • document.dat          (original document)                 │
│  • signature.base64      (P-256 signature)                   │
│  • metadata.json         (public metadata)                   │
│                                                              │
│  ❌ No private data package                                  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  UPLOAD TO S3 (Optional)                     │
│  ZIP → Encrypt (AES-256) → Upload                            │
└─────────────────────────────────────────────────────────────┘
```

## 3. Document Signing Flow (With Private Data)

```
┌─────────────────────────────────────────────────────────────┐
│         USER SELECTS DOCUMENT TO SIGN                        │
│         (Contract / Will / Legal Document)                   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│         signDocumentWithPrivateInfo()                        │
│         requiresPrivateData: true                            │
├─────────────────────────────────────────────────────────────┤
│  1. Check if persona.backgroundCheckRequired                 │
│  2. Verify persona.backgroundValidated == true               │
│  3. Load persona from PersonaStore                           │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│           DECRYPT PRIVATE DATA (CLIENT-SIDE)                 │
├─────────────────────────────────────────────────────────────┤
│  PrivateDataStore.loadPrivateData(for: did)                  │
│    ↓                                                         │
│  Retrieve from UserDefaults (encrypted)                      │
│    ↓                                                         │
│  Get AES-256 key from Keychain                               │
│    ↓                                                         │
│  PrivateDataManager.decrypt()                                │
│    ↓                                                         │
│  🔓 PrivatePersonaData (in memory, temporary)                │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              CREATE ENCRYPTED PACKAGE                        │
├─────────────────────────────────────────────────────────────┤
│  PrivateDataManager.packageForSigning()                      │
│    ↓                                                         │
│  SigningPackage {                                            │
│    document: Base64,                                         │
│    privateData: PrivatePersonaData,                          │
│    did: String,                                              │
│    timestamp: String                                         │
│  }                                                           │
│    ↓                                                         │
│  Encrypt entire package (AES-256-GCM)                        │
│    ↓                                                         │
│  🔒 Encrypted package                                        │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│            SIGN DOCUMENT WITH P-256 KEY                      │
├─────────────────────────────────────────────────────────────┤
│  1. Hash document (SHA-256)                                  │
│  2. Sign with P-256 private key                              │
│  3. Create public metadata                                   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              SIGNED DOCUMENT PACKAGE                         │
├─────────────────────────────────────────────────────────────┤
│  • document.dat              (original document)             │
│  • signature.base64          (P-256 signature)               │
│  • metadata.json             (public metadata)               │
│  • private-data.encrypted    (AES-256 encrypted package)     │
│                                                              │
│  ✅ Private data included (encrypted!)                       │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    UPLOAD TO S3                              │
├─────────────────────────────────────────────────────────────┤
│  1. ZIP all files together                                   │
│  2. Encrypt ZIP with AES-256                                 │
│  3. Upload to S3 bucket                                      │
│  4. Store S3 URL + encryption key (securely)                 │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│           🔒 CLEAR PRIVATE DATA FROM MEMORY                  │
│  Decrypted private data is immediately cleared               │
└─────────────────────────────────────────────────────────────┘
```

## 4. Template Filling Flow

```
┌─────────────────────────────────────────────────────────────┐
│                  TEMPLATE DOCUMENT                           │
├─────────────────────────────────────────────────────────────┤
│  LAST WILL AND TESTAMENT                                     │
│                                                              │
│  I, {{PRIVATE.GIVEN_NAME}}, residing at                      │
│  {{PRIVATE.ADDRESS.FULL}}, being of sound mind...            │
│                                                              │
│  Contact: {{PRIVATE.EMAIL}}                                  │
│  SSN: {{PRIVATE.SSN}}                                        │
│                                                              │
│  Public Affiliations: {{PUBLIC.AFFILIATIONS}}                │
│  Signed: {{NAME}} ({{DID}})                                  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│           fillTemplate() - Parse Placeholders                │
├─────────────────────────────────────────────────────────────┤
│  Detected placeholders:                                      │
│  • {{PRIVATE.GIVEN_NAME}}         → needs private data       │
│  • {{PRIVATE.ADDRESS.FULL}}       → needs private data       │
│  • {{PRIVATE.EMAIL}}              → needs private data       │
│  • {{PRIVATE.SSN}}                → needs private data       │
│  • {{PUBLIC.AFFILIATIONS}}        → use metadata             │
│  • {{NAME}}, {{DID}}              → use persona              │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│         DECRYPT PRIVATE DATA (Temporary)                     │
├─────────────────────────────────────────────────────────────┤
│  PrivateDataStore.loadPrivateData(for: did)                  │
│    ↓                                                         │
│  🔓 PrivatePersonaData (in memory)                           │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              FILL PLACEHOLDERS                               │
├─────────────────────────────────────────────────────────────┤
│  • {{PRIVATE.GIVEN_NAME}}      → "John Smith"                │
│  • {{PRIVATE.ADDRESS.FULL}}    → "123 Main St, Anytown..."   │
│  • {{PRIVATE.EMAIL}}           → "john@private.com"          │
│  • {{PRIVATE.SSN}}             → "123-45-6789"               │
│  • {{PUBLIC.AFFILIATIONS}}     → "University of Example"     │
│  • {{NAME}}                    → "John Smith"                │
│  • {{DID}}                     → "john@example.com"          │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│           🔒 CLEAR PRIVATE DATA FROM MEMORY                  │
│  defer { /* clear sensitive data */ }                        │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  FILLED DOCUMENT                             │
├─────────────────────────────────────────────────────────────┤
│  LAST WILL AND TESTAMENT                                     │
│                                                              │
│  I, John Smith, residing at                                  │
│  123 Main St, Anytown, CA, 12345, USA, being of sound...     │
│                                                              │
│  Contact: john@private.com                                   │
│  SSN: 123-45-6789                                            │
│                                                              │
│  Public Affiliations: University of Example                  │
│  Signed: John Smith (john@example.com)                       │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│         CONVERT TO PDF → SIGN → ENCRYPT → UPLOAD            │
└─────────────────────────────────────────────────────────────┘
```

## 5. Storage Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         iOS DEVICE                                   │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  PersonaStore (Core Data / File Storage)                             │
├─────────────────────────────────────────────────────────────────────┤
│  PersonaProfile {                                                    │
│    dID: "john@example.com"                                           │
│    name: "John Smith"                                                │
│    email: "john@public.com"                              [PUBLIC]    │
│    metadata: {                                                       │
│      "publicKey": "...",                                             │
│      "publicAffiliations": "University",                 [PUBLIC]    │
│      "socialMediaLinks": "twitter.com/john"              [PUBLIC]    │
│    }                                                                 │
│    privateData: nil                    ❌ NOT STORED HERE            │
│  }                                                                   │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  UserDefaults (Encrypted Private Data)                               │
├─────────────────────────────────────────────────────────────────────┤
│  Key: "privateData.john@example.com"                                 │
│  Value: "a4F9xK2p...encrypted-base64..."         [ENCRYPTED]         │
│                                                                      │
│  This is PrivatePersonaData encrypted with AES-256-GCM               │
│  Only decryptable with key from Keychain                             │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  iOS Keychain (Encryption Keys)                                      │
├─────────────────────────────────────────────────────────────────────┤
│  Account: "com.signator.privatedata.john@example.com"                │
│  Value: [32 bytes of AES-256 key]                [SECURE]            │
│                                                                      │
│  Protection: kSecAttrAccessibleWhenUnlockedThisDeviceOnly            │
│  • Requires device to be unlocked                                    │
│  • Does not sync to iCloud                                           │
│  • Tied to this device only                                          │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  PrivateKeyStore (P-256 Signing Keys)                                │
├─────────────────────────────────────────────────────────────────────┤
│  Key: "john@example.com"                                             │
│  Value: P256.Signing.PrivateKey                  [SECURE]            │
│                                                                      │
│  Used for signing documents                                          │
│  Separate from encryption keys                                       │
└─────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────┐
│                         SERVER                                       │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  Database (Public Persona Data Only)                                 │
├─────────────────────────────────────────────────────────────────────┤
│  PersonaProfile {                                                    │
│    dID: "john@example.com"                                           │
│    name: "John Smith"                                                │
│    email: "john@public.com"                              [PUBLIC]    │
│    metadata: {                                                       │
│      "publicKey": "...",                                             │
│      "publicAffiliations": "University",                 [PUBLIC]    │
│      "socialMediaLinks": "twitter.com/john"              [PUBLIC]    │
│    }                                                                 │
│    verificationMethod: [...]                                         │
│  }                                                                   │
│                                                                      │
│  ❌ NO PRIVATE DATA - Server never sees it!                          │
└─────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────┐
│                      S3 STORAGE                                      │
│               (Only when document is signed)                         │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  s3://bucket/signed-doc-12345-1234567890/package.encrypted           │
├─────────────────────────────────────────────────────────────────────┤
│  [Double-Encrypted ZIP Archive]                                      │
│                                                                      │
│  Inside (after first decryption):                                    │
│  ├─ document.dat                         [ORIGINAL DOC]              │
│  ├─ signature.base64                     [P-256 SIGNATURE]           │
│  ├─ metadata.json                        [PUBLIC METADATA]           │
│  └─ private-data.encrypted               [AES-256 ENCRYPTED]         │
│                                                                      │
│  Private data is double-encrypted:                                   │
│  1. First encryption: PrivatePersonaData + document                  │
│  2. Second encryption: Entire ZIP archive                            │
│                                                                      │
│  🔒 Private data only accessible with correct keys                   │
└─────────────────────────────────────────────────────────────────────┘
```

## 6. Security Layers

```
┌────────────────────────────────────────────────────────────┐
│              SECURITY LAYER DIAGRAM                         │
└────────────────────────────────────────────────────────────┘

Layer 1: Device Security
├─ iOS Passcode/Face ID/Touch ID
├─ Secure Enclave (on supported devices)
└─ Device Encryption (FileVault equivalent)

Layer 2: Keychain Protection
├─ kSecAttrAccessibleWhenUnlockedThisDeviceOnly
├─ No iCloud sync (device-specific)
├─ Hardware-backed encryption
└─ OS-level protection

Layer 3: AES-256-GCM Encryption
├─ Industry-standard encryption algorithm
├─ Authenticated encryption (prevents tampering)
├─ Unique keys per persona
└─ Nonce-based (prevents replay attacks)

Layer 4: Network Security
├─ HTTPS/TLS for all server communication
├─ Certificate pinning (recommended)
├─ Private data never in network requests
└─ Encrypted packages for S3 uploads

Layer 5: Storage Isolation
├─ PersonaStore: Public data only
├─ UserDefaults: Encrypted private data
├─ Keychain: Encryption keys
└─ PrivateKeyStore: Signing keys

Layer 6: Memory Protection
├─ Decrypt only when needed
├─ Clear from memory immediately
├─ No caching of decrypted data
└─ Defer blocks for cleanup

Layer 7: Access Control
├─ Background validation required
├─ Per-document authorization
├─ Biometric auth (future)
└─ Audit logging (future)
```

## 7. Threat Model

```
┌────────────────────────────────────────────────────────────┐
│                  THREAT ANALYSIS                            │
└────────────────────────────────────────────────────────────┘

✅ PROTECTED AGAINST:

├─ Server Compromise
│  └─ Private data never reaches server
│      → No risk even if server is hacked

├─ Network Interception (MITM)
│  └─ Private data encrypted before transmission
│      → Intercepted data is useless

├─ Storage Access
│  └─ Private data encrypted at rest
│      → UserDefaults data is encrypted

├─ App Cloning/Jailbreak
│  └─ Keychain keys don't copy
│      → Even with full file access, can't decrypt

├─ Database Dump
│  └─ Server database has no private data
│      → SQL injection or backup leak is safe

└─ Lost Device (with passcode)
   └─ Keychain requires device unlock
       → Data inaccessible without passcode

⚠️ VULNERABLE TO:

├─ Device Compromise (unlocked)
│  └─ If attacker has unlocked device
│      → Can run app and access private data
│      ✅ Mitigation: Add biometric auth

├─ App Vulnerability
│  └─ If app has security flaw
│      → Could leak decrypted data
│      ✅ Mitigation: Code review, security audit

├─ User Error
│  └─ If user screenshots or shares
│      → Private data exposed by user
│      ✅ Mitigation: User education, warnings

├─ Lost Device (no passcode)
│  └─ If device has no passcode
│      → Keychain may be accessible
│      ✅ Mitigation: Require passcode

└─ Memory Forensics
   └─ While private data is decrypted
       → Could be extracted from RAM
       ✅ Mitigation: Clear memory, use Secure Enclave

RECOMMENDATIONS:

1. Add biometric authentication before decrypting
2. Implement memory zeroing for sensitive data
3. Add audit logging (local only)
4. Use Secure Enclave on supported devices
5. Implement data expiration/auto-lock
6. Add rate limiting for decryption attempts
7. Warn user if no device passcode
8. Implement selective disclosure per document
```

---

This visual guide complements the detailed documentation and shows the complete flow of data through the system. All private data remains encrypted on the device and is only decrypted when absolutely necessary for document signing.
