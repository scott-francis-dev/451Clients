//
//  VariableIndexObject.swift
//  Core451
//
//  Layer 1 of the `.variable` object kind — the client→server bridge (search index 3).
//  The *ingest walk* in each app (Layer 2 carrier) turns its tagged slots into these objects;
//  they ride to the server in `DocumentMetadata451.variables` at publish.
//  See thesis/Documentation/VARIABLE_OBJECT_KIND.md §"The ingest walk".
//
//  ⚠️ MIRRORED FILE. Signator is decoupled from Core451 and keeps its own copy at
//  Signator/Signator/VariableIndexObject.swift, exactly as it mirrors Document451.
//  Keep the two textually in sync until/unless Signator re-couples to Core451.
//

import Foundation

/// The pinned, shared vocabulary for S451's polymorphic object index (index 3).
///
/// This resolves the open "vocabulary reconciliation" item: the **server's** `entity_type` is the
/// one vocabulary. Client-side authoring kinds (thesis's `EntityKind`: concept | location |
/// variable) are an editor concern and map onto this at ingest — they are not a second vocabulary
/// on the wire.
public enum IndexEntityType: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case document
    case concept
    case equation
    case figure
    /// Net-new: a fill-in slot. See `VariableIndexObject`.
    case variable
}

/// One `entity_type = variable` row in search index 3 — the wire form of a `VariableManifest`
/// once it has been located inside a specific document.
///
/// Server column mapping (the rest lands in the object's JSON side payload):
/// - `entity_type`   ← always `variable`
/// - `document_id`   ← owning document
/// - `cited_key`     ← `key`
/// - `cited_literal` ← `value` (nil until filled; a *filled* variable still indexes, so completed
///                     documents keep advertising their slots and remain usable as templates)
///
/// Extraction is reading tagged slots, never NLP: thesis walks `TextRun`s carrying the variable
/// attribute, Signator walks its `{{key}}` placeholders. Both produce exactly this.
public struct VariableIndexObject: Codable, Equatable, Hashable, Identifiable, Sendable {

    // MARK: Index identity

    /// Always `.variable`. Present on the wire so the server can route the row without inferring.
    public let entityType: IndexEntityType
    /// The document this slot belongs to. Nil when emitted before the document has an id
    /// (the publish path stamps it in).
    public var documentID: String?
    /// Position of first appearance within the document — stable question order for the
    /// on-device conversation, so it does not have to invent one.
    public var ordinal: Int

    // MARK: Manifest fields (mirrors `VariableManifest`)

    public var key: String
    public var value: String?
    public var label: String
    public var dataType: VariableDataType
    public var required: Bool
    public var prompt: String
    public var resolvesFrom: String?
    public var options: [String]?
    public var conditional: String?
    public var repeatable: Bool?
    public var validation: String?

    /// Unique within a document — the same key is emitted once, however many runs carry it.
    public var id: String { "\(documentID ?? "-"):\(key)" }

    /// True once this slot carries a value — i.e. the document is filled at this slot.
    public var isFilled: Bool { !(value?.isEmpty ?? true) }

    private enum CodingKeys: String, CodingKey {
        case entityType = "entity_type"
        case documentID = "document_id"
        case ordinal
        case key = "cited_key"
        case value = "cited_literal"
        case label
        case dataType = "data_type"
        case required
        case prompt
        case resolvesFrom = "resolves_from"
        case options
        case conditional
        case repeatable
        case validation
    }

    public init(manifest: VariableManifest, documentID: String? = nil, ordinal: Int = 0) {
        self.entityType = .variable
        self.documentID = documentID
        self.ordinal = ordinal
        self.key = manifest.key
        self.value = manifest.value
        self.label = manifest.label
        self.dataType = manifest.dataType
        self.required = manifest.required
        self.prompt = manifest.prompt
        self.resolvesFrom = manifest.resolvesFrom
        self.options = manifest.options
        self.conditional = manifest.conditional
        self.repeatable = manifest.repeatable
        self.validation = manifest.validation
    }

    /// Back to a manifest — the read direction, for the will-flow reader: search returns variable
    /// objects, the on-device model reconciles them as manifests.
    public var manifest: VariableManifest {
        VariableManifest(
            key: key,
            label: label,
            dataType: dataType,
            required: required,
            prompt: prompt,
            resolvesFrom: resolvesFrom,
            value: value,
            options: options,
            conditional: conditional,
            repeatable: repeatable,
            validation: validation
        )
    }

    /// The shared tail of every carrier's ingest walk: collapse the manifests a walk found — in
    /// document order, one per tagged span — into one index object per distinct key.
    ///
    /// A single variable legitimately appears in several spans (a name repeated through a will, a
    /// `{{key}}` used twice), and the spans may disagree if only one was filled. Occurrences merge
    /// via `VariableManifest.mergingOccurrence(_:)`, keeping first-appearance order.
    public static func objects(
        from manifests: [VariableManifest],
        documentID: String? = nil
    ) -> [VariableIndexObject] {
        var order: [String] = []
        var merged: [String: VariableManifest] = [:]

        for manifest in manifests where !manifest.key.isEmpty {
            if let existing = merged[manifest.key] {
                merged[manifest.key] = existing.mergingOccurrence(manifest)
            } else {
                order.append(manifest.key)
                merged[manifest.key] = manifest
            }
        }

        return order.enumerated().compactMap { ordinal, key in
            merged[key].map { VariableIndexObject(manifest: $0, documentID: documentID, ordinal: ordinal) }
        }
    }
}

public extension VariableManifest {
    /// Merge a later occurrence of the *same* variable into this one.
    ///
    /// First occurrence wins for the descriptive fields (that is where the author defined the
    /// slot); a value or an auto-fill keypath found on any occurrence is kept, and `required` is
    /// the union — if any span says the slot is required, the document cannot be complete without
    /// it. Occurrences with a different `key` are not merged; the caller groups by key.
    func mergingOccurrence(_ other: VariableManifest) -> VariableManifest {
        guard other.key == key else { return self }
        var result = self
        if result.value?.isEmpty ?? true { result.value = other.value }
        if result.resolvesFrom?.isEmpty ?? true { result.resolvesFrom = other.resolvesFrom }
        if result.label.isEmpty { result.label = other.label }
        if result.prompt.isEmpty { result.prompt = other.prompt }
        if result.options?.isEmpty ?? true { result.options = other.options }
        if result.conditional?.isEmpty ?? true { result.conditional = other.conditional }
        if result.validation?.isEmpty ?? true { result.validation = other.validation }
        result.required = result.required || other.required
        result.repeatable = (result.repeatable ?? false) || (other.repeatable ?? false)
            ? true
            : (result.repeatable ?? other.repeatable)
        return result
    }
}
