import Foundation

// MARK: - DataSource protocol
//
// Abstraction for reading raw bytes from any backing store.
// The byte-range API is intentional: large files (GB-scale) are never
// consumed whole — callers request only the window they need.
// Current implementation: local file.  Future: S3DataSource.

protocol DataSource: Sendable {
    var totalSize: Int { get async throws }
    func read(byteRange: Range<Int>) async throws -> Data
}

// MARK: - LocalFileDataSource

struct LocalFileDataSource: DataSource {
    let url: URL

    var totalSize: Int {
        get async throws {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            return (attrs[.size] as? Int) ?? 0
        }
    }

    func read(byteRange: Range<Int>) async throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(byteRange.lowerBound))
        let length = byteRange.upperBound - byteRange.lowerBound
        return try handle.read(upToCount: length) ?? Data()
    }
}

// MARK: - Chart assets directory

enum ChartAssets {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir  = base.appendingPathComponent("thesis/charts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Copy a picked file into the stable assets directory and return its new URL.
    static func importFile(from source: URL) throws -> URL {
        let ext  = source.pathExtension
        let name = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let dest = directory.appendingPathComponent(name)
        try FileManager.default.copyItem(at: source, to: dest)
        return dest
    }
}
