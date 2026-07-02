import Foundation

enum SharedContainer {
    // Update this to your actual App Group ID in your project capabilities
    static let appGroupID: String = "group.org.the451project.451apps"

    static var url: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return url
        }
        // Fallback to documents directory if App Group isn't configured yet (development convenience)
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    static var draftsDirectory: URL {
        url.appendingPathComponent("Drafts", isDirectory: true)
    }

    static var resolverCacheURL: URL {
        fileURL("persona_resolver_cache.json")
    }

    static var legacyResolverCacheURL: URL {
        documentsURL.appendingPathComponent("persona_resolver_cache.json")
    }

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func ensureDirectories() {
        let fm = FileManager.default
        do {
            if !fm.fileExists(atPath: draftsDirectory.path) {
                try fm.createDirectory(at: draftsDirectory, withIntermediateDirectories: true)
            }
        } catch {
            // Non-fatal: directory creation failure shouldn't crash app
            print("SharedContainer.ensureDirectories error: \(error.localizedDescription)")
        }
    }

    static func fileURL(_ name: String) -> URL {
        return url.appendingPathComponent(name)
    }
}
