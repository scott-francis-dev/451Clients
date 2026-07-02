import Foundation

struct ServerConfig {
    // MARK: - Preset Servers
    
    /// Predefined server presets
    enum Preset: String, CaseIterable {
        case production = "production"
        case development = "development"
        case local = "local"
        
        var url: String {
            switch self {
            case .production:
                return "https://api.451.info"
            case .development:
                return "https://api.dev.451.info"
            case .local:
                return "https://api.local.451.info"
            }
        }
        
        var displayName: String {
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
    static var selectedPreset: Preset {
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
    
    /// Get the current base URL (priority: custom → selected preset → production default)
    static var baseURL: String {
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
    static func setCustomServer(_ url: String?) {
        if let url = url, !url.isEmpty {
            var trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove any trailing slashes
            while trimmed.hasSuffix("/") {
                trimmed.removeLast()
            }
            
            // Ensure it has a scheme
            if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
                trimmed = "https://" + trimmed
            }
            
            // Clean the URL to remove any malformations
            let finalURL = cleanURL(trimmed)
            
            UserDefaults.standard.set(finalURL, forKey: customServerKey)
        } else {
            UserDefaults.standard.removeObject(forKey: customServerKey)
        }
    }
    
    /// Check if a custom server URL is currently set
    static var isUsingCustomServer: Bool {
        if let custom = UserDefaults.standard.string(forKey: customServerKey), !custom.isEmpty {
            return true
        }
        return false
    }
    
    /// Get the default production URL
    static var defaultURL: String {
        return Preset.production.url
    }
    
    // MARK: - Reset
    
    /// Reset all server configuration to defaults (production preset, no custom server)
    static func resetToDefaults() {
        setCustomServer(nil)
        selectedPreset = .production  // Default to Production
    }
    
    // MARK: - Debug Utilities
    
    /// Get diagnostic information about the current server configuration
    static func diagnosticInfo() -> String {
        var info = "=== Server Configuration Diagnostics ===\n"
        info += "Current Base URL: \(baseURL)\n"
        info += "Using Custom Server: \(isUsingCustomServer)\n"
        
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
