import Foundation

// MARK: - RowIndexEntry

struct RowIndexEntry: Codable {
    var time: Double
    var byteOffset: Int
}

// MARK: - RowIndex

/// Sparse positional index over a CSV/TSV file.
/// Stores one entry every `sampleEvery` data rows, each recording the
/// time value and byte offset of that row.  Enables O(log n) seek to
/// any time window without loading the full file.
struct RowIndex: Codable {
    var entries: [RowIndexEntry]
    var columnNames: [String]       // full header (col 0 = time/label, rest = series)
    var delimiterString: String     // "," or "\t"  (Character isn't Codable)
    var hasNumericFirstColumn: Bool // true → scrubber/windowing enabled

    var delimiter: Character { delimiterString.first ?? "," }

    enum BuildError: Error, LocalizedError {
        case noColumns, empty
        var errorDescription: String? {
            switch self {
            case .noColumns: return "File has fewer than 2 columns."
            case .empty:     return "File contains no data rows."
            }
        }
    }

    // MARK: - Byte-range query

    /// Returns the byte range in the source file that conservatively covers
    /// all rows whose time value falls within [windowStart, windowEnd].
    func byteRange(windowStart: Double, windowEnd: Double, totalSize: Int) -> Range<Int> {
        guard entries.count >= 2 else { return 0..<totalSize }

        // Last entry with time ≤ windowStart (binary search, upper-biased mid).
        var lo = 0, hi = entries.count - 1
        while lo < hi {
            let m = (lo + hi + 1) / 2
            if entries[m].time <= windowStart { lo = m } else { hi = m - 1 }
        }
        let startIdx = max(0, lo - 1)   // one stride back as safety buffer

        // First entry with time ≥ windowEnd (binary search, lower-biased mid).
        lo = 0; hi = entries.count - 1
        while lo < hi {
            let m = (lo + hi) / 2
            if entries[m].time >= windowEnd { hi = m } else { lo = m + 1 }
        }
        let endIdx = min(entries.count - 1, lo + 1)   // one stride forward

        let byteStart = entries[startIdx].byteOffset
        let byteEnd   = endIdx + 1 < entries.count
            ? entries[endIdx + 1].byteOffset
            : totalSize

        return byteStart..<min(byteEnd, totalSize)
    }

    // MARK: - Build

    /// Scan `url` and build a sparse row index.  Runs on a detached utility
    /// task so it never blocks the main actor.  For a 200 MB file this
    /// typically takes < 2 seconds on an M-series Mac.
    static func build(url: URL, sampleEvery: Int = 500) async throws -> RowIndex {
        try await Task.detached(priority: .utility) {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            return try _scan(data: data, sampleEvery: sampleEvery)
        }.value
    }

    private static func _scan(data: Data, sampleEvery: Int) throws -> RowIndex {
        let count = data.count
        var pos   = 0

        // Skip UTF-8 BOM if present.
        if count >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF { pos = 3 }

        let nl = UInt8(ascii: "\n")
        let cr = UInt8(ascii: "\r")

        // Returns (string content of line, byte offset of line start) or nil at EOF.
        func nextLine() -> (String, byteStart: Int)? {
            guard pos < count else { return nil }
            let start = pos
            while pos < count && data[pos] != nl { pos += 1 }
            var end = pos
            if end > start && data[end - 1] == cr { end -= 1 }
            if pos < count { pos += 1 }   // consume \n
            let slice = data[start..<end]
            let str = String(data: slice, encoding: .utf8)
                   ?? String(data: slice, encoding: .isoLatin1)
                   ?? ""
            return (str, start)
        }

        // ── Parse header ────────────────────────────────────────────────────────
        var columnNames: [String] = []
        var delim: Character = ","
        while let (raw, _) = nextLine() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            delim = line.contains(",") ? "," : "\t"
            columnNames = ChartFileParser.splitLine(line, delimiter: delim)
            break
        }
        guard columnNames.count >= 2 else { throw BuildError.noColumns }

        // ── Peek at first data row to detect numeric first column ────────────
        let peekPos = pos
        var isNumeric = false
        if let (raw, _) = nextLine() {
            let fields = ChartFileParser.splitLine(
                raw.trimmingCharacters(in: .whitespaces), delimiter: delim)
            if let first = fields.first,
               Double(first.trimmingCharacters(in: .whitespaces)) != nil {
                isNumeric = true
            }
        }
        pos = peekPos   // reset — first row is included in the main scan below

        // ── Main scan ───────────────────────────────────────────────────────────
        var entries: [RowIndexEntry] = []
        var rowCount = 0

        while let (raw, byteStart) = nextLine() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            if rowCount % sampleEvery == 0 {
                let fields = ChartFileParser.splitLine(line, delimiter: delim)
                let first  = fields.first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                let t      = Double(first) ?? Double(rowCount)
                entries.append(RowIndexEntry(time: t, byteOffset: byteStart))
            }
            rowCount += 1
        }

        guard !entries.isEmpty else { throw BuildError.empty }

        return RowIndex(
            entries: entries,
            columnNames: columnNames,
            delimiterString: String(delim),
            hasNumericFirstColumn: isNumeric
        )
    }

    // MARK: - Persistence

    /// Derived index URL: same path as the data file but with ".ridx" extension.
    static func indexURL(for dataURL: URL) -> URL {
        dataURL.deletingPathExtension().appendingPathExtension("ridx")
    }

    func save(to url: URL) throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: url, options: .atomic)
    }

    static func load(from url: URL) throws -> RowIndex {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RowIndex.self, from: data)
    }
}
