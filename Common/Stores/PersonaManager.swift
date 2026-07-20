//
//  PersonaManager.swift
//  451Wallet
//
//  Created by User451 on 4/25/25.
//

import Foundation
import Combine
import os


struct PersonaServerError: Codable, Error {
    let error: String?
    let message: String?
}

public class PersonaManager: ObservableObject {
    @Published public private(set) var personas: [Persona] = []
    @Published public var activePersonaId: String? = nil {
        didSet {
            SharedContainer.sharedDefaults.set(activePersonaId, forKey: "active_persona_id")
        }
    }
    /// Set to `true` by PersonaCreationView after a successful creation.
    /// PersonasTabView watches this and closes the entire creation sheet,
    /// then resets it to `false`.
    @Published public var dismissCreationFlow: Bool = false

    private let personasKey = "personas_list"
    private let logger = Logger(subsystem: "org.the451project.wallet", category: "PersonaManager")

    public init() {
        SharedContainer.ensureDirectories()
        loadPersonas()
        self.activePersonaId = SharedContainer.sharedDefaults.string(forKey: "active_persona_id")
    }
    
    public func loadPersonas() {
        // 1) Try shared defaults first
        if let data = SharedContainer.sharedDefaults.data(forKey: personasKey),
           let decoded = try? JSONDecoder().decode([Persona].self, from: data) {
            personas = decoded
            return
        }
        // 2) Migrate from standard defaults if present
        if let data = UserDefaults.standard.data(forKey: personasKey),
           let decoded = try? JSONDecoder().decode([Persona].self, from: data) {
            personas = decoded
            // Save into shared defaults and clear standard
            if let encoded = try? JSONEncoder().encode(decoded) {
                SharedContainer.sharedDefaults.set(encoded, forKey: personasKey)
                UserDefaults.standard.removeObject(forKey: personasKey)
            }
            return
        }
        personas = []
    }
    
    public func savePersonas() {
        if let encoded = try? JSONEncoder().encode(personas) {
            SharedContainer.sharedDefaults.set(encoded, forKey: personasKey)
        }
    }
    
    // Local-only insertion used by PersonaCreationView after successful server creation
    public func addPersona(_ persona: Persona) {
        // Prevent duplicates by id
        guard !personas.contains(where: { $0.id == persona.id }) else { return }
        personas.append(persona)
        savePersonas()
    }

    public func deletePersona(_ persona: Persona) {
        personas.removeAll { $0.id == persona.id }
        // If we deleted the active persona, clear it
        if activePersonaId == persona.id {
            activePersonaId = nil
        }
        savePersonas()
        // Delete from both legacy and Secure Enclave storage
        PrivateKeyStore.deletePrivateKey(for: persona.id)
    }
    
    /// Delete all personas and reset the app state - useful for testing
    public func deleteAllPersonas() {
        // Delete private keys for all personas
        for persona in personas {
            PrivateKeyStore.deletePrivateKey(for: persona.id)
        }
        // Clear personas array
        personas.removeAll()
        // Clear active persona
        activePersonaId = nil
        // Save empty state
        savePersonas()
    }
    
    public func setActivePersona(_ persona: Persona) {
        self.activePersonaId = persona.id
    }
     
    public func activePersona() -> Persona? {
        return personas.first(where: { $0.id == activePersonaId })
    }

    public func updatePersona(_ persona: Persona) {
        if let idx = personas.firstIndex(where: { $0.id == persona.id }) {
            personas[idx] = persona
            savePersonas()
        }
    }
    
    public func updatePersonaStatus(personaId: String, status: String) {
        if let idx = personas.firstIndex(where: { $0.id == personaId }) {
            personas[idx].status = status
            savePersonas()
        }
    }
    
    /// Scans the Secure Enclave/Keychain for keys and reports which DIDs have keys
    /// This helps identify orphaned keys that aren't in the personas list
    public func auditSecureEnclaveKeys() {
        logger.info("🔍 [PersonaManager] Auditing Secure Enclave keys...")
        
        // Get all persona IDs from our list
        let knownPersonaIds = Set(personas.map { $0.id })
        logger.info("📋 [PersonaManager] Known personas: \(knownPersonaIds.count)")
        
        // Check which personas have keys
        for persona in personas {
            let hasKey = SecureEnclaveKeyStore.keyExists(for: persona.id)
            logger.info("  - \(persona.name) (\(persona.id)): \(hasKey ? "✅ Has key" : "❌ Missing key")")
        }
        
        // Note: We can't enumerate ALL keys in the keychain without knowing their tags
        // The Secure Enclave doesn't provide a "list all keys" API
        logger.info("ℹ️ [PersonaManager] Note: Cannot enumerate unknown keys without their DIDs")
        logger.info("ℹ️ [PersonaManager] If you created personas but don't see them, the metadata wasn't saved")
    }
    
    /// Manually adds a persona by DID if you know it exists but isn't showing up
    /// This is useful for debugging/recovery scenarios
    public func recoverPersonaByDID(_ did: String) async throws {
        logger.info("🔄 [PersonaManager] Attempting to recover persona: \(did)")
        
        // Check if persona already exists
        if personas.contains(where: { $0.id == did }) {
            logger.info("ℹ️ [PersonaManager] Persona already exists in list")
            return
        }
        
        // Check if key exists
        guard SecureEnclaveKeyStore.keyExists(for: did) else {
            throw NSError(domain: "PersonaManager", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "No key found for DID: \(did)"
            ])
        }
        
        // Try to fetch persona from server
        guard let url = URL(string: "https://api.451.info/personas/\(did)") else {
            throw NSError(domain: "PersonaManager", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Invalid DID format"
            ])
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "PersonaManager", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Failed to fetch persona from server"
            ])
        }
        
        // Decode the server response (you'll need to adjust this based on your API)
        // For now, create a minimal persona
        let persona = Persona(
            id: did,
            controller: did,
            name: "Recovered: \(did.suffix(8))",
            handle: "recovered.\(did.suffix(8))",
            address: nil,
            email: nil,
            affiliations: nil,
            socialLinks: nil,
            publicKeyBase64: "",
            storageEndpoints: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: nil,
            eTag: nil,
            visibility: .private,
            status: "recovered"
        )
        
        addPersona(persona)
        logger.info("✅ [PersonaManager] Recovered persona: \(did)")
    }
}

