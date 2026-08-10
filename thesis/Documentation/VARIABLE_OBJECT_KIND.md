# The `.variable` Object Kind — scoping

**Status:** design, decisions made. Companion to `WILL_FLOW_ARCHITECTURE.md` (net-new item #1 —
the keystone the will-flow rests on).

A variable is not a new subsystem and it is **not thesis-only**. It splits into two layers:

- **Layer 1 — the variable *model* (shared, app-agnostic):** the manifest, the index-3 object, and
  the resolve/auto-fill logic. Format-level — lives *with* `Document451`.
- **Layer 2 — the *carrier* (per app, per format):** how a variable is marked inside a given
  document. Different in each app; both map onto the same Layer-1 manifest.

Signator is arguably the *primary* consumer (signing is fill-in-the-blank by nature) and reaches it
with **less** work than thesis — see Carriers below.

## Decisions (made)

1. **Shared model home = (a):** `VariableManifest` lives with the canonical `Document451` in
   `451Core/Sources/Core451/Models/`, and is **mirrored into Signator's own copy**
   (`Signator/Signator/Document451.swift`) — matching how `Document451` itself is already
   duplicated across the decoupled Signator target. (Tax: two copies to keep in sync; if that
   stings, revisit Signator's Core451 decoupling.)
2. **thesis carrier: one `app.entityType` key + a companion structured payload** — not a key per
   type. Builds the general tagging system (concept / location / variable / …).
3. **thesis payload is structured** — `JSONValue` (already used by `ObjectRun.state`), not a
   flattened JSON string.

---

## Layer 1 — the variable model (shared)

Lives next to `Document451` (canonical in Core451, mirrored in Signator). App-agnostic.

```swift
struct VariableManifest: Codable, Equatable {
    var key: String            // stable id, e.g. "executor_name"
    var label: String
    var dataType: DataType     // person | date | currency | address | partyRef | enumValue | boolean | text
    var required: Bool
    var prompt: String         // question text / description — feeds BOTH the model and the UI
    var resolvesFrom: String?  // persona keypath to auto-fill from (e.g. "PRIVATE.ADDRESS.FULL"); nil = must ask
    var value: String?         // current value

    // optional, later
    var conditional: String?
    var repeatable: Bool?
    var validation: String?
}
```

`resolvesFrom` is the bridge to persona auto-fill: it tells the on-device model which variables it
can fill from the user's (private, on-device) persona and therefore must NOT ask.

**Also Layer 1:** the ingest emission (manifest → `entity_type = variable` object in index 3) and
the resolve/fill logic — both shared, so both apps behave identically.

---

## Layer 2 — carriers (per app)

Each carrier is just a way to attach a `VariableManifest` to a span of a document. Both emit the
same index-3 objects at ingest.

### thesis — typed range over `NSAttributedString`

thesis has the rich-text model (`RichDoc`, `RichAttributes`, `RichTextCodec` — all `thesis/`-local).
A variable is a **typed text range**, like a concept or location would be:

```swift
// RichAttributes.swift — extend the existing key pattern
extension NSAttributedString.Key {
    static let entityType    = NSAttributedString.Key("app.entityType")    // "concept" | "location" | "variable"
    static let entityPayload = NSAttributedString.Key("app.entityPayload") // JSONValue: qid for concept, VariableManifest for variable
}
enum EntityKind: String, Codable { case concept, location, variable }
```

- `RichDoc.TextRun.attrs` gains `entityType: String?` + `entityPayload: JSONValue?`.
- `RichTextCodec.makeRichDoc(from:)` / `makeAttributedString(from:)` round-trip them between the
  `NSAttributedString.Key`s and `attrs`.
- **Why a range, not an `ObjectRun`:** a variable is real, readable, editable, fillable text.
  Filling changes the run's **text**; the `entityType` + manifest **stay on the run** — so a
  completed will still advertises its slots ("filled but still identifiable"). Equations stay
  `ObjectRun`; the two shapes coexist.

⚠️ **Trap:** `RichAttributeRun` / `encodeAttributes` / `decodeAttributes` in `RichAttributes.swift`
are **dead code — referenced nowhere.** Extend those and the tag silently never persists. All real
work goes through `RichTextCodec` / `RichDoc`.

### Signator — `{{placeholder}}` in string templates

Signator has **no rich-text model** — its own `Document451.swift:343` stubs `RichTextDocument`
("Thesis app provides real implementation"). Its documents are string templates
(`{{PLACEHOLDER}}`, `____` blanks) + SwiftUI form fields, filled by `fillTemplate()`. So a `{{}}`
token *is* a variable slot — the carrier is: **a `{{key}}` placeholder plus its `VariableManifest`**
(stored alongside the template). This upgrades the existing crude `{{PRIVATE.SSN}}` /
`fillTemplate` path into real manifest-bearing variables — **no NSAttributedString needed**, which
is why Signator is the cheaper adoption.

---

## Client → server bridge (index 3) — the ingest walk

**Status: built (step 4), not yet called from a publish site.** At publish, each carrier walks its
own document and emits, per variable, an `entity_type = variable` object into index 3. thesis walks
`TextRun`s with the variable attr; Signator walks its `{{}}` placeholders. **Extraction is reading
tagged slots, not NLP.**

### Shape

`VariableIndexObject` (Layer 1, `451Core/Sources/Core451/Models/VariableIndexObject.swift`,
mirrored into `Signator/Signator/`) is a manifest that knows where it lives: the manifest fields
plus `documentID` and `ordinal` (position of first appearance — stable question order, so the
on-device model doesn't have to invent one). It converts back via `.manifest`, which is the read
direction for the will-flow: search returns objects, the model reconciles manifests.

Wire ↔ server column mapping (the rest lands in the object's JSON side payload):

| wire key | column | note |
|---|---|---|
| `entity_type` | `entity_type` | always `variable` |
| `document_id` | `document_id` | |
| `cited_key` | `cited_key` | ← `key` |
| `cited_literal` | `cited_literal` | ← `value`; nil until filled |
| `ordinal`, `label`, `data_type`, `required`, `prompt`, `resolves_from`, `options`, `conditional`, `repeatable`, `validation` | JSON payload | |

### The walks

- **thesis** (`thesis/VariableIngest.swift`): `RichDoc.variableIndexObjects(documentID:)`, plus
  `NSAttributedString.variableIndexObjects(documentID:)` for the editor's own string, and
  `hasVariables` — the will-flow's "docs that have variable objects" filter in local form. A run
  tagged `variable` whose payload won't decode is **skipped, not guessed at**: inventing a manifest
  would put a junk question in front of the user.
- **Signator** (`Signator/Signator/VariableIngest.swift`):
  `VariableTemplate.variableIndexObjects(documentID:)`. Two sources in order — `{{key}}`
  placeholders still in `content` (an *unfilled* template; a placeholder with no authored manifest
  gets `defaultManifest(forKey:)` rather than being dropped), then manifests whose key no longer
  appears in `content` (a *filled* template, where `fillTemplate` already substituted the value).
  That second source is what keeps a completed document advertising its slots.
- **Shared tail:** `VariableIndexObject.objects(from:documentID:)` collapses the per-span manifests
  into one object per distinct key, first-appearance order. Occurrences merge via
  `VariableManifest.mergingOccurrence(_:)`: first occurrence owns the descriptive fields, any
  occurrence's value or `resolvesFrom` is kept, `required` is the **union**. A variable repeated
  through a will where only one span was filled still indexes as filled.

### ⚠️ Fill contract

Filled-ness comes from the manifest's `value`, never from the run's rendered text — the walk cannot
tell a placeholder rendering ("[executor]") from a real value. **A fill must therefore write both**:
the run's text *and* `value` on the manifest riding that run. Write only the text and the slot
indexes as unfilled; write only the value and the document renders stale. This binds the editor
affordances in step 6.

### Publish bridge

`DocumentMetadata451.variables: [VariableIndexObject]?` (both copies) carries the walk's output in
the metadata that gets embedded into the document at publish, so the server populates index 3 at
ingest without re-parsing the body. `metadata.attachVariables(objects)` stamps `documentID` from
the metadata's own `id`/`did` onto any object that lacks one.

**Not yet wired to a call site**, because neither app's publish path can reach its carrier yet:
thesis's send flow (`EnhancedSendSigningFlowView.sendDocument`) only ever sees inline text or a
picked file URL, never the `RichDoc`; Signator has no store that holds documents as
`VariableTemplate`s. Both are plumbing jobs, not walk changes.

### Server side (not in this repo)

S451 lives elsewhere: add `.variable` to the polymorphic `EntityType` in `SearchIndexService` and
map the payload above onto the object columns. The client contract is frozen by
`VariableIndexObject`'s `CodingKeys` and the table above.

## Vocabulary reconciliation — decided

**The server's `entity_type` is the one vocabulary**, pinned as `IndexEntityType`
(`document | concept | equation | figure | variable`) next to `VariableManifest`. thesis's
`EntityKind` (`concept | location | variable`) stays the *editor's* authoring vocabulary and maps
onto it at ingest via `EntityKind.indexEntityType`; it is not a second vocabulary on the wire.
`.location` indexes as `.concept` — a place is a Wikidata concept with a `qid` like any other —
until the server grows a distinct kind. Only `.variable` is emitted today; concept/location ingest
is this step's unbuilt sibling.

## Build order

1. ✅ **Layer 1 first — `VariableManifest` + `DataType`** next to `Document451` in Core451; mirror
   into Signator's copy. Shared, no UI, no rich-text dependency.
2. ✅ **thesis carrier:** the two `NSAttributedString.Key`s + `EntityKind`; extend
   `RichDoc.TextRun.attrs`; round-trip in `RichTextCodec`.
3. ✅ **Signator carrier:** `{{key}}` + manifest alongside its templates; fold into `fillTemplate`.
4. ◐ **Ingest walk → index 3** (per carrier) — walks, shared collapse, and the
   `DocumentMetadata451.variables` publish bridge are built and unit-tested; **remaining:** call
   them from each app's publish path (needs the plumbing noted above), and add the server
   `.variable` `EntityType` in S451 (separate repo).
5. **Wire the will-flow reader** to pull variable objects (per `WILL_FLOW_ARCHITECTURE.md`).
6. Editor/authoring affordances in each app (can lag the model work) — bound by the fill contract
   above: a fill writes the run text *and* the manifest's `value`.
