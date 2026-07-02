import Foundation

/// Centralized client-side logging utility
/// Provides structured logging with request IDs, timestamps, and severity levels
public struct ClientLogger {
    
    public enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    /// Global setting to control whether logs are printed
    /// Set to false in production builds to disable logging
    public static var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false // Change to true if you want logging in Release builds
        #endif
    }()
    
    /// Log a message with optional request ID
    /// - Parameters:
    ///   - level: The severity level
    ///   - component: The component or module name (e.g., "SignRequestsView", "DocumentService")
    ///   - message: The log message
    ///   - requestID: Optional request ID for tracing related logs
    ///   - file: Source file (auto-filled)
    ///   - line: Line number (auto-filled)
    public static func log(
        _ level: Level,
        component: String,
        _ message: String,
        requestID: String? = nil,
        file: String = #file,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        
        var logMessage = "[ \(level.rawValue) ] [\(component)]"
        
        if let requestID = requestID {
            logMessage += " [request-id: \(requestID)]"
        }
        
        logMessage += " \(message)"
        
        // In debug builds, also show file and line
        #if DEBUG
        logMessage += " (\(fileName):\(line))"
        #endif
        
        print(logMessage)
    }
    
    // MARK: - Convenience Methods
    
    public static func debug(component: String, _ message: String, requestID: String? = nil, file: String = #file, line: Int = #line) {
        log(.debug, component: component, message, requestID: requestID, file: file, line: line)
    }
    
    public static func info(component: String, _ message: String, requestID: String? = nil, file: String = #file, line: Int = #line) {
        log(.info, component: component, message, requestID: requestID, file: file, line: line)
    }
    
    public static func warning(component: String, _ message: String, requestID: String? = nil, file: String = #file, line: Int = #line) {
        log(.warning, component: component, message, requestID: requestID, file: file, line: line)
    }
    
    public static func error(component: String, _ message: String, requestID: String? = nil, file: String = #file, line: Int = #line) {
        log(.error, component: component, message, requestID: requestID, file: file, line: line)
    }
}

// MARK: - Request ID Generator

public struct RequestIDGenerator {
    /// Generate a short, readable request ID similar to server format
    /// Example: "A2FC6EBC-585C-4F01-B432-062B28333091"
    public static func generate() -> String {
        return UUID().uuidString
    }
    
    /// Generate a shorter 8-character request ID
    /// Example: "A2FC6EBC"
    public static func generateShort() -> String {
        return UUID().uuidString.prefix(8).uppercased()
    }
}

// MARK: - Component Names (for consistency)

public enum LogComponent {
    public static let signRequestsView = "SignRequestsView"
    public static let documentSigningDetail = "DocumentSigningDetail"
    public static let documentService = "DocumentSigningService"
    public static let personaManager = "PersonaManager"
    public static let contactsView = "ContactsView"
    public static let networkClient = "NetworkClient"
    public static let proposedPersona = "ProposedPersona"
}
