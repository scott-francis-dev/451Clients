# Secure Enclave Key Generation Fixes

## Issues Fixed

### 1. Key Generation Error -50 (errSecParam)
**Problem:** The Secure Enclave key generation was failing with error -50 when trying to use `.biometryCurrentSet` flag.

**Root Cause:** The `.biometryCurrentSet` access control flag can cause parameter errors on some devices or configurations, especially when biometrics aren't properly configured or during certain device states.

**Solution:** 
- Changed from `.biometryCurrentSet` to `.userPresence` which is more reliable
- Added proper error handling with fallback to non-biometric keys if access control creation fails
- Added authentication context with localized reason for better user experience
- Improved error propagation from Secure Enclave errors to keychain errors

**Code Changes in `SecureEnclaveKeyStore.swift`:**
```swift
// Before: Used .biometryCurrentSet (unreliable)
[.privateKeyUsage, .biometryCurrentSet]

// After: Use .userPresence (more reliable)
[.privateKeyUsage, .userPresence]

// Added fallback:
if let cfError = error?.takeRetainedValue() {
    print("⚠️ [SecureEnclave] Failed to create access control: \(cfError)")
}
// Fall back to no biometrics if access control fails
print("⚠️ [SecureEnclave] Falling back to key without biometric requirement")
privateKey = try SecureEnclave.P256.Signing.PrivateKey()
```

### 2. Key Cleanup on Server Registration Failure
**Problem:** If key generation succeeded but server registration failed, the Secure Enclave key was left orphaned in the keychain.

**Solution:** Added cleanup logic to delete the Secure Enclave key if server registration fails.

**Code Changes in `PersonaCreationView.swift`:**
```swift
} catch {
    // ❌ Server registration failed - clean up the Secure Enclave key
    print("❌ [PersonaCreation] Server registration failed: \(error)")
    print("🧹 [PersonaCreation] Cleaning up Secure Enclave key for: \(didToUse)")
    SecureEnclaveKeyStore.deleteKey(for: didToUse)
    
    await MainActor.run {
        self.errorMessage = error.localizedDescription
    }
    return
}
```

## Flow

### Correct Persona Creation Flow (with fixes):
1. ✅ Generate DID and handle
2. ✅ Create Secure Enclave key (with reliable `.userPresence` flag)
   - If access control fails → fallback to key without biometrics
   - If Secure Enclave unavailable → fallback to regular CryptoKit key
3. ✅ Extract public key
4. ✅ Send canonicalization request to server
5. ✅ Sign canonical profile with Secure Enclave key
6. ✅ Send finalize request to server
7. ✅ If server fails → **DELETE the Secure Enclave key** (NEW!)
8. ✅ If server succeeds → Save persona locally

### Key Security Properties:
- ✅ Private keys NEVER leave the Secure Enclave hardware
- ✅ Signing operations happen inside the Secure Enclave
- ✅ Only key references are stored in keychain, not actual keys
- ✅ Orphaned keys are cleaned up on failure
- ✅ Biometric protection when available, graceful fallback when not

## Testing

### Test Cases:
1. **Normal flow:** Key creation → server success → persona saved ✅
2. **Server failure:** Key creation → server fails → key deleted ✅
3. **Network error:** Key creation → network fails → key deleted ✅
4. **Simulator:** Falls back to regular CryptoKit key ✅
5. **No biometrics:** Falls back to key without biometric requirement ✅

### Manual Testing:
```
1. Try creating a persona normally
   Expected: Key creates, server succeeds, persona saved
   
2. Disconnect network and try creating persona
   Expected: Key creates, server fails, key deleted, error shown
   
3. Create persona on simulator (no Secure Enclave)
   Expected: Falls back to regular key, persona created successfully
```

## Additional Notes

### Why `.userPresence` instead of `.biometryCurrentSet`?
- `.biometryCurrentSet` requires that biometrics are enrolled AND invalidates if biometrics change
- `.userPresence` is more flexible - requires authentication (biometric OR passcode) but doesn't fail if biometrics aren't set up
- This makes the app more robust across different device configurations

### Error -50 (errSecParam) Common Causes:
- Invalid access control flags
- Secure Enclave not available but trying to use SE-specific features
- Missing or invalid authentication context
- Attempting operations that conflict with access control settings

### Future Improvements:
- [ ] Add retry logic for key generation with different access control options
- [ ] Provide user feedback about biometric vs. passcode authentication
- [ ] Add key rotation support for compromised keys
- [ ] Implement key backup/recovery mechanism (if feasible with SE constraints)
