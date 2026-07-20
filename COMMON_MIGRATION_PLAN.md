# 451Clients: unify on one shared `Common/` — migration plan

**Status:** analysis complete, execution held pending other agents finishing (shared working tree).
**Goal (user's words):** "There is no Signator way and a Thesis way, there is one way."
`451Core` stops being a Swift package and becomes a plain `Common/` subdirectory compiled into
**both** app targets. `thesis/` keeps only the editor; `Signator/` keeps only image/witness capture;
everything else is shared.

---

## 1. Diagnosis — why the persona-creation errors exist

There are **three** copies of the "common" code and they have drifted apart:

| Location | Role | Core451 dup files | Uses Core451 |
|---|---|---|---|
| `451Core/` (Swift package, product `Core451`) | canonical shared lib | — | — |
| `thesis/` (product `wordsmatter`) | editor app, clean citizen | 0 | `import Core451` in 64 files |
| `Signator/Signator/` | forked app | 40 private copies | none — compiles its own |

Only **thesis** links the `Core451` package (pbxproj line 246). **Signator links nothing** (its
Frameworks phase is empty) and compiles private forks.

The current build errors are all in `Signator/Signator/PersonaCreationView.swift` and are **cross-platform
availability failures**, not type conflicts: `UIApplication`, `UIKeyboardType`, `UITextContentType`,
`AVAudioSession`, `Color(.systemBackground)`, `.systemGray5`, `.navigationBarTitleDisplayMode`,
`.textInputAutocapitalization` — UIKit/iOS-only APIs compiled for macOS (`Signator` `SUPPORTED_PLATFORMS`
includes `macosx`). Signator's fork was never made cross-platform-clean; the shared/thesis path already
handles this via `Color+Platform`, `PlatformImage`, and platform guards. **Converging onto the canonical
copy fixes these errors** rather than creating new ones.

---

## 2. Target architecture

```
Common/          ← former 451Core/Sources/Core451, compiled into BOTH targets (no more package)
thesis/          ← editor only: BlockDocumentEditor, RichTextEditor, Page/Pages, CAS/, Molecules/,
                   Chart*, Equation*/Math*, DiscoveryView, Drafts*, writing assistant + thesisApp.swift
Signator/        ← capture only: QRScannerView, QuickActionMediaCaptureView, WitnessFlowView,
                   media/witness capture support + SignatorApp.swift
```

Rule: everything that is **not** the editor and **not** image/witness capture lives in `Common/`.

---

## 3. Exact `project.pbxproj` edits (synchronized folder groups — small, clean)

The project uses Xcode-16 `PBXFileSystemSynchronizedRootGroup`s, so sharing a folder across targets is a
few lines, not per-file entries.

**Add** a synchronized root group for `Common` (new object; pick an unused 24-hex id, e.g.
`C0000A5100000000000000C1`):
```
        C0000A5100000000000000C1 /* Common */ = {
            isa = PBXFileSystemSynchronizedRootGroup;
            path = Common;
            sourceTree = "<group>";
        };
```
- add `C0000A5100000000000000C1 /* Common */,` to the **mainGroup** children (near line 172)
- add it to **Signator** target `fileSystemSynchronizedGroups` (line 217-219)
- add it to **thesis** target `fileSystemSynchronizedGroups` (line 240-242)

**Remove the Core451 package** (7 spots):
1. line 13  — PBXBuildFile `B6F04183… /* Core451 in Frameworks */`
2. line 133 — that ref inside thesis Frameworks phase `86A28B5A`
3. line 159 — `B67581A7… /* Core451 */` child of the Frameworks PBXGroup
4. line 55  — PBXFileReference `B67581A7… /* Core451 */ … path = ../Core451`
5. line 246 — `B6F04182… /* Core451 */` in thesis `packageProductDependencies`
6. line 333 — `B6F04181… XCLocalSwiftPackageReference "451Core"` in `packageReferences`
7. lines 878-883 — the `XCLocalSwiftPackageReference "451Core"` object
8. lines 915-919 — the `XCSwiftPackageProductDependency` `Core451` object

Back up the pbxproj to `/tmp` first and run a build immediately after; a malformed pbxproj fails loudly.

---

## 4. Filesystem moves

- `mkdir Common`
- move `451Core/Sources/Core451/{App,Infrastructure,Models,Network,Onboarding,Persona,Resources,Services,Stores}`
  → `Common/` (keep the subfolder structure; the sync group recurses)
- `Resources/Onboarding/*.mov` come along — a synchronized group auto-classifies them as bundle resources
  for **both** targets (verify they land in each app's Resources phase after reload).
- Leftover `451Core/` (now just `Sources/cli451`, `Package.swift`, `Tests/`) is orphaned dev tooling —
  optional cleanup, not required for the apps.
- Verify `Common/App/ClientApp.swift` / `AppRootScaffold.swift` are **not** `@main` (the two real entry
  points are `Signator/SignatorApp.swift` and `thesis/thesisApp.swift`, which stay put).

---

## 5. Source edits

- **thesis:** strip `import Core451` from all 64 files (Common is now same-module). Mechanical
  find/replace of the `import Core451` line.
- **Signator:** no `import Core451` today; after Common is added, references resolve to Common's types.
- **Common files:** already `public` — harmless in-module; leave as-is.

---

## 6. File disposition manifest

### 6a. Signator's 40 Core451 duplicates → DELETE from Signator, adopt `Common`
**29 are byte-identical** (safe delete): BlockchainAPI, ClientLogger, ConnectionManager, ConnectionModels,
CredentialItem, CredentialVerificationService, Document451, DocumentSubmissionService, EscrowService,
InitiatedSigningStore, MilestoneModels, MilestoneService, PersonaResolver, PrivateDataManager,
PrivateDataStore, ProductionSSEClient, ProposalVerificationService, ProposedPersona, SecureEnclaveKeyStore,
ServerConfiguration, ServerProgressEvents, ServerProgressMapper, SharedContainer, SignatorUploadMetadata,
SignedDocumentPayload, SignerService+SecureEnclave, SignerService, VCStore, VerifiableCredential, WalletAPI,
WalletAction.

**11 diverged — Core451 is the superset; adopt Core451, then fix Signator app-code fallout:**
| File | diverged lines | note |
|---|---|---|
| PersonaProfile.swift | 253 | Core451 much richer (184 core-only vs 69 sig-only) |
| DocumentMetadata451.swift | 216 | reconcile field set |
| Persona.swift | 139 | field order + extra fields; Core451 canonical |
| DocumentSigningService.swift | 60 | check `UploadResponse` shape |
| PersonaManager.swift | 34 | check `dismissCreationFlow` used by Signator UI |
| CollaboratorsStore.swift | 14 | |
| DocumentMetadataEmbedding.swift | 8 | |
| PrivateKeyStore.swift | 6 | |
| PersonaStore.swift | 6 | |
| ServerConfig.swift | 4 | |

After deleting these, build Signator and port any **fork-only members** its 64 app files reference into the
Common version (don't re-fork — add to Common).

### 6b. The 16 thesis↔Signator duplicate views → collapse into `Common` (Phase 2)
These are **not** in Core451 and diverged heavily (e.g. `PersonaCreationView` differs 3292 lines between the
two apps — thesis's is the cross-platform-clean one). Adopt thesis's version as canonical, verify against
Signator usage, delete both copies, place one in `Common`:
AccessCodeEntryView, AppTopHeader, DocumentListView, EditPersonaView, EnhancedSendSigningFlowView, IntroView,
PersonaCreationView, PersonaManagerView, ProgressStatusCardView, PublishingCardsStreamView,
PublishingCardsViewModel, SendSigningFlowView, SignAndSubmitView, ValidateRequestFlowView.
**Capture pair — send to Signator, not Common:** `QuickActionMediaCaptureView`, `WitnessFlowView`
(thesis references WitnessFlowView 0×, QRScannerView 0×, QuickActionMediaCaptureView 1× — verify that one
editor use before removing from thesis).

### 6c. Signator's 64 unique files
**Stay in Signator (target app shell + capture):** SignatorApp (@main), ContentView, RootView, MainTabView,
QRScannerView, ServerIndicatorView/ServerSettingsView (if Signator-specific), DeepLinkParser, PlatformCompat.
**DELETE — cruft/backups/examples (9):** `SignAndSubmitView 2`, `MainTabView 2`, `ServerSettingsView 2`,
`SignAndSubmitView_CLEAN`, `CompleteDocumentUploadExample`, `DocumentSigningProgressExample`,
`DocumentSigningProgressIntegrationExample`, `ExampleSignFlow`, `SecureEnclaveQuickReference`
(also the `.swift2` files already excluded via membership exceptions).
**→ Common (shared identity / signing / persona / document / institution flows):** everything else —
BackgroundCheckRequestView, CollaboratorsListView, ColleaguesView, ConnectionGuardView, CreatePersonaView,
CreateProposalForClientView, CredentialSelectionView, CredentialVerificationView, DocumentMetadataEditor,
DocumentSigningWithPrivateData, EditableStringList, EmailVerificationField, Environment+PersonaKeys,
EscrowStatusView, HaveMyOwnDomainView, IdentityMethodSelectionView, InitiatedRequestDetailView,
InstitutionAdminView, MentionChip, MilestoneTimelineView, MultiPartySigningView, OnboardingView,
OnboardingDebugHelpers, OrcidInputField, PersonaCredentialsSection, PersonaDebugView, PersonaDirectoryPicker,
PersonaEditView, PersonaHandleCard, PersonaHandleWizardView, PersonaHelpView, PersonaIdentityDisplayView,
PersonaListView, PersonaPurposeSelectionView, PersonaSelectorView, PersonaTypeSelectionView,
ProposedPersonaEntryView, ProposedPersonaReviewView, PublicOrPrivateSelectionView,
RequestInstitutionAccessView, ServiceSignInView, SignDocumentView, SignatorSignInInitiatorView,
StatusCardView, TestPushNotificationView, WelcomeOnboardingView.
> Consequence to accept: these compile into **thesis** too. That is the "one way" — both apps share the
> identity/signing machinery; thesis adds the editor, Signator adds capture. Any of these using raw UIKit
> must be made cross-platform-safe (same fix as the persona errors) since thesis builds macОS.

---

## 7. Execution order (build after every phase)

0. Back up `project.pbxproj` to `/tmp`. Confirm other agents are done.
1. **Foundation (Task #1):** create `Common/`, move Core451 sources, add sync group to both targets,
   remove the package, strip thesis `import Core451`, delete Signator's 40 dups → **build thesis + Signator**,
   fix fallout (port fork-only members into Common).
2. **Dedup views (Task #2):** collapse the 16 shared views into Common (thesis version canonical),
   route the capture pair to Signator → **build both**.
3. **Reclassify (Task #3):** move 6c "→ Common" set into Common, delete cruft, ensure Signator = capture +
   shell, thesis = editor + shell → **build both**, make any raw-UIKit views cross-platform-safe.

## 8. Risks
- **Shared working tree / concurrent agents** — do not run while others edit `project.pbxproj` or these
  files. (Reason for the current hold.)
- **macOS availability** — Signator/shared views using bare UIKit break the thesis (macOS) build; wrap with
  `#if canImport(UIKit)` / platform helpers.
- **Divergence loss** — the 11 + 16 diverged files may hold Signator-only behavior; port genuine additions
  into Common instead of dropping them.
