//
//  SecureEnclaveQuickReference.swift
//  451Wallet
//
//  Quick reference for common Secure Enclave operations
//  Copy-paste these examples into your code
//

import Foundation
import CryptoKit

// MARK: - Common Operations Quick Reference

/*
 ═══════════════════════════════════════════════════════════════
 1. CREATE A NEW PERSONA WITH SECURE ENCLAVE KEY
 ═══════════════════════════════════════════════════════════════
 */

func exampleCreatePersona() throws {
    // 1. Generate DID first
    let did = "did:451:\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16))"
    
    // 2. Create key in Secure Enclave (private key NEVER leaves hardware)
    let publicKey = try SecureEnclaveKeyStore.createKey(
        for: did,
        requireBiometrics: true  // Face ID/Touch ID required for signing
    )
    
    // 3. Extract public key to share (100% safe!)
    let publicKeyRaw = publicKey.rawRepresentation
    let publicKeyBase64 = publicKeyRaw.base64EncodedString()
    
    // 4. Use publicKeyBase64 in persona profile
    print("✅ Created persona with DID: \(did)")
    print("🔑 Public key (safe to share): \(publicKeyBase64)")
    
    // Private key is already secured in Secure Enclave - no need to save it!
}

/*
 ═══════════════════════════════════════════════════════════════
 2. SIGN A DOCUMENT
 ═══════════════════════════════════════════════════════════════
 */

func exampleSignDocument(documentData: Data, personaDid: String) throws {
    // 1. Hash the document
    let documentHash = SHA256.hash(data: documentData)
    let hashData = Data(documentHash)
    
    // 2. Sign with Secure Enclave (may prompt for Face ID)
    //    Signing happens INSIDE the Secure Enclave hardware
    let signature = try SecureEnclaveKeyStore.sign(hashData, for: personaDid)
    
    // 3. Extract signature for sharing/transmission
    let signatureBase64 = signature.derRepresentation.base64EncodedString()
    
    print("✅ Document signed")
    print("📄 Hash: \(hashData.base64EncodedString().prefix(20))...")
    print("✍️ Signature: \(signatureBase64.prefix(20))...")
    
    // Share hashData and signature - both are safe!
}

/*
 ═══════════════════════════════════════════════════════════════
 3. SIGN WITH DOCUMENT SIGNING SERVICE
 ═══════════════════════════════════════════════════════════════
 */

func exampleSignWithService(documentId: String, persona: Persona, documentHash: Data) async throws {
    // Use the new Secure Enclave-aware method
    let response = try await DocumentSigningService.addSignatureWithSecureEnclave(
        documentId: documentId,
        signerDID: persona.id,
        signerPublicKey: persona.publicKeyBase64,
        documentHash: documentHash,
        role: .author,
        previousEntryID: nil  // or previous entry ID from PROOF stage
    )
    
    print("✅ Signature added to ledger")
    print("📝 Ledger entry ID: \(response.ledgerEntryID)")
    print("📊 Ledger index: \(response.ledgerIndex)")
}

/*
 ═══════════════════════════════════════════════════════════════
 4. VERIFY A SIGNATURE
 ═══════════════════════════════════════════════════════════════
 */

func exampleVerifySignature(
    signature: P256.Signing.ECDSASignature,
    data: Data,
    publicKeyBase64: String
) throws -> Bool {
    // 1. Reconstruct public key from base64
    guard let publicKeyData = Data(base64Encoded: publicKeyBase64) else {
        throw NSError(domain: "InvalidPublicKey", code: -1)
    }
    
    let publicKey = try P256.Signing.PublicKey(x963Representation: publicKeyData)
    
    // 2. Verify signature
    let isValid = publicKey.isValidSignature(signature, for: data)
    
    if isValid {
        print("✅ Signature is valid - document is authentic")
    } else {
        print("❌ Signature is invalid - document may be tampered")
    }
    
    return isValid
}

/*
 ═══════════════════════════════════════════════════════════════
 5. DELETE A PERSONA (CLEANUP)
 ═══════════════════════════════════════════════════════════════
 */

func exampleDeletePersona(persona: Persona) {
    // This cleans up keys from BOTH legacy and Secure Enclave storage
    PrivateKeyStore.deletePrivateKey(for: persona.id)
    
    print("✅ Deleted keys for: \(persona.id)")
}

/*
 ═══════════════════════════════════════════════════════════════
 6. CHECK IF KEY EXISTS
 ═══════════════════════════════════════════════════════════════
 */

func exampleCheckKeyExists(personaDid: String) {
    if SecureEnclaveKeyStore.keyExists(for: personaDid) {
        print("✅ Key exists for: \(personaDid)")
    } else {
        print("❌ No key found for: \(personaDid)")
    }
}

/*
 ═══════════════════════════════════════════════════════════════
 7. ERROR HANDLING
 ═══════════════════════════════════════════════════════════════
 */

func exampleErrorHandling(data: Data, personaDid: String) {
    do {
        let signature = try SecureEnclaveKeyStore.sign(data, for: personaDid)
        print("✅ Signed successfully")
        
    } catch SecureEnclaveKeyStoreError.secureEnclaveNotAvailable {
        // Device doesn't have Secure Enclave (very rare, old devices)
        print("⚠️ Secure Enclave not available on this device")
        
    } catch SecureEnclaveKeyStoreError.biometricAuthenticationFailed {
        // User cancelled Face ID or authentication failed
        print("⚠️ Biometric authentication failed or cancelled")
        print("💡 Ask user to try again")
        
    } catch SecureEnclaveKeyStoreError.keyNotFound {
        // Key doesn't exist for this persona
        print("❌ Key not found for persona: \(personaDid)")
        print("💡 Persona may have been deleted or never created")
        
    } catch SecureEnclaveKeyStoreError.keychainError(let status) {
        // Keychain operation failed
        print("❌ Keychain error: \(status)")
        
    } catch {
        // Other unexpected errors
        print("❌ Unexpected error: \(error)")
    }
}

/*
 ═══════════════════════════════════════════════════════════════
 8. CONVENIENCE: SIGN AND GET BASE64
 ═══════════════════════════════════════════════════════════════
 */

func exampleSignAndGetBase64(data: Data, personaDid: String) throws -> String {
    let signature = try SecureEnclaveKeyStore.sign(data, for: personaDid)
    return signature.derRepresentation.base64EncodedString()
}

/*
 ═══════════════════════════════════════════════════════════════
 9. CREATE KEY WITHOUT BIOMETRICS (FOR TESTING)
 ═══════════════════════════════════════════════════════════════
 */

func exampleCreateKeyNoAuth(personaDid: String) throws {
    // For private/temporary personas that don't need biometric protection
    let publicKey = try SecureEnclaveKeyStore.createKey(
        for: personaDid,
        requireBiometrics: false  // No Face ID required
    )
    
    print("✅ Created key without biometric requirement")
}

/*
 ═══════════════════════════════════════════════════════════════
 10. FULL DOCUMENT SIGNING WORKFLOW
 ═══════════════════════════════════════════════════════════════
 */

func exampleFullSigningWorkflow(
    documentData: Data,
    persona: Persona
) async throws {
    print("📄 Starting document signing workflow...")
    
    // 1. Hash document
    let documentHash = SHA256.hash(data: documentData)
    let hashData = Data(documentHash)
    print("1️⃣ Document hashed")
    
    // 2. Upload document and get PROOF entry
    let uploadResponse = try await DocumentSigningService.uploadDocument(
        documentData: documentData,
        originalFilename: "example.pdf"
    )
    print("2️⃣ Document uploaded - PROOF entry created: \(uploadResponse.ledgerProofEntryID)")
    
    // 3. Sign document (creates SIGN entry) - Secure Enclave signing happens here!
    let signResponse = try await DocumentSigningService.addSignatureWithSecureEnclave(
        documentId: uploadResponse.documentId,
        signerDID: persona.id,
        signerPublicKey: persona.publicKeyBase64,
        documentHash: hashData,
        role: .author,
        previousEntryID: uploadResponse.ledgerProofEntryID
    )
    print("3️⃣ Document signed - SIGN entry created: \(signResponse.ledgerEntryID)")
    
    // 4. Optionally finalize (creates ATTEST entry)
    let finalizeResponse = try await DocumentSigningService.finalizeDocument(
        documentId: uploadResponse.documentId,
        finalizedBy: persona.id,
        signatureEntryIDs: [signResponse.ledgerEntryID]
    )
   
    
    print("✅ Complete workflow finished!")
}

/*
 ═══════════════════════════════════════════════════════════════
 KEY TAKEAWAYS
 ═══════════════════════════════════════════════════════════════
 
 ✅ DO:
 - Use SecureEnclaveKeyStore.createKey() for new personas
 - Use SecureEnclaveKeyStore.sign() for signing
 - Share public keys freely
 - Share signatures freely
 - Handle biometric authentication failures gracefully
 
 ❌ DON'T:
 - Try to access the private key value (you can't!)
 - Try to export the private key (impossible)
 - Expect keys to sync via iCloud (they don't)
 - Forget to handle Face ID cancellation
 
 🔐 SECURITY:
 - Private keys NEVER leave the Secure Enclave hardware
 - Signing happens INSIDE the Secure Enclave
 - Your app can't access private keys even if compromised
 - Biometric protection adds extra security layer
 
 📱 COMPATIBILITY:
 - Works on all modern iPhones/iPads (2013+)
 - Simulator automatically falls back to regular keys
 - Legacy personas still work via compatibility layer
 
 ═══════════════════════════════════════════════════════════════
 */

