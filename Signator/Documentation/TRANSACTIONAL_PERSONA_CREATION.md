# Transactional Persona Creation - Implementation Notes

## Problem Statement

If any part of the server registration fails during persona creation, **no orphaned data** should remain in local storage. This requires a strict transactional approach with complete cleanup on failure.

## Solution Architecture

### Order of Operations

```
1. Generate DID (permanent identifier: did:451:xxxxx)
2. Generate Handle (human-readable: name.publisher.451.info)
3. Create Secure Enclave Key
   └─> Private key NEVER leaves hardware
   └─> Only public key is extracted
4. Build PersonaProfileModel
5. Send to Server for Registration
   ├─> SUCCESS: Proceed to step 6
   └─> FAILURE: Execute complete cleanup (step 7)
6. Save Locally (only if server succeeds)
   ├─> PersonaStore (full profile)
   ├─> PrivateDataStore (encrypted sensitive data)
   └─> PersonaManager (lightweight reference)
7. Cleanup on Failure
   ├─> Delete Secure Enclave key
   ├─> Remove from PersonaStore
   ├─> Delete from PrivateDataStore
   └─> Remove from PersonaManager
```

### Critical Components

#### 1. Secure Enclave Key Storage
**File**: `SecureEnclaveKeyStore.swift`

- Keys are stored as `kSecClassGenericPassword` (not `kSecClassKey`)
- The `dataRepresentation` is a **reference handle**, not the actual key
- Private key **never** leaves the Secure Enclave hardware
- Cleanup: `SecureEnclaveKeyStore.deleteKey(for: did)`

#### 2. Persona Profile Storage
**File**: `PersonaStore.swift`

- Stores complete `PersonaProfileModel` with metadata
- Persisted to disk for offline access
- Cleanup: `store.removePersona(withID: did)`

#### 3. Private Data Storage
**File**: `PrivateDataStore.swift`

- Stores encrypted sensitive information (SSN, private address, etc.)
- Separate from public profile for security
- Cleanup: `PrivateDataStore.deletePrivateData(for: did)`

#### 4. Persona Manager
**File**: `PersonaManager.swift`

- In-memory lightweight `Persona` objects
- Used for UI and quick access
- Cleanup: `personaManager.deletePersona(persona)`

## Implementation Details

### Cleanup Function

```swift
private func cleanupFailedPersonaCreation(did: String) async {
    // 1. Delete Secure Enclave key (CRITICAL)
    SecureEnclaveKeyStore.deleteKey(for: did)
    
    // 2. Remove from PersonaStore
    try? store.removePersona(withID: did)
    
    // 3. Delete encrypted private data
    try? PrivateDataStore.deletePrivateData(for: did)
    
    // 4. Remove from PersonaManager
    if let persona = personaManager.personas.first(where: { $0.id == did }) {
        personaManager.deletePersona(persona)
    }
}
```

### Error Scenarios Handled

#### Scenario A: Server Registration Fails
**When**: Server returns error during POST to `/persona`

**Action**:
```swift
do {
    let serverPersona = try await sendPersonaCreationRequest(...)
} catch {
    // Complete cleanup - nothing was saved to server
    await cleanupFailedPersonaCreation(did: didToUse)
    self.errorMessage = error.localizedDescription
    return
}
```

**Result**: All local data deleted, user can retry

#### Scenario B: Local Save Fails After Server Success
**When**: PersonaStore or PrivateDataStore fails after server registration

**Action**:
```swift
do {
    try store.addPersona(fullPersona)
    try PrivateDataStore.savePrivateData(privateData, for: did)
} catch {
    // Emergency cleanup - server has persona but we can't use it
    await cleanupFailedPersonaCreation(did: serverPersona.dID)
    self.errorMessage = "Critical error: Could not save locally..."
    return
}
```

**Result**: Local data deleted, persona exists on server but is inaccessible locally

**Note**: This is a critical error state. The persona is registered on the server but the app cannot use it. The user would need to contact support or use a server API to delete the remote persona.

#### Scenario C: Partial Save Failure
**When**: PersonaStore succeeds but PrivateDataStore fails

**Action**: Same as Scenario B - complete cleanup to maintain consistency

## Security Considerations

### Private Key Protection
- **Secure Enclave keys** are created with P-256 elliptic curve
- Keys are stored with `kSecAttrTokenIDSecureEnclave` flag
- Private keys **never** exist in application memory
- Only public keys are extracted for sharing

### Private Data Encryption
- Sensitive data (SSN, private email, address) stored separately
- Encrypted using iOS keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Not included in server registration payload

### Biometric Protection
- Public personas require biometrics (higher security)
- Private personas don't require biometrics (better UX for anonymous personas)

## Testing Checklist

- [ ] Server registration failure triggers complete cleanup
- [ ] PersonaStore failure triggers complete cleanup
- [ ] PrivateDataStore failure triggers complete cleanup
- [ ] Secure Enclave key is deleted in all failure scenarios
- [ ] No orphaned data remains after any failure
- [ ] Successful creation saves all data correctly
- [ ] Cleanup logs show all 4 steps complete
- [ ] Error messages are clear and actionable

## Known Limitations

### Server Persona Orphaning
If local save fails after server registration succeeds, the persona exists on the server but is unusable by the app. This requires:
- Server-side cleanup API (delete persona by DID)
- OR: User contacts support for manual deletion
- OR: Re-registration attempt (if server allows duplicate DIDs)

**Future Enhancement**: Implement a server-side DELETE endpoint and call it during cleanup if server registration succeeded but local save failed.

## Files Modified

1. `SecureEnclaveKeyStore.swift` - Fixed keychain storage approach
2. `PersonaCreationView.swift` - Added transactional cleanup
3. `TRANSACTIONAL_PERSONA_CREATION.md` - This documentation

## References

- [Apple CryptoKit Documentation](https://developer.apple.com/documentation/cryptokit)
- [Secure Enclave Overview](https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/protecting_keys_with_the_secure_enclave)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
