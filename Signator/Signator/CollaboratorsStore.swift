import Foundation
import Combine

final class CollaboratorsStore: ObservableObject {
    static let shared = CollaboratorsStore()

    @Published private(set) var collaborators: [PersonaResolvedProfile] = []

    private let storageKey = "collaborators_v1"

    private init() {
        load()
    }

    func load() {
        if let data = SharedContainer.sharedDefaults.data(forKey: storageKey) {
            if let decoded = try? JSONDecoder().decode([PersonaResolvedProfile].self, from: data) {
                collaborators = decoded
                return
            }
        }
        collaborators = []
    }

    private func save() {
        if let data = try? JSONEncoder().encode(collaborators) {
            SharedContainer.sharedDefaults.set(data, forKey: storageKey)
        }
    }

    func add(_ profile: PersonaResolvedProfile) {
        // Deduplicate by DID (case-insensitive)
        if collaborators.contains(where: { $0.did.caseInsensitiveCompare(profile.did) == .orderedSame }) {
            return
        }
        collaborators.insert(profile, at: 0)
        save()
        objectWillChange.send()
    }

    func remove(did: String) {
        collaborators.removeAll { $0.did.caseInsensitiveCompare(did) == .orderedSame }
        save()
        objectWillChange.send()
    }

    func contains(did: String) -> Bool {
        collaborators.contains { $0.did.caseInsensitiveCompare(did) == .orderedSame }
    }
}
