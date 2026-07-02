//
//  InterestStore.swift
//  wordsmatter
//
//  A lightweight, persistent record of works the reader has marked as
//  "interesting." It is meant to accumulate a memory of the user's interests
//  that can later be fed to the AI as context for personalization /
//  recommendations.
//

import Foundation
import Observation

/// One saved interest — a compact, Codable snapshot of a feed item.
/// Identity is a stable key (title + author) so saves survive app relaunches
/// even though in-memory feed items use ephemeral UUIDs.
struct InterestRecord: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var subtitle: String
    var author: String
    var tags: [String]
    var summary: String
    var savedAt: Date
}

/// Persists saved interests to a JSON file in the app's Documents directory.
@Observable
final class InterestStore {
    static let shared = InterestStore()

    private(set) var records: [InterestRecord] = []

    @ObservationIgnored
    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("interests.json")
    }()

    init() {
        load()
    }

    // MARK: - Queries

    func isSaved(id: String) -> Bool {
        records.contains { $0.id == id }
    }

    /// Concatenated, human-readable description of everything the user has
    /// saved — intended to be handed to the model as interest context.
    var interestContext: String {
        guard !records.isEmpty else { return "" }
        let lines = records.map { rec -> String in
            let tags = rec.tags.isEmpty ? "" : " [\(rec.tags.joined(separator: ", "))]"
            return "• \(rec.title) — \(rec.author)\(tags)"
        }
        return "Topics the reader has saved as interesting:\n" + lines.joined(separator: "\n")
    }

    // MARK: - Mutations

    /// Adds the record if not present, removes it if it is. Returns the new
    /// saved state for the record.
    @discardableResult
    func toggle(_ record: InterestRecord) -> Bool {
        if let idx = records.firstIndex(where: { $0.id == record.id }) {
            records.remove(at: idx)
            save()
            return false
        } else {
            records.append(record)
            save()
            return true
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([InterestRecord].self, from: data) {
            records = decoded
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
