// PrivateDataManager.swift
// Manages encryption and decryption of private persona data using AES-256-GCM

import Foundation
import CryptoKit
import Security

/// Manages the encryption and secure storage of private persona data
/// Private data includes sensitive information like SSN, private email, full address
/// This data is encrypted locally and only decrypted when needed for document signing
struct PrivateDataManager {
    
    // MARK: - Encryption/Decryption
    
    /// Encrypt private persona data using AES-256-GCM
    /// - Parameters:
    ///   - privateData: The private data to encrypt
    ///   - did: The DID to associate with this private data
    /// - Returns: Encrypted data as Base64 string
    static func encrypt(_ privateData: PersonaProfile.PrivatePersonaData, for did: String) throws -> String {
        let key = try getEncryptionKey(for: did)
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(privateData)
        
        let sealedBox = try AES.GCM.seal(jsonData, using: key)
        guard let combined = sealedBox.combined else {
            throw PrivateDataError.encryptionFailed
        }
        
        return combined.base64EncodedString()
    }
    
    /// Decrypt private persona data
    /// - Parameters:
    ///   - encryptedBase64: Base64-encoded encrypted data
    ///   - did: The DID associated with this private data
    /// - Returns: Decrypted private persona data
    static func decrypt(_ encryptedBase64: String, for did: String) throws -> PersonaProfile.PrivatePersonaData {
        guard let encryptedData = Data(base64Encoded: encryptedBase64) else {
            throw PrivateDataError.invalidEncryptedData
        }
        
        let key = try getEncryptionKey(for: did)
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        let decoder = JSONDecoder()
        return try decoder.decode(PersonaProfile.PrivatePersonaData.self, from: decryptedData)
    }
    
    // MARK: - Key Management
    
    /// Get or create encryption key for a DID
    /// Keys are stored securely in the Keychain
    private static func getEncryptionKey(for did: String) throws -> SymmetricKey {
        let keychainKey = "com.signator.privatedata.\(did)"
        
        // Try to retrieve existing key from Keychain
        if let existingKeyData = try? retrieveKeyFromKeychain(identifier: keychainKey) {
            return SymmetricKey(data: existingKeyData)
        }
        
        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        // Store in Keychain
        try storeKeyInKeychain(keyData, identifier: keychainKey)
        
        return newKey
    }
    
    // MARK: - Keychain Operations
    
    private static func storeKeyInKeychain(_ keyData: Data, identifier: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PrivateDataError.keychainError(status)
        }
    }
    
    private static func retrieveKeyFromKeychain(identifier: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data else {
            throw PrivateDataError.keychainError(status)
        }
        
        return keyData
    }
    
    /// Delete encryption key for a DID (use when deleting persona)
    static func deleteEncryptionKey(for did: String) throws {
        let keychainKey = "com.signator.privatedata.\(did)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PrivateDataError.keychainError(status)
        }
    }
    
    // MARK: - Document Signing Support
    
    /// Prepare private data for document signing
    /// This creates a package containing the document and private data, encrypted together
    /// - Parameters:
    ///   - documentData: The document to sign
    ///   - privateData: Private persona data
    ///   - did: The DID signing the document
    /// - Returns: Encrypted package as Data
    static func packageForSigning(documentData: Data, privateData: PersonaProfile.PrivatePersonaData, for did: String) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        // Create package structure
        let package = SigningPackage(
            document: documentData.base64EncodedString(),
            privateData: privateData,
            did: did,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        
        let packageJSON = try encoder.encode(package)
        
        // Encrypt the entire package
        let key = try getEncryptionKey(for: did)
        let sealedBox = try AES.GCM.seal(packageJSON, using: key)
        guard let combined = sealedBox.combined else {
            throw PrivateDataError.encryptionFailed
        }
        
        return combined
    }
    
    /// Extract private data from encrypted package for verification
    static func extractPrivateData(from encryptedPackage: Data, for did: String) throws -> PersonaProfile.PrivatePersonaData {
        let key = try getEncryptionKey(for: did)
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedPackage)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        let decoder = JSONDecoder()
        let package = try decoder.decode(SigningPackage.self, from: decryptedData)
        
        return package.privateData
    }
}

// MARK: - Supporting Types

struct SigningPackage: Codable {
    let document: String // Base64-encoded document
    let privateData: PersonaProfile.PrivatePersonaData
    let did: String
    let timestamp: String
}

enum PrivateDataError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidEncryptedData
    case keychainError(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt private data"
        case .decryptionFailed:
            return "Failed to decrypt private data"
        case .invalidEncryptedData:
            return "Invalid encrypted data format"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        }
    }
}
