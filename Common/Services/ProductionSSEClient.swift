import Foundation

// Import progress types
// Note: ProgressStep, CompletionEvent, and ErrorEvent should be defined in ServerProgressMapper.swift
// If not in the same module, add appropriate import statement

// MARK: - Production SSE Client

/// Production-ready Server-Sent Events (SSE) client for real-time progress tracking
/// 
/// Features:
/// - Real-time SSE streaming from Vapor backend
/// - Automatic reconnection (up to 2 attempts) if connection drops
/// - Polling fallback if SSE unavailable
/// - Thread-safe, memory-safe implementation
/// - Graceful cleanup on completion or error
public class ProductionSSEClient {
    
    // MARK: - Types
    
    public struct UploadResult {
        public let taskId: String
        public let draftId: String
        public let documentId: String
    }
    
    // MARK: - Properties
    
    private var streamTask: URLSessionDataTask?
    private var session: URLSession?
    private var buffer = ""
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 2
    private var isConnected = false
    private var isCancelled = false
    private var didReceiveAnyEvent = false
    private var didReceiveTerminalEvent = false
    
    // MARK: - Initialization
    
    public init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300 // 5 minutes
        configuration.timeoutIntervalForResource = 3600 // 1 hour
        configuration.httpMaximumConnectionsPerHost = 1
        self.session = URLSession(configuration: configuration)
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Public Methods
    
    /// Upload document with real-time SSE progress tracking
    public static func uploadDocumentWithProgress(
        baseURL: String,
        documentData: Data,
        documentHash: String,
        fileType: String,
        authorDID: String,
        participants: [[String: String]],
        metadata: [String: String],
        originalFilename: String?,
        onProgress: @escaping (ProgressStep) -> Void,
        onComplete: @escaping (CompletionEvent) -> Void,
        onError: @escaping (ErrorEvent) -> Void
    ) async throws -> UploadResult {
        
        // Step 1: Create draft document
        print("📝 Step 1: Creating draft document...")
        let draftResult = try await createDraft(
            baseURL: baseURL,
            documentHash: documentHash,
            fileType: fileType,
            authorDID: authorDID,
            participants: participants,
            metadata: metadata
        )
        
        print("✅ Draft created: \(draftResult.draftId)")
        print("   Document ID: \(draftResult.documentId)")
        
        // Step 2: Upload document content
        print("📤 Step 2: Uploading document content...")
        let taskId = try await uploadContent(
            baseURL: baseURL,
            draftId: draftResult.draftId,
            documentData: documentData,
            filename: originalFilename ?? "document.\(fileType)"
        )
        
        print("✅ Upload started, Task ID: \(taskId)")
        
        // Step 3: Connect to SSE stream for progress
        print("🔌 Step 3: Connecting to SSE progress stream...")
        let client = ProductionSSEClient()
        await client.connectToProgressStream(
            baseURL: baseURL,
            taskId: taskId,
            onProgress: onProgress,
            onComplete: onComplete,
            onError: onError
        )
        
        return UploadResult(
            taskId: taskId,
            draftId: draftResult.draftId,
            documentId: draftResult.documentId
        )
    }
    
    /// Disconnect from SSE stream
    public func disconnect() {
        isCancelled = true
        streamTask?.cancel()
        streamTask = nil
        session?.invalidateAndCancel()
        session = nil
        isConnected = false
        print("🔌 SSE connection closed")
    }
    
    // MARK: - Private Methods
    
    private struct DraftResult: Decodable {
        let draftId: String
        let documentId: String
    }
    
    private static func createDraft(
        baseURL: String,
        documentHash: String,
        fileType: String,
        authorDID: String,
        participants: [[String: String]],
        metadata: [String: String]
    ) async throws -> DraftResult {
        
        guard let url = URL(string: "\(baseURL)/api/document/draft") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "documentHash": documentHash,
            "fileType": fileType,
            "authorDID": authorDID,
            "participants": participants,
            "metadata": metadata
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "ProductionSSEClient",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Draft creation failed: \(errorMessage)"]
            )
        }
        
        return try JSONDecoder().decode(DraftResult.self, from: data)
    }
    
    private static func uploadContent(
        baseURL: String,
        draftId: String,
        documentData: Data,
        filename: String
    ) async throws -> String {
        
        guard let url = URL(string: "\(baseURL)/api/document/draft/\(draftId)/content") else {
            throw URLError(.badURL)
        }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart form data
        var body = Data()
        
        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(documentData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 202 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "ProductionSSEClient",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Content upload failed: \(errorMessage)"]
            )
        }
        
        struct UploadResponse: Decodable {
            let taskId: String
            let message: String
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse.taskId
    }
    
    public func connectToProgressStream(
        baseURL: String,
        taskId: String,
        onProgress: @escaping (ProgressStep) -> Void,
        onComplete: @escaping (CompletionEvent) -> Void,
        onError: @escaping (ErrorEvent) -> Void,
        onStreamClosed: (() -> Void)? = nil
    ) async {
        
        didReceiveAnyEvent = false
        didReceiveTerminalEvent = false
        
        guard let url = URL(string: "\(baseURL)/api/progress/\(taskId)/stream") else {
            onError(ErrorEvent(
                code: "invalid_url",
                message: "Invalid SSE stream URL",
                details: nil
            ))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 3600 // 1 hour
        
        print("🔌 Connecting to SSE stream: \(url.absoluteString)")
        
        // IMPORTANT: Create a custom URLSession with delegate to receive streaming data
        let delegateSession: URLSession
        if #available(iOS 15.0, macOS 12.0, *) {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 3600
            configuration.timeoutIntervalForResource = 3600
            configuration.httpMaximumConnectionsPerHost = 1
            
            let delegate = SSEDelegate(
                onData: { [weak self] data in
                    self?.handleStreamData(
                        data,
                        onProgress: onProgress,
                        onComplete: onComplete,
                        onError: onError
                    )
                },
                onComplete: { [weak self] error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        if !self.isCancelled {
                            print("❌ SSE connection error: \(error.localizedDescription)")
                            
                            // Attempt reconnection
                            if self.reconnectAttempts < self.maxReconnectAttempts {
                                self.reconnectAttempts += 1
                                print("🔄 Reconnecting... (attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts))")
                                
                                Task {
                                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                                    await self.connectToProgressStream(
                                        baseURL: baseURL,
                                        taskId: taskId,
                                        onProgress: onProgress,
                                        onComplete: onComplete,
                                        onError: onError
                                    )
                                }
                            } else {
                                onError(ErrorEvent(
                                    code: "connection_failed",
                                    message: "Failed to connect to progress stream after \(self.maxReconnectAttempts) attempts",
                                    details: error.localizedDescription
                                ))
                            }
                        }
                    } else {
                        print("✅ SSE stream completed normally")
                        if !self.isCancelled && !self.didReceiveTerminalEvent {
                            onStreamClosed?()
                        }
                    }
                },
                onResponse: { [weak self] response in
                    guard let self = self else { return }
                    guard let httpResponse = response as? HTTPURLResponse else {
                        if !self.isCancelled {
                            onError(ErrorEvent(
                                code: "invalid_response",
                                message: "Invalid HTTP response",
                                details: nil
                            ))
                        }
                        return
                    }
                    
                    if httpResponse.statusCode == 200 {
                        self.isConnected = true
                        print("✅ Connected to SSE stream (status: 200)")
                    } else {
                        if !self.isCancelled {
                            onError(ErrorEvent(
                                code: "http_error",
                                message: "SSE stream returned status \(httpResponse.statusCode)",
                                details: "Expected 200, got \(httpResponse.statusCode)"
                            ))
                        }
                    }
                }
            )
            
            delegateSession = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        } else {
            // Fallback for older iOS versions - use polling
            print("⚠️ iOS 14 or earlier detected - falling back to polling")
            await Self.pollProgress(
                baseURL: baseURL,
                taskId: taskId,
                onProgress: onProgress,
                onComplete: onComplete,
                onError: onError
            )
            return
        }
        
        // Create streaming task (without completion handler so delegate is used)
        streamTask = delegateSession.dataTask(with: request)
        streamTask?.resume()
        print("🚀 SSE stream task started")
    }
    
    private func handleStreamData(
        _ data: Data,
        onProgress: @escaping (ProgressStep) -> Void,
        onComplete: @escaping (CompletionEvent) -> Void,
        onError: @escaping (ErrorEvent) -> Void
    ) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        
        buffer.append(chunk)
        
        // Process complete SSE events
        while let eventRange = buffer.range(of: "\n\n") {
            // Extract the event safely
            let event = String(buffer[..<eventRange.lowerBound])
            
            // Calculate the range to remove - need to be careful with String.Index
            let endIndex = buffer.index(eventRange.lowerBound, offsetBy: 2, limitedBy: buffer.endIndex) ?? buffer.endIndex
            
            // Remove the processed event and the delimiter safely
            if endIndex <= buffer.endIndex {
                buffer.removeSubrange(buffer.startIndex..<endIndex)
            } else {
                // If somehow the range is invalid, clear the buffer to prevent infinite loop
                buffer = ""
                print("⚠️ SSE buffer range error - cleared buffer")
                break
            }
            
            parseSSEEvent(
                event,
                onProgress: onProgress,
                onComplete: onComplete,
                onError: onError
            )
        }
    }
    
    private func parseSSEEvent(
        _ event: String,
        onProgress: @escaping (ProgressStep) -> Void,
        onComplete: @escaping (CompletionEvent) -> Void,
        onError: @escaping (ErrorEvent) -> Void
    ) {
        let lines = event.components(separatedBy: "\n")
        var eventType = "message"
        var eventData = ""
        
        for line in lines {
            if line.hasPrefix("event:") {
                eventType = line.replacingOccurrences(of: "event:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                eventData = line.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        
        guard !eventData.isEmpty else { return }
        guard let data = eventData.data(using: .utf8) else { return }
        
        do {
            switch eventType {
            case "progress":
                let progress = try JSONDecoder().decode(ProgressStep.self, from: data)
                didReceiveAnyEvent = true
                onProgress(progress)
                
            case "complete":
                let completion = try JSONDecoder().decode(CompletionEvent.self, from: data)
                didReceiveAnyEvent = true
                didReceiveTerminalEvent = true
                onComplete(completion)
                disconnect()
                
            case "error":
                if let parsedError = decodeServerError(from: data) {
                    didReceiveAnyEvent = true
                    didReceiveTerminalEvent = true
                    onError(parsedError)
                    disconnect()
                } else {
                    throw NSError(domain: "ProductionSSEClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error payload"])
                }
                
            default:
                print("⚠️ Unknown SSE event type: \(eventType)")
            }
        } catch {
            print("❌ Failed to parse SSE event: \(error)")
            onError(ErrorEvent(
                code: "parse_error",
                message: "Failed to parse server event",
                details: error.localizedDescription
            ))
        }
    }

    private func decodeServerError(from data: Data) -> ErrorEvent? {
        if let error = try? JSONDecoder().decode(ErrorEvent.self, from: data) {
            return error
        }

        struct ServerErrorPayload: Decodable {
            let error: Bool?
            let reason: String?
            let message: String?
        }

        if let payload = try? JSONDecoder().decode(ServerErrorPayload.self, from: data) {
            let message = payload.reason ?? payload.message ?? "Server error"
            return ErrorEvent(code: "server_error", message: message, details: nil)
        }

        if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
            return ErrorEvent(code: "server_error", message: raw, details: nil)
        }

        return nil
    }
}

// MARK: - SSE Delegate (iOS 15+)

@available(iOS 15.0, macOS 12.0, *)
private class SSEDelegate: NSObject, URLSessionDataDelegate {
    let onData: (Data) -> Void
    let onComplete: (Error?) -> Void
    let onResponse: (URLResponse) -> Void
    
    init(
        onData: @escaping (Data) -> Void,
        onComplete: @escaping (Error?) -> Void,
        onResponse: @escaping (URLResponse) -> Void
    ) {
        self.onData = onData
        self.onComplete = onComplete
        self.onResponse = onResponse
    }
    
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        onResponse(response)
        completionHandler(.allow)
    }
    
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        onData(data)
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        onComplete(error)
    }
}

// MARK: - Fallback Implementation (iOS 14 and earlier)

// For iOS 14 and earlier, you can implement a polling fallback:
extension ProductionSSEClient {
    
    /// Fallback polling method if SSE is unavailable
    private static func pollProgress(
        baseURL: String,
        taskId: String,
        onProgress: @escaping (ProgressStep) -> Void,
        onComplete: @escaping (CompletionEvent) -> Void,
        onError: @escaping (ErrorEvent) -> Void
    ) async {
        
        var isPolling = true
        var pollCount = 0
        let maxPolls = 300 // 5 minutes at 1 second intervals

        // The status endpoint returns the whole step history on every poll, while
        // `onProgress` is a per-step callback. Track how many we have already
        // delivered so a slow poll reports each step once rather than replaying them.
        var reportedSteps = 0

        while isPolling && pollCount < maxPolls {
            pollCount += 1

            do {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                guard let url = URL(string: "\(baseURL)/api/progress/\(taskId)/status") else {
                    onError(ErrorEvent(
                        code: "invalid_url",
                        message: "Invalid polling URL",
                        details: nil
                    ))
                    return
                }

                let (data, _) = try await URLSession.shared.data(from: url)

                /// Mirrors the server's `ProgressStatusResponse`.
                struct PollResponse: Decodable {
                    let taskId: String
                    let steps: [ProgressStep]
                    let completion: CompletionEvent?
                    let error: ErrorEvent?
                    let isComplete: Bool
                }

                let response = try JSONDecoder().decode(PollResponse.self, from: data)

                if response.steps.count > reportedSteps {
                    for step in response.steps[reportedSteps...] {
                        onProgress(step)
                    }
                    reportedSteps = response.steps.count
                }

                if let completion = response.completion {
                    onComplete(completion)
                    isPolling = false
                }

                if let error = response.error {
                    onError(error)
                    isPolling = false
                }

            } catch {
                print("⚠️ Polling error: \(error.localizedDescription)")
                // Continue polling despite errors
            }
        }
        
        if pollCount >= maxPolls {
            onError(ErrorEvent(
                code: "timeout",
                message: "Progress polling timed out after 5 minutes",
                details: nil
            ))
        }
    }
}
