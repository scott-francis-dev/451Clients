# Persona Identity Examples

## Example 1: Academic Researcher with Full Credentials

### Dr. Jane Wu - University of Wisconsin, Department of Biology

```swift
Persona(
    id: "did:451:a4a360afd06844da8d939131f3dd2631",
    controller: "did:451:a4a360afd06844da8d939131f3dd2631",
    name: "Jane Wu",
    label: "jane.wu.university.wisconsin.department.biology",
    email: "jane.wu@wisc.edu",
    emailVerified: true,
    orcid: "0000-0002-1825-0097",
    orcidVerified: true,
    affiliations: "University of Wisconsin-Madison",
    publicKeyBase64: "...",
    createdAt: "2026-01-31T00:00:00Z",
    visibility: .public
)
```

### Display in UI:

```
┌─────────────────────────────────────────────────────┐
│ jane.wu.university.wisconsin.department.biology     │
│ did:451:a4a360af...3dd2631                         │
│                                                     │
│ 🎓 ORCID: 0000-0002-1825-0097                      │
│    ✓ Verified                                       │
│                                                     │
│ 📧 jane.wu@wisc.edu                                │
│    ✓ Verified                                       │
│                                                     │
│ [📧 Verified Email] [🎓 ORCID Verified]            │
└─────────────────────────────────────────────────────┘
```

### Use Cases:
- Publishing research papers
- Signing grant applications
- Peer review activities
- Academic collaboration
- Research data sharing

---

## Example 2: Independent Writer (No ORCID)

### John Doe - Freelance Writer

```swift
Persona(
    id: "did:451:b5b471bge17955eb9e040242g4ee3742",
    controller: "did:451:b5b471bge17955eb9e040242g4ee3742",
    name: "John Doe",
    label: "john.doe.freelance.writer",
    email: "john@example.com",
    emailVerified: true,
    orcid: nil,  // No ORCID - not a researcher
    orcidVerified: false,
    publicKeyBase64: "...",
    createdAt: "2026-01-31T00:00:00Z",
    visibility: .public
)
```

### Display in UI:

```
┌─────────────────────────────────────────────────────┐
│ john.doe.freelance.writer                           │
│ did:451:b5b471bg...4ee3742                         │
│                                                     │
│ 📧 john@example.com                                │
│    ✓ Verified                                       │
│                                                     │
│ [📧 Verified Email]                                │
└─────────────────────────────────────────────────────┘
```

### Use Cases:
- Publishing articles
- Signing freelance contracts
- Content attribution
- Digital identity for publications

---

## Example 3: Anonymous Public Persona

### Pseudonymous Author

```swift
Persona(
    id: "did:451:c6c582csh28066fc0f151353h5ff4853",
    controller: "did:451:c6c582csh28066fc0f151353h5ff4853",
    name: "A. Nonymous",
    label: "a.nonymous.451.info",
    email: nil,  // No email - wants privacy
    emailVerified: false,
    orcid: nil,  // No ORCID
    orcidVerified: false,
    publicKeyBase64: "...",
    createdAt: "2026-01-31T00:00:00Z",
    visibility: .public
)
```

### Display in UI:

```
┌─────────────────────────────────────────────────────┐
│ a.nonymous.451.info                                 │
│ did:451:c6c582cs...5ff4853                         │
│                                                     │
│ No verified credentials                             │
└─────────────────────────────────────────────────────┘
```

### Use Cases:
- Anonymous publishing
- Whistleblowing
- Privacy-focused signing
- Pseudonymous content creation

---

## Example 4: Corporate Employee

### Sarah Silver - Silver Publishing

```swift
Persona(
    id: "did:451:d7d693dti39177gd1g262464i6gg5964",
    controller: "did:451:d7d693dti39177gd1g262464i6gg5964",
    name: "Sara Silver",
    label: "sara.silver.silver.publishing.451.info",
    email: "sara@silverpublishing.com",
    emailVerified: true,
    orcid: nil,  // Not a researcher
    orcidVerified: false,
    affiliations: "Silver Publishing, Senior Editor",
    publicKeyBase64: "...",
    createdAt: "2026-01-31T00:00:00Z",
    visibility: .public
)
```

### Display in UI:

```
┌─────────────────────────────────────────────────────┐
│ sara.silver.silver.publishing.451.info              │
│ did:451:d7d693dt...6gg5964                         │
│                                                     │
│ 📧 sara@silverpublishing.com                       │
│    ✓ Verified                                       │
│                                                     │
│ Silver Publishing, Senior Editor                    │
│                                                     │
│ [📧 Verified Email]                                │
└─────────────────────────────────────────────────────┘
```

### Use Cases:
- Publishing house documents
- Editorial decisions
- Contract signing
- Professional correspondence

---

## Example 5: Medical Professional with ORCID

### Dr. Michael Chen - Hospital Researcher

```swift
Persona(
    id: "did:451:e8e7a4euj4a288he2h373575j7hh6a75",
    controller: "did:451:e8e7a4euj4a288he2h373575j7hh6a75",
    name: "Dr. Michael Chen",
    label: "michael.chen.hospital.research.stanford",
    email: "mchen@stanford.edu",
    emailVerified: true,
    orcid: "0000-0003-4567-8901",
    orcidVerified: true,
    affiliations: "Stanford Medical Center, Research Division",
    publicKeyBase64: "...",
    createdAt: "2026-01-31T00:00:00Z",
    visibility: .public
)
```

### Display in UI:

```
┌─────────────────────────────────────────────────────┐
│ michael.chen.hospital.research.stanford             │
│ did:451:e8e7a4eu...7hh6a75                         │
│                                                     │
│ 🎓 ORCID: 0000-0003-4567-8901                      │
│    ✓ Verified                                       │
│                                                     │
│ 📧 mchen@stanford.edu                              │
│    ✓ Verified                                       │
│                                                     │
│ Stanford Medical Center, Research Division          │
│                                                     │
│ [📧 Verified Email] [🎓 ORCID Verified]            │
└─────────────────────────────────────────────────────┘
```

### Use Cases:
- Medical research publication
- Clinical trial documentation
- Patient consent forms
- Medical record transfers
- Research collaboration

---

## Example 6: Student (Email Only, Pending Verification)

### Emily Johnson - Graduate Student

```swift
Persona(
    id: "did:451:f9f8b5fvk5b399if3i484686k8ii7b86",
    controller: "did:451:f9f8b5fvk5b399if3i484686k8ii7b86",
    name: "Emily Johnson",
    label: "emily.johnson.student.university.california",
    email: "emily.j@berkeley.edu",
    emailVerified: false,  // Just sent verification email
    orcid: "0000-0001-2345-6789",
    orcidVerified: false,  // Will verify later
    affiliations: "UC Berkeley, Graduate Student",
    publicKeyBase64: "...",
    createdAt: "2026-01-31T00:00:00Z",
    visibility: .public
)
```

### Display in UI:

```
┌─────────────────────────────────────────────────────┐
│ emily.johnson.student.university.california         │
│ did:451:f9f8b5fv...8ii7b86                         │
│                                                     │
│ 🎓 ORCID: 0000-0001-2345-6789                      │
│    ⚠️ Pending verification                          │
│                                                     │
│ 📧 emily.j@berkeley.edu                            │
│    ⚠️ Pending verification                          │
│                                                     │
│ UC Berkeley, Graduate Student                       │
└─────────────────────────────────────────────────────┘
```

### User Experience:
1. Created persona immediately
2. Verification email sent to berkeley.edu
3. ORCID verification can happen later
4. Can start using persona right away
5. Verification badges appear after clicking links

---

## Comparison Table

| Persona Type | Label Format | DID | ORCID | Email | Use Case |
|--------------|--------------|-----|-------|-------|----------|
| Academic | `jane.wu.university.wisconsin` | ✅ Always | ✅ Yes | ✅ Yes | Research, publication |
| Professional | `sara.silver.company-name` | ✅ Always | ❌ No | ✅ Yes | Corporate, business |
| Independent | `john.doe.freelance` | ✅ Always | ❌ No | ✅ Optional | Freelance, personal |
| Anonymous | `a.nonymous.451.info` | ✅ Always | ❌ No | ❌ No | Privacy, anonymity |
| Student | `emily.student.institution` | ✅ Always | ⚠️ Maybe | ✅ Yes | Academic work |
| Medical | `dr.chen.hospital.research` | ✅ Always | ✅ Yes | ✅ Yes | Medical, research |

---

## Visual Hierarchy Examples

### Full Display (Detail View)
```
████████████████████████ (36pt, semibold)
jane.wu.university.wisconsin.department.biology

████ did:451:a4a3... (10pt, monospaced, gray)

███████████████ ORCID: 0000-0002-1825-0097 (14pt, monospaced)
        ✓ Verified (10pt, green)

███████████ jane.wu@wisc.edu (14pt)
    ✓ Verified (10pt, blue)

[Badge] [Badge]
```

### Compact Display (List View)
```
████████████ (17pt, bold)
jane.wu.university.wisconsin

███ did:451:a4a3... (8pt, monospaced, gray)

██████ 🎓 0000-0002-1825-0097 (11pt, monospaced)

█ 📧 Verified Email • 🎓 ORCID Verified (9pt, gray)
```

### Minimal Display (Badge/Chip)
```
jane.wu.university.wisconsin [🎓][📧]
```

---

## Code Snippets for Common Operations

### Creating a Researcher Persona
```swift
let researcher = Persona(
    id: generateDID(),
    controller: generateDID(),
    name: "Jane Wu",
    label: "jane.wu.\(institution).\(department)",
    email: email,
    emailVerified: false,
    orcid: orcid,
    orcidVerified: false,
    publicKeyBase64: publicKey,
    createdAt: ISO8601DateFormatter().string(from: Date()),
    visibility: .public
)
```

### Displaying in a List
```swift
List(personas) { persona in
    PersonaIdentityCompactView(persona: persona)
        .onTapGesture {
            selectedPersona = persona
        }
}
```

### Filtering by Credentials
```swift
// Show only verified personas
let verifiedPersonas = personas.filter { 
    $0.emailVerified || $0.orcidVerified 
}

// Show only researchers (with ORCID)
let researchers = personas.filter { 
    $0.orcid != nil 
}

// Show by credential strength
let fullyVerified = personas.filter {
    $0.emailVerified && $0.orcidVerified
}
```

### Checking Credential Status
```swift
if persona.credentialBadges.count >= 2 {
    // High trust persona
    Text("Fully Verified")
        .foregroundColor(.green)
} else if persona.credentialBadges.count == 1 {
    // Partially verified
    Text("Partially Verified")
        .foregroundColor(.orange)
} else {
    // Basic persona
    Text("No Verified Credentials")
        .foregroundColor(.gray)
}
```

---

## Migration Path for Existing Personas

If you have existing personas without these new fields:

```swift
extension Persona {
    func withDefaultCredentials() -> Persona {
        var updated = self
        
        // Add label if missing (derive from existing handle/name)
        if updated.label.isEmpty {
            updated.label = generateLabelFromExisting(self)
        }
        
        // Initialize verification flags if needed
        if updated.email != nil && !updated.emailVerified {
            // Existing emails are unverified by default
            updated.emailVerified = false
        }
        
        return updated
    }
    
    private func generateLabelFromExisting(_ persona: Persona) -> String {
        // Convert existing name to dot notation
        let cleanName = persona.name
            .lowercased()
            .replacingOccurrences(of: " ", with: ".")
        return "\(cleanName).451.info"
    }
}

// Usage
let migratedPersonas = existingPersonas.map { $0.withDefaultCredentials() }
```

---

## Summary

This architecture provides:

1. **Mandatory Foundation**: DID + Label (always present)
2. **Optional Trust**: ORCID + Email (adds credibility)
3. **Clear Hierarchy**: Label > ORCID > DID (visual importance)
4. **Flexible Verification**: Can verify now or later
5. **Format Validation**: Invalid data can't be saved
6. **Rich Display**: Multiple view styles for different contexts
7. **Academic Support**: ORCID integration for researchers (small fraction)
8. **Universal Appeal**: Works for everyone, specializes for academics
