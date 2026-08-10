//
//  VariableIngest.swift
//  thesis
//
//  Step 4 of the `.variable` object kind — the thesis half of the *ingest walk*.
//
//  At publish time the carrier walks its own document and emits one `entity_type = variable`
//  object per distinct slot into search index 3. thesis's carrier is a typed text range, so the
//  walk is: every `TextRun` whose `attrs.entityType == "variable"`, decode its `entityPayload`
//  into a `VariableManifest`, collapse by key. Reading tagged slots — never NLP.
//
//  See thesis/Documentation/VARIABLE_OBJECT_KIND.md §"The ingest walk".
//

import Foundation
import Core451

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Authoring vocabulary → index vocabulary

extension EntityKind {
    /// How an authoring kind lands in the server's polymorphic object index (index 3).
    ///
    /// `EntityKind` is the *editor's* vocabulary; `IndexEntityType` is the wire's. `.location` is
    /// indexed as a concept — a place is a Wikidata concept with a `qid`, the same as any other
    /// (index 2 keys them identically) — until the server grows a distinct kind for it.
    /// Only `.variable` is actually emitted today; concept/location ingest is step 4's sibling,
    /// not yet built.
    var indexEntityType: IndexEntityType {
        switch self {
        case .variable: return .variable
        case .concept, .location: return .concept
        }
    }
}

// MARK: - The walk

public extension RichDoc {

    /// Every text run tagged with `kind`, in document order, paired with its owning block id.
    ///
    /// Runs are returned per span, *not* deduplicated: one variable may legitimately span several
    /// runs (a bold word inside it) or recur through the document. Collapsing is the caller's job
    /// — `variableIndexObjects(documentID:)` does it by key.
    func taggedRuns(kind: EntityKind) -> [(blockID: String, run: TextRun)] {
        var found: [(blockID: String, run: TextRun)] = []
        for block in blocks {
            for inline in block.inlines {
                // Only text runs carry entity tags. ObjectRuns (equations, figures) are a
                // different index kind and are walked elsewhere.
                guard case .text(let run) = inline,
                      run.attrs.entityType == kind.rawValue else { continue }
                found.append((block.id, run))
            }
        }
        return found
    }

    /// The document's variable manifests, one per tagged span, in document order.
    ///
    /// A run tagged `variable` whose payload is missing or undecodable is skipped rather than
    /// guessed at — an untyped span is not a variable, and inventing a manifest for it would put
    /// a junk question in front of the user.
    func variableManifests() -> [VariableManifest] {
        taggedRuns(kind: .variable).compactMap { _, run in
            run.attrs.entityPayload?.decoded(as: VariableManifest.self)
        }
    }

    /// The document's `entity_type = variable` objects for search index 3 — one per distinct key,
    /// ordered by first appearance.
    ///
    /// Filled-ness comes from the manifest's `value`, not from the run's rendered text: a fill
    /// writes both (the run's text *and* `value` on the manifest riding that run) so a completed
    /// document still advertises its slots with the value in `cited_literal`.
    func variableIndexObjects(documentID: String? = nil) -> [VariableIndexObject] {
        VariableIndexObject.objects(from: variableManifests(), documentID: documentID)
    }

    /// Whether this document is *actionable* — has fill-in slots at all. The will-flow's index-3
    /// filter ("docs that have variable objects") in local form.
    var hasVariables: Bool {
        !taggedRuns(kind: .variable).isEmpty
    }
}

// MARK: - Editor-side convenience

public extension NSAttributedString {
    /// Walk an editor string directly, via the codec. Same result as converting to `RichDoc`
    /// first — this is the shape the editor and the publish path actually hold.
    func variableIndexObjects(documentID: String? = nil) -> [VariableIndexObject] {
        RichTextCodec.makeRichDoc(from: self).variableIndexObjects(documentID: documentID)
    }
}

// MARK: - Publish bridge

public extension DocumentMetadata451 {
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
