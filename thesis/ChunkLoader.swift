import Foundation
import SwiftUI

// MARK: - ChunkLoader

/// Actor that reads and parses only the byte range needed for the current
/// time window.  Backed by any DataSource (local file today, S3 tomorrow).
///
/// Usage:
///   let loader = try await ChunkLoader.prepare(url: fileURL)
///   let series = try await loader.load(windowStart: 0, windowEnd: 5)
actor ChunkLoader {

    // nonisolated lets callers read these without an await.
    nonisolated let source: DataSource
    nonisolated let index:  RowIndex

    private static let palette: [Color] = [
        .blue, .orange, .green, .red, .purple, .cyan, .yellow, .pink
    ]

    init(source: DataSource, index: RowIndex) {
        self.source = source
        self.index  = index
    }

    // MARK: - Factory

    /// Build (or load a cached) row index for `url`, then return a ready loader.
    /// The index is persisted alongside the data file as `<name>.ridx` so
    /// subsequent opens are instant.
    static func prepare(url: URL) async throws -> ChunkLoader {
        let idxURL = RowIndex.indexURL(for: url)

        let rowIndex: RowIndex
        if FileManager.default.fileExists(atPath: idxURL.path),
           let cached = try? RowIndex.load(from: idxURL) {
            rowIndex = cached
        } else {
            rowIndex = try await RowIndex.build(url: url)
            try? rowIndex.save(to: idxURL)   // best-effort cache
        }

        return ChunkLoader(source: LocalFileDataSource(url: url), index: rowIndex)
    }

    // MARK: - Load window

    /// Read only the byte range that covers [windowStart, windowEnd] and parse
    /// it into series, downsampled to at most `maxPoints` per series.
    func load(windowStart: Double, windowEnd: Double, maxPoints: Int = 200) async throws -> [ChartSeries] {
        try await ChartPerf.measureAsync("ChunkLoader.load", detail: "window=\(windowStart)...\(windowEnd)") {
            let totalSize = try await source.totalSize
            let range     = index.byteRange(windowStart: windowStart,
                                             windowEnd:   windowEnd,
                                             totalSize:   totalSize)
            guard range.count > 0 else { return [] }

            let chunk = try await ChartPerf.measureAsync("ChunkLoader.read", detail: "bytes=\(range.count)") {
                try await source.read(byteRange: range)
            }
            return ChartPerf.measure("ChunkLoader.parse", detail: "bytes=\(chunk.count)") {
                parse(chunk: chunk, windowStart: windowStart, windowEnd: windowEnd, maxPoints: maxPoints)
            }
        }
    }

    // MARK: - Private parsing

    private func parse(chunk: Data, windowStart: Double, windowEnd: Double, maxPoints: Int) -> [ChartSeries] {
        let seriesNames = Array(index.columnNames.dropFirst())
        guard !seriesNames.isEmpty else { return [] }

        guard let text = String(data: chunk, encoding: .utf8)
                      ?? String(data: chunk, encoding: .isoLatin1)
        else { return [] }

        let delim = index.delimiter
        var pointsBySeries = [[ChartDataPoint]](repeating: [], count: seriesNames.count)

        // The chunk may start mid-line if the index entry landed inside a row.
        // Dropping the first line is safe because the index's safety buffer
        // guarantees the preceding entry's byte range overlaps the window.
        var lines = text.components(separatedBy: "\n")
        if lines.count > 1 { lines.removeFirst() }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let fields = ChartFileParser.splitLine(trimmed, delimiter: delim)
            guard let rawFirst = fields.first else { continue }
            let first = rawFirst.trimmingCharacters(in: .whitespaces)
            guard let xVal = Double(first),
                  xVal >= windowStart, xVal <= windowEnd else { continue }

            for i in 0..<seriesNames.count {
                let raw   = i + 1 < fields.count ? fields[i + 1] : ""
                let value = Double(raw.trimmingCharacters(in: .whitespaces)) ?? 0
                pointsBySeries[i].append(
                    ChartDataPoint(label: first, value: value, xNumeric: xVal)
                )
            }
        }

        // Build series, downsampling each to maxPoints.
        return seriesNames.enumerated().map { idx, name in
            var pts = pointsBySeries[idx]
            if pts.count > maxPoints {
                let step = pts.count / maxPoints
                pts = pts.enumerated().filter { $0.offset % step == 0 }.map(\.element)
            }
            return ChartSeries(
                name:       name,
                color:      Self.palette[idx % Self.palette.count],
                dataPoints: pts
            )
        }
    }
}
