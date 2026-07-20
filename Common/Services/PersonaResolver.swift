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

    // Memberwise initializer
    public init(
        did: String,
        guid: String? = nil,
        shortId: String? = nil,
        handle: String? = nil,
        prettyDID: String? = nil,
        name: String? = nil
    ) {
        self.did = did
        self.guid = guid
        self.shortId = shortId
        self.handle = handle
        self.prettyDID = prettyDID
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case did = "did"  // Server sends lowercase "did", not "dID"
        case dID = "dID"  // Also support legacy "dID" format
        case guid
        case shortId
        case handle
        case prettyDID
        case name
    }
    
    // Custom decoder that handles both "did" and "dID" formats and ignores extra fields
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try both "did" (lowercase) and "dID" (camelCase) for compatibility
        if let didValue = try? container.decode(String.self, forKey: .did) {
            self.did = didValue
        } else if let didValue = try? container.decode(String.self, forKey: .dID) {
            self.did = didValue
        } else {
            throw DecodingError.keyNotFound(CodingKeys.did, 
                DecodingError.Context(codingPath: decoder.codingPath, 
                                    debugDescription: "Missing 'did' or 'dID' key"))
        }
        
        self.guid = try? container.decode(String.self, forKey: .guid)
        self.shortId = try? container.decode(String.self, forKey: .shortId)
        self.handle = try? container.decode(String.self, forKey: .handle)
        self.prettyDID = try? container.decode(String.self, forKey: .prettyDID)
        self.name = try? container.decode(String.self, forKey: .name)
    }
    
    // Custom encoder to match the decoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode using lowercase "did" key (modern format)
        try container.encode(did, forKey: .did)
        try container.encodeIfPresent(guid, forKey: .guid)
        try container.encodeIfPresent(shortId, forKey: .shortId)
        try container.encodeIfPresent(handle, forKey: .handle)
        try container.encodeIfPresent(prettyDID, forKey: .prettyDID)
        try container.encodeIfPresent(name, forKey: .name)
    }
}

// MARK: - Resolver service

protocol PersonaResolvingService {
    func resolve(_ input: PersonaIdentifierInput) async throws -> PersonaResolvedProfile
}

final class PersonaResolver: PersonaResolvingService, ObservableObject {
    private let baseURLString: String
    private let session: URLSession
    private let personaManager: PersonaManager

    // Simple in-memory alias cache (handle, shortId, did -> profile)
    private var cache: [String: PersonaResolvedProfile] = [:]
    private let cacheFileURL: URL = SharedContainer.resolverCacheURL
    private let logger = Logger(subsystem: "org.the451project.wallet", category: "PersonaResolver")

    // DEBUG-only verbose logging helper
    @inline(__always)
    private func debugLog(_ message: String) {
#if DEBUG
        logger.debug("\(message, privacy: .public)")
#endif
    }

    init(baseURLString: String = ServerConfig.baseURL, session: URLSession = .shared, personaManager: PersonaManager) {
        self.baseURLString = baseURLString
        self.session = session
        self.personaManager = personaManager
        loadCacheFromDisk()
        debugLog("PersonaResolver initialized with baseURL=\(baseURLString)")
    }

    func resolve(_ input: PersonaIdentifierInput) async throws -> PersonaResolvedProfile {
        // Log incoming resolve request
        debugLog("Resolve called for input=\(String(describing: input))")
        switch input {
        case .me:
            debugLog("Resolving @me using active persona")
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
            debugLog("Resolved @me -> DID=\(profile.did)")
            return profile

        case .raw(let identifier):
            debugLog("Resolving raw identifier=\(identifier)")
            if let cached = cache[identifier.lowercased()] {
                debugLog("Cache hit for identifier=\(identifier) -> DID=\(cached.did)")
                return cached
            }
            guard let base = URL(string: baseURLString) else { throw URLError(.badURL) }
            let url = base
                .appendingPathComponent("api")
                .appendingPathComponent("persona")
                .appendingPathComponent("resolve")
                // appending as a path component will safely percent-encode '@' and other characters
                .appendingPathComponent(identifier)

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            debugLog("GET \(request.url?.absoluteString ?? "(nil URL)") [resolve]")

            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                debugLog("Resolve response status=\(http.statusCode) url=\(http.url?.absoluteString ?? "(nil)")")
            }
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
            debugLog("Resolved identifier=\(identifier) -> DID=\(profile.did)")
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
        debugLog("Caching aliases for DID=\(profile.did): \(aliases.joined(separator: ", "))")
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
            debugLog("Loaded resolver cache entries=\(decoded.count)")
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
                    debugLog("Migrated legacy resolver cache entries=\(decoded.count)")
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
        debugLog("resolveString called with input=\(input)")
        guard let parsed = PersonaIdentifierParser.parse(input) else {
            throw NSError(domain: "PersonaResolver", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid identifier input"])
        }
        return try await resolve(parsed)
    }
}

// MARK: - Search and short-code helpers
extension PersonaResolver {
    // Accept ABC1234 or ABC-1234 (7 hex-like chars ignoring dash). Returns variants to try.
    private func normalizeShortCode(_ s: String) -> [String]? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let dashless = trimmed.replacingOccurrences(of: "-", with: "")
        let hexSet = CharacterSet(charactersIn: "0123456789ABCDEF")
        guard dashless.count == 7, dashless.unicodeScalars.allSatisfy({ hexSet.contains($0) }) else { return nil }
        let dashed = String(dashless.prefix(3)) + "-" + String(dashless.suffix(4))
        return [dashless, dashed]
    }

    // Try exact resolve first; on failure, try short-code variants if applicable
    func resolveStringWithShortCodeSupport(_ input: String) async throws -> PersonaResolvedProfile {
        debugLog("resolveStringWithShortCodeSupport input=\(input)")
        do {
            return try await resolveString(input)
        } catch {
            if let variants = normalizeShortCode(input) {
                debugLog("Primary resolve failed; trying short-code variants for=\(input): \(variants.joined(separator: ", "))")
                for v in variants {
                    debugLog("Trying variant=\(v)")
                    do { return try await resolve(.raw(v)) } catch { /* try next */ }
                }
            }
            debugLog("All resolve attempts failed for input=\(input): \(error.localizedDescription)")
            throw error
        }
    }

    // Server-backed search using /api/persona/search?q=
    func search(query: String) async throws -> [PersonaResolvedProfile] {
        debugLog("Search called with query=\(query)")
        guard let base = URL(string: baseURLString) else { throw URLError(.badURL) }
        guard let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        let baseURL = base
            .appendingPathComponent("api")
            .appendingPathComponent("persona")
            .appendingPathComponent("search")
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "q", value: q)]
        guard let url = comps.url else { throw URLError(.badURL) }
        debugLog("GET \(url.absoluteString) [search]")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            debugLog("Search response status=\(http.statusCode) url=\(http.url?.absoluteString ?? "(nil)")")
        }
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 404 { return [] }
            throw NSError(domain: "PersonaResolver", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Search failed: \(http.statusCode)"])
        }

        let decoder = JSONDecoder()
        
        // Try the full profile format first (old format)
        struct PersonaSearchResponse: Decodable { let hits: [PersonaResolvedProfile] }
        struct PersonaSearchWrapper: Decodable { let results: [PersonaResolvedProfile] }
        
        if let primary = try? decoder.decode(PersonaSearchResponse.self, from: data) {
            debugLog("Search decoded hits count=\(primary.hits.count)")
            return primary.hits
        }
        if let array = try? decoder.decode([PersonaResolvedProfile].self, from: data) {
            debugLog("Search decoded array count=\(array.count)")
            return array
        }
        if let wrapped = try? decoder.decode(PersonaSearchWrapper.self, from: data) {
            debugLog("Search decoded wrapped results count=\(wrapped.results.count)")
            return wrapped.results
        }
        
        // Try the minimal search result format (SearchKit format with just documentID and relevance)
        struct MinimalSearchHit: Decodable {
            let documentID: String
            let relevance: Float?
        }
        struct MinimalSearchResponse: Decodable {
            let hits: [MinimalSearchHit]
            let totalCount: Int?
            let processingTimeMs: Double?
        }
        
        if let minimal = try? decoder.decode(MinimalSearchResponse.self, from: data) {
            debugLog("Search decoded minimal format, hits count=\(minimal.hits.count)")
            // Fetch full profiles for each documentID
            var profiles: [PersonaResolvedProfile] = []
            for hit in minimal.hits {
                debugLog("Resolving full profile for documentID=\(hit.documentID)")
                if let profile = try? await resolve(.raw(hit.documentID)) {
                    profiles.append(profile)
                } else {
                    debugLog("Failed to resolve profile for documentID=\(hit.documentID), skipping")
                }
            }
            debugLog("Successfully resolved \(profiles.count) of \(minimal.hits.count) profiles")
            return profiles
        }
        
        debugLog("Search decode fallback: returning empty results")
        return []
    }
}

extension PersonaResolver {
    // Parameterized search that exposes server query params without conflicting with existing `search(query:)`
    func searchWithParams(
        query: String,
        limit: Int?,
        offset: Int?,
        publicOnly: Bool?,
        waitForIndexing: Bool?
    ) async throws -> [PersonaResolvedProfile] {
        debugLog("SearchWithParams called query=\(query) limit=\(String(describing: limit)) offset=\(String(describing: offset)) publicOnly=\(String(describing: publicOnly)) waitForIndexing=\(String(describing: waitForIndexing))")
        guard let base = URL(string: baseURLString) else { throw URLError(.badURL) }
        var comps = URLComponents(url: base
            .appendingPathComponent("api")
            .appendingPathComponent("persona")
            .appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [URLQueryItem(name: "q", value: query)]
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let offset { items.append(URLQueryItem(name: "offset", value: String(offset))) }
        if let publicOnly { items.append(URLQueryItem(name: "publicOnly", value: publicOnly ? "true" : "false")) }
        if let waitForIndexing { items.append(URLQueryItem(name: "waitForIndexing", value: waitForIndexing ? "true" : "false")) }
        comps.queryItems = items
        guard let url = comps.url else { throw URLError(.badURL) }
        debugLog("GET \(url.absoluteString) [searchWithParams]")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            debugLog("SearchWithParams response status=\(http.statusCode) url=\(http.url?.absoluteString ?? "(nil)")")
            
            // DEBUG: Log raw response body
            if let responseString = String(data: data, encoding: .utf8) {
                debugLog("SearchWithParams raw response: \(responseString)")
            }
        }
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 404 { return [] }
            throw NSError(domain: "PersonaResolver", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Search failed: \(http.statusCode)"])
        }
        let decoder = JSONDecoder()
        struct PersonaSearchResponse: Decodable { let hits: [PersonaResolvedProfile] }
        struct PersonaSearchWrapper: Decodable { let results: [PersonaResolvedProfile] }
        
        // Try primary format first (Meilisearch format with hits array)
        do {
            let primary = try decoder.decode(PersonaSearchResponse.self, from: data)
            debugLog("SearchWithParams ✅ decoded hits count=\(primary.hits.count)")
            return primary.hits
        } catch {
            debugLog("SearchWithParams ❌ failed to decode PersonaSearchResponse: \(error)")
        }
        
        // Try array format
        do {
            let array = try decoder.decode([PersonaResolvedProfile].self, from: data)
            debugLog("SearchWithParams ✅ decoded array count=\(array.count)")
            return array
        } catch {
            debugLog("SearchWithParams ❌ failed to decode array: \(error)")
        }
        
        // Try wrapped format
        do {
            let wrapped = try decoder.decode(PersonaSearchWrapper.self, from: data)
            debugLog("SearchWithParams ✅ decoded wrapped results count=\(wrapped.results.count)")
            return wrapped.results
        } catch {
            debugLog("SearchWithParams ❌ failed to decode PersonaSearchWrapper: \(error)")
        }
        
        // Try the minimal search result format (SearchKit format with just documentID and relevance)
        struct MinimalSearchHit: Decodable {
            let documentID: String
            let relevance: Float?
        }
        struct MinimalSearchResponse: Decodable {
            let hits: [MinimalSearchHit]
            let totalCount: Int?
            let processingTimeMs: Double?
        }
        
        do {
            let minimal = try decoder.decode(MinimalSearchResponse.self, from: data)
            debugLog("SearchWithParams ✅ decoded minimal format, hits count=\(minimal.hits.count)")
            // Fetch full profiles for each documentID
            var profiles: [PersonaResolvedProfile] = []
            for hit in minimal.hits {
                debugLog("Resolving full profile for documentID=\(hit.documentID)")
                if let profile = try? await resolve(.raw(hit.documentID)) {
                    profiles.append(profile)
                } else {
                    debugLog("Failed to resolve profile for documentID=\(hit.documentID), skipping")
                }
            }
            debugLog("Successfully resolved \(profiles.count) of \(minimal.hits.count) profiles")
            return profiles
        } catch {
            debugLog("SearchWithParams ❌ failed to decode MinimalSearchResponse: \(error)")
        }
        
        debugLog("SearchWithParams ⚠️ All decode attempts failed, returning empty results")
        return []
    }

    // Optimized for immediate post-creation lookup
    func searchAfterCreation(query: String, limit: Int? = nil, offset: Int? = nil) async throws -> [PersonaResolvedProfile] {
        debugLog("searchAfterCreation query=\(query) limit=\(String(describing: limit)) offset=\(String(describing: offset))")
        guard let base = URL(string: baseURLString) else { throw URLError(.badURL) }
        var comps = URLComponents(url: base.appendingPathComponent("api/persona/search-after-creation"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [URLQueryItem(name: "q", value: query)]
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let offset { items.append(URLQueryItem(name: "offset", value: String(offset))) }
        comps.queryItems = items
        guard let url = comps.url else { throw URLError(.badURL) }
        debugLog("GET \(url.absoluteString) [searchAfterCreation]")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            debugLog("searchAfterCreation response status=\(http.statusCode) url=\(http.url?.absoluteString ?? "(nil)")")
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
        let decoder = JSONDecoder()
        struct PersonaSearchResponse: Decodable { let hits: [PersonaResolvedProfile] }
        if let primary = try? decoder.decode(PersonaSearchResponse.self, from: data) {
            debugLog("searchAfterCreation decoded hits count=\(primary.hits.count)")
            return primary.hits
        }
        if let array = try? decoder.decode([PersonaResolvedProfile].self, from: data) {
            debugLog("searchAfterCreation decoded array count=\(array.count)")
            return array
        }
        debugLog("searchAfterCreation decode fallback: returning empty results")
        return []
    }

    // Exact DID lookup through Meilisearch purpose key
    func searchExact(did: String, publicOnly: Bool? = nil) async throws -> [PersonaResolvedProfile] {
        debugLog("searchExact did=\(did) publicOnly=\(String(describing: publicOnly))")
        guard let base = URL(string: baseURLString) else { throw URLError(.badURL) }
        var comps = URLComponents(url: base.appendingPathComponent("api/persona/search-exact"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [URLQueryItem(name: "did", value: did)]
        if let publicOnly { items.append(URLQueryItem(name: "publicOnly", value: publicOnly ? "true" : "false")) }
        comps.queryItems = items
        guard let url = comps.url else { throw URLError(.badURL) }
        debugLog("GET \(url.absoluteString) [searchExact]")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            debugLog("searchExact response status=\(http.statusCode) url=\(http.url?.absoluteString ?? "(nil)")")
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
        let decoder = JSONDecoder()
        struct MeiliHits<T: Decodable>: Decodable { let hits: [T]? }
        if let meili = try? decoder.decode(MeiliHits<PersonaResolvedProfile>.self, from: data) {
            let count = meili.hits?.count ?? 0
            debugLog("searchExact decoded hits count=\(count)")
            return meili.hits ?? []
        }
        debugLog("searchExact decode fallback: returning empty results")
        return []
    }

    // Direct DID search by index name
    func searchDirect(did: String) async throws -> [PersonaResolvedProfile] {
        debugLog("searchDirect did=\(did)")
        guard let base = URL(string: baseURLString) else { throw URLError(.badURL) }
        var comps = URLComponents(url: base.appendingPathComponent("api/persona/search-direct"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "did", value: did)]
        guard let url = comps.url else { throw URLError(.badURL) }
        debugLog("GET \(url.absoluteString) [searchDirect]")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            debugLog("searchDirect response status=\(http.statusCode) url=\(http.url?.absoluteString ?? "(nil)")")
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
        let decoder = JSONDecoder()
        struct MeiliHits<T: Decodable>: Decodable { let hits: [T]? }
        if let meili = try? decoder.decode(MeiliHits<PersonaResolvedProfile>.self, from: data) {
            let count = meili.hits?.count ?? 0
            debugLog("searchDirect decoded hits count=\(count)")
            return meili.hits ?? []
        }
        debugLog("searchDirect decode fallback: returning empty results")
        return []
    }
}
