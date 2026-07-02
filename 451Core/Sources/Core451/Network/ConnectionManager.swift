//
//  ConnectionManager.swift
//  451Wallet
//
//  Manages colleague connections and requests
//

import Foundation
import os

final class ConnectionManager: ObservableObject {
    // MARK: - Published State
    
    @Published private(set) var colleagues: [Colleague] = []
    @Published private(set) var pendingRequests: [ConnectionRequest] = []
    @Published private(set) var sentRequests: [ConnectionRequest] = []
    
    // MARK: - Dependencies
    
    private let baseURLString: String
    private let session: URLSession
    private let personaManager: PersonaManager
    
    private let colleaguesKey = "colleagues_list"
    private let pendingRequestsKey = "pending_requests_list"
    private let sentRequestsKey = "sent_requests_list"
    
    private let logger = Logger(subsystem: "org.the451project.wallet", category: "ConnectionManager")
    
    // DEBUG-only verbose logging helper
    @inline(__always)
    private func debugLog(_ message: String) {
#if DEBUG
        logger.debug("\(message, privacy: .public)")
#endif
    }
    
    // MARK: - Initialization
    
    init(
        baseURLString: String = ServerConfig.baseURL,
        session: URLSession = .shared,
        personaManager: PersonaManager
    ) {
        self.baseURLString = baseURLString
        self.session = session
        self.personaManager = personaManager
        loadFromDisk()
        debugLog("ConnectionManager initialized")
    }
    
    // MARK: - Persistence
    
    private func loadFromDisk() {
        let defaults = SharedContainer.sharedDefaults
        
        if let data = defaults.data(forKey: colleaguesKey),
           let decoded = try? JSONDecoder().decode([Colleague].self, from: data) {
            colleagues = decoded
            debugLog("Loaded \(decoded.count) colleagues")
        }
        
        if let data = defaults.data(forKey: pendingRequestsKey),
           let decoded = try? JSONDecoder().decode([ConnectionRequest].self, from: data) {
            pendingRequests = decoded
            debugLog("Loaded \(decoded.count) pending requests")
        }
        
        if let data = defaults.data(forKey: sentRequestsKey),
           let decoded = try? JSONDecoder().decode([ConnectionRequest].self, from: data) {
            sentRequests = decoded
            debugLog("Loaded \(decoded.count) sent requests")
        }
    }
    
    private func saveToDisk() {
        let defaults = SharedContainer.sharedDefaults
        let encoder = JSONEncoder()
        
        if let encoded = try? encoder.encode(colleagues) {
            defaults.set(encoded, forKey: colleaguesKey)
        }
        if let encoded = try? encoder.encode(pendingRequests) {
            defaults.set(encoded, forKey: pendingRequestsKey)
        }
        if let encoded = try? encoder.encode(sentRequests) {
            defaults.set(encoded, forKey: sentRequestsKey)
        }
        
        debugLog("Saved to disk: \(colleagues.count) colleagues, \(pendingRequests.count) pending, \(sentRequests.count) sent")
    }
    
    // MARK: - Connection Request Flow
    
    /// Send a connection request to another persona
    func sendConnectionRequest(
        toDID: String,
        message: String? = nil
    ) async throws -> ConnectionRequest {
        debugLog("sendConnectionRequest to=\(toDID)")
        
        guard let myPersona = personaManager.activePersona() else {
            throw NSError(domain: "ConnectionManager", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "No active persona"])
        }
        
        // Check if already connected or request pending
        if colleagues.contains(where: { $0.did == toDID }) {
            throw NSError(domain: "ConnectionManager", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Already connected to this persona"])
        }
        
        if sentRequests.contains(where: { $0.toDID == toDID && $0.status == .pending }) {
            throw NSError(domain: "ConnectionManager", code: 3,
                         userInfo: [NSLocalizedDescriptionKey: "Connection request already pending"])
        }
        
        guard let base = URL(string: baseURLString) else { throw URLError(.badURL) }
        let url = base
            .appendingPathComponent("api")
            .appendingPathComponent("connections")
            .appendingPathComponent("request")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(myPersona.id, forHTTPHeaderField: "X-DID")
        
        let body = CreateConnectionRequest(toDID: toDID, message: message)
        request.httpBody = try JSONEncoder().encode(body)
        
        debugLog("POST \(url.absoluteString) [sendConnectionRequest]")
        
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        debugLog("sendConnectionRequest response status=\(http.statusCode)")
        
        guard (200...299).contains(http.statusCode) else {
            // Try to decode error message
            if let errorResponse = try? JSONDecoder().decode(ConnectionRequestResponse.self, from: data),
               let errorMsg = errorResponse.error {
                throw NSError(domain: "ConnectionManager", code: http.statusCode,
                             userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
            throw NSError(domain: "ConnectionManager", code: http.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to send connection request: \(http.statusCode)"])
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(ConnectionRequestResponse.self, from: data)
        
        guard result.success else {
            throw NSError(domain: "ConnectionManager", code: 4,
                         userInfo: [NSLocalizedDescriptionKey: result.error ?? "Unknown error"])
        }
        
        // Add to sent requests
        sentRequests.append(result.request)
        saveToDisk()
        
        debugLog("Connection request sent successfully, id=\(result.request.id)")
        return result.request
    }
    
    /// Accept a connection request
    func acceptConnectionRequest(_ request: ConnectionRequest) async throws -> Colleague {
        debugLog("acceptConnectionRequest id=\(request.id)")
        
        guard let myPersona = personaManager.activePersona() else {
            throw NSError(domain: "ConnectionManager", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "No active persona"])
        }
        
        try await respondToConnectionRequest(request, accept: true)
        
        // Create colleague from accepted request
        guard var colleague = Colleague.from(request: request, myDID: myPersona.id) else {
            throw NSError(domain: "ConnectionManager", code: 5,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create colleague from request"])
        }
        
        // Mark as verified since they accepted our request
        colleague.verificationStatus = .verified
        
        // Update existing unverified colleague or add new
        if let existingIndex = colleagues.firstIndex(where: { $0.did == colleague.did }) {
            colleagues[existingIndex] = colleague
        } else {
            colleagues.append(colleague)
        }
        
        pendingRequests.removeAll { $0.id == request.id }
        saveToDisk()
        
        debugLog("Connection accepted, added/updated colleague did=\(colleague.did)")
        return colleague
    }
    
    /// Reject a connection request
    func rejectConnectionRequest(_ request: ConnectionRequest) async throws {
        debugLog("rejectConnectionRequest id=\(request.id)")
        
        try await respondToConnectionRequest(request, accept: false)
        
        // Remove from pending
        pendingRequests.removeAll { $0.id == request.id }
        saveToDisk()
        
        debugLog("Connection rejected")
    }
    
    private func respondToConnectionRequest(_ request: ConnectionRequest, accept: Bool) async throws {
        guard let myPersona = personaManager.activePersona() else {
            throw NSError(domain: "ConnectionManager", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "No active persona"])
        }
        
        guard let base = URL(string: baseURLString) else { throw URLError(.badURL) }
        let url = base
            .appendingPathComponent("api")
            .appendingPathComponent("connections")
            .appendingPathComponent("respond")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(myPersona.id, forHTTPHeaderField: "X-DID")
        
        let body = RespondToConnectionRequest(requestId: request.id, accept: accept, message: nil)
        urlRequest.httpBody = try JSONEncoder().encode(body)
        
        debugLog("POST \(url.absoluteString) [respondToConnectionRequest] accept=\(accept)")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        debugLog("respondToConnectionRequest response status=\(http.statusCode)")
        
        guard (200...299).contains(http.statusCode) else {
            throw NSError(domain: "ConnectionManager", code: http.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to respond to request: \(http.statusCode)"])
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(ConnectionResponseResult.self, from: data)
        
        guard result.success else {
            throw NSError(domain: "ConnectionManager", code: 6,
                         userInfo: [NSLocalizedDescriptionKey: result.error ?? "Unknown error"])
        }
    }
    
    // MARK: - Syncing with Server
    
    /// Fetch pending requests from server
    func syncPendingRequests() async throws {
        debugLog("syncPendingRequests")
        
        guard let myPersona = personaManager.activePersona() else {
            debugLog("No active persona, skipping sync")
            return
        }
        
        guard let base = URL(string: baseURLString) else { throw URLError(.badURL) }
        let url = base
            .appendingPathComponent("api")
            .appendingPathComponent("connections")
            .appendingPathComponent("pending")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(myPersona.id, forHTTPHeaderField: "X-DID")
        
        debugLog("GET \(url.absoluteString) [syncPendingRequests]")
        
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        debugLog("syncPendingRequests response status=\(http.statusCode)")
        
        guard (200...299).contains(http.statusCode) else {
            throw NSError(domain: "ConnectionManager", code: http.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to sync pending requests: \(http.statusCode)"])
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        struct PendingRequestsResponse: Codable {
            let requests: [ConnectionRequest]
        }
        
        let result = try decoder.decode(PendingRequestsResponse.self, from: data)
        pendingRequests = result.requests
        saveToDisk()
        
        debugLog("Synced \(result.requests.count) pending requests")
    }
    
    /// Fetch sent requests from server
    func syncSentRequests() async throws {
        debugLog("syncSentRequests")
        
        guard let myPersona = personaManager.activePersona() else {
            debugLog("No active persona, skipping sync")
            return
        }
        
        guard let base = URL(string: baseURLString) else { throw URLError(.badURL) }
        let url = base
            .appendingPathComponent("api")
            .appendingPathComponent("connections")
            .appendingPathComponent("sent")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(myPersona.id, forHTTPHeaderField: "X-DID")
        
        debugLog("GET \(url.absoluteString) [syncSentRequests]")
        
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        debugLog("syncSentRequests response status=\(http.statusCode)")
        
        guard (200...299).contains(http.statusCode) else {
            throw NSError(domain: "ConnectionManager", code: http.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to sync sent requests: \(http.statusCode)"])
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        struct SentRequestsResponse: Codable {
            let requests: [ConnectionRequest]
        }
        
        let result = try decoder.decode(SentRequestsResponse.self, from: data)
        
        // Update sent requests, moving accepted ones to colleagues
        for request in result.requests {
            if request.status == .accepted {
                if var colleague = Colleague.from(request: request, myDID: myPersona.id) {
                    colleague.verificationStatus = .verified
                    
                    // Update existing colleague or add new
                    if let existingIndex = colleagues.firstIndex(where: { $0.did == colleague.did }) {
                        var existing = colleagues[existingIndex]
                        existing.verificationStatus = .verified
                        colleagues[existingIndex] = existing
                    } else {
                        colleagues.append(colleague)
                    }
                }
            } else if request.status == .rejected {
                // Update verification status to rejected
                if let existingIndex = colleagues.firstIndex(where: { $0.did == request.toDID }) {
                    var existing = colleagues[existingIndex]
                    existing.verificationStatus = .rejected
                    colleagues[existingIndex] = existing
                }
            }
        }
        
        // Keep only pending/rejected sent requests
        sentRequests = result.requests.filter { $0.status != .accepted }
        saveToDisk()
        
        debugLog("Synced \(result.requests.count) sent requests")
    }
    
    /// Fetch all colleagues from server
    func syncColleagues() async throws {
        debugLog("syncColleagues")
        
        guard let myPersona = personaManager.activePersona() else {
            debugLog("No active persona, skipping sync")
            return
        }
        
        guard let base = URL(string: baseURLString) else { throw URLError(.badURL) }
        let url = base
            .appendingPathComponent("api")
            .appendingPathComponent("connections")
            .appendingPathComponent("colleagues")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(myPersona.id, forHTTPHeaderField: "X-DID")
        
        debugLog("GET \(url.absoluteString) [syncColleagues]")
        
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        debugLog("syncColleagues response status=\(http.statusCode)")
        
        guard (200...299).contains(http.statusCode) else {
            throw NSError(domain: "ConnectionManager", code: http.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to sync colleagues: \(http.statusCode)"])
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        struct ColleaguesResponse: Codable {
            let colleagues: [Colleague]
        }
        
        let result = try decoder.decode(ColleaguesResponse.self, from: data)
        colleagues = result.colleagues
        saveToDisk()
        
        debugLog("Synced \(result.colleagues.count) colleagues")
    }
    
    /// Full sync of all connection data
    func syncAll() async throws {
        try await syncPendingRequests()
        try await syncSentRequests()
        try await syncColleagues()
    }
    
    // MARK: - Local Management
    
    /// Add an unverified colleague (for immediate visibility before verification)
    func addUnverifiedColleague(
        did: String,
        name: String,
        shortId: String?,
        prettyDID: String?,
        handle: String?
    ) {
        // Don't add if already exists
        guard !colleagues.contains(where: { $0.did == did }) else {
            debugLog("Colleague already exists: \(did)")
            return
        }
        
        let colleague = Colleague(
            id: UUID().uuidString,
            did: did,
            name: name,
            handle: handle,
            email: nil,
            address: nil,
            affiliations: nil,
            socialLinks: nil,
            shortId: shortId,
            prettyDID: prettyDID,
            connectedAt: Date(),
            lastInteractionAt: nil,
            notes: nil,
            isFavorite: false,
            tags: nil,
            verificationStatus: .unverified
        )
        
        colleagues.append(colleague)
        saveToDisk()
        debugLog("Added unverified colleague: \(name) (\(did))")
    }
    
    /// Remove a colleague (local only - server endpoint needed for full deletion)
    func removeColleague(_ colleague: Colleague) {
        colleagues.removeAll { $0.id == colleague.id }
        saveToDisk()
        debugLog("Removed colleague did=\(colleague.did)")
    }
    
    /// Update colleague notes/metadata
    func updateColleague(_ colleague: Colleague) {
        if let idx = colleagues.firstIndex(where: { $0.id == colleague.id }) {
            colleagues[idx] = colleague
            saveToDisk()
            debugLog("Updated colleague did=\(colleague.did)")
        }
    }
    
    /// Check if DID is already a colleague
    func isColleague(did: String) -> Bool {
        return colleagues.contains { $0.did == did }
    }
    
    /// Check if there's a pending request to/from this DID
    func hasPendingRequest(did: String) -> Bool {
        return pendingRequests.contains { $0.fromDID == did } ||
               sentRequests.contains { $0.toDID == did && $0.status == .pending }
    }
    
    /// Get colleague by DID
    func colleague(for did: String) -> Colleague? {
        return colleagues.first { $0.did == did }
    }
}
