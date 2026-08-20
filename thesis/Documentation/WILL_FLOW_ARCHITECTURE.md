# "Make me a will" — Document-Assembly Flow (architecture)

**Status:** design, agreed. Supersedes the earlier "pull full text and infer variables" content-hop
sketch — variable inference moves to ingest time, not query time (see §Four indices, §Why).

An intent-driven flow that turns a natural-language request ("make me a will", "make me a will
with a pour-over trust", "lease a bulldozer for two years") into an intelligent form-filling
conversation, on-device, over the 451 published corpus. Generalizes to any *actionable* document
type — the small set of forms that carry fill-in variables (will, contract, lease, …), identified
by `Document451.type`.

---

## The four indices (what each is for)

The S451 search DB (`SearchIndexService`) is four surfaces, each answering a different question:

| # | Index | Backing | Role in this flow |
|---|-------|---------|-------------------|
| 1 | **Cited docs** | citation-edge table + `citation_count` | Ranking — "most cited" (blended, see `RankingWeights`). |
| 2 | **Wikidata metadata** | concepts keyed by `qid` (`concept_label`, `concept_type`) | Situation matching — steer search by the intent's concepts ("pour-over trust"). |
| 3 | **Object type** | polymorphic `entity_type` (`document \| concept \| equation \| figure`) | **Variables live here** as a new `entity_type = variable`. The structured variable-sets. |
| 4 | **Full text** | `pagetext.sqlite` behind `PageTextCodec` (raw now, zstd later) | The document body — heavy tier, pulled only to fill/render the winner. |

**Variables are an object kind, not a full-text artifact.** Adding them = a new `EntityType`
case (`.variable`) on the existing polymorphic model + a populate-at-ingest step. Mechanism
exists; we add a kind. A variable object persists even once filled (`cited_literal` holds the
value), so a *completed* document still advertises its slots — completed docs are prime templates,
not to be excluded.

---

## The pipeline

```
Intent: "make me a will with a pour-over trust"   (App Intent captures it)
  → search:
       index 2 (concept: pour-over trust)
       + index 1 (most-cited, blended via RankingWeights)
       + FILTER index 3 (must have variable objects; include filled-but-once-variable docs)
  → 5 hits as { id, title, concepts, variable-set, excerpt }     ← NOT full bodies
  → FoundationModels (on-device):
       reconcile the 5 overlapping variable-sets → a conversation
       pre-fill from the user's encrypted persona; ask ONLY the gaps
  → user answers
  → match: which of the 5 best fits the user's situation
  → pull the winner's full body from egress-free R2 (index 4)
  → complete + render → Signator two-phase sign/publish
```

### Key properties

- **Question-building needs index 3, not index 4.** The model reconciles pre-extracted
  variable-sets and phrases questions — it does not re-infer variables from prose. Full-text
  inference remains only as the *bootstrap* for docs index 3 hasn't covered yet (the hybrid:
  infer-once → index as objects → thereafter just read).
- **Full text is pulled for one winner, at completion.** Never move five bodies over the wire.
- **Matching is pushed upstream where possible.** The explicit intent's concepts (index 2)
  pre-filter the five to the situation, so the model's "most like their situation" job is
  half-done and tag-grounded before it starts.

---

## Cost / caching

Full-text serving is bounded to *actionable types* — a tiny slice of the ~1 TB corpus. The
"most-cited (+ blend)" result set is stable, so the same handful of documents recur across
requests: cache that hot set (really "actionable-type docs above a citation threshold") and serve
bodies from the **egress-free provider (Cloudflare R2)** among the existing B2 / R2 / MinIO trio.
A million "make me a will" requests cost ~nothing in egress. Prefer publish-time promotion into R2
for actionable types (the set is small); lazy promotion on first return is the self-tuning
alternative.

---

## The on-device privacy boundary (non-negotiable)

The whole conversation and completion run **on-device via FoundationModels**, because the auto-fill
draws on the user's **private, encrypted persona** (name, address, family, interests). That data is
readable only because it's the user's own device and own keys — it never reaches a server model.
This is the DID + encryption model (see the project memory of the same name): the public corpus is
read openly; the private completion stays local. Signing/publishing the result is the existing
Signator two-phase (Tier C) path.

---

## What's net-new vs. exists

**Exists:** the four indices; `/api/search/local` (ranked, citation-aware); on-device
FoundationModels with `@Generable`; the R2 upload fan-out; Signator two-phase signing; the client
`SearchService` (ranked search, `RankingWeights`).

**Net-new:**
1. `entity_type = variable` as an object kind + extract-at-ingest population (index 3). **Scoped in `VARIABLE_OBJECT_KIND.md`** — variable = a typed text range (single `app.entityType` key + structured `JSONValue` payload), extracted at ingest by reading tagged ranges, not NLP.
2. Search filter/join: "docs that have variable objects", and concept-steering from the intent (index 2).
3. Search hits (or a resolve step) returning the variable-set + concepts + excerpt, not just id+scores.
4. On-device `@Generable` types + prompts for: reconcile→converse, match, complete.
5. The App Intent ("Create a 451 document") that opens the app into the flow.
6. Egress-free R2 cache/serve path for actionable-type bodies.
