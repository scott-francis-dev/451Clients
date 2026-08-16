import XCTest
@testable import Core451

final class Core451Tests: XCTestCase {

    func testPersonaShortID() {
        let persona = Persona(
            id: "did:451:abc123",
            controller: "did:451:abc123",
            name: "Test",
            handle: "test.451.info",
            publicKeyBase64: "dGVzdA==",
            createdAt: "2026-01-01T00:00:00Z"
        )
        XCTAssertEqual(persona.shortID.count, 8)
        XCTAssertEqual(persona.shortIDPhoneStyle.count, 8) // "XXX-XXXX"
    }

    func testPersonaProfileCodingKeys() throws {
        let json = """
        {
            "did": "did:451:test123",
            "controller": "did:451:test123",
            "backgroundCheckRequired": false,
            "handle": "test.451.info",
            "verificationMethod": []
        }
        """
        let data = json.data(using: .utf8)!
        let profile = try JSONDecoder().decode(PersonaProfile.self, from: data)
        XCTAssertEqual(profile.dID, "did:451:test123")
        XCTAssertEqual(profile.handle, "test.451.info")

        // Round-trip: encoded JSON should use lowercase "did", not "dID"
        let encoded = try JSONEncoder().encode(profile)
        let dict = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        XCTAssertNotNil(dict["did"], "Should encode as lowercase 'did'")
        XCTAssertNil(dict["dID"], "Should NOT encode as 'dID'")
    }

    func testServerConfigDefaults() {
        XCTAssertEqual(ServerConfig.baseURL, "https://api.451.info")
    }

    func testDocumentMetadata() {
        let doc = Document451()
        doc.title = "Test"
        doc.accessRights = .public
        XCTAssertEqual(doc.accessrights, "public")
    }
}

