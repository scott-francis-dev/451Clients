# Renaming "Participants" to "Contract Parties"

## Summary

This document describes the changes made to rename "participants" to "contractParties" throughout the codebase to better reflect the intended meaning: the parties who need to sign a contract.

## Rationale

In contract signing workflows:
- **Author** = The person who creates/uploads the document (e.g., a lawyer drafting a contract)
- **Contract Parties** = The important signers who are parties to the contract (e.g., buyer, seller, etc.)
- **Other roles** = Witnesses, notaries, reviewers

The term "participants" was ambiguous and didn't convey the legal significance of these signers. "Contract Parties" makes it clear that these are the primary stakeholders in the agreement.

## Files Changed

### 1. DocumentSigningService.swift
- **`SignerRole` enum**: Renamed `.participant` → `.contractParty`
- **Code examples in comments**: Updated documentation to use `contractParty` role
- **Migration guide**: Updated to reflect new terminology

### 2. SendSigningFlowView.swift
- **`Metadata` struct**: Renamed `participants: [String]` → `contractParties: [String]`
- **State variables**: 
  - `resolvedParticipants` → `resolvedContractParties`
  - `unresolvedParticipants` → `unresolvedContractParties`
- **`ActiveField` enum**: `.participants` → `.contractParties`
- **Computed properties**:
  - `allParticipantsResolved` → `allContractPartiesResolved`
- **UI labels**: "participants" → "contract parties" in all user-facing text
- **Functions**: `resolveParticipants()` → `resolveContractParties()`
- **XMP metadata**: Updated both XML and dictionary generation to use "contractParties"

### 3. InitiatedSigningStore.swift
- **`InitiatedSigningRecord`**: Renamed `participants: [String]` → `contractParties: [String]`
- Updated initializer parameter names

### 4. InitiatedRequestDetailView.swift
- **View parameters**: `participants: [PersonaResolvedProfile]` → `contractParties: [PersonaResolvedProfile]`
- **UI section header**: "Participants" → "Contract Parties"
- **Preview**: Updated to use `contractParties` parameter

### 5. MultiPartySigningView.swift
- **Default role**: Changed from `.participant` to `.contractParty`
- **Picker label**: "Participant" → "Contract Party"

## Backward Compatibility

⚠️ **Breaking Change**: This is a breaking change for:

1. **Stored data**: Existing `InitiatedSigningRecord` objects saved with `participants` field will need migration
2. **Server API**: If the server expects "participants" in metadata, it will need to be updated to accept "contractParties"
3. **XMP metadata**: Old documents will have `prov:participants`, new ones will have `prov:contractParties`

## Migration Path

### For existing stored records:
```swift
// In InitiatedSigningStore.load()
let records = try decoder.decode([InitiatedSigningRecord].self, from: data)

// Could add fallback decoding with custom CodingKeys if needed:
enum CodingKeys: String, CodingKey {
    case contractParties
    case participants // fallback for old data
    // ... other keys
}

init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Try new key first, fall back to old key
    if let parties = try? container.decode([String].self, forKey: .contractParties) {
        self.contractParties = parties
    } else {
        self.contractParties = (try? container.decode([String].self, forKey: .participants)) ?? []
    }
    // ... decode other properties
}
```

### For server communication:
- Server endpoints should accept both `participants` and `contractParties` during transition period
- New submissions should use `contractParties`
- Old document queries should map `participants` → `contractParties` when loading

## Current Workflow

After these changes, the workflow is:

1. **Author uploads document** with `contractParties` metadata
   - Contract parties are stored as DIDs in metadata
   - No signatures created for contract parties yet
   
2. **Contract parties sign separately** (pending documents workflow)
   - Each party receives a pending document notification
   - They sign individually when ready
   - Creates separate SIGN ledger entries

3. **Document finalized** once all required signatures collected
   - Creates ATTEST ledger entry
   - References all SIGN entries

## Future Work

Consider also renaming:
- `authors` → Could be clarified as `documentAuthors` or `documentCreators`
- The relationship between "author" role in signatures vs "authors" in metadata
- Whether "authors" metadata is still needed if author always signs as first signer

## Testing

Test cases to verify:
- [ ] Creating new document with contract parties works
- [ ] Old documents with "participants" can be loaded (if migration implemented)
- [ ] UI displays "Contract Parties" correctly
- [ ] XMP metadata contains `prov:contractParties`
- [ ] Server accepts the new field name
- [ ] Signature workflow creates proper SIGN entries for contract parties

## Related Documentation

- `README_DOCUMENT_SIGNING.md` - Main documentation for document signing
- `DOCUMENT_SIGNING_MIGRATION.md` - Migration guide from old to new workflow
- `SIGNING_PERSISTENCE_IMPLEMENTATION.md` - How signing records are persisted
