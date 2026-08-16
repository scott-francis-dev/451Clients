import XCTest
@testable import Core451

/// Covers how a request's destination is chosen. Every command and service
/// resolves its host through `ServerConfig.baseURL`, so a regression here
/// silently points traffic at the wrong server rather than failing loudly.
final class ServerConfigTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServerConfig.overrideURL = nil
        ServerConfig.setCustomServer(nil)
        ServerConfig.selectedPreset = .production
    }

    override func tearDown() {
        ServerConfig.overrideURL = nil
        ServerConfig.setCustomServer(nil)
        ServerConfig.selectedPreset = .production
        super.tearDown()
    }

    // MARK: - Presets

    func testPresetURLs() {
        XCTAssertEqual(ServerConfig.Preset.production.url, "https://api.451.info")
        XCTAssertEqual(ServerConfig.Preset.development.url, "https://api.dev.451.info")
        XCTAssertEqual(ServerConfig.Preset.local.url, "https://api.local.451.info")
    }

    func testDefaultsToProduction() {
        XCTAssertEqual(ServerConfig.baseURL, "https://api.451.info")
        XCTAssertEqual(ServerConfig.defaultURL, "https://api.451.info")
        XCTAssertFalse(ServerConfig.isUsingCustomServer)
    }

    func testSelectedPresetChangesBaseURL() {
        ServerConfig.selectedPreset = .development
        XCTAssertEqual(ServerConfig.baseURL, "https://api.dev.451.info")
    }

    // MARK: - Precedence: override → custom → preset

    func testCustomServerBeatsPreset() {
        ServerConfig.selectedPreset = .development
        ServerConfig.setCustomServer("https://ngrok.example.com")
        XCTAssertEqual(ServerConfig.baseURL, "https://ngrok.example.com")
        XCTAssertTrue(ServerConfig.isUsingCustomServer)
    }

    func testOverrideBeatsCustomServerAndPreset() {
        ServerConfig.selectedPreset = .development
        ServerConfig.setCustomServer("https://ngrok.example.com")
        ServerConfig.overrideURL = "http://localhost:8080"
        XCTAssertEqual(ServerConfig.baseURL, "http://localhost:8080")
    }

    func testClearingOverrideFallsBackToCustomServer() {
        ServerConfig.setCustomServer("https://ngrok.example.com")
        ServerConfig.overrideURL = "http://localhost:8080"
        ServerConfig.overrideURL = nil
        XCTAssertEqual(ServerConfig.baseURL, "https://ngrok.example.com")
    }

    func testClearingCustomServerFallsBackToPreset() {
        ServerConfig.setCustomServer("https://ngrok.example.com")
        ServerConfig.setCustomServer(nil)
        XCTAssertEqual(ServerConfig.baseURL, "https://api.451.info")
        XCTAssertFalse(ServerConfig.isUsingCustomServer)
    }

    // MARK: - The override must never persist

    /// The CLI's `--server` flag is per-invocation. If it leaked into
    /// UserDefaults it would silently redirect every later run — and the
    /// GUI apps, which share this domain.
    func testOverrideIsNotPersisted() {
        ServerConfig.overrideURL = "http://localhost:8080"

        XCTAssertFalse(
            ServerConfig.isUsingCustomServer,
            "Override must not register as a persisted custom server"
        )

        // Simulate a fresh process: persisted state is all that survives.
        ServerConfig.overrideURL = nil
        XCTAssertEqual(
            ServerConfig.baseURL,
            "https://api.451.info",
            "A new process must not inherit the previous run's --server"
        )
    }

    func testSetCustomServerDoesPersist() {
        ServerConfig.setCustomServer("https://ngrok.example.com")
        // Read through a separate lookup to prove it round-tripped to storage.
        let stored = UserDefaults.standard.string(forKey: "customServerURL")
        XCTAssertEqual(stored, "https://ngrok.example.com")
    }

    // MARK: - Normalization

    func testSchemeIsAddedWhenMissing() {
        ServerConfig.overrideURL = "api.dev.451.info"
        XCTAssertEqual(ServerConfig.baseURL, "https://api.dev.451.info")
    }

    func testExplicitHTTPSchemeIsPreserved() {
        ServerConfig.overrideURL = "http://localhost:8080"
        XCTAssertEqual(ServerConfig.baseURL, "http://localhost:8080")
    }

    func testTrailingSlashesAreStripped() {
        ServerConfig.overrideURL = "https://api.451.info///"
        XCTAssertEqual(ServerConfig.baseURL, "https://api.451.info")
    }

    func testWhitespaceIsTrimmed() {
        ServerConfig.overrideURL = "  https://api.451.info  "
        XCTAssertEqual(ServerConfig.baseURL, "https://api.451.info")
    }

    func testDoubledSchemeIsRepaired() {
        ServerConfig.overrideURL = "https://https://api.451.info"
        XCTAssertEqual(ServerConfig.baseURL, "https://api.451.info")

        ServerConfig.overrideURL = "http://https://api.451.info"
        XCTAssertEqual(ServerConfig.baseURL, "https://api.451.info")
    }

    func testEmptyAndWhitespaceOnlyAreTreatedAsUnset() {
        ServerConfig.overrideURL = ""
        XCTAssertNil(ServerConfig.overrideURL)
        XCTAssertEqual(ServerConfig.baseURL, "https://api.451.info")

        ServerConfig.overrideURL = "   "
        XCTAssertNil(ServerConfig.overrideURL)
        XCTAssertEqual(ServerConfig.baseURL, "https://api.451.info")
    }

    /// `baseURL` is string-concatenated into request paths all over the
    /// services layer, so it must never end in a slash.
    func testBaseURLNeverEndsInSlash() {
        for candidate in ["https://api.451.info/", "https://api.451.info//", "api.451.info/"] {
            ServerConfig.overrideURL = candidate
            XCTAssertFalse(
                ServerConfig.baseURL.hasSuffix("/"),
                "baseURL ended in a slash for input \(candidate)"
            )
        }
    }

    /// Whatever `baseURL` returns must survive `URL(string:)`, or every
    /// request builder throws `URLError.badURL`.
    func testBaseURLIsAlwaysParseable() {
        for candidate in ["api.451.info", "http://localhost:8080", "https://api.451.info///"] {
            ServerConfig.overrideURL = candidate
            XCTAssertNotNil(
                URL(string: ServerConfig.baseURL),
                "baseURL was unparseable for input \(candidate)"
            )
        }
    }

    // MARK: - Reset & diagnostics

    func testResetToDefaults() {
        ServerConfig.selectedPreset = .development
        ServerConfig.setCustomServer("https://ngrok.example.com")
        ServerConfig.resetToDefaults()

        XCTAssertEqual(ServerConfig.selectedPreset, .production)
        XCTAssertFalse(ServerConfig.isUsingCustomServer)
        XCTAssertEqual(ServerConfig.baseURL, "https://api.451.info")
    }

    func testDiagnosticInfoReportsActiveOverride() {
        ServerConfig.overrideURL = "http://localhost:8080"
        let info = ServerConfig.diagnosticInfo()
        XCTAssertTrue(info.contains("http://localhost:8080"))
        XCTAssertTrue(info.contains("Process Override"))
    }
}
