//
//  VariableIngest.swift
//  Signator
//
//  Step 4 of the `.variable` object kind — the Signator half of the *ingest walk*.
//
//  At publish time the carrier walks its own document and emits one `entity_type = variable`
//  object per distinct slot into search index 3. Signator's carrier is a `{{key}}` placeholder
//  plus its manifest, so the walk is: placeholders in template order, each paired with its
//  authored manifest. Reading tagged slots — never NLP.
//
//  See thesis/Documentation/VARIABLE_OBJECT_KIND.md §"The ingest walk".
//

import Foundation

extension VariableTemplate {

    /// The template's manifests, one per distinct slot, in the order the slots appear.
    ///
    /// Two sources, in this order, because a Signator template changes shape once filled:
    /// 1. `{{key}}` placeholders still present in `content` — an *unfilled* template. A
    ///    placeholder with no authored manifest gets the default one rather than being dropped;
    ///    an untyped `{{}}` is still a genuine slot the user must fill.
    /// 2. Manifests whose key no longer appears in `content` — a *filled* template, where
    ///    `fillTemplate` has already substituted the value into the text. These still index, so a
    ///    completed document keeps advertising its slots and remains usable as a template.
    func variableManifests() -> [VariableManifest] {
        let authored = Dictionary(variables.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        let keysInContent = Self.placeholderKeys(in: content)

        var manifests = keysInContent.map { key in
            authored[key] ?? Self.defaultManifest(forKey: key)
        }

        let seen = Set(keysInContent)
        manifests.append(contentsOf: variables.filter { !seen.contains($0.key) })

        return manifests
    }

    /// The template's `entity_type = variable` objects for search index 3 — one per distinct key,
    /// ordered by first appearance.
    func variableIndexObjects(documentID: String? = nil) -> [VariableIndexObject] {
        VariableIndexObject.objects(from: variableManifests(), documentID: documentID)
    }

    /// Whether this template is *actionable* — has fill-in slots at all. The will-flow's index-3
    /// filter ("docs that have variable objects") in local form.
    var hasVariables: Bool {
        !variables.isEmpty || !Self.placeholderKeys(in: content).isEmpty
    }
}

// MARK: - Publish bridge

extension DocumentMetadata451 {
    /// Attach a document's variable objects to the metadata that gets embedded at publish, so the
    /// server can populate index 3 at ingest without re-parsing the body.
    ///
    /// Stamps `documentID` onto every object from the metadata itself when the caller did not
    /// supply one, so the rows arrive already keyed to their document.
    mutating func attachVariables(_ objects: [VariableIndexObject]) {
        guard !objects.isEmpty else { return }
        let owner = id ?? did
        variables = objects.map { object in
            guard object.documentID == nil, let owner else { return object }
            var stamped = object
            stamped.documentID = owner
            return stamped
        }
    }
}
