# PersonaCreationView - Exact Changes Needed

This document shows the EXACT changes needed in your existing `PersonaCreationView.swift` file to integrate the new identity system.

## 1. Add State Variables (Line ~343, after existing @State variables)

Find this section in your code:
```swift
@State private var publicEmail = ""
```

Add these NEW variables right after:
```swift
@State private var orcid = ""
@State private var orcidVerified = false
@State private var emailVerified = false
```

## 2. Add Computed Property for Label (Line ~700, before `var body: some View`)

Add this new computed property:
```swift
/// Generate label from the normalized handle (without default domain)
private var generatedLabel: String {
    let handle = normalizedDID
    
    // For custom domain, use the full handle
    if isPublicPersona && useCustomDomain {
        return handle
    }
    
    // For publishing house or private, strip the default domain
    if handle.hasSuffix("." + defaultDomain) {
        return String(handle.dropLast(defaultDomain.count + 1))
    }
    
    return handle
}
```

## 3. Update Form Content (Line ~800, in your Form)

Find your existing Form structure:
```swift
private var formContent: some View {
    Form {
        Section { /* visibility toggle */ }
        identitySection
        privateFieldsSection
        createButtonSection
        // ... etc
    }
}
```

Change it to:
```swift
private var formContent: some View {
    Form {
        Section { /* visibility toggle */ }
        identitySection
        
        // ADD THIS NEW SECTION (only for public personas)
        if isPublicPersona {
            PersonaCredentialsSection(
                email: $publicEmail,
                emailVerified: $emailVerified,
                orcid: $orcid,
                orcidVerified: $orcidVerified,
                personaDID: fullDID
            )
        }
        
        privateFieldsSection
        createButtonSection
        if personaManager != nil && !(personaManager?.personas.isEmpty ?? true) {
            deletePersonaSection
        }
    }
}
```

## 4. Update ServerPersonaCreationRequest (Line ~30)

Find the existing struct:
```swift
private struct ServerPersonaCreationRequest: Encodable {
    let did: String
    let handle: String
    let name: String
    // ... existing fields
}
```

Change it to include the new fields:
```swift
private struct ServerPersonaCreationRequest: Encodable {
    let did: String
    let handle: String
    let label: String              // ADD THIS
    let name: String
    let attributes: [String: String]?
    let address: [String: String]?
    let email: String?             // existing
    let emailVerified: Bool?       // ADD THIS
    let orcid: String?             // ADD THIS
    let orcidVerified: Bool?       // ADD THIS
    let verified: Bool
    let isPublic: Bool?
    let backgroundValidated: Bool?
    let backgroundCheckRequired: Bool
    let domainToBeVerified: String?
    let dnsChallengeValue: String?
    let verificationMethod: [ServerPersonaProfileForSigning.VerificationMethod]?
    let signature: String?
}
```

## 5. Update Persona Creation (Find `handleCreatePersona()` function)

Find where you create the Persona object (likely around line 1500-2000):
```swift
private func handleCreatePersona() async {
    // ... existing code ...
    
    let persona = Persona(
        id: generatedFullDID,
        controller: generatedFullDID,
        name: name,
        address: addressString,
        email: publicEmail.isEmpty ? nil : publicEmail,
        // ... existing fields
    )
}
```

Change it to include the new fields:
```swift
private func handleCreatePersona() async {
    // ... existing code ...
    
    let persona = Persona(
        id: generatedFullDID,
        controller: generatedFullDID,
        name: name,
        label: generatedLabel,                                    // ADD THIS
        address: addressString,
        email: publicEmail.isEmpty ? nil : publicEmail,
        emailVerified: emailVerified,                             // ADD THIS
        orcid: orcid.isEmpty ? nil : orcid,                      // ADD THIS
        orcidVerified: orcidVerified,                            // ADD THIS
        affiliations: publicAffiliations.isEmpty ? nil : publicAffiliations,
        socialLinks: socialMediaLinks.isEmpty ? nil : socialMediaLinks,
        publicKeyBase64: publicKeyBase64,
        storageEndpoints: nil,
        createdAt: ISO8601DateFormatter().string(from: Date()),
        visibility: isPublicPersona ? .public : .private
    )
    
    // ... rest of existing code ...
}
```

## 6. Update Server Request Creation (in the same `handleCreatePersona()` function)

Find where you create the server request:
```swift
let request = ServerPersonaCreationRequest(
    did: generatedFullDID,
    handle: fullHandle,
    name: name,
    // ... existing fields
)
```

Change it to include new fields:
```swift
let request = ServerPersonaCreationRequest(
    did: generatedFullDID,
    handle: fullHandle,
    label: generatedLabel,                                    // ADD THIS
    name: name,
    attributes: nil,
    address: addressForServer,
    email: publicEmail.isEmpty ? nil : publicEmail,
    emailVerified: emailVerified,                             // ADD THIS
    orcid: orcid.isEmpty ? nil : orcid,                      // ADD THIS
    orcidVerified: orcidVerified,                            // ADD THIS
    verified: false,
    isPublic: isPublicPersona,
    backgroundValidated: false,
    backgroundCheckRequired: !isPublicPersona,
    domainToBeVerified: shouldVerifyDNS ? customDomain : nil,
    dnsChallengeValue: nil,
    verificationMethod: [verificationMethod],
    signature: signatureBase64
)
```

## 7. Add Import at Top of File (Line ~1)

Make sure you have this import:
```swift
import SwiftUI
import Combine
import Foundation
import CryptoKit
// Your existing imports...
```

## Complete Diff Summary

Here's what you're changing in summary:

### New State Variables
```diff
  @State private var publicEmail = ""
+ @State private var orcid = ""
+ @State private var orcidVerified = false
+ @State private var emailVerified = false
```

### New Computed Property
```diff
+ private var generatedLabel: String {
+     // ... implementation
+ }
```

### Updated Form
```diff
  Form {
      Section { /* visibility */ }
      identitySection
+     if isPublicPersona {
+         PersonaCredentialsSection(
+             email: $publicEmail,
+             emailVerified: $emailVerified,
+             orcid: $orcid,
+             orcidVerified: $orcidVerified,
+             personaDID: fullDID
+         )
+     }
      privateFieldsSection
      createButtonSection
  }
```

### Updated Server Request
```diff
  private struct ServerPersonaCreationRequest: Encodable {
      let did: String
      let handle: String
+     let label: String
      let name: String
      let attributes: [String: String]?
      let address: [String: String]?
+     let email: String?
+     let emailVerified: Bool?
+     let orcid: String?
+     let orcidVerified: Bool?
      // ... rest
  }
```

### Updated Persona Creation
```diff
  let persona = Persona(
      id: generatedFullDID,
      controller: generatedFullDID,
      name: name,
+     label: generatedLabel,
      address: addressString,
      email: publicEmail.isEmpty ? nil : publicEmail,
+     emailVerified: emailVerified,
+     orcid: orcid.isEmpty ? nil : orcid,
+     orcidVerified: orcidVerified,
      // ... rest
  )
```

## Testing After Integration

Once you make these changes:

1. **Build the project** - Should compile without errors
2. **Run the app** - Navigate to persona creation
3. **Test basic creation** - Create a persona without ORCID/email (should work as before)
4. **Test with email** - Add email, click send verification
5. **Test with ORCID** - Add ORCID, see auto-formatting
6. **Test with both** - Add both, see both sections

## Troubleshooting

### Compile Errors

**"Cannot find 'PersonaCredentialsSection' in scope"**
→ Make sure `PersonaCredentialsSection.swift` is added to your Xcode project

**"Value of type 'Persona' has no member 'label'"**
→ Make sure you've updated `Persona.swift` with the new fields

**"Extra argument 'label' in call"**
→ You need to update BOTH the Persona initializer AND where you call it

### Runtime Issues

**Credentials section not appearing**
→ Check that `isPublicPersona` is true
→ Check that the section is inside the Form

**ORCID not formatting**
→ Check that `OrcidInputField.swift` is in your project
→ Verify the String extension is available

**Email verification not sending**
→ Update the URL in `EmailVerificationService`
→ Check your backend is running

## Files You Need

Make sure these files are in your Xcode project:

1. ✅ `Persona.swift` (updated)
2. ✅ `PersonaCreationView.swift` (this file you're editing)
3. ✅ `PersonaCredentialsSection.swift` (new)
4. ✅ `OrcidInputField.swift` (new)
5. ✅ `EmailVerificationField.swift` (new)
6. ✅ `PersonaIdentityDisplayView.swift` (new)

## Optional: Display Updates

If you have a persona list or detail view, update them to use the new display components:

### List View
```swift
List(personas) { persona in
    NavigationLink {
        PersonaDetailView(persona: persona)
    } label: {
        PersonaIdentityCompactView(persona: persona)  // Use new component
    }
}
```

### Detail View
```swift
ScrollView {
    VStack {
        PersonaIdentityCardView(persona: persona)  // Use new component
        // ... other details
    }
}
```

## Migration for Existing Personas

If you already have personas in your database without the new fields, you'll need to handle migration:

```swift
// Add this helper function to PersonaCreationView or a migration file
private func migrateOldPersonas() {
    let oldPersonas = PersonaStore.shared.allPersonas
    
    for var persona in oldPersonas {
        // Add label if missing (derive from name or handle)
        if persona.label.isEmpty {
            persona.label = generateLabelFromName(persona.name)
        }
        
        // Initialize verification flags
        persona.emailVerified = false
        persona.orcidVerified = false
        
        // Save updated persona
        PersonaStore.shared.update(persona)
    }
}

private func generateLabelFromName(_ name: String) -> String {
    return name
        .lowercased()
        .replacingOccurrences(of: " ", with: ".")
        + ".451.info"
}
```

## Summary of Changes

| Change Type | Files Modified | Lines Changed |
|-------------|----------------|---------------|
| State Variables | PersonaCreationView.swift | +3 lines |
| Computed Property | PersonaCreationView.swift | +15 lines |
| Form Update | PersonaCreationView.swift | +10 lines |
| Server Request | PersonaCreationView.swift | +4 lines |
| Persona Creation | PersonaCreationView.swift | +4 lines |
| **Total** | **1 file** | **~36 lines** |

Plus 6 new files for components and documentation.

## Next Steps

1. ✅ Make these changes to PersonaCreationView.swift
2. ✅ Add all new Swift files to your Xcode project
3. ✅ Update your backend to accept new fields
4. ✅ Test persona creation flow
5. ✅ Test email verification flow
6. ✅ Test ORCID verification flow
7. ✅ Update display views to use new components
8. ✅ Deploy and celebrate! 🎉

---

**Need Help?**
- Check the Integration Guide for more context
- Review Persona Examples for usage patterns
- See Quick Reference for syntax reminders
