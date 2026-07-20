// VCStore.swift
// Stores Verifiable Credentials received by each persona.
// Uses the shared app-group UserDefaults so the widget/extension can read them too.

import Foundation
import Combine
import os

final class VCStore: ObservableObject {

    static let shared = VCStore()

    @Published private(set) var credentials: [VerifiableCredential] = []

    private let logger = Logger(subsystem: "org.the451project.wallet", category: "VCStore")
    private let keyPrefix = "vcs_for_"

    private init() {}

    // MARK: - Per-Persona Access

    /// All VCs stored for the given persona DID.
    func credentials(for personaDID: String) -> [VerifiableCredential] {
        let key = storageKey(personaDID)
        guard let data = SharedContainer.sharedDefaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([VerifiableCredential].self, from: data)) ?? []
    }

    /// Adds a VC to a persona's wallet. Ignores duplicates (by credential id).
    func add(_ vc: VerifiableCredential, to personaDID: String) {
        var vcs = credentials(for: personaDID)
        guard !vcs.contains(where: { $0.id == vc.id }) else { return }
        vcs.append(vc)
        save(vcs, for: personaDID)
        logger.info("[VCStore] Stored VC \(vc.id) for \(personaDID)")
        // Publish update so any observing view refreshes
        DispatchQueue.main.async { [weak self] in
            self?.credentials = vcs
        }
    }

    /// Removes a VC by credential id from a persona's wallet.
    func remove(credentialID: String, from personaDID: String) {
        var vcs = credentials(for: personaDID)
        vcs.removeAll { $0.id == credentialID }
        save(vcs, for: personaDID)
    }

    /// Loads credentials for the active persona into the published property.
    func loadForPersona(_ personaDID: String) {
        credentials = credentials(for: personaDID)
    }

    // MARK: - Private

    private func storageKey(_ personaDID: String) -> String {
        // Hash the DID so it's safe as a UserDefaults key
        keyPrefix + personaDID.replacingOccurrences(of: ":", with: "_")
    }

    private func save(_ vcs: [VerifiableCredential], for personaDID: String) {
        let key = storageKey(personaDID)
        if let encoded = try? JSONEncoder().encode(vcs) {
            SharedContainer.sharedDefaults.set(encoded, forKey: key)
        }
    }
}
