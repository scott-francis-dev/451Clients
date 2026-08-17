import XCTest
@testable import Core451

/// `SignatureStatus` was rewritten to mirror the server's `SignaturesDocument` after the
/// client was found calling `/api/document/{id}/signatures` — singular, and not a route. The
/// real one is `/api/documents/{id}/signatures`, and it returns a payload that shares only
/// `documentId` with what the client used to expect. Fixing the path alone would have traded
/// a 404 for a decode error.
///
/// The payload below is not hand-written. It is the response captured verbatim from an S451
/// server on 2026-08-17, running against local MinIO, for a document seeded into storage.
/// That matters: a fixture invented from reading the server's Swift types would agree with
/// those types by construction and prove nothing about what actually crosses the wire.
///
/// Two details in it are the ones worth pinning, and both are easy to get wrong by inspecting
/// the model instead of the traffic: `completedAt` is *absent* rather than null when a
/// document is still being signed, and a pending signer's row omits every optional field
/// rather than sending nulls.
final class SignatureStatusDecodingTests: XCTestCase {

    /// Verbatim server response. Do not reformat — the point is that this is what arrived.
    private let liveResponse = Data("""
    {"documentId":"DOC123","requiredSignatures":2,"documentHash":"abc123hash","metadataHash":"def456hash","created":"2026-08-17T00:00:00Z","collectedSignatures":1,"updated":"2026-08-17T01:00:00Z","status":"signing","signatures":[{"signature":"AA==","role":"author","documentHash":"abc123hash","blockchainBlockHash":"blockhash3","metadataHash":"def456hash","timestamp":"2026-08-17T00:30:00Z","status":"verified","signer":"did:451:alice","blockchainBlockIndex":3},{"status":"pending","role":"participant","signer":"did:451:bob"}]}
    """.utf8)

    private func decoded() throws -> DocumentSigningService.SignatureStatus {
        try JSONDecoder().decode(DocumentSigningService.SignatureStatus.self, from: liveResponse)
    }

    func testDecodesTheLiveServerResponse() throws {
        let status = try decoded()
        XCTAssertEqual(status.documentId, "DOC123")
        XCTAssertEqual(status.documentHash, "abc123hash")
        XCTAssertEqual(status.metadataHash, "def456hash")
        XCTAssertEqual(status.requiredSignatures, 2)
        XCTAssertEqual(status.collectedSignatures, 1)
        XCTAssertEqual(status.status, "signing")
        XCTAssertEqual(status.signatures.count, 2)
    }

    /// The server omits `completedAt` entirely while signing rather than sending null, so the
    /// field has to be optional and its absence must not fail the decode.
    func testAbsentCompletedAtDecodesAsNil() throws {
        XCTAssertNil(try decoded().completedAt)
    }

    /// A signer who has not signed yet arrives with only signer/role/status — no timestamp,
    /// no signature, no block reference. Every one of those has to be optional.
    func testAPendingSignerOmitsAllOptionalFields() throws {
        let pending = try XCTUnwrap(try decoded().signatures.first { $0.signer == "did:451:bob" })
        XCTAssertEqual(pending.role, "participant")
        XCTAssertEqual(pending.status, "pending")
        XCTAssertFalse(pending.hasSigned)
        XCTAssertNil(pending.signature)
        XCTAssertNil(pending.timestamp)
        XCTAssertNil(pending.documentHash)
        XCTAssertNil(pending.metadataHash)
        XCTAssertNil(pending.blockchainBlockIndex)
        XCTAssertNil(pending.blockchainBlockHash)
    }

    func testASignedRowCarriesItsProof() throws {
        let signed = try XCTUnwrap(try decoded().signatures.first { $0.signer == "did:451:alice" })
        XCTAssertTrue(signed.hasSigned, "status \"verified\" is what counts as signed")
        XCTAssertEqual(signed.signature, "AA==")
        XCTAssertEqual(signed.timestamp, "2026-08-17T00:30:00Z")
        XCTAssertEqual(signed.blockchainBlockIndex, 3)
        XCTAssertEqual(signed.blockchainBlockHash, "blockhash3")
    }

    // MARK: - The derived values the UI reads

    /// `totalSignatures` is what MultiPartySigningView shows. It must be the count actually
    /// collected, not the size of the roster — the roster includes people who have not signed.
    func testTotalSignaturesCountsCollectedNotRoster() throws {
        let status = try decoded()
        XCTAssertEqual(status.totalSignatures, 1, "one of two signers has signed")
        XCTAssertEqual(status.signatures.count, 2, "but both are listed")
    }

    /// Grouping counts verified rows only, so it sums to `collectedSignatures` rather than to
    /// the number of rows.
    func testSignaturesByRoleCountsOnlyVerified() throws {
        let status = try decoded()
        XCTAssertEqual(status.signaturesByRole, ["author": 1])
        XCTAssertNil(status.signaturesByRole["participant"], "a pending participant has not signed")
        XCTAssertEqual(status.signaturesByRole.values.reduce(0, +), status.collectedSignatures)
    }
}
