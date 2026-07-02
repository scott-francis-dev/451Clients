import Foundation
import SwiftUI

// MARK: - Parser

enum ChartFileParser {

    enum ParseError: LocalizedError {
        case emptyFile
        case noColumns
        case noDataRows

        var errorDescription: String? {
            switch self {
            case .emptyFile:   return "The file is empty."
            case .noColumns:   return "Could not find column headers."
            case .noDataRows:  return "The file has headers but no data rows."
            }
        }
    }

    // MARK: - Entry point

    /// Parse a CSV or TSV file into ChartSeries ready for ChartData.
    /// Column layout expected:
    ///   • First column  — labels (time, category, x-axis)
    ///   • Other columns — one series each; header row = series name
    static func parse(url: URL) throws -> [ChartSeries] {
        let raw = try String(contentsOf: url, encoding: .utf8)
        return try ChartPerf.measure("ChartFileParser.parse", detail: "chars=\(raw.count)") {
            try parse(string: raw)
        }
    }

    static func parse(string: String) throws -> [ChartSeries] {
        var lines = string
            .components(separatedBy: .newlines)
            .map    { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        guard !lines.isEmpty            else { throw ParseError.emptyFile }

        let headerLine = lines.removeFirst()
        let delimiter: Character = headerLine.contains(",") ? "," : "\t"
        let headers = split(headerLine, delimiter: delimiter)

        guard headers.count >= 2        else { throw ParseError.noColumns }
        guard !lines.isEmpty            else { throw ParseError.noDataRows }

        // First column is labels; remaining columns become series.
        let seriesNames = Array(headers.dropFirst())
        var seriesPoints: [[ChartDataPoint]] = Array(repeating: [], count: seriesNames.count)

        var rowIndex = 0
        for line in lines {
            let fields   = split(line, delimiter: delimiter)
            let label    = fields.first ?? ""
            // Use the label as a numeric x if parseable, otherwise fall back to row index.
            let xNumeric = Double(label.trimmingCharacters(in: .whitespaces)) ?? Double(rowIndex)
            for i in 0 ..< seriesNames.count {
                let raw   = i + 1 < fields.count ? fields[i + 1] : ""
                let value = Double(raw.trimmingCharacters(in: .whitespaces)) ?? 0
                seriesPoints[i].append(ChartDataPoint(label: label, value: value, xNumeric: xNumeric))
            }
            rowIndex += 1
        }

        let palette: [Color] = [.blue, .orange, .green, .red, .purple, .cyan, .yellow, .pink]
        return seriesNames.enumerated().map { idx, name in
            ChartSeries(
                name: name,
                color: palette[idx % palette.count],
                dataPoints: seriesPoints[idx]
            )
        }
    }

    // MARK: - Helpers

    /// Public CSV/TSV line splitter used by RowIndex and ChunkLoader.
    static func splitLine(_ line: String, delimiter: Character) -> [String] {
        split(line, delimiter: delimiter)
    }

    /// Minimal CSV split that respects double-quoted fields.
    private static func split(_ line: String, delimiter: Character) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == delimiter && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        result.append(current)
        return result
    }
}
