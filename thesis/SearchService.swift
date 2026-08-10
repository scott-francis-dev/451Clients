import Foundation
import Core451

// MARK: - Wire models for GET /api/search/local (S451 FTS5 index)

/// A single hit from the S451 full-text index.
///
/// The endpoint returns *pointers* only — an id, a title, and the separate ranking
/// factors. It does NOT return the document body, an excerpt, or tags. See the
/// TODO(content-hop) note in `search(query:...)` and in `SearchAssistantService`.
public struct LocalSearchHit: Codable, Hashable {
    public let documentID: String
    public let title: String?
    public let ftsScore: Double
    public let citationCount: Int
    public let contextBoost: Double
    public let combinedScore: Double
}

/// The envelope returned by `/api/search/local`.
public struct LocalSearchResponse: Codable {
    public let hits: [LocalSearchHit]
    public let query: String
    public let limit: Int
    public let offset: Int
    public let total: Int
    public let hasMore: Bool
}

/// A tunable ranking blend over the three factors the endpoint returns unblended
/// (`ftsScore`, `citationCount`, `contextBoost`). Kept client-side and parameterized so the
/// selection algorithm can be tuned against real results without any server change.
///
/// Note: the three factors are on different scales (fts is a relevance score, citation an
/// integer count, context a boost), so weights are empirical, not probabilities — tune them
/// once you can see live hits.
public struct RankingWeights: Sendable {
    public var fts: Double
    public var citation: Double
    public var context: Double

    public init(fts: Double, citation: Double, context: Double) {
        self.fts = fts
        self.citation = citation
        self.context = context
    }

    /// v1 default — "probably most cited": citation-dominant with a light relevance tiebreak.
    public static let `default` = RankingWeights(fts: 0.1, citation: 1.0, context: 0.0)

    func score(_ hit: LocalSearchHit) -> Double {
        fts * hit.ftsScore
            + citation * Double(hit.citationCount)
            + context * hit.contextBoost
    }
}

/// Real full-text search against the S451 server's FTS5 index.
///
/// Replaces the `FakeSearchResults` mock path. Reuses `ServerConfig.baseURL` and `URLSession`,
/// the same substrate `MilestoneService`/`EscrowService`/`PersonaResolver` already use.
public struct SearchService {
    public init() {}

    /// Query the FTS5 index and map hits onto the app's `SearchResult` model.
    ///
    /// TODO(content-hop): `/api/search/local` returns no document body, so the resulting
    /// `SearchSnippet.snippet` and `.tags` are empty. Any consumer that needs to reason over
    /// document *content* (e.g. inferring template variables for the "make me a will" flow)
    /// must fetch each top hit's body — via a get-document endpoint or `documentUrl` (S3) —
    /// before handing text to FoundationModels. Titles alone are not enough.
    public func search(query: String,
                       limit: Int = 20,
                       weights: RankingWeights = .default) async throws -> SearchResult {
        // We re-rank client-side, so pull a wider pool than we return — otherwise the blend
        // only reorders the server's top `limit` by combinedScore. See TICKET below.
        let response = try await fetch(query: query, limit: max(limit, 50))

        let ranked = response.hits.sorted { weights.score($0) > weights.score($1) }
        let hits = Array(ranked.prefix(limit))

        let resultID = UUID()
        let snippets = hits.enumerated().map { index, hit in
            SearchSnippet(
                resultID: resultID,
                index: index,
                title: hit.title ?? hit.documentID,
                tags: [],                 // TODO(content-hop): not returned by search
                url: hit.documentID,      // TODO: resolve documentID → canonical URL/DID
                snippet: ""               // TODO(content-hop): body not returned by search
            )
        }
        return SearchResult(id: resultID, query: query, snippets: snippets)
    }

    // MARK: - Networking

    private func fetch(query: String, limit: Int) async throws -> LocalSearchResponse {
        guard let base = URL(string: ServerConfig.baseURL) else { throw URLError(.badURL) }
        guard var components = URLComponents(
            url: base.appendingPathComponent("api/search/local"),
            resolvingAgainstBaseURL: false
        ) else { throw URLError(.badURL) }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(LocalSearchResponse.self, from: data)
    }
}

// TICKET (server, S451): return ranking factors for the full match set, or accept the blend
// weights server-side, so ranking is a true global ordering instead of a re-rank over an
// over-fetched pool. Cheap — ftsScore/citationCount/contextBoost are already computed per hit.
// TICKET (server, S451): include `excerpt` (already on IndexedDocument, ≤500 chars) per hit so
// snippet display works without a second round-trip. Full body still needs the content-hop.
