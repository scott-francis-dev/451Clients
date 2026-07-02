# Secure Enclave Architecture Diagrams

## 1. Key Generation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         YOUR APP                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. User creates new persona                                    │
│     ↓                                                            │
│  2. Call: SecureEnclaveKeyStore.createKey(for: did)            │
│     ↓                                                            │
│  ┌──────────────────────────────────────────────┐              │
│  │  SecureEnclaveKeyStore                       │              │
│  │  ↓                                            │              │
│  │  Check: SecureEnclave.isAvailable?           │              │
│  └──────────────────────────────────────────────┘              │
│     ↓                                                            │
└─────┼────────────────────────────────────────────────────────────┘
      ↓
┌─────────────────────────────────────────────────────────────────┐
│               SECURE ENCLAVE (Hardware Chip)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  3. Generate P256 private key IN HARDWARE                       │
│     ↓                                                            │
│  4. Store private key IN SECURE ENCLAVE                         │
│     • Encrypted with hardware key                               │
│     • Cannot be extracted                                       │
│     • Protected by biometrics                                   │
│     ↓                                                            │
│  5. Return ONLY public key                                      │
│     ↓                                                            │
└─────┼────────────────────────────────────────────────────────────┘
      ↓
┌─────────────────────────────────────────────────────────────────┐
│                         YOUR APP                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  6. Receive public key (safe!)                                  │
│     ↓                                                            │
│  7. Convert to Base64                                           │
│     ↓                                                            │
│  8. Share publicly in persona profile                           │
│     ↓                                                            │
│  9. Send to server                                              │
│                                                                  │
│  ✅ Private key NEVER seen by app!                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Document Signing Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         YOUR APP                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. User signs document                                         │
│     ↓                                                            │
│  2. Hash document: SHA256(document)                             │
│     ↓                                                            │
│  3. Call: SecureEnclaveKeyStore.sign(hash, for: did)           │
│     ↓                                                            │
│  4. Send hash to Secure Enclave                                │
│     ↓                                                            │
└─────┼────────────────────────────────────────────────────────────┘
      ↓
┌─────────────────────────────────────────────────────────────────┐
│               SECURE ENCLAVE (Hardware Chip)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  5. Check biometric authentication                              │
│     ↓                                                            │
│     Face ID / Touch ID prompt                                   │
│     ↓                                                            │
│  6. User authenticates ✓                                        │
│     ↓                                                            │
│  7. Load private key FROM SECURE STORAGE                        │
│     • Key never leaves Secure Enclave!                          │
│     ↓                                                            │
│  8. Sign hash with private key                                  │
│     signature = ECDSA_Sign(hash, privateKey)                    │
│     ↓                                                            │
│  9. Return ONLY signature                                       │
│     ↓                                                            │
└─────┼────────────────────────────────────────────────────────────┘
      ↓
┌─────────────────────────────────────────────────────────────────┐
│                         YOUR APP                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  10. Receive signature (safe!)                                  │
│      ↓                                                           │
│  11. Convert to DER format                                      │
│      ↓                                                           │
│  12. Encode as Base64                                           │
│      ↓                                                           │
│  13. Send to server with:                                       │
│      • Document hash                                            │
│      • Signature                                                │
│      • Public key (for verification)                            │
│                                                                  │
│  ✅ Private key NEVER exposed!                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 3. Security Boundaries

```
╔═══════════════════════════════════════════════════════════════╗
║                    SECURE ENCLAVE CHIP                         ║
║                     (Hardware Isolated)                        ║
╠═══════════════════════════════════════════════════════════════╣
║                                                                ║
║  🔒 PRIVATE KEYS                                               ║
║     • Generated here                                           ║
║     • Stored here                                              ║
║     • NEVER leave here                                         ║
║                                                                ║
║  🔒 SIGNING OPERATIONS                                         ║
║     • Happen here                                              ║
║     • Use keys stored here                                     ║
║     • Protected by biometrics                                  ║
║                                                                ║
║  ❌ CANNOT ACCESS FROM:                                        ║
║     • Your app                                                 ║
║     • Other apps                                               ║
║     • Operating system                                         ║
║     • Debugger                                                 ║
║     • Jailbreak tools                                          ║
║     • Physical extraction                                      ║
║                                                                ║
╚═══════════════════════════════════════════════════════════════╝
                           ↕️
            (Only signatures and public keys)
                           ↕️
┌───────────────────────────────────────────────────────────────┐
│                       YOUR APP CODE                            │
│                    (Normal App Sandbox)                        │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│  ✅ CAN ACCESS:                                                │
│     • Public keys                                              │
│     • Signatures                                               │
│     • Key references (not actual keys)                         │
│                                                                │
│  ✅ CAN DO:                                                    │
│     • Request key generation                                   │
│     • Request signing                                          │
│     • Share public keys                                        │
│     • Verify signatures                                        │
│                                                                │
│  ❌ CANNOT ACCESS:                                             │
│     • Private key values                                       │
│     • Private key bytes                                        │
│     • Secure Enclave internals                                 │
│                                                                │
└───────────────────────────────────────────────────────────────┘
```

## 4. What Data Flows Where

```
                    PUBLIC KEY
                        ↓
    ┌───────────────────────────────────────┐
    │ Your App → Server → Everyone          │
    │ ✅ SAFE TO SHARE                      │
    └───────────────────────────────────────┘

                    SIGNATURE
                        ↓
    ┌───────────────────────────────────────┐
    │ Your App → Server → Anyone Verifying  │
    │ ✅ SAFE TO SHARE                      │
    └───────────────────────────────────────┘

                   PRIVATE KEY
                        ↓
    ┌───────────────────────────────────────┐
    │ 🔒 STAYS IN SECURE ENCLAVE            │
    │ ❌ NEVER LEAVES HARDWARE              │
    │ ❌ NEVER ACCESSIBLE TO APP            │
    │ ❌ CANNOT BE EXPORTED                 │
    └───────────────────────────────────────┘

               SIGNING OPERATION
                        ↓
    ┌───────────────────────────────────────┐
    │ 1. App sends data → Secure Enclave    │
    │ 2. Secure Enclave signs internally    │
    │ 3. Secure Enclave → signature → App   │
    │ ✅ PRIVATE KEY NEVER EXPOSED          │
    └───────────────────────────────────────┘
```

## 5. Comparison: Legacy vs. Secure Enclave

```
┌─────────────────────────────────────────────────────────────────┐
│                    LEGACY APPROACH (OLD)                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────┐                                            │
│  │   App Memory    │                                            │
│  ├─────────────────┤                                            │
│  │ Private Key 🔓  │  ← Vulnerable!                             │
│  │ Public Key ✓    │                                            │
│  │ Signature ✓     │                                            │
│  └─────────────────┘                                            │
│          ↕️                                                       │
│  ┌─────────────────┐                                            │
│  │    Keychain     │                                            │
│  ├─────────────────┤                                            │
│  │ Private Key 🔓  │  ← Can be extracted!                       │
│  └─────────────────┘                                            │
│                                                                  │
│  ⚠️ RISKS:                                                       │
│  • Private key in app memory                                    │
│  • Can be debugged                                              │
│  • Can be extracted from keychain                               │
│  • Vulnerable to memory dumps                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────┐
│               SECURE ENCLAVE APPROACH (NEW)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────┐                                            │
│  │   App Memory    │                                            │
│  ├─────────────────┤                                            │
│  │ Public Key ✓    │  ← Safe!                                   │
│  │ Signature ✓     │  ← Safe!                                   │
│  │ Key Reference   │  ← Just a pointer, not the key!            │
│  └─────────────────┘                                            │
│                                                                  │
│  ╔═══════════════════════════════════════╗                      │
│  ║     SECURE ENCLAVE (Hardware)         ║                      │
│  ╠═══════════════════════════════════════╣                      │
│  ║ 🔒 Private Key (ENCRYPTED)            ║                      │
│  ║ 🔒 Signing Operations                 ║                      │
│  ║ 🔒 Biometric Protection               ║                      │
│  ╚═══════════════════════════════════════╝                      │
│     ↑                                                            │
│     └─ Hardware isolated, cannot be accessed!                   │
│                                                                  │
│  ✅ BENEFITS:                                                    │
│  • Private key never in app memory                              │
│  • Cannot be debugged                                           │
│  • Cannot be extracted                                          │
│  • Hardware-enforced protection                                 │
│  • Biometric authentication required                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 6. Trust Model

```
┌───────────────────────────────────────────────────────────────┐
│                WHO CAN ACCESS WHAT?                            │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│  PUBLIC KEY:                                                   │
│    ✅ Your app                                                 │
│    ✅ Your server                                              │
│    ✅ Other users                                              │
│    ✅ Anyone on the internet                                   │
│    → Used for signature verification                           │
│                                                                │
│  SIGNATURE:                                                    │
│    ✅ Your app                                                 │
│    ✅ Your server                                              │
│    ✅ Anyone verifying the document                            │
│    → Proves document authenticity                              │
│                                                                │
│  PRIVATE KEY:                                                  │
│    ❌ Your app                                                 │
│    ❌ Your server                                              │
│    ❌ Other apps                                               │
│    ❌ Operating system                                         │
│    ❌ Apple                                                    │
│    ❌ Hackers                                                  │
│    ❌ Government (even with court order!)                      │
│    ✅ ONLY: Secure Enclave (hardware)                          │
│    → Never accessible, locked in hardware                      │
│                                                                │
└───────────────────────────────────────────────────────────────┘
```

## 7. User Experience Flow

```
USER CREATES PERSONA
        ↓
   App generates key
        ↓
   [No user action needed]
        ↓
   ✅ Persona created
   🔐 Key secured in hardware


USER SIGNS DOCUMENT
        ↓
   App requests signature
        ↓
   ┌─────────────────────┐
   │   Face ID Prompt    │
   │   👤               │
   │  "Sign with your    │
   │   face to confirm"  │
   └─────────────────────┘
        ↓
   User authenticates
        ↓
   Secure Enclave signs
        ↓
   ✅ Document signed


VERIFIER CHECKS SIGNATURE
        ↓
   Gets: document + signature + public key
        ↓
   Runs: publicKey.isValidSignature(signature, for: document)
        ↓
   ✅ Valid → Document is authentic
   ❌ Invalid → Document may be tampered
```

## 8. Security Levels

```
┌──────────────────────────────────────────────────────────────┐
│              SECURITY LEVEL COMPARISON                        │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  SOFTWARE KEYS (Regular CryptoKit)                           │
│  ▓░░░░░░░░░ 20% Security                                     │
│  • Keys in app memory                                        │
│  • Can be extracted                                          │
│  • Vulnerable to attacks                                     │
│                                                               │
│  KEYCHAIN STORAGE (iOS Keychain)                             │
│  ▓▓▓▓▓░░░░░ 50% Security                                     │
│  • Keys encrypted                                            │
│  • Can still be extracted with tools                         │
│  • Some protection                                           │
│                                                               │
│  SECURE ENCLAVE (Hardware)                                   │
│  ▓▓▓▓▓▓▓▓▓▓ 100% Security                                    │
│  • Keys in dedicated chip                                    │
│  • Physically isolated                                       │
│  • Cannot be extracted                                       │
│  • Hardware-enforced                                         │
│  • Biometric protection                                      │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## Key Takeaways

1. **Private keys NEVER leave the Secure Enclave hardware**
2. **Your app only sees public keys and signatures**
3. **Signing happens inside the Secure Enclave**
4. **Biometric authentication protects usage**
5. **Even you (the developer) cannot access private keys**

This is as secure as cryptography gets on mobile devices! 🔒✨
