# Visual Guide: What Users Will See

## Before vs After Implementation

### BEFORE (Current System)
```
┌───────────────────────────────────┐
│ Create Persona                    │
├───────────────────────────────────┤
│ Name: [Jane Wu              ]     │
│                                   │
│ Publishing House:                 │
│ [University Wisconsin       ]     │
│                                   │
│ Email (optional):                 │
│ [jane.wu@wisc.edu          ]     │
│                                   │
│ [Create Persona]                  │
└───────────────────────────────────┘
```

### AFTER (New System)
```
┌───────────────────────────────────┐
│ Create Persona                    │
├───────────────────────────────────┤
│ Name: [Jane Wu              ]     │
│                                   │
│ Publishing House:                 │
│ [University Wisconsin       ]     │
│                                   │
│ Label (auto-generated):           │
│ jane.wu.university.wisconsin      │
│ ✓ Unique                          │
│                                   │
├─ Optional Credentials ────────────┤
│                                   │
│ 📧 Email                          │
│ [jane.wu@wisc.edu          ]     │
│ ✓ Valid format                    │
│ [Send Verification Email]         │
│                                   │
│ 🎓 ORCID (for researchers)        │
│ [0000-0002-1825-0097       ]     │
│ ✓ Format valid                    │
│ [Verify with ORCID]               │
│                                   │
│ ℹ️ Optional credentials increase  │
│    trust but are not required     │
│                                   │
├───────────────────────────────────┤
│ [Create Persona]                  │
└───────────────────────────────────┘
```

---

## Persona Display: Different Contexts

### 1. List View (Personas Screen)

```
┌─────────────────────────────────────────────┐
│ My Personas                                 │
├─────────────────────────────────────────────┤
│                                             │
│ jane.wu.university.wisconsin               │
│ did:451:a4a360af...3dd2631                │
│ 🎓 0000-0002-1825-0097                     │
│ 📧 Verified Email • 🎓 ORCID Verified      │
│                                             │
├─────────────────────────────────────────────┤
│                                             │
│ john.doe.freelance.writer                  │
│ did:451:b5b471bg...4ee3742                │
│ 📧 Verified Email                          │
│                                             │
├─────────────────────────────────────────────┤
│                                             │
│ anonymous.451.info                         │
│ did:451:c6c582cs...5ff4853                │
│ No verified credentials                    │
│                                             │
└─────────────────────────────────────────────┘
```

### 2. Detail View (Tap on Persona)

```
┌─────────────────────────────────────────────┐
│ ← Back          Persona Details             │
├─────────────────────────────────────────────┤
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 👤 Persona Identity                     │ │
│ │                                         │ │
│ │ jane.wu.university.wisconsin           │ │
│ │ Department of Biology                   │ │
│ │                                         │ │
│ │ DID:                                    │ │
│ │ did:451:a4a360afd06844da8d939131...    │ │
│ │                                         │ │
│ │ 🎓 ORCID: 0000-0002-1825-0097          │ │
│ │    ✓ Verified                           │ │
│ │                                         │ │
│ │ 📧 jane.wu@wisc.edu                    │ │
│ │    ✓ Verified                           │ │
│ │                                         │ │
│ │ [📧 Verified Email] [🎓 ORCID Verified]│ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ Public Information                      │ │
│ │                                         │ │
│ │ Affiliations:                           │ │
│ │ University of Wisconsin-Madison         │ │
│ │                                         │ │
│ │ Created: January 31, 2026               │ │
│ │ Status: Active                          │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ [Edit Persona] [Share] [Archive]            │
│                                             │
└─────────────────────────────────────────────┘
```

### 3. Signing Dialog (When Signing a Document)

```
┌─────────────────────────────────────────────┐
│ Sign Document                               │
├─────────────────────────────────────────────┤
│ You are about to sign:                      │
│ "Research Grant Application 2026.pdf"       │
│                                             │
│ With persona:                               │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ jane.wu.university.wisconsin           │ │
│ │ did:451:a4a360af...                    │ │
│ │ 🎓 📧 Verified                          │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ This will create a cryptographic signature  │
│ proving you signed this document.           │
│                                             │
│ [Cancel]              [Sign Document] →     │
└─────────────────────────────────────────────┘
```

---

## ORCID Input Flow (For Researchers)

### Step 1: Empty Field
```
┌─────────────────────────────────────────────┐
│ 🎓 ORCID (optional)                         │
│ [0000-0002-1825-0097                  ]    │
│                                             │
│ ORCID is an optional identifier for         │
│ researchers. Format: 0000-0002-1825-0097    │
└─────────────────────────────────────────────┘
```

### Step 2: User Types (Auto-formatting)
```
┌─────────────────────────────────────────────┐
│ 🎓 ORCID (optional)                         │
│ [0000-0002-182                        ] ×  │
│                                             │
│ ✓ Format is valid                           │
│                                             │
│ ORCID is an optional identifier for         │
│ researchers. Format: 0000-0002-1825-0097    │
└─────────────────────────────────────────────┘
```
(Note: Hyphens auto-inserted at positions 4, 8, 12)

### Step 3: Complete ORCID Entered
```
┌─────────────────────────────────────────────┐
│ 🎓 ORCID (optional)                         │
│ [0000-0002-1825-0097                  ] ×  │
│                                             │
│ ✓ Format is valid                           │
│                                             │
│ [Verify with ORCID]                         │
│                                             │
│ ORCID is an optional identifier for         │
│ researchers. Format: 0000-0002-1825-0097    │
└─────────────────────────────────────────────┘
```

### Step 4: Verifying
```
┌─────────────────────────────────────────────┐
│ 🎓 ORCID (optional)                         │
│ [0000-0002-1825-0097                  ] ×  │
│                                             │
│ ✓ Format is valid                           │
│                                             │
│ [◐ Verifying...]                            │
│                                             │
│ ORCID is an optional identifier for         │
│ researchers. Format: 0000-0002-1825-0097    │
└─────────────────────────────────────────────┘
```

### Step 5: Verified
```
┌─────────────────────────────────────────────┐
│ 🎓 ORCID (optional)                         │
│ [0000-0002-1825-0097                  ] ×  │
│                                             │
│ ✓ ORCID verified successfully               │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ ✓ ORCID Verified                        │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ORCID is an optional identifier for         │
│ researchers. Format: 0000-0002-1825-0097    │
└─────────────────────────────────────────────┘
```

---

## Email Verification Flow

### Step 1: Enter Email
```
┌─────────────────────────────────────────────┐
│ 📧 Email (optional)                         │
│ [jane.wu@wisc.edu                     ] ×  │
│                                             │
│ ✓ Valid email format                        │
│                                             │
│ [Send Verification Email]                   │
│                                             │
│ Email is optional but adds credibility      │
│ to your persona. Verification can be        │
│ completed later.                            │
└─────────────────────────────────────────────┘
```

### Step 2: Sending
```
┌─────────────────────────────────────────────┐
│ 📧 Email (optional)                         │
│ [jane.wu@wisc.edu                     ] ×  │
│                                             │
│ ✓ Valid email format                        │
│                                             │
│ [◐ Sending...]                              │
└─────────────────────────────────────────────┘
```

### Step 3: Sent (Can Create Persona Now)
```
┌─────────────────────────────────────────────┐
│ 📧 Email (optional)                         │
│ [jane.wu@wisc.edu                     ] ×  │
│                                             │
│ ✓ Valid email format                        │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 📧 Verification email sent              │ │
│ │                                         │ │
│ │ Check your inbox and click the          │ │
│ │ verification link. You can create       │ │
│ │ the persona now and verify later.       │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### Step 4: After Clicking Link in Email
```
┌─────────────────────────────────────────────┐
│ 📧 Email (optional)                         │
│ [jane.wu@wisc.edu                     ] ×  │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ ✓ Email Verified                        │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

---

## Info Sheet (When User Taps ℹ️)

```
┌─────────────────────────────────────────────┐
│        Optional Credentials        Done     │
├─────────────────────────────────────────────┤
│                                             │
│ 📧 Email Verification                       │
│                                             │
│ Adding a verified email address:            │
│                                             │
│ ✓ Increases credibility of your persona    │
│ ✓ Enables account recovery options          │
│ ✓ Allows others to contact you securely    │
│                                             │
│ Verification Process:                       │
│ 1. Enter your email address                 │
│ 2. Click 'Send Verification Email'          │
│ 3. Check your inbox for verification link   │
│ 4. Click the link to verify                 │
│                                             │
│ You can create your persona before          │
│ verification completes.                     │
│                                             │
│ ─────────────────────────────────────────── │
│                                             │
│ 🎓 ORCID Identifier                         │
│                                             │
│ What is ORCID?                              │
│                                             │
│ ORCID (Open Researcher and Contributor ID)  │
│ is a unique identifier for researchers      │
│ and academics. It connects you to your      │
│ research outputs and activities.            │
│                                             │
│ Who should add ORCID?                       │
│ • Academic researchers                      │
│ • Scientists and scholars                   │
│ • Grant recipients                          │
│ • Anyone with published research            │
│                                             │
│ Most users don't need an ORCID. Only add    │
│ one if you have an existing ORCID           │
│ identifier from your research institution.  │
│                                             │
│ Format: 0000-0002-1825-0097                 │
│                                             │
│ ─────────────────────────────────────────── │
│                                             │
│ 🔒 Privacy & Control                        │
│                                             │
│ You control what information is visible     │
│ in your persona. Email and ORCID are        │
│ optional and can be kept private or         │
│ shared selectively based on your needs.     │
│                                             │
└─────────────────────────────────────────────┘
```

---

## Onboarding: New Identity Page

```
┌─────────────────────────────────────────────┐
│                                             │
│        [Background Video Playing]           │
│                                             │
│         ┌─────────────────────┐             │
│         │ Your Digital        │             │
│         │ Identity            │             │
│         │                     │             │
│         │ Your persona has    │             │
│         │ three components:   │             │
│         │                     │             │
│         │ • A readable label  │             │
│         │   (jane.wu.univ)    │             │
│         │                     │             │
│         │ • A permanent DID   │             │
│         │   for crypto ops    │             │
│         │                     │             │
│         │ • Optional ORCID    │             │
│         │   for researchers   │             │
│         └─────────────────────┘             │
│                                             │
│                    •••○○○○                  │
│                                             │
│                   [Next]                    │
│                                             │
└─────────────────────────────────────────────┘
```

---

## Real-World Example: Complete Flow

### Scenario: Dr. Jane Wu creates a research persona

#### 1. Start Persona Creation
```
[Tap "Create Persona"]
```

#### 2. Enter Basic Info
```
Name: Jane Wu
Publishing House: University Wisconsin
→ Label auto-generated: jane.wu.university.wisconsin
✓ Label is unique
```

#### 3. Scroll to Optional Credentials
```
📧 Email: jane.wu@wisc.edu
[Tap "Send Verification Email"]
→ ✓ Email sent! Check inbox.

🎓 ORCID: 0000-0002-1825-0097
[Tap "Verify with ORCID"]
→ ✓ ORCID verified!
```

#### 4. Create Persona
```
[Tap "Create Persona"]
→ ✓ Persona created successfully!
```

#### 5. Check Email Later
```
[Email arrives: "Verify your email for Signator"]
[Click link in email]
→ ✓ Email verified!
```

#### 6. View Completed Persona
```
┌───────────────────────────────────────┐
│ jane.wu.university.wisconsin         │
│ did:451:a4a360af...3dd2631          │
│ 🎓 0000-0002-1825-0097              │
│ 📧 jane.wu@wisc.edu                 │
│ [📧 Verified] [🎓 Verified]         │
└───────────────────────────────────────┘
```

---

## Error States

### Invalid ORCID Format
```
┌─────────────────────────────────────────────┐
│ 🎓 ORCID (optional)                         │
│ [1234-5678                            ] ×  │
│                                             │
│ ✗ Invalid ORCID format. Expected:           │
│   0000-0002-1825-0097                       │
└─────────────────────────────────────────────┘
```

### Invalid Email Format
```
┌─────────────────────────────────────────────┐
│ 📧 Email (optional)                         │
│ [not-an-email                         ] ×  │
│                                             │
│ ✗ Invalid email format                      │
└─────────────────────────────────────────────┘
```

### ORCID Verification Failed
```
┌─────────────────────────────────────────────┐
│ 🎓 ORCID (optional)                         │
│ [0000-0002-1825-0097                  ] ×  │
│                                             │
│ ⚠️ ORCID not found in registry              │
│                                             │
│ [Try Again]                                 │
└─────────────────────────────────────────────┘
```

### Email Send Failed
```
┌─────────────────────────────────────────────┐
│ 📧 Email (optional)                         │
│ [jane.wu@wisc.edu                     ] ×  │
│                                             │
│ ⚠️ Failed to send verification email        │
│                                             │
│ [Try Again]                                 │
└─────────────────────────────────────────────┘
```

---

## Visual Hierarchy Comparison

### Small (List Row)
```
LABEL          jane.wu.university (17pt bold)
DID            did:451:a4a3...     (9pt mono gray)
ORCID          🎓 0000-0002...     (11pt mono)
BADGES         📧 🎓               (9pt)
```

### Medium (Card View)
```
LABEL          jane.wu.university (24pt bold)
DID            did:451:a4a360...   (10pt mono gray)
ORCID          🎓 0000-0002-1825-0097 (14pt mono)
               ✓ Verified          (10pt green)
EMAIL          📧 jane.wu@wisc.edu (14pt)
               ✓ Verified          (10pt blue)
BADGES         [📧 Verified] [🎓]  (10pt chips)
```

### Large (Detail View)
```
LABEL          jane.wu.university.wisconsin (36pt bold)
               Department of Biology        (14pt gray)
DID            did:451:a4a360afd...         (10pt mono gray)
ORCID          🎓 ORCID: 0000-0002-1825-0097 (16pt mono)
               ✓ Verified                   (12pt green)
EMAIL          📧 jane.wu@wisc.edu          (16pt)
               ✓ Verified                   (12pt blue)
BADGES         [📧 Verified Email] [🎓 ORCID Verified] (12pt)
```

---

## Summary

This visual guide shows exactly what users will see after implementing the new identity system. The key improvements are:

1. **Clear Hierarchy**: Label is always most prominent
2. **Optional Credentials**: ORCID and email are clearly optional
3. **Progressive Enhancement**: Can add/verify credentials later
4. **Visual Feedback**: Icons, colors, and badges show status
5. **Non-Blocking**: Can create persona without waiting for verification
6. **Educational**: Info buttons explain when/why to use each field

The design prioritizes usability while supporting advanced features for researchers who need ORCID integration.
