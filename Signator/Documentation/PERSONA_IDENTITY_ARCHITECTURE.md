# Persona Identity Architecture

## Overview

This document describes the complete persona identity structure for Signator, including mandatory and optional components with proper visual hierarchy and validation.

## Identity Components

### 1. **DID (Decentralized Identifier)** - MANDATORY
- **Format**: `did:451:a4a360afd06844da8d939131f3dd2631`
- **Purpose**: Permanent, cryptographic identifier for all signing operations
- **Creation**: Auto-generated on client, verified by server
- **Visibility**: Displayed subtly underneath the label
- **Changeability**: Never changes (permanent identity anchor)

### 2. **Label** - MANDATORY
- **Format**: Dot notation (e.g., `jane.wu.university.wisconsin.department.biology`)
- **Purpose**: Human-readable, hierarchical identifier
- **Creation**: User-created on client, verified for uniqueness by server
- **Visibility**: Most prominent display element
- **Changeability**: Can be changed (like a handle)

### 3. **ORCID** - OPTIONAL
- **Format**: `0000-0002-1825-0097` (16 digits with hyphens, last char can be X)
- **Purpose**: Links persona to academic research and publications
- **Creation**: User-entered (must already have ORCID from institution)
- **Validation**: 
  - Format validation required to save
  - Server verification optional (can happen later)
  - Persona creation not blocked by verification status
- **Visibility**: Displayed larger than DID but smaller than label
- **Who needs it**: Only researchers, academics, and scholars (small fraction of users)

### 4. **Email** - OPTIONAL
- **Format**: Standard email address
- **Purpose**: Communication, account recovery, trust building
- **Verification**: 
  - User receives verification email
  - Can create persona before clicking verification link
  - Verification can complete later
- **Visibility**: Shown with verification badge if verified

## Visual Hierarchy

When displaying a persona, the hierarchy from most to least prominent:

```
1. Label (largest, most readable)
   jane.wu.university.wisconsin.department.biology

2. DID (small, subtle, monospaced)
   did:451:a4a360af...3dd2631

3. ORCID (medium, with verification badge)
   🎓 ORCID: 0000-0002-1825-0097 ✓ Verified

4. Email (medium, with verification badge)
   📧 jane.wu@wisc.edu ✓ Verified

5. Credential Badges
   📧 Verified Email • 🎓 ORCID Verified
```

## Implementation Files

### Data Model (`Persona.swift`)
```swift
struct Persona {
    let did: String                // Mandatory, UUID-based
    var label: String              // Mandatory, dot notation
    var orcid: String?             // Optional
    var orcidVerified: Bool        // Verification status
    var email: String?             // Optional
    var emailVerified: Bool        // Verification status
    // ... other fields
}
```

### UI Components

1. **PersonaIdentityDisplayView.swift**
   - Full display of persona identity with proper hierarchy
   - Compact version for list rows
   - Card-style display option

2. **OrcidInputField.swift**
   - ORCID input with auto-formatting
   - Format validation (blocks invalid input)
   - Optional server verification
   - Visual feedback for validation status

3. **EmailVerificationField.swift**
   - Email input with format validation
   - Send verification email button
   - Status tracking (sent, verified)
   - User can proceed without verification

4. **PersonaCredentialsSection.swift**
   - Reusable section for PersonaCreationView
   - Combines email and ORCID inputs
   - Info sheet explaining credentials
   - Integrates with verification services

### Services

1. **OrcidVerificationService**
   - Verifies ORCID against public ORCID API
   - Endpoint: `https://pub.orcid.org/v3.0/{orcid}`
   - Returns true if ORCID exists in registry

2. **EmailVerificationService**
   - Sends verification email via backend
   - Verifies token from email link
   - Tracks verification status

## Validation Rules

### Label Validation
- ✅ Must be dot notation
- ✅ Unique across all personas (server-verified)
- ✅ Lowercase, hyphens allowed
- ✅ Example: `jane.wu.university.wisconsin.department.biology`

### ORCID Validation
- ✅ Format: `XXXX-XXXX-XXXX-XXXZ` (Z can be digit or X)
- ✅ Must match regex: `^\d{4}-\d{4}-\d{4}-\d{3}[0-9X]$`
- ✅ Format validation REQUIRED to save
- ⚠️ Server verification OPTIONAL (can happen later)
- ❌ Cannot save invalid ORCID format

### Email Validation
- ✅ Standard email format
- ✅ Verification email sent to address
- ⚠️ Persona can be created before verification
- ⚠️ User can verify later via email link

## User Flow

### Creating Persona with Credentials

```
1. User enters label: jane.wu.university.wisconsin
   → Server checks uniqueness
   → DID auto-generated

2. User optionally enters email: jane.wu@wisc.edu
   → Format validated
   → "Send Verification Email" button appears
   → User clicks, email sent
   → Can continue without waiting for verification

3. User optionally enters ORCID: 0000-0002-1825-0097
   → Format validated as user types
   → Auto-formatted with hyphens
   → "Verify with ORCID" button appears
   → User can verify now or later

4. User creates persona
   → Persona saved with all fields
   → emailVerified: false (until link clicked)
   → orcidVerified: false (until verification completes)

5. User verifies later
   → Clicks email link → emailVerified: true
   → Returns to app → clicks "Verify ORCID" → orcidVerified: true
```

## Display Examples

### Card Display
```
┌─────────────────────────────────────────────────┐
│ 👤 Persona Identity                             │
│                                                 │
│ jane.wu.university.wisconsin.department.biology │
│ DID: did:451:a4a360af...3dd2631                │
│                                                 │
│ 🎓 ORCID: 0000-0002-1825-0097                  │
│    ✓ Verified                                   │
│                                                 │
│ 📧 jane.wu@wisc.edu                            │
│    ✓ Verified                                   │
│                                                 │
│ [📧 Verified Email] [🎓 ORCID Verified]        │
└─────────────────────────────────────────────────┘
```

### List Row (Compact)
```
jane.wu.university.wisconsin.department.biology
did:451:a4a360af...3dd2631
🎓 0000-0002-1825-0097
📧 Verified Email • 🎓 ORCID Verified
```

## Integration with PersonaCreationView

Add to the form after the identity section:

```swift
// After identitySection
PersonaCredentialsSection(
    email: $email,
    emailVerified: $emailVerified,
    orcid: $orcid,
    orcidVerified: $orcidVerified,
    personaDID: generatedDID
)
```

## Backend Requirements

### API Endpoints Needed

1. **POST /api/verify-email**
   - Sends verification email with token
   - Body: `{ "email": "...", "did": "..." }`
   - Returns: `{ "success": true, "token": "..." }`

2. **POST /api/verify-email/confirm**
   - Verifies email with token from link
   - Body: `{ "email": "...", "token": "..." }`
   - Returns: `{ "verified": true }`

3. **Persona Creation/Update**
   - Include new fields in persona payload:
     ```json
     {
       "did": "did:451:...",
       "label": "jane.wu.university.wisconsin",
       "orcid": "0000-0002-1825-0097",
       "orcidVerified": false,
       "email": "jane.wu@wisc.edu",
       "emailVerified": false
     }
     ```

### Database Schema Updates

Add columns to persona table:
```sql
ALTER TABLE personas ADD COLUMN label VARCHAR(255) NOT NULL;
ALTER TABLE personas ADD COLUMN orcid VARCHAR(19);  -- 0000-0002-1825-0097
ALTER TABLE personas ADD COLUMN orcid_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE personas ADD COLUMN email_verified BOOLEAN DEFAULT FALSE;

-- Unique constraint on label
CREATE UNIQUE INDEX idx_personas_label ON personas(label);

-- Index for ORCID lookups
CREATE INDEX idx_personas_orcid ON personas(orcid) WHERE orcid IS NOT NULL;
```

## Benefits of This Architecture

### User Experience
- ✅ Clear visual hierarchy prioritizes readability
- ✅ Optional credentials don't block persona creation
- ✅ Progressive disclosure (can add/verify later)
- ✅ Familiar dot-notation labels
- ✅ Academic users can link research via ORCID

### Technical Benefits
- ✅ DID provides permanent cryptographic identity
- ✅ Label provides human-readable addressing
- ✅ ORCID links to external academic ecosystem
- ✅ Email enables communication and recovery
- ✅ All validations prevent invalid data

### Trust & Credibility
- ✅ Multiple verification layers build trust
- ✅ Verified credentials displayed prominently
- ✅ ORCID connects to research reputation
- ✅ Email verification proves address ownership
- ✅ Visual badges show verification status

## Testing Checklist

- [ ] Create persona with only mandatory fields (DID, label)
- [ ] Create persona with email (unverified)
- [ ] Verify email via link, check badge updates
- [ ] Create persona with ORCID (unverified)
- [ ] Verify ORCID, check badge updates
- [ ] Test invalid ORCID format (should be blocked)
- [ ] Test invalid email format
- [ ] Test label uniqueness validation
- [ ] Test display in list view
- [ ] Test display in detail view
- [ ] Test display in card view
- [ ] Test credential info sheet
- [ ] Test ORCID auto-formatting
- [ ] Test verification service integration

## Future Enhancements

1. **Additional Credentials**
   - LinkedIn verification
   - Twitter/X verification
   - Domain ownership verification
   - Professional certifications

2. **Selective Disclosure**
   - Control which credentials are public
   - Share different subsets with different parties
   - Privacy-preserving credential proofs

3. **Credential Expiration**
   - Re-verification for old credentials
   - Expiration warnings
   - Auto-renewal flows

4. **Reputation System**
   - Trust score based on verified credentials
   - Community endorsements
   - Signing history reputation
