# Quick Reference: Persona Identity System

## 📋 Component Summary

| Component | Required | Format | Validation | Display Priority |
|-----------|----------|--------|------------|------------------|
| **DID** | ✅ Yes | `did:451:uuid` | Auto-generated | 3️⃣ Subtle |
| **Label** | ✅ Yes | Dot notation | Server-checked | 1️⃣ Prominent |
| **ORCID** | ⬜️ Optional | `0000-0002-1825-0097` | Format + API | 2️⃣ Medium |
| **Email** | ⬜️ Optional | Standard email | Format + Link | 2️⃣ Medium |

---

## 🎯 Visual Hierarchy (Largest to Smallest)

```
1. LABEL           jane.wu.university.wisconsin    [36pt, bold]
2. DID             did:451:a4a360af...3dd2631      [10pt, mono, gray]
3. ORCID           🎓 0000-0002-1825-0097          [14pt, mono]
4. EMAIL           📧 jane.wu@wisc.edu             [14pt]
5. BADGES          [📧 Verified] [🎓 Verified]     [10pt]
```

---

## 🔧 Files Created

### Core Model
- ✅ **Persona.swift** - Updated with label, orcid, email fields

### UI Components
- ✅ **PersonaIdentityDisplayView.swift** - Display components (full, compact, card)
- ✅ **OrcidInputField.swift** - ORCID input with validation
- ✅ **EmailVerificationField.swift** - Email input with verification
- ✅ **PersonaCredentialsSection.swift** - Combined section for persona creation

### Documentation
- ✅ **PERSONA_IDENTITY_ARCHITECTURE.md** - Complete architecture guide
- ✅ **INTEGRATION_GUIDE.md** - Step-by-step integration
- ✅ **PERSONA_EXAMPLES.md** - Real-world examples
- ✅ **QUICK_REFERENCE.md** - This file

### Updated
- ✅ **OnboardingView.swift** - Added identity explanation page

---

## 💻 Code Snippets

### Import Display Components
```swift
import SwiftUI

// Use in any view
PersonaIdentityDisplayView(persona: persona)
PersonaIdentityCompactView(persona: persona)
PersonaIdentityCardView(persona: persona)
```

### Add to PersonaCreationView
```swift
// Add state variables
@State private var orcid = ""
@State private var orcidVerified = false
@State private var emailVerified = false

// Add section to form (after identity section)
PersonaCredentialsSection(
    email: $publicEmail,
    emailVerified: $emailVerified,
    orcid: $orcid,
    orcidVerified: $orcidVerified,
    personaDID: fullDID
)
```

### Create Persona with Credentials
```swift
let persona = Persona(
    id: did,
    controller: did,
    name: name,
    label: label,                    // NEW
    email: email,
    emailVerified: emailVerified,    // NEW
    orcid: orcid,                    // NEW
    orcidVerified: orcidVerified,    // NEW
    publicKeyBase64: publicKey,
    createdAt: ISO8601DateFormatter().string(from: Date())
)
```

### Validate ORCID Format
```swift
// Auto-format as user types
orcid = String.formatOrcidInput(orcid)

// Validate before saving
if let validOrcid = String.validateAndFormatOrcid(orcid) {
    persona.orcid = validOrcid
}
```

### Verify ORCID with API
```swift
let verified = await OrcidVerificationService.shared.verify(orcid)
if verified {
    persona.orcidVerified = true
}
```

### Send Email Verification
```swift
let sent = await EmailVerificationService.shared.sendVerification(
    to: email,
    for: persona.id
)
```

---

## ✅ Validation Rules

### Label
```
✓ Must use dot notation (e.g., jane.wu.institution)
✓ Must be unique (server-validated)
✓ Lowercase preferred
✓ Hyphens allowed
✓ No spaces
```

### ORCID
```
✓ Format: XXXX-XXXX-XXXX-XXXZ (Z can be digit or X)
✓ Auto-formatted with hyphens
✓ Cannot save invalid format
✗ Can save unverified (verification optional)
```

### Email
```
✓ Standard email format
✓ Verification email sent
✗ Can create persona before verification
✗ Verification happens async via email link
```

---

## 🎨 Display Examples

### List Row
```swift
PersonaIdentityCompactView(persona: persona)
```
Output:
```
jane.wu.university.wisconsin
did:451:a4a360af...3dd2631
🎓 0000-0002-1825-0097
📧 Verified Email • 🎓 ORCID Verified
```

### Detail View
```swift
PersonaIdentityCardView(persona: persona)
```
Output:
```
┌─────────────────────────────────────┐
│ 👤 Persona Identity                 │
├─────────────────────────────────────┤
│ jane.wu.university.wisconsin        │
│ did:451:a4a360af...3dd2631         │
│                                     │
│ 🎓 ORCID: 0000-0002-1825-0097      │
│    ✓ Verified                       │
│                                     │
│ 📧 jane.wu@wisc.edu                │
│    ✓ Verified                       │
└─────────────────────────────────────┘
```

---

## 📊 Persona Types

| Type | Label Example | ORCID | Email | Use Case |
|------|---------------|-------|-------|----------|
| **Academic** | `jane.wu.university` | ✅ Yes | ✅ Yes | Research, publications |
| **Professional** | `sara.silver.company` | ❌ No | ✅ Yes | Business, corporate |
| **Independent** | `john.doe.freelance` | ❌ No | ⚠️ Optional | Personal, freelance |
| **Anonymous** | `anonymous.451.info` | ❌ No | ❌ No | Privacy, anonymity |
| **Student** | `emily.student.university` | ⚠️ Maybe | ✅ Yes | Academic work |

---

## 🔐 Security & Privacy

### What's Public
- Label (always visible)
- DID (always visible)
- ORCID (if user chooses to share)
- Email (if user chooses to share)
- Verification badges (if verified)

### What's Private
- Private key (always encrypted)
- Private persona fields (encrypted)
- Verification tokens (server-only)

### What Can Change
- ✅ Label (can be updated)
- ✅ Email (can be updated)
- ✅ ORCID (can be added/updated)
- ✅ Verification status (changes when verified)
- ❌ DID (permanent, never changes)

---

## 🚀 Backend Requirements

### Database Columns
```sql
ALTER TABLE personas ADD COLUMN label VARCHAR(255) NOT NULL;
ALTER TABLE personas ADD COLUMN orcid VARCHAR(19);
ALTER TABLE personas ADD COLUMN orcid_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE personas ADD COLUMN email_verified BOOLEAN DEFAULT FALSE;

CREATE UNIQUE INDEX idx_personas_label ON personas(label);
```

### API Endpoints
```
POST /api/verify-email
  Body: { "email": "...", "did": "..." }
  Response: { "success": true }

POST /api/verify-email/confirm
  Body: { "email": "...", "token": "..." }
  Response: { "verified": true }

GET /api/orcid/{orcid}
  Response: { "valid": true, "name": "..." }
```

---

## 🧪 Testing Checklist

- [ ] Create persona with label only
- [ ] Create persona with email (unverified)
- [ ] Create persona with ORCID (unverified)
- [ ] Create persona with both email and ORCID
- [ ] Verify email via link
- [ ] Verify ORCID via API
- [ ] Test invalid ORCID format (should block)
- [ ] Test invalid email format
- [ ] Test duplicate label (should fail)
- [ ] Display persona in list view
- [ ] Display persona in detail view
- [ ] Display persona in card view
- [ ] Test ORCID auto-formatting
- [ ] Test email verification flow

---

## 📖 Documentation Links

- **Full Architecture**: See `PERSONA_IDENTITY_ARCHITECTURE.md`
- **Integration Guide**: See `INTEGRATION_GUIDE.md`
- **Examples**: See `PERSONA_EXAMPLES.md`
- **Code**: See Swift files in `/repo`

---

## 🎓 ORCID Quick Facts

- **What**: Unique identifier for researchers
- **Who**: Academics, scientists, grant recipients
- **Format**: `0000-0002-1825-0097` (16 digits with hyphens)
- **How Many**: Small fraction of users (~5-10%)
- **Required**: No, completely optional
- **Verification**: Via public ORCID API
- **Purpose**: Links persona to research publications

---

## 💡 Key Design Decisions

1. **Label ≠ ORCID**: ORCID is separate metadata, not part of label
2. **Label Most Prominent**: Human-readable is primary identifier
3. **DID Permanent**: Never changes, used for crypto operations
4. **ORCID Optional**: Only for researchers, not required
5. **Format Validation**: Can't save invalid ORCID format
6. **Async Verification**: Can verify later, don't block creation
7. **Visual Hierarchy**: Label > ORCID > DID in size/prominence
8. **Progressive Enhancement**: Basic persona → add credentials → verify

---

## 🎯 User Journey

```
1. Enter label          jane.wu.university.wisconsin
2. DID generated        did:451:a4a360af...
3. Add email (opt)      jane.wu@wisc.edu
4. Send verification    📧 Email sent
5. Add ORCID (opt)      0000-0002-1825-0097
6. Verify ORCID (opt)   🎓 Checking...
7. Create persona       ✓ Created (unverified)
8. Click email link     📧 Verified!
9. ORCID verified       🎓 Verified!
10. Full credentials    📧 🎓 Both verified
```

---

## 🔄 State Transitions

```
Email: empty → entered → sent → verified
ORCID: empty → entered → format valid → API verified
Persona: creating → created → email verified → ORCID verified → fully verified
```

---

## 🎨 Color Scheme

| Element | Color | Meaning |
|---------|-------|---------|
| 🎓 ORCID | Orange | Academic credential |
| 📧 Email | Blue | Communication verified |
| ✓ Verified | Green | Credential confirmed |
| ⚠️ Pending | Orange | Awaiting verification |
| DID | Gray | Subtle, technical |
| Label | Primary | Most important |

---

## ⚡ Performance Tips

- Cache ORCID verification results
- Debounce email validation
- Load personas asynchronously
- Use compact views in lists
- Lazy load full details
- Cache formatted strings

---

## 🐛 Common Issues

### ORCID not formatting
→ Check `String.formatOrcidInput` is available

### Email not sending
→ Check backend URL in `EmailVerificationService`

### Credentials not showing
→ Verify persona model has new fields

### Validation failing
→ Check regex patterns match format

### Display hierarchy wrong
→ Review font sizes in display views

---

## 📱 Platform Support

- ✅ iOS 17+
- ✅ iPadOS 17+
- ⚠️ macOS (needs testing)
- ⚠️ visionOS (needs testing)

---

## 🎁 Bonus Features

- Auto-formatting for ORCID input
- Real-time format validation
- Verification status badges
- Multiple display styles
- Info sheets for guidance
- Async verification (non-blocking)
- Credential strength indicators
- Privacy-preserving display options

---

## 📞 Support

Questions? Check:
1. Architecture doc for concepts
2. Integration guide for implementation
3. Examples for real-world usage
4. This quick reference for syntax

---

**Last Updated**: January 31, 2026
**Version**: 1.0
**Status**: ✅ Complete and ready for integration
