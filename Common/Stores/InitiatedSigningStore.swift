import Foundation
import SwiftUI

public struct InitiatedSigningRecord: Codable {
    public let id: String
    public let documentUUID: String
    public let version: String
    public let title: String
    public let originalFilename: String
    public let savedFilePath: String
    public let fileSize: Int64
    public let contentType: String
    public let createdAt: String
    public let metadata: [String: String]
    public let contractParties: [String]
    public let authors: [String]
    public let accessCode: String? // Human-readable access code for private documents

    public init(
        id: String,
        documentUUID: String,
        version: String,
        title: String,
        originalFilename: String,
        savedFilePath: String,
        fileSize: Int64,
        contentType: String,
        createdAt: String,
        metadata: [String: String],
        contractParties: [String],
        authors: [String],
        accessCode: String? = nil
    ) {
        self.id = id
        self.documentUUID = documentUUID
        self.version = version
        self.title = title
        self.originalFilename = originalFilename
        self.savedFilePath = savedFilePath
        self.fileSize = fileSize
        self.contentType = contentType
        self.createdAt = createdAt
        self.metadata = metadata
        self.contractParties = contractParties
        self.authors = authors
        self.accessCode = accessCode
    }

    public var url: URL? {
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documents.appendingPathComponent("InitiatedSignings").appendingPathComponent(savedFilePath)
    }
}

public final class InitiatedSigningStore {
    public static let shared = InitiatedSigningStore()
    public static let didUpdateNotification = Notification.Name("InitiatedSigningStore.didUpdate")

    private let baseDirectory: URL
    private let documentsDirectory: URL
    private let indexFileURL: URL

    private init() {
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to access user documents directory")
        }
        baseDirectory = documents.appendingPathComponent("InitiatedSignings", isDirectory: true)
        documentsDirectory = baseDirectory.appendingPathComponent("documents", isDirectory: true)
        indexFileURL = baseDirectory.appendingPathComponent("index.json", isDirectory: false)
        ensureDirectoriesExist()
    }

    private func ensureDirectoriesExist() {
        let fm = FileManager.default
        do {
            if !fm.fileExists(atPath: baseDirectory.path) {
                try fm.createDirectory(at: baseDirectory, withIntermediateDirectories: true, attributes: nil)
                #if DEBUG
                print("Created base directory at \(baseDirectory.path)")
                #endif
            }
            if !fm.fileExists(atPath: documentsDirectory.path) {
                try fm.createDirectory(at: documentsDirectory, withIntermediateDirectories: true, attributes: nil)
                #if DEBUG
                print("Created documents directory at \(documentsDirectory.path)")
                #endif
            }
        } catch {
            #if DEBUG
            print("Error creating directories: \(error)")
            #endif
        }
    }

    public func load() -> [InitiatedSigningRecord] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: indexFileURL.path) else {
            #if DEBUG
            print("Index file does not exist at path \(indexFileURL.path), returning empty array")
            #endif
            return []
        }
        do {
            let data = try Data(contentsOf: indexFileURL)
            let decoder = JSONDecoder()
            let records = try decoder.decode([InitiatedSigningRecord].self, from: data)
            #if DEBUG
            print("Loaded \(records.count) initiated signing records")
            #endif
            return records
        } catch {
            #if DEBUG
            print("Failed to load index file: \(error)")
            #endif
            return []
        }
    }

    public func save(_ records: [InitiatedSigningRecord]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(records)
            try data.write(to: indexFileURL, options: .atomic)
            #if DEBUG
            print("Saved \(records.count) initiated signing records to index file")
            #endif
        } catch {
            #if DEBUG
            print("Failed to save index file: \(error)")
            #endif
        }
    }

    public func append(_ record: InitiatedSigningRecord) {
        var records = load()
        records.append(record)
        save(records)
        NotificationCenter.default.post(name: InitiatedSigningStore.didUpdateNotification, object: nil)
    }

    public func copyDocumentToStore(sourceURL: URL, documentUUID: String, version: String, contentType: String) throws -> (absoluteURL: URL, relativePath: String) {
        let fm = FileManager.default

        let documentFolder = documentsDirectory.appendingPathComponent(documentUUID, isDirectory: true)
        if !fm.fileExists(atPath: documentFolder.path) {
            try fm.createDirectory(at: documentFolder, withIntermediateDirectories: true, attributes: nil)
            #if DEBUG
            print("Created document folder at \(documentFolder.path)")
            #endif
        }

        let ext = sourceURL.pathExtension.isEmpty ? "" : "." + sourceURL.pathExtension
        let destinationFileName = "\(documentUUID)-\(version)\(ext)"
        let destinationURL = documentFolder.appendingPathComponent(destinationFileName, isDirectory: false)

        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
            #if DEBUG
            print("Removed existing file at \(destinationURL.path)")
            #endif
        }

        try fm.copyItem(at: sourceURL, to: destinationURL)
        #if DEBUG
        print("Copied document to store: \(destinationURL.path)")
        #endif

        // savedFilePath should be relative to baseDirectory
        let savedFilePath = "documents/\(documentUUID)/\(destinationFileName)"
        return (absoluteURL: destinationURL, relativePath: savedFilePath)
    }
    
    /// Removes records at the given indices and optionally deletes associated files
    public func remove(at indices: IndexSet, deleteFiles: Bool = true) {
        var records = load()
        let fm = FileManager.default
        
        if deleteFiles {
            for index in indices {
                guard index < records.count else { continue }
                let record = records[index]
                
                // Delete the document folder for this UUID
                let documentFolder = documentsDirectory.appendingPathComponent(record.documentUUID, isDirectory: true)
                if fm.fileExists(atPath: documentFolder.path) {
                    do {
                        try fm.removeItem(at: documentFolder)
                        #if DEBUG
                        print("Deleted document folder: \(documentFolder.path)")
                        #endif
                    } catch {
                        #if DEBUG
                        print("Failed to delete document folder: \(error)")
                        #endif
                    }
                }
            }
        }
        
        records.remove(atOffsets: indices)
        save(records)
    }
    
    /// Clears all initiated signing records and optionally deletes all associated files
    public func clearAll(deleteFiles: Bool = true) {
        let fm = FileManager.default
        
        if deleteFiles {
            // Delete the entire documents directory
            if fm.fileExists(atPath: documentsDirectory.path) {
                do {
                    try fm.removeItem(at: documentsDirectory)
                    #if DEBUG
                    print("Deleted all documents at: \(documentsDirectory.path)")
                    #endif
                    // Recreate the directory
                    try fm.createDirectory(at: documentsDirectory, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    #if DEBUG
                    print("Failed to clear documents: \(error)")
                    #endif
                }
            }
        }
        
        // Clear the index
        save([])
        #if DEBUG
        print("Cleared all initiated signing records")
        #endif
    }
}
