//
//  PrivateKeyStore.swift
//  451Wallet
//
//  Created by User451 on 4/25/25.
//
//  DEPRECATED: Use SecureEnclaveKeyStore instead
//  This file is kept for backward compatibility only
//

import Foundation
import CryptoKit
import Security

struct PrivateKeyStore {
    
    /// DEPRECATED: Use SecureEnclaveKeyStore.createKey() instead
    /// This method is kept for compatibility but creates a REGULAR key, not Secure Enclave
    @available(*, deprecated, message: "Use SecureEnclaveKeyStore.createKey() for Secure Enclave protection")
    static func savePrivateKey(_ privateKey: P256.Signing.PrivateKey, for personaId: String) throws {
        print("⚠️ [PrivateKeyStore] DEPRECATED: Using legacy key storage. Consider migrating to SecureEnclaveKeyStore")
        
        let tag = personaId.data(using: .utf8)!
        let keyData = privateKey.rawRepresentation
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecValueData as String: keyData,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // Delete existing key if exists
        SecItemDelete(query as CFDictionary)
        
        // Add new key
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw NSError(domain: "PrivateKeyStore", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to save private key: \(status)"])
        }
    }
    
    /// DEPRECATED: Use SecureEnclaveKeyStore.loadKey() instead
    @available(*, deprecated, message: "Use SecureEnclaveKeyStore.loadKey() for Secure Enclave support")
    static func loadPrivateKey(for personaId: String) throws -> P256.Signing.PrivateKey {
        // Try loading from old storage first
        if let oldKey = try? loadLegacyKey(for: personaId) {
            return oldKey
        }
        
        // Try loading from SecureEnclaveKeyStore as fallback
        return try SecureEnclaveKeyStore.loadRegularKey(for: personaId)
    }
    
    private static func loadLegacyKey(for personaId: String) throws -> P256.Signing.PrivateKey {
        let tag = personaId.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let keyData = item as? Data else {
            throw NSError(domain: "PrivateKeyStore", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Private key not found: \(status)"])
        }
        
        return try P256.Signing.PrivateKey(rawRepresentation: keyData)
    }
    
    /// Delete key from both old and new storage locations
    static func deletePrivateKey(for personaId: String) {
        // Delete from legacy storage
        let legacyTag = personaId.data(using: .utf8)!
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: legacyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom
        ]
        SecItemDelete(legacyQuery as CFDictionary)
        
        // Delete from SecureEnclaveKeyStore
        SecureEnclaveKeyStore.deleteKey(for: personaId)
        
        print("✅ [PrivateKeyStore] Deleted keys from all storage locations")
    }
}
