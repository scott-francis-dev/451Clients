import Foundation

/// Server configuration for different environments
public struct ServerConfiguration {
    public let baseURL: String
    public let environment: Environment
    
    public enum Environment {
        case development
        case staging
        case production
        
        var displayName: String {
            switch self {
            case .development: return "Development"
            case .staging: return "Staging"
            case .production: return "Production"
            }
        }
    }
    
    /// Current active configuration
    public static var current: ServerConfiguration {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    /// Development server (localhost)
    public static let development = ServerConfiguration(
        baseURL: "http://localhost:8080",
        environment: .development
    )
    
    /// Staging server (if you have one)
    public static let staging = ServerConfiguration(
        baseURL: "https://staging.the451project.org",
        environment: .staging
    )
    
    /// Production server
    public static let production = ServerConfiguration(
        baseURL: "https://the451project.org",
        environment: .production
    )
    
    /// Override for custom configuration
    public static func custom(baseURL: String) -> ServerConfiguration {
        return ServerConfiguration(baseURL: baseURL, environment: .development)
    }
}
