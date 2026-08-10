//
//  VariableManifest.swift
//  Core451
//
//  Layer 1 of the `.variable` object kind — the shared, app-agnostic variable MODEL.
//  See thesis/Documentation/VARIABLE_OBJECT_KIND.md.
//
//  ⚠️ MIRRORED FILE. Signator is decoupled from Core451 and keeps its own copy at
//  Signator/Signator/VariableManifest.swift, exactly as it mirrors Document451.
//  Keep the two textually in sync until/unless Signator re-couples to Core451.
//

import Foundation

/// The kind of value a variable holds. Drives how the on-device model phrases its question,
/// how the UI renders the input, and how the value is validated/auto-filled.
public enum VariableDataType: String, Codable, Equatable, Sendable, CaseIterable {
    case person       // a person's name
    case date
    case currency
    case address
    case partyRef     // reference to a signing party / persona
    case enumValue    // one of a fixed set (see `options` on the manifest)
    case boolean
    case text         // free text (default)
}

/// The schema of a single fill-in variable in a 451 document — Layer 1 (shared).
///
/// This is format-level, so it lives with `Document451`. Each app attaches it to a span of a
/// document via its own *carrier* (Layer 2): thesis a typed `NSAttributedString` range,
/// Signator a `{{key}}` template placeholder. Both emit the same `entity_type = variable`
/// object into search index 3 at ingest.
public struct VariableManifest: Codable, Equatable, Hashable, Identifiable, Sendable {
    /// Stable identifier, unique within a document, e.g. "executor_name".
    public var key: String
    /// Human-facing label, e.g. "Executor".
    public var label: String
    /// What kind of value this is.
    public var dataType: VariableDataType
    /// Whether the document cannot be considered complete until this is filled.
    public var required: Bool
    /// Question text / description. Feeds BOTH the on-device model (to phrase the conversation)
    /// and the UI (as the field prompt).
    public var prompt: String
    /// Keypath into the user's persona to auto-fill from, e.g. "PRIVATE.ADDRESS.FULL".
    /// `nil` means the value is not derivable from the persona and must be asked.
    public var resolvesFrom: String?
    /// Current value. The carrier's rendered text mirrors this once filled; the variable stays
    /// identifiable as a variable even after filling.
    public var value: String?

    // MARK: Optional (later)

    /// For `.enumValue`: the allowed choices.
    public var options: [String]?
    /// Show-if expression referencing other variables' keys/values (grammar TBD).
    public var conditional: String?
    /// Whether this variable repeats (e.g. N beneficiaries).
    public var repeatable: Bool?
    /// Validation expression/regex (grammar TBD).
    public var validation: String?

    public var id: String { key }

    /// True once a required variable has a non-empty value.
    public var isSatisfied: Bool {
        guard required else { return true }
        return !(value?.isEmpty ?? true)
    }

    public init(
        key: String,
        label: String,
        dataType: VariableDataType = .text,
        required: Bool = true,
        prompt: String,
        resolvesFrom: String? = nil,
        value: String? = nil,
        options: [String]? = nil,
        conditional: String? = nil,
        repeatable: Bool? = nil,
        validation: String? = nil
    ) {
        self.key = key
        self.label = label
        self.dataType = dataType
        self.required = required
        self.prompt = prompt
        self.resolvesFrom = resolvesFrom
        self.value = value
        self.options = options
        self.conditional = conditional
        self.repeatable = repeatable
        self.validation = validation
    }
}
