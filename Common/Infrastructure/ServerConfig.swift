import Foundation

public struct ServerConfig {
    // MARK: - Preset Servers
    
    /// Predefined server presets
    public enum Preset: String, CaseIterable {
        case production = "production"
        case development = "development"
        case local = "local"

        public var url: String {
            switch self {
            case .production:
                return "https://api.451.info"
            case .development:
                return "https://api.dev.451.info"
            case .local:
                return "https://api.local.451.info"
            }
        }
        
        public var displayName: String {
            switch self {
            case .production:
                return "Production"
            case .development:
                return "Dev/QA"
            case .local:
                return "Local"
            }
        }
    }
    
    // MARK: - UserDefaults Keys
    
    private static let customServerKey = "customServerURL"
    private static let selectedPresetKey = "selectedServerPreset"
    
    // MARK: - Selected Preset
    
    /// Get the currently selected preset (defaults to production)
    public static var selectedPreset: Preset {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: selectedPresetKey),
                  let preset = Preset(rawValue: rawValue) else {
                return .production  // Default to Production
            }
            return preset
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: selectedPresetKey)
        }
    }
    
    // MARK: - Base URL Resolution
    
    /// Clean and validate a URL string
    private static func cleanURL(_ url: String) -> String {
        var cleaned = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove trailing slashes
        while cleaned.hasSuffix("/") {
            cleaned.removeLast()
        }
        
        // Fix malformed URLs with double protocol (https://https://)
        if cleaned.lowercased().hasPrefix("https://https://") {
            cleaned = String(cleaned.dropFirst("https://".count))
        } else if cleaned.lowercased().hasPrefix("https://http://") {
            cleaned = String(cleaned.dropFirst("https://".count))
        } else if cleaned.lowercased().hasPrefix("http://https://") {
            cleaned = String(cleaned.dropFirst("http://".count))
        } else if cleaned.lowercased().hasPrefix("http://http://") {
            cleaned = String(cleaned.dropFirst("http://".count))
        }
        
        // Fix double-slashes after protocol (e.g., https://example.com → https://example.com)
        if let range = cleaned.range(of: "://") {
            let afterProtocol = cleaned[range.upperBound...]
            let withoutDoubleSlash = afterProtocol.replacingOccurrences(of: "//", with: "/")
            cleaned = String(cleaned[..<range.upperBound]) + withoutDoubleSlash
        }
        
        return cleaned
    }
    
    /// Normalize a user-supplied server URL: trim, strip trailing slashes,
    /// add a scheme when missing, and repair common malformations.
    /// Returns nil for nil, empty, or whitespace-only input.
    private static func normalize(_ url: String?) -> String? {
        guard let url else { return nil }
        var trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Remove any trailing slashes
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }

        // Ensure it has a scheme
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "https://" + trimmed
        }

        // Clean the URL to remove any malformations
        return cleanURL(trimmed)
    }

    // MARK: - Process Override

    private static var _overrideURL: String?

    /// Process-scoped server override — highest priority, never persisted.
    ///
    /// Set this for a single run (the CLI's `--server` flag) so one invocation
    /// cannot silently redirect later runs, or the GUI apps sharing this domain.
    /// Use `setCustomServer` instead when the choice *should* stick.
    public static var overrideURL: String? {
        get { _overrideURL }
        set { _overrideURL = normalize(newValue) }
    }

    /// Get the current base URL
    /// (priority: process override → custom → selected preset → production default)
    public static var baseURL: String {
        // Priority 0: Process-scoped override (CLI --server), never persisted
        if let overrideURL = _overrideURL {
            return overrideURL
        }

        // Priority 1: Custom server URL (e.g., ngrok)
        if let customURL = UserDefaults.standard.string(forKey: customServerKey), !customURL.isEmpty {
            return cleanURL(customURL)
        }

        // Priority 2: Selected preset (production or development)
        return selectedPreset.url
    }

    // MARK: - Custom Server Management

    /// Set a custom server URL (e.g., ngrok URL for development)
    /// Pass nil or empty string to reset to preset selection
    public static func setCustomServer(_ url: String?) {
        if let finalURL = normalize(url) {
            UserDefaults.standard.set(finalURL, forKey: customServerKey)
        } else {
            UserDefaults.standard.removeObject(forKey: customServerKey)
        }
    }

    /// Check if a custom server URL is currently set
    public static var isUsingCustomServer: Bool {
        if let custom = UserDefaults.standard.string(forKey: customServerKey), !custom.isEmpty {
            return true
        }
        return false
    }
    
    /// Get the default production URL
    public static var defaultURL: String {
        return Preset.production.url
    }
    
    // MARK: - Reset
    
    /// Reset all server configuration to defaults (production preset, no custom server)
    public static func resetToDefaults() {
        setCustomServer(nil)
        selectedPreset = .production  // Default to Production
    }
    
    // MARK: - Debug Utilities
    
    /// Get diagnostic information about the current server configuration
    public static func diagnosticInfo() -> String {
        var info = "=== Server Configuration Diagnostics ===\n"
        info += "Current Base URL: \(baseURL)\n"
        info += "Using Custom Server: \(isUsingCustomServer)\n"

        if let overrideURL = _overrideURL {
            info += "Process Override (not persisted): \(overrideURL)\n"
        }

        if isUsingCustomServer {
            if let raw = UserDefaults.standard.string(forKey: customServerKey) {
                info += "Raw Custom URL (before cleaning): \(raw)\n"
                info += "Cleaned Custom URL: \(cleanURL(raw))\n"
            }
        } else {
            info += "Selected Preset: \(selectedPreset.displayName)\n"
            info += "Preset URL: \(selectedPreset.url)\n"
        }
        
        return info
    }
}

// Usage: ServerConfig.baseURL everywhere you build network requests.
