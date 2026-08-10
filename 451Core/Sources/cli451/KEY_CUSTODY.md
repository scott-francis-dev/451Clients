# 451 CLI — Signing Key Custody (design decision)

**Status:** decided (design). `451 sign` is currently a stub — `SignCommand.run()` holds a
`TODO: Load persona from store, sign via SecureEnclaveKeyStore, …` and no code writes keys to
disk yet. This note governs how signing keys are handled when that command is implemented.

**Context:** 451 is a distributed system whose entire value is *provenance by signature*. A
private key that can sign as a DID is the one secret that must never leak — anyone holding it can
forge that identity's signatures. See the custody-tier framing in `S451/Documentation/MCP_TOOL_DESIGN.md`.

---

## The rule

**The CLI must never store a raw/plaintext private key on disk.** What it uses instead depends on
*who the CLI is acting as* — the same human-vs-agent custody split that runs through the rest of
the system.

### 1. CLI acting as a human, on Apple hardware → Secure Enclave

Reuse the existing `Core451/Services/SecureEnclaveKeyStore`. Keys are generated in the Secure
Enclave, never leave the hardware, and are biometric-gated. This is already what `SignCommand`'s
own abstract promises ("Sign a document using a persona's **Secure Enclave key**"). Do **not**
invent a CLI-specific on-disk key store for this case.

Signator-generated (hardware-bound) keys are intentionally **not importable** into the CLI — that
is correct and stays. A human's key lives in one Secure Enclave, full stop.

### 2. CLI as an autonomous / headless / Linux agent → encrypted software key only

Secure Enclave and the macOS Keychain do not exist on Linux, and biometrics cannot be answered by
an unattended process. This — and only this — is where a software P-256 key is legitimate. It is
the **agent-as-instrument** tier: the agent holds *its own* keypair and signs *its own* blocks; it
is not impersonating a human persona.

When (and only when) this mode is built, a software key must be:

- **encrypted at rest** — key material sealed with a key derived from a passphrase, or an OS
  secret store (e.g. `libsecret`/Keyring on Linux); never the private key in the clear;
- **`0600`, owner-only** file permissions;
- **never** `~/.451/keys/<did>.key` as raw bytes / base64.

Gate this behind an explicit instrument/agent mode; don't make it the default path.

---

## Why not "just software keys on disk," which the CLI reference previously described

`CLI_REFERENCE.md` advertised `~/.451/keys/<did>.key` as "P-256 private key (raw bytes, base64)".
That is a plaintext signing key readable by anyone with file access — a total compromise of that
DID's provenance, and exactly the property the system exists to protect. It was also never
implemented. The reference has been corrected to point here.

---

## Implementation checklist (when `451 sign` is built)

- [ ] Wire `SignCommand.run()` → `SecureEnclaveKeyStore.loadKey` → `DocumentSigningService.uploadDocument()`.
- [ ] Keep Signator (Secure Enclave) keys non-importable.
- [ ] Add an explicit `--agent` (instrument) mode *only* once a real headless use case exists;
      software keys live behind it, encrypted at rest.
- [ ] Delete the deprecated `PrivateKeyStore` path once nothing references it.
