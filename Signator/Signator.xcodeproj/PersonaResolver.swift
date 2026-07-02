import Foundation
import os

// MARK: - Identifier parsing

enum PersonaIdentifierInput: Equatable {
    case me
    case raw(String) // @handle, shortId, or DID as typed (server resolves)
}

struct PersonaIdentifierParser {
    static func parse(_ raw: String) -> PersonaIdentifierInput? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased() == "@me" { return .me }
        return .raw(trimmed)
    }
}

// MARK: - Resolved profile (lightweight)

public struct PersonaResolvedProfile: Codable, Identifiable, Hashable {
    // Canonical identifier
    public var id: String { did }

    public let did: String
    public let guid: String?
    public let shortId: String?
    public let handle: String?
    public let prettyDID: String?
    public let name: String?

    public var displayName: String {
        // Prefer explicit name, then prettyDID, then @handle, then DID
        if let name, !name.isEmpty { return name }
        if let prettyDID, !prettyDID.isEmpty { return prettyDID }
        if let handle, !handle.isEmpty { return "@\(handle)" }
        return did
    }

    enum CodingKeys: String, CodingKey {
        case did = "dID"
        case guid
        case shortId
        case handle
        case prettyDID
        case name
    }
}

// MARK: - Resolver service

protocol PersonaResolvingService {
    func resolve(_ input: PersonaIdentifierInput) async throws -> PersonaResolvedProfile
}

final class PersonaResolver: PersonaResolvingService {
    private let baseURLString: String
    private let session: URLSession
    private let personaManager: PersonaManager

    // Simple in-memory alias cache (handle, shortId, did -> profile)
    private var cache: [String: PersonaResolvedProfile] = [:]
    private let cacheFileURL: URL = SharedContainer.resolverCacheURL
    private let logger = Logger(subsystem: "org.the451project.wallet", category: "PersonaResolver")

    init(baseURLString: String = ServerConfig.baseURL, session: URLSession = .shared, personaManager: PersonaManager) {
        self.baseURLString = baseURLString
        self.session = session
        self.personaManager = personaManager
        loadCacheFromDisk()
    }

    func resolve(_ input: PersonaIdentifierInput) async throws -> PersonaResolvedProfile {
        switch input {
        case .me:
            // Resolve locally using active persona
            guard let me = personaManager.activePersona() else {
                throw NSError(domain: "PersonaResolver", code: 1, userInfo: [NSLocalizedDescriptionKey: "No active persona for @me"])
            }
            // Build a minimal profile using local info
            let profile = PersonaResolvedProfile(
                did: me.id,
                guid: me.id, // If GUID is different server-side, this is a placeholder
                shortId: nil,
                handle: nil,
                prettyDID: me.name,
                name: me.name
            )
            cacheAliases(for: profile, aliases: [profile.did])
            saveCacheToDisk()
            return profile

        case .raw(let identifier):
            if let cached = cache[identifier.lowercased()] { return cached }
            guard let base = URL(string: baseURLString) else { throw URLError(.badURL) }
            let url = base
                .appendingPathComponent("api")
                .appendingPathComponent("persona")
                .appendingPathComponent("resolve")
                // appending as a path component will safely percent-encode '@' and other characters
                .appendingPathComponent(identifier)

            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard (200...299).contains(http.statusCode) else {
                if http.statusCode == 404 {
                    throw NSError(domain: "PersonaResolver", code: 404, userInfo: [NSLocalizedDescriptionKey: "Persona not found"])
                }
                throw NSError(domain: "PersonaResolver", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(http.statusCode)"])
            }

            let decoder = JSONDecoder()
            // Server returns a full PersonaProfile; we only decode fields we care about.
            let profile = try decoder.decode(PersonaResolvedProfile.self, from: data)
            // Cache with useful aliases for quick lookups
            var aliases: [String] = [profile.did]
            if let guid = profile.guid, !guid.isEmpty { aliases.append(guid) }
            if let sid = profile.shortId, !sid.isEmpty { aliases.append(sid) }
            if let handle = profile.handle, !handle.isEmpty { aliases.append("@\(handle)") }
            cacheAliases(for: profile, aliases: aliases)
            return profile
        }
    }

    private func cacheAliases(for profile: PersonaResolvedProfile, aliases: [String]) {
        for key in aliases {
            cache[key.lowercased()] = profile
        }
        saveCacheToDisk()
    }

    private func loadCacheFromDisk() {
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoded = try JSONDecoder().decode([String: PersonaResolvedProfile].self, from: data)
            self.cache = decoded
        } catch {
            // no-op on first run
        }
        // Attempt migration from legacy Documents location
        if cache.isEmpty {
            let legacyURL = SharedContainer.legacyResolverCacheURL
            if FileManager.default.fileExists(atPath: legacyURL.path) {
                do {
                    let data = try Data(contentsOf: legacyURL)
                    let decoded = try JSONDecoder().decode([String: PersonaResolvedProfile].self, from: data)
                    self.cache = decoded
                    try? FileManager.default.removeItem(at: legacyURL)
                    saveCacheToDisk()
                } catch {
                    // ignore migration errors
                }
            }
        }
    }

    private func saveCacheToDisk() {
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: cacheFileURL, options: [.atomic])
        } catch {
            logger.error("Failed to save resolver cache: \(error.localizedDescription)")
        }
    }
}

// MARK: - Convenience helpers

extension PersonaResolver {
    func resolveString(_ input: String) async throws -> PersonaResolvedProfile {
        guard let parsed = PersonaIdentifierParser.parse(input) else {
            throw NSError(domain: "PersonaResolver", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid identifier input"])
        }
        return try await resolve(parsed)
    }
}
