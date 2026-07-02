// BlockchainAPI.swift
// Networking layer for fetching blockchain blocks for the current persona as a signator

import Foundation
import CryptoKit
import Observation
import Combine

public struct CodableData: Codable, CustomStringConvertible {
    public let value: Any

    public var description: String { String(describing: value) }

    public init<T>(_ value: T) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // You can expand this for more types as needed.
        if let str = try? container.decode(String.self) {
            value = str
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let dict = try? container.decode([String: CodableData].self) {
            value = dict
        } else if let arr = try? container.decode([CodableData].self) {
            value = arr
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "CodableData: unsupported type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let str as String:
            try container.encode(str)
        case let int as Int:
            try container.encode(int)
        case let bool as Bool:
            try container.encode(bool)
        case let double as Double:
            try container.encode(double)
        case let dict as [String: CodableData]:
            try container.encode(dict)
        case let arr as [CodableData]:
            try container.encode(arr)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "CodableData: unsupported type"))
        }
    }
}

public struct BlockchainBlock: Codable, Identifiable {
    public let index: Int
    public let timestamp: Int64
    public let previousHash: String
    public var hash: String
    public let data: CodableData
    public let type: String
    public var isDeprecated: Bool
    public var replacedBy: String?
    public var s3UploadResults: [S3UploadResult]
    public var signature: String?
    public var publicKey: String?

    public var id: String { String(index) + hash } // Conform to Identifiable for SwiftUI

    public enum EntityType: String, Codable {
        case persona
        case publishedDocument
        case privateContract
        case metadata
        case blockchainBlock
        case draftBlock
        case personaProfile
        case timestampRecord
    }

    public struct S3UploadResult: Codable {
        public let providerName: String
        public let url: String
        public let eTag: String
    }

    enum CodingKeys: String, CodingKey {
        case index, timestamp, previousHash, hash, data, type, isDeprecated, replacedBy, s3UploadResults, signature, publicKey
    }

    public init(
        index: Int, timestamp: Int64, previousHash: String, hash: String, data: CodableData, type: String, isDeprecated: Bool, replacedBy: String?, s3UploadResults: [S3UploadResult], signature: String? = nil, publicKey: String? = nil
    ) {
        self.index = index
        self.timestamp = timestamp
        self.previousHash = previousHash
        self.hash = hash
        self.data = data
        self.type = type
        self.isDeprecated = isDeprecated
        self.replacedBy = replacedBy
        self.s3UploadResults = s3UploadResults
        self.signature = signature
        self.publicKey = publicKey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decode(Int.self, forKey: .index)
        timestamp = try container.decode(Int64.self, forKey: .timestamp)
        previousHash = try container.decode(String.self, forKey: .previousHash)
        hash = try container.decode(String.self, forKey: .hash)
        data = try container.decode(CodableData.self, forKey: .data)
        type = try container.decode(String.self, forKey: .type)
        isDeprecated = try container.decode(Bool.self, forKey: .isDeprecated)
        replacedBy = try container.decodeIfPresent(String.self, forKey: .replacedBy)
        s3UploadResults = try container.decode([S3UploadResult].self, forKey: .s3UploadResults)
        signature = try container.decodeIfPresent(String.self, forKey: .signature)
        publicKey = try container.decodeIfPresent(String.self, forKey: .publicKey)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(previousHash, forKey: .previousHash)
        try container.encode(hash, forKey: .hash)
        try container.encode(data, forKey: .data)
        try container.encode(type, forKey: .type)
        try container.encode(isDeprecated, forKey: .isDeprecated)
        try container.encodeIfPresent(replacedBy, forKey: .replacedBy)
        try container.encode(s3UploadResults, forKey: .s3UploadResults)
        try container.encodeIfPresent(signature, forKey: .signature)
        try container.encodeIfPresent(publicKey, forKey: .publicKey)
    }

    public func calculateHash() -> String {
        let hashInput = "\(index)\(timestamp)\(previousHash)\(type)\(String(describing: data))"
        return SHA256.hash(data: Data(hashInput.utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }
}

class BlockchainAPI: ObservableObject {
    enum Environment {
        case production
        case development
        
        var baseURL: URL {
            switch self {
            case .production:
                return URL(string: "https://blockchain.the451project.org")!
            case .development:
                return URL(string: "http://localhost:8080")!
            }
        }
    }
    
    @Published var blocks: [BlockchainBlock] = []
    @Published var isLoading: Bool = false
    @Published var messageError: String?
    
    var environment: Environment = .development // Change to .production for prod

    /// Validates parties and authors with the backend. Returns true if valid.
    func validateParties(parties: [String], authors: [String]) async throws -> Bool {
        // TODO: Implement real validation logic with server.
        // For now, always return true after a short delay (simulate network call)
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        return true
    }
    
    func fetchBlocks(for personaID: String) async {
        isLoading = true
        messageError = nil
        let url = environment.baseURL.appendingPathComponent("/api/blocks?signator=\(personaID)")
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let blocks = try JSONDecoder().decode([BlockchainBlock].self, from: data)
            await MainActor.run {
                self.blocks = blocks
            }
        } catch {
            await MainActor.run {
                self.messageError = error.localizedDescription
            }
        }
        isLoading = false
    }
    
    @MainActor
    func initiatePublish(documentData: Data, metadata: Any) async throws -> Bool {
        // TODO: Implement actual publish logic
        // Simulate network delay and success
        try await Task.sleep(nanoseconds: 200_000_000)
        return true
    }
    
    /// Initiate a validation request for the given persona and note.
    func initiateValidation(personaId: String, note: String) async throws -> Bool {
        // TODO: Implement actual network call to validation endpoint
        try await Task.sleep(nanoseconds: 300_000_000) // simulate delay
        return true // Simulate a successful request
    }
}

