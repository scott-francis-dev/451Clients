//
//  VariableTemplate.swift
//  Signator
//
//  Layer-2 Signator carrier for the shared variable model (VariableManifest).
//
//  Signator has no rich-text model — its own Document451.swift stubs RichTextDocument, and its
//  documents are plain-text templates with `{{key}}` placeholders filled by
//  DocumentSigningWithPrivateData.fillTemplate. This carrier pairs each `{{key}}` placeholder
//  with a VariableManifest, the Signator analog of thesis's typed NSAttributedString range.
//  See thesis/Documentation/VARIABLE_OBJECT_KIND.md.
//

import Foundation

/// A plain-text template whose `{{key}}` placeholders are backed by `VariableManifest`s.
struct VariableTemplate: Codable, Equatable {
    /// Template text containing `{{key}}` placeholders.
    var content: String
    /// One manifest per distinct placeholder key that carries variable semantics.
    var variables: [VariableManifest]

    init(content: String, variables: [VariableManifest] = []) {
        self.content = content
        self.variables = variables
    }

    /// The distinct placeholder keys present in a template, in order of first appearance,
    /// e.g. `"PRIVATE.SSN"`, `"executor_name"`. This is the Signator analog of walking the
    /// tagged `TextRun`s in thesis — the carrier's "find the variable slots" operation.
    static func placeholderKeys(in content: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: "\\{\\{([^{}]+)\\}\\}") else { return [] }
        let ns = content as NSString
        let matches = re.matches(in: content, range: NSRange(location: 0, length: ns.length))
        var keys: [String] = []
        var seen = Set<String>()
        for m in matches where m.numberOfRanges > 1 {
            let key = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
            if seen.insert(key).inserted { keys.append(key) }
        }
        return keys
    }

    /// The default `.text` manifest for a placeholder that has no authored one. Persona-backed
    /// tokens (`PRIVATE.*`, `PUBLIC.*`, `DID`/`NAME`/`PRETTY_DID`) get `resolvesFrom` set to the
    /// same key so they auto-fill and are not asked; everything else is treated as user-supplied.
    /// A bootstrap — real manifests would be authored.
    static func defaultManifest(forKey key: String) -> VariableManifest {
        let personaBacked = key.hasPrefix("PRIVATE.") || key.hasPrefix("PUBLIC.")
            || ["DID", "NAME", "PRETTY_DID"].contains(key)
        return VariableManifest(
            key: key,
            label: key,
            dataType: .text,
            required: true,
            prompt: "Enter \(key)",
            resolvesFrom: personaBacked ? key : nil
        )
    }

    /// Lift a raw template string into a carrier, creating a default manifest per placeholder.
    static func lift(_ content: String) -> VariableTemplate {
        VariableTemplate(
            content: content,
            variables: placeholderKeys(in: content).map(defaultManifest(forKey:))
        )
    }

    /// Variables that must be asked of the user: required, no value yet, and not auto-fillable
    /// from the persona (`resolvesFrom == nil`). Feeds the will-flow conversation.
    func variablesNeedingInput() -> [VariableManifest] {
        variables.filter { $0.required && ($0.value?.isEmpty ?? true) && $0.resolvesFrom == nil }
    }

    /// Apply the manifests' own values into the template text (persona auto-fill happens
    /// separately, in the fillTemplate overload below).
    func applyingManifestValues() -> String {
        var filled = content
        for v in variables {
            if let value = v.value, !value.isEmpty {
                filled = filled.replacingOccurrences(of: "{{\(v.key)}}", with: value)
            }
        }
        return filled
    }
}

extension DocumentSigningWithPrivateData {
    /// Manifest-aware fill. Composes with the existing `fillTemplate(_:persona:includePrivateData:)`
    /// rather than duplicating its persona mapping: manifest-provided values are applied first and
    /// take precedence, then persona-backed placeholders are resolved (and any remaining `{{...}}`
    /// stripped) by the existing path.
    static func fillTemplate(
        _ template: VariableTemplate,
        persona: PersonaProfile,
        includePrivateData: Bool
    ) throws -> String {
        let withManifestValues = template.applyingManifestValues()
        return try fillTemplate(withManifestValues, persona: persona, includePrivateData: includePrivateData)
    }
}
