import XCTest
@testable import Core451

/// Step 4 of the `.variable` object kind — the shared tail of both carriers' ingest walks.
/// The per-carrier walks (thesis `RichDoc`, Signator `VariableTemplate`) live in their apps.
final class VariableIndexObjectTests: XCTestCase {

    private func manifest(
        _ key: String,
        value: String? = nil,
        required: Bool = true,
        resolvesFrom: String? = nil,
        label: String? = nil
    ) -> VariableManifest {
        VariableManifest(
            key: key,
            label: label ?? key.capitalized,
            dataType: .person,
            required: required,
            prompt: "Who is the \(key)?",
            resolvesFrom: resolvesFrom,
            value: value
        )
    }

    // MARK: - Manifest ↔ object

    func testRoundTripsThroughManifest() {
        let original = VariableManifest(
            key: "executor_name",
            label: "Executor",
            dataType: .person,
            required: true,
            prompt: "Who should serve as executor?",
            resolvesFrom: "PRIVATE.NAME.FULL",
            value: "Ada Lovelace",
            options: ["a", "b"],
            conditional: "has_executor",
            repeatable: false,
            validation: "^.+$"
        )

        let object = VariableIndexObject(manifest: original, documentID: "doc-1", ordinal: 3)

        XCTAssertEqual(object.entityType, .variable)
        XCTAssertEqual(object.documentID, "doc-1")
        XCTAssertEqual(object.ordinal, 3)
        XCTAssertTrue(object.isFilled)
        XCTAssertEqual(object.manifest, original)
    }

    func testUnfilledObjectIsNotFilled() {
        XCTAssertFalse(VariableIndexObject(manifest: manifest("executor")).isFilled)
        XCTAssertFalse(VariableIndexObject(manifest: manifest("executor", value: "")).isFilled)
    }

    // MARK: - Wire shape (server column mapping)

    func testEncodesToServerColumnNames() throws {
        let object = VariableIndexObject(
            manifest: manifest("executor_name", value: "Ada"),
            documentID: "doc-1",
            ordinal: 0
        )
        let data = try JSONEncoder().encode(object)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["entity_type"] as? String, "variable")
        XCTAssertEqual(json["document_id"] as? String, "doc-1")
        XCTAssertEqual(json["cited_key"] as? String, "executor_name")
        XCTAssertEqual(json["cited_literal"] as? String, "Ada")
        XCTAssertEqual(json["data_type"] as? String, "person")
        XCTAssertNil(json["resolves_from"])

        let decoded = try JSONDecoder().decode(VariableIndexObject.self, from: data)
        XCTAssertEqual(decoded, object)
    }

    // MARK: - The walk's tail: collapse by key

    func testCollapsesRepeatedKeysKeepingFirstAppearanceOrder() {
        // A will names the executor three times; the testator once, later.
        let objects = VariableIndexObject.objects(
            from: [manifest("executor"), manifest("testator"), manifest("executor")],
            documentID: "doc-1"
        )

        XCTAssertEqual(objects.map(\.key), ["executor", "testator"])
        XCTAssertEqual(objects.map(\.ordinal), [0, 1])
        XCTAssertTrue(objects.allSatisfy { $0.documentID == "doc-1" })
    }

    func testFilledOccurrenceSuppliesTheValue() {
        // Only one span of a repeated variable got filled — the slot is still filled.
        let objects = VariableIndexObject.objects(
            from: [manifest("executor"), manifest("executor", value: "Ada")]
        )

        XCTAssertEqual(objects.count, 1)
        XCTAssertEqual(objects[0].value, "Ada")
        XCTAssertTrue(objects[0].isFilled)
    }

    func testFirstValueWinsOverLaterOne() {
        let objects = VariableIndexObject.objects(
            from: [manifest("executor", value: "Ada"), manifest("executor", value: "Grace")]
        )
        XCTAssertEqual(objects.map(\.value), ["Ada"])
    }

    func testRequiredIsTheUnionAndAutoFillSurvives() {
        let objects = VariableIndexObject.objects(
            from: [
                manifest("address", required: false),
                manifest("address", required: true, resolvesFrom: "PRIVATE.ADDRESS.FULL"),
            ]
        )

        XCTAssertEqual(objects.count, 1)
        XCTAssertTrue(objects[0].required, "any occurrence marking the slot required makes it required")
        XCTAssertEqual(objects[0].resolvesFrom, "PRIVATE.ADDRESS.FULL")
    }

    func testFirstOccurrenceOwnsTheDescriptiveFields() {
        let objects = VariableIndexObject.objects(
            from: [manifest("executor", label: "Executor"), manifest("executor", label: "Personal rep")]
        )
        XCTAssertEqual(objects.map(\.label), ["Executor"])
    }

    func testDropsKeylessManifests() {
        let objects = VariableIndexObject.objects(from: [manifest(""), manifest("executor")])
        XCTAssertEqual(objects.map(\.key), ["executor"])
    }

    func testEmptyWalkEmitsNothing() {
        XCTAssertTrue(VariableIndexObject.objects(from: []).isEmpty)
    }

    // MARK: - Publish bridge

    func testMergingOccurrenceIgnoresADifferentKey() {
        let executor = manifest("executor")
        XCTAssertEqual(executor.mergingOccurrence(manifest("testator", value: "Ada")), executor)
    }
}
