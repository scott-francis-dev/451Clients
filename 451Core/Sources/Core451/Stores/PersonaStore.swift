// PersonaStore.swift
// Local storage for PersonaProfile

import Foundation
import os

public final class PersonaStore: ObservableObject {
    public static let shared = PersonaStore()
    private let userDefaultsKey = "persona_profiles_v1"
    private let logger = Logger(subsystem: "org.the451project.wallet", category: "PersonaStore")
    
    @Published private(set) var personas: [PersonaProfile] = []
    
    private init() {
        SharedContainer.ensureDirectories()
        load()
    }
    
    func load() {
        // Try shared defaults first
        if let data = SharedContainer.sharedDefaults.data(forKey: userDefaultsKey) {
            let decoded = try? JSONDecoder().decode([PersonaProfile].self, from: data)
            personas = decoded ?? []
            return
        }
        // Migrate from standard defaults if present
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            personas = []
            return
        }
        let decoded = try? JSONDecoder().decode([PersonaProfile].self, from: data)
        // Save into shared defaults and clear standard
        if let encoded = try? JSONEncoder().encode(decoded ?? []) {
            SharedContainer.sharedDefaults.set(encoded, forKey: userDefaultsKey)
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
        personas = decoded ?? []
    }
    
    func save() {
        let encoded = try? JSONEncoder().encode(personas)
        if let encoded {
            SharedContainer.sharedDefaults.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    public func addPersona(_ persona: PersonaProfile) throws {
        personas.append(persona)
        save()
    }
    
    func removePersona(_ personaId: String) {
        personas.removeAll { $0.dID == personaId }
        save()
    }
    
    func removeAllPersonas() {
        personas.removeAll()
        save()
    }
}
