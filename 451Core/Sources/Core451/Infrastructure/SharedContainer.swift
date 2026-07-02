import Foundation

public enum SharedContainer {
    // Set once at app launch before any store initializes.
    // Must match the App Group entitlement in each app target.
    public static var appGroupID: String = "group.info.451.451apps"

    public static var url: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return url
        }
        // Fallback to documents directory if App Group isn't configured yet (development convenience)
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    public static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    public static var draftsDirectory: URL {
        url.appendingPathComponent("Drafts", isDirectory: true)
    }

    public static var resolverCacheURL: URL {
        fileURL("persona_resolver_cache.json")
    }

    public static var legacyResolverCacheURL: URL {
        documentsURL.appendingPathComponent("persona_resolver_cache.json")
    }

    public static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    public static func ensureDirectories() {
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

    public static func fileURL(_ name: String) -> URL {
        return url.appendingPathComponent(name)
    }
}
