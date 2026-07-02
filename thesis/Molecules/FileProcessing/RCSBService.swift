import Foundation

enum RCSBError: Error {
    case invalidIdentifier
    case networkFailed(URLError)
    case notFound
    case server(Int)
}

/// Fetches PDB files from the RCSB Protein Data Bank by 4-character ID.
/// Successful downloads are cached on disk so subsequent loads are offline-capable.
struct RCSBService {
    static let shared = RCSBService()

    private let session: URLSession
    private let cacheDirectory: URL

    private init() {
        self.session = URLSession(configuration: .default)
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.cacheDirectory = caches.appendingPathComponent("RCSBCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Returns the normalized PDB ID (uppercased, trimmed) if it looks valid; nil otherwise.
    static func normalize(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count == 4,
              trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return trimmed
    }

    /// Returns the cached PDB data for the given ID if present.
    func cachedData(for id: String) -> Data? {
        let url = cacheURL(for: id)
        return try? Data(contentsOf: url)
    }

    /// Downloads the PDB file for the given ID and caches it. Returns the raw bytes.
    func fetch(id: String) async throws -> Data {
        guard let normalized = Self.normalize(id) else { throw RCSBError.invalidIdentifier }

        if let cached = cachedData(for: normalized) {
            return cached
        }

        guard let url = URL(string: "https://files.rcsb.org/download/\(normalized).pdb") else {
            throw RCSBError.invalidIdentifier
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch let urlError as URLError {
            throw RCSBError.networkFailed(urlError)
        }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200: break
            case 404: throw RCSBError.notFound
            default: throw RCSBError.server(http.statusCode)
            }
        }

        try? data.write(to: cacheURL(for: normalized), options: .atomic)
        return data
    }

    private func cacheURL(for id: String) -> URL {
        cacheDirectory.appendingPathComponent("\(id).pdb")
    }
}
