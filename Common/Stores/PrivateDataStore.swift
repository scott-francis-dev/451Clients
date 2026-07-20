// PrivateDataStore.swift
// Persistent storage for encrypted private persona data

import Foundation

/// Manages persistent storage of encrypted private data
/// Uses UserDefaults for simplicity, but data is always encrypted
struct PrivateDataStore {
    
    private static let keyPrefix = "privateData"
    
    // MARK: - Storage Operations
    
    /// Save encrypted private data for a persona
    static func savePrivateData(_ privateData: PersonaProfile.PrivatePersonaData, for did: String) throws {
        let encrypted = try PrivateDataManager.encrypt(privateData, for: did)
        let key = storageKey(for: did)
        UserDefaults.standard.set(encrypted, forKey: key)
        print("✅ [PrivateDataStore] Saved encrypted private data for: \(did)")
    }
    
    /// Retrieve and decrypt private data for a persona
    static func loadPrivateData(for did: String) throws -> PersonaProfile.PrivatePersonaData? {
        let key = storageKey(for: did)
        guard let encrypted = UserDefaults.standard.string(forKey: key) else {
            print("ℹ️ [PrivateDataStore] No private data found for: \(did)")
            return nil
        }
        
        let decrypted = try PrivateDataManager.decrypt(encrypted, for: did)
        print("✅ [PrivateDataStore] Loaded private data for: \(did)")
        return decrypted
    }
    
    /// Delete private data for a persona
    static func deletePrivateData(for did: String) {
        let key = storageKey(for: did)
        UserDefaults.standard.removeObject(forKey: key)
        
        // Also delete the encryption key
        try? PrivateDataManager.deleteEncryptionKey(for: did)
        
        print("🗑️ [PrivateDataStore] Deleted private data and encryption key for: \(did)")
    }
    
    /// Check if private data exists for a persona
    static func hasPrivateData(for did: String) -> Bool {
        let key = storageKey(for: did)
        return UserDefaults.standard.string(forKey: key) != nil
    }
    
    /// Update private data for a persona
    static func updatePrivateData(_ privateData: PersonaProfile.PrivatePersonaData, for did: String) throws {
        // Same as save - encryption automatically handles updates
        try savePrivateData(privateData, for: did)
        print("✏️ [PrivateDataStore] Updated private data for: \(did)")
    }
    
    // MARK: - Helpers
    
    private static func storageKey(for did: String) -> String {
        return "\(keyPrefix).\(did)"
    }
    
    // MARK: - Bulk Operations
    
    /// Get all DIDs that have private data stored
    static func allDIDsWithPrivateData() -> [String] {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        
        return allKeys
            .filter { $0.hasPrefix("\(keyPrefix).") }
            .compactMap { key in
                let did = key.replacingOccurrences(of: "\(keyPrefix).", with: "")
                return did.isEmpty ? nil : did
            }
    }
    
    /// Delete all private data (use with caution)
    static func deleteAllPrivateData() {
        let dids = allDIDsWithPrivateData()
        for did in dids {
            deletePrivateData(for: did)
        }
        print("🗑️ [PrivateDataStore] Deleted all private data (\(dids.count) personas)")
    }
    
    // MARK: - Migration Support
    
    /// Migrate old storage format to new format if needed
    static func migrateIfNeeded() {
        // Implement migration logic here if storage format changes
        // For now, this is a placeholder
        print("ℹ️ [PrivateDataStore] Migration check completed")
    }
}

// MARK: - Convenience Extensions

extension PersonaProfile {
    /// Load private data from storage
    mutating func loadPrivateData() throws {
        self.privateData = try PrivateDataStore.loadPrivateData(for: self.dID)
    }
    
    /// Save private data to storage
    func savePrivateData() throws {
        guard let privateData = self.privateData else {
            print("ℹ️ [PersonaProfile] No private data to save for: \(self.dID)")
            return
        }
        try PrivateDataStore.savePrivateData(privateData, for: self.dID)
    }
    
    /// Check if private data is available
    func hasPrivateData() -> Bool {
        return PrivateDataStore.hasPrivateData(for: self.dID)
    }
}
