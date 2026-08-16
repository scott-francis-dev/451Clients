import XCTest
@testable import Core451

/// Pins the wire contract for the `/api/connections/*` endpoints: URL, method,
/// headers and body. These are what the server actually sees, so they are the
/// assertions that catch a client/server drift.
@MainActor
final class ConnectionManagerRequestTests: XCTestCase {

    private let base = "https://api.test.451.info"
    private var personaManager: PersonaManager!
    private var persona: Persona!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()

        persona = Persona(
            id: "did:451:tester",
            controller: "did:451:tester",
            name: "Tester",
            handle: "tester.451.info",
            publicKeyBase64: "dGVzdA==",
            createdAt: "2026-01-01T00:00:00Z"
        )

        personaManager = PersonaManager()
        personaManager.deleteAllPersonas()
        personaManager.addPersona(persona)
        personaManager.setActivePersona(persona)
    }

    override func tearDown() {
        personaManager?.deleteAllPersonas()
        personaManager = nil
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeManager() -> ConnectionManager {
        ConnectionManager(
            baseURLString: base,
            session: MockURLProtocol.makeSession(),
            personaManager: personaManager
        )
    }

    // MARK: - GET /api/connections/pending

    func testSyncPendingRequestsIssuesGETWithDIDHeader() async throws {
        MockURLProtocol.respond(json: #"{"requests":[]}"#)
        let manager = makeManager()

        try await manager.syncPendingRequests()

        let request = try XCTUnwrap(MockURLProtocol.recorded.first)
        XCTAssertEqual(request.url?.absoluteString, "\(base)/api/connections/pending")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-DID"), "did:451:tester")
    }

    func testSyncPendingRequestsThrowsOnServerError() async {
        MockURLProtocol.respond(status: 500, json: #"{"error":"boom"}"#)
        let manager = makeManager()

        do {
            try await manager.syncPendingRequests()
            XCTFail("Expected a 500 to throw")
        } catch {
            XCTAssertEqual((error as NSError).code, 500)
        }
    }

    // MARK: - POST /api/connections/request

    func testSendConnectionRequestIssuesPOSTWithJSONBody() async throws {
        MockURLProtocol.respond(json: #"{"success":true,"request":null}"#)
        let manager = makeManager()

        // The response shape is incidental here; the request is what we assert.
        _ = try? await manager.sendConnectionRequest(
            toDID: "did:451:other",
            message: "hello"
        )

        let request = try XCTUnwrap(MockURLProtocol.recorded.first)
        XCTAssertEqual(request.url?.absoluteString, "\(base)/api/connections/request")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-DID"), "did:451:tester")

        let body = try XCTUnwrap(MockURLProtocol.body(of: request))
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        XCTAssertEqual(json["toDID"] as? String, "did:451:other")
        XCTAssertEqual(json["message"] as? String, "hello")
    }

    // MARK: - Base URL plumbing

    /// Guards the path join: a base URL carrying a trailing slash or a
    /// sub-path must still produce a well-formed endpoint.
    func testBaseURLWithTrailingSlashStillFormsValidPath() async throws {
        MockURLProtocol.respond(json: #"{"requests":[]}"#)
        let manager = ConnectionManager(
            baseURLString: "https://api.test.451.info/",
            session: MockURLProtocol.makeSession(),
            personaManager: personaManager
        )

        try await manager.syncPendingRequests()

        let request = try XCTUnwrap(MockURLProtocol.recorded.first)
        let url = try XCTUnwrap(request.url?.absoluteString)
        XCTAssertFalse(url.contains("//api/"), "Double slash in path: \(url)")
        XCTAssertTrue(url.hasSuffix("/api/connections/pending"), "Got \(url)")
    }

    /// No active persona means no credentials to send; the sync must not
    /// fire a request the server would reject.
    func testSyncWithoutActivePersonaIssuesNoRequest() async throws {
        personaManager.activePersonaId = nil
        MockURLProtocol.respond(json: #"{"requests":[]}"#)
        let manager = makeManager()

        try await manager.syncPendingRequests()

        XCTAssertTrue(
            MockURLProtocol.recorded.isEmpty,
            "Expected no request without an active persona"
        )
    }
}
