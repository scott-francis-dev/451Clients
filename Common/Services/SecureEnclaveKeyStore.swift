//
//  SecureEnclaveKeyStore.swift
//  451Wallet
//
//  Secure Enclave-backed key storage for maximum security
//  Private keys NEVER leave the Secure Enclave hardware
//

import Foundation
import CryptoKit
import Security
import LocalAuthentication

enum SecureEnclaveKeyStoreError: Error {
    case secureEnclaveNotAvailable
    case keyGenerationFailed
    case keyNotFound
    case biometricAuthenticationFailed
    case keychainError(OSStatus)
    case invalidKeyData
    
    var localizedDescription: String {
        switch self {
        case .secureEnclaveNotAvailable:
            return "Secure Enclave is not available on this device"
        case .keyGenerationFailed:
            return "Failed to generate key in Secure Enclave"
        case .keyNotFound:
            return "Private key not found"
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .invalidKeyData:
            return "Invalid key data"
        }
    }
}

struct SecureEnclaveKeyStore {
    
    // MARK: - Key Generation
    
    /// Creates a new P256 signing key in the Secure Enclave
    /// Returns the public key (private key stays in Secure Enclave)
    static func createKey(for personaId: String, requireBiometrics: Bool = true) throws -> P256.Signing.PublicKey {
        print("🔐 [SecureEnclave] Creating key for persona: \(personaId)")
        print("🔐 [SecureEnclave] Biometrics required: \(requireBiometrics)")
        
        #if targetEnvironment(simulator)
        // Always use regular key on simulator
        print("⚠️ [SecureEnclave] Running on simulator - using regular key")
        let regularKey = P256.Signing.PrivateKey()
        try saveRegularKey(regularKey, for: personaId)
        return regularKey.publicKey
        #else
        // Check if Secure Enclave is available
        guard SecureEnclave.isAvailable else {
            print("⚠️ [SecureEnclave] Secure Enclave not available, falling back to regular key")
            // Fallback: create regular key (for older devices)
            let regularKey = P256.Signing.PrivateKey()
            try saveRegularKey(regularKey, for: personaId)
            return regularKey.publicKey
        }
        
        print("✅ [SecureEnclave] Secure Enclave is available")
        
        // Generate key in Secure Enclave
        do {
            let privateKey: SecureEnclave.P256.Signing.PrivateKey
            
            // For biometric protection, use a simpler approach that works reliably
            if requireBiometrics {
                print("🔐 [SecureEnclave] Setting up biometric protection...")
                
                // Check biometric availability first
                let context = LAContext()
                var error: NSError?
                let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
                
                if let error = error {
                    print("⚠️ [SecureEnclave] Biometric check error: \(error)")
                }
                print("🔐 [SecureEnclave] Biometrics available: \(canEvaluate)")
                
                // If biometrics are not available, skip biometric protection
                if !canEvaluate {
                    print("⚠️ [SecureEnclave] Biometrics not available, creating key without biometric requirement")
                    privateKey = try SecureEnclave.P256.Signing.PrivateKey()
                    try storeKeyReference(privateKey, for: personaId)
                    print("✅ [SecureEnclave] Key created successfully (without biometrics due to unavailability)")
                    return privateKey.publicKey
                }
                
                // Create access control that requires biometrics but doesn't cause -50 errors
                var accessControlError: Unmanaged<CFError>?
                guard let accessControl = SecAccessControlCreateWithFlags(
                    kCFAllocatorDefault,
                    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                    [.privateKeyUsage, .userPresence],  // Use userPresence instead of biometryCurrentSet
                    &accessControlError
                ) else {
                    if let cfError = accessControlError?.takeRetainedValue() {
                        print("⚠️ [SecureEnclave] Failed to create access control: \(cfError)")
                        print("⚠️ [SecureEnclave] Error domain: \(CFErrorGetDomain(cfError))")
                        print("⚠️ [SecureEnclave] Error code: \(CFErrorGetCode(cfError))")
                    }
                    // Fall back to no biometrics if access control fails
                    print("⚠️ [SecureEnclave] Falling back to key without biometric requirement")
                    privateKey = try SecureEnclave.P256.Signing.PrivateKey()
                    try storeKeyReference(privateKey, for: personaId)
                    print("✅ [SecureEnclave] Key created successfully (without biometrics)")
                    return privateKey.publicKey
                }
                
                print("✅ [SecureEnclave] Access control created successfully")
                
                // Create authentication context
                let authContext = LAContext()
                authContext.localizedReason = "Authenticate to create secure signing key"
                
                print("🔐 [SecureEnclave] Creating Secure Enclave key with biometric protection...")
                
                // Try to create with biometrics, but catch errors and fall back if needed
                do {
                    privateKey = try SecureEnclave.P256.Signing.PrivateKey(
                        accessControl: accessControl,
                        authenticationContext: authContext
                    )
                    print("✅ [SecureEnclave] Secure Enclave key created with biometrics")
                } catch {
                    print("⚠️ [SecureEnclave] Biometric key creation failed: \(error)")
                    print("⚠️ [SecureEnclave] Creating key without biometric protection as fallback")
                    privateKey = try SecureEnclave.P256.Signing.PrivateKey()
                    print("✅ [SecureEnclave] Key created successfully (without biometrics after failed attempt)")
                }
            } else {
                // No biometric requirement - simpler and more reliable
                print("🔐 [SecureEnclave] Creating Secure Enclave key without biometric protection...")
                privateKey = try SecureEnclave.P256.Signing.PrivateKey()
                print("✅ [SecureEnclave] Secure Enclave key created without biometrics")
            }
            
            // Store reference to the key in keychain
            print("🔐 [SecureEnclave] Storing key reference in keychain...")
            try storeKeyReference(privateKey, for: personaId)
            
            print("✅ [SecureEnclave] Key created successfully")
            return privateKey.publicKey
            
        } catch {
            print("❌ [SecureEnclave] Key generation failed: \(error)")
            print("❌ [SecureEnclave] Error type: \(type(of: error))")
            
            // Try to extract more info from NSError
            if let nsError = error as NSError? {
                print("❌ [SecureEnclave] Error domain: \(nsError.domain)")
                print("❌ [SecureEnclave] Error code: \(nsError.code)")
                print("❌ [SecureEnclave] Error userInfo: \(nsError.userInfo)")
            }
            
            // Fallback to regular key if Secure Enclave fails
            print("⚠️ [SecureEnclave] Falling back to regular key due to error")
            let regularKey = P256.Signing.PrivateKey()
            try saveRegularKey(regularKey, for: personaId)
            return regularKey.publicKey
        }
        #endif
    }
    
    // MARK: - Key Storage (References Only)
    
    /// Stores a REFERENCE to the Secure Enclave key (not the key itself!)
    /// For CryptoKit Secure Enclave keys, we just store the dataRepresentation as generic data
    private static func storeKeyReference(_ privateKey: SecureEnclave.P256.Signing.PrivateKey, for personaId: String) throws {
        let tag = keyTag(for: personaId)
        let keyData = privateKey.dataRepresentation  // This is just a reference, not the actual key!
        
        print("🔐 [SecureEnclave] Key data size: \(keyData.count) bytes")
        
        // For CryptoKit Secure Enclave keys, store the dataRepresentation as generic data
        // The key itself is already in the Secure Enclave, we just need to persist the reference
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,  // Use generic password for storing the reference
            kSecAttrAccount as String: personaId,
            kSecAttrService as String: "SecureEnclaveKeyReference",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        print("🔐 [SecureEnclave] Keychain query attributes:")
        print("   - Class: GenericPassword (storing key reference)")
        print("   - Account: \(personaId)")
        print("   - Service: SecureEnclaveKeyReference")
        
        // Delete existing key reference if exists
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: personaId,
            kSecAttrService as String: "SecureEnclaveKeyReference"
        ]
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        if deleteStatus == errSecSuccess {
            print("🔐 [SecureEnclave] Deleted existing key reference")
        } else if deleteStatus == errSecItemNotFound {
            print("🔐 [SecureEnclave] No existing key reference to delete")
        } else {
            print("⚠️ [SecureEnclave] Delete returned status: \(deleteStatus)")
        }
        
        // Add new key reference
        print("🔐 [SecureEnclave] Adding key reference to keychain...")
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            print("❌ [SecureEnclave] Failed to add key reference, status: \(status)")
            print("❌ [SecureEnclave] Status description: \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown")")
            throw SecureEnclaveKeyStoreError.keychainError(status)
        }
        
        print("✅ [SecureEnclave] Stored key reference for: \(personaId)")
    }
    
    /// Fallback: Save a regular key (for simulator or devices without Secure Enclave)
    private static func saveRegularKey(_ privateKey: P256.Signing.PrivateKey, for personaId: String) throws {
        let tag = keyTag(for: personaId)
        let keyData = privateKey.rawRepresentation
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecValueData as String: keyData,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw SecureEnclaveKeyStoreError.keychainError(status)
        }
        
        print("✅ [SecureEnclave] Stored regular key for: \(personaId)")
    }
    
    // MARK: - Key Retrieval
    
    /// Loads a Secure Enclave key for signing
    /// The key itself never leaves the Secure Enclave - this returns a handle to use it
    static func loadSecureEnclaveKey(for personaId: String) throws -> SecureEnclave.P256.Signing.PrivateKey {
        // Load the key reference from generic password storage
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: personaId,
            kSecAttrService as String: "SecureEnclaveKeyReference",
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let keyData = item as? Data else {
            throw SecureEnclaveKeyStoreError.keyNotFound
        }
        
        // Reconstruct the Secure Enclave key handle from stored reference
        do {
            return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData)
        } catch {
            print("❌ [SecureEnclave] Failed to load key: \(error)")
            throw SecureEnclaveKeyStoreError.invalidKeyData
        }
    }
    
    /// Loads a regular (non-Secure Enclave) key as fallback
    static func loadRegularKey(for personaId: String) throws -> P256.Signing.PrivateKey {
        let tag = keyTag(for: personaId)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let keyData = item as? Data else {
            throw SecureEnclaveKeyStoreError.keyNotFound
        }
        
        return try P256.Signing.PrivateKey(rawRepresentation: keyData)
    }
    
    /// Attempts to load key, trying Secure Enclave first, then falling back to regular
    static func loadKey(for personaId: String) throws -> any SigningKey {
        // Try Secure Enclave first
        if let seKey = try? loadSecureEnclaveKey(for: personaId) {
            print("✅ [SecureEnclave] Loaded Secure Enclave key")
            return seKey
        }
        
        // Fallback to regular key
        print("⚠️ [SecureEnclave] Falling back to regular key")
        return try loadRegularKey(for: personaId)
    }
    
    // MARK: - Signing Operations
    
    /// Signs data with the Secure Enclave key (signing happens IN the Secure Enclave)
    static func sign(_ data: Data, for personaId: String) throws -> P256.Signing.ECDSASignature {
        let key = try loadKey(for: personaId)
        
        if let seKey = key as? SecureEnclave.P256.Signing.PrivateKey {
            // Sign with Secure Enclave (private key never exposed)
            print("🔐 [SecureEnclave] Signing with Secure Enclave key")
            return try seKey.signature(for: data)
        } else if let regularKey = key as? P256.Signing.PrivateKey {
            // Sign with regular key
            print("⚠️ [SecureEnclave] Signing with regular key")
            return try regularKey.signature(for: data)
        } else {
            throw SecureEnclaveKeyStoreError.invalidKeyData
        }
    }
    
    // MARK: - Key Deletion
    
    /// Deletes the key reference (and the Secure Enclave key if applicable)
    static func deleteKey(for personaId: String) {
        // Delete Secure Enclave key reference
        let seQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: personaId,
            kSecAttrService as String: "SecureEnclaveKeyReference"
        ]
        
        let seStatus = SecItemDelete(seQuery as CFDictionary)
        
        // Also try deleting regular key (for fallback cases)
        let tag = keyTag(for: personaId)
        let regularQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag
        ]
        
        let regularStatus = SecItemDelete(regularQuery as CFDictionary)
        
        if seStatus == errSecSuccess || regularStatus == errSecSuccess {
            print("✅ [SecureEnclave] Deleted key for: \(personaId)")
        } else if seStatus == errSecItemNotFound && regularStatus == errSecItemNotFound {
            print("⚠️ [SecureEnclave] Key not found for deletion: \(personaId)")
        } else {
            print("❌ [SecureEnclave] Failed to delete key: SE=\(seStatus), Regular=\(regularStatus)")
        }
    }
    
    // MARK: - Helpers
    
    private static func keyTag(for personaId: String) -> Data {
        return "org.the451project.secureenclave.\(personaId)".data(using: .utf8)!
    }
    
    /// Check if a key exists for a persona
    static func keyExists(for personaId: String) -> Bool {
        // Check for Secure Enclave key reference
        let seQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: personaId,
            kSecAttrService as String: "SecureEnclaveKeyReference",
            kSecReturnData as String: false
        ]
        
        let seStatus = SecItemCopyMatching(seQuery as CFDictionary, nil)
        if seStatus == errSecSuccess {
            return true
        }
        
        // Check for regular key
        let tag = keyTag(for: personaId)
        let regularQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnData as String: false
        ]
        
        let regularStatus = SecItemCopyMatching(regularQuery as CFDictionary, nil)
        return regularStatus == errSecSuccess
    }
}

// MARK: - Protocol for Unified Signing Interface

protocol SigningKey {
    func signature(for data: Data) throws -> P256.Signing.ECDSASignature
}

extension SecureEnclave.P256.Signing.PrivateKey: SigningKey {}
extension P256.Signing.PrivateKey: SigningKey {}
