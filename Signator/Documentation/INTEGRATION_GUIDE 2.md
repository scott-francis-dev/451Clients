# PersonaCreationView Integration Guide

## Quick Start: Adding ORCID and Email to PersonaCreationView

This guide shows how to integrate the new identity components into your existing `PersonaCreationView.swift`.

## Step 1: Add State Variables

Add these new `@State` variables to `PersonaCreationView`:

```swift
struct PersonaCreationView: View {
    // Existing state variables...
    @State private var name = ""
    @State private var publishingHouse = ""
    // ... etc
    
    // ADD THESE NEW STATE VARIABLES:
    @State private var label = ""              // Human-readable label
    @State private var orcid = ""              // Optional ORCID
    @State private var orcidVerified = false   // ORCID verification status
    @State private var emailVerified = false   // Email verification status
    
    // Note: publicEmail already exists in your code, so just add verification flag
    // ... rest of view
}
```

## Step 2: Update the Form

Add the credentials section after your existing identity section:

```swift
var body: some View {
    formContent
        // ... existing onChange handlers
}

private var formContent: some View {
    Form {
        // Existing sections...
        Section { /* visibility toggle */ }
        identitySection
        
        // ADD THIS NEW SECTION:
        if isPublicPersona {
            PersonaCredentialsSection(
                email: $publicEmail,
                emailVerified: $emailVerified,
                orcid: $orcid,
                orcidVerified: $orcidVerified,
                personaDID: fullDID  // or generatedDID if you have it
            )
        }
        
        privateFieldsSection  // existing section
        createButtonSection   // existing section
    }
}
```

## Step 3: Generate Label from Handle

The label should be derived from your existing `fullHandle` or `normalizedDID`. Add this computed property:

```swift
private var generatedLabel: String {
    // Remove the domain suffix to get clean label
    let handle = normalizedDID
    
    // If it's a custom domain, use the full handle
    if useCustomDomain {
        return handle
    }
    
    // Otherwise, strip the default domain
    if handle.hasSuffix("." + defaultDomain) {
        return String(handle.dropLast(defaultDomain.count + 1))
    }
    
    return handle
}
```

## Step 4: Update Persona Creation

When you create the persona in `handleCreatePersona()`, include the new fields:

```swift
private func handleCreatePersona() async {
    // ... existing setup code
    
    let persona = Persona(
        id: generatedDID,
        controller: generatedDID,
        name: name,
        label: generatedLabel,  // ADD THIS
        address: addressString,
        email: publicEmail.isEmpty ? nil : publicEmail,
        emailVerified: emailVerified,  // ADD THIS
        orcid: orcid.isEmpty ? nil : orcid,  // ADD THIS
        orcidVerified: orcidVerified,  // ADD THIS
        affiliations: publicAffiliations.isEmpty ? nil : publicAffiliations,
        socialLinks: socialMediaLinks.isEmpty ? nil : socialMediaLinks,
        publicKeyBase64: publicKeyBase64,
        storageEndpoints: nil,
        createdAt: ISO8601DateFormatter().string(from: Date()),
        visibility: isPublicPersona ? .public : .private
    )
    
    // ... rest of creation code
}
```

## Step 5: Update Server Payload

Update your `ServerPersonaCreationRequest` to include new fields:

```swift
private struct ServerPersonaCreationRequest: Encodable {
    let did: String
    let handle: String
    let label: String  // ADD THIS
    let name: String
    let attributes: [String: String]?
    let address: [String: String]?
    let email: String?  // existing
    let emailVerified: Bool?  // ADD THIS
    let orcid: String?  // ADD THIS
    let orcidVerified: Bool?  // ADD THIS
    let verified: Bool
    let isPublic: Bool?
    // ... rest of fields
}
```

## Step 6: Display Personas

When displaying personas in lists or detail views, use the new display components:

### List View
```swift
List(personas) { persona in
    NavigationLink {
        PersonaDetailView(persona: persona)
    } label: {
        PersonaIdentityCompactView(persona: persona)
    }
}
```

### Detail View
```swift
struct PersonaDetailView: View {
    let persona: Persona
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Full identity display
                PersonaIdentityCardView(persona: persona)
                    .padding()
                
                // Other persona details...
            }
        }
        .navigationTitle(persona.displayLabel)
    }
}
```

## Complete Example: Adding to Existing Code

Here's what the full integration looks like in your existing `PersonaCreationView`:

```swift
struct PersonaCreationView: View {
    // Existing variables
    @State private var name = ""
    @State private var publishingHouse = ""
    @State private var customDomain = ""
    @State private var didInput = ""
    @State private var publicEmail = ""
    
    // NEW: Add these
    @State private var orcid = ""
    @State private var orcidVerified = false
    @State private var emailVerified = false
    
    // ... all other existing state
    
    var body: some View {
        Form {
            // Visibility toggle section
            Section {
                Toggle(isOn: $isPublicPersona) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isPublicPersona ? "Public Persona" : "Private Persona")
                            .font(.headline)
                        Text(isPublicPersona ? "Use for publishing; can be anonymous." : "Use for contracts; requires full identity.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Identity section (existing)
            identitySection
            
            // NEW: Credentials section (only for public personas)
            if isPublicPersona {
                PersonaCredentialsSection(
                    email: $publicEmail,
                    emailVerified: $emailVerified,
                    orcid: $orcid,
                    orcidVerified: $orcidVerified,
                    personaDID: fullDID
                )
            }
            
            // Private fields section (existing)
            privateFieldsSection
            
            // Create button section (existing)
            createButtonSection
        }
        // ... existing modifiers
    }
    
    // NEW: Computed property for label
    private var generatedLabel: String {
        let handle = normalizedDID
        if useCustomDomain {
            return handle
        }
        if handle.hasSuffix("." + defaultDomain) {
            return String(handle.dropLast(defaultDomain.count + 1))
        }
        return handle
    }
    
    // Existing function - update it
    private func handleCreatePersona() async {
        // ... existing validation code
        
        let persona = Persona(
            id: generatedFullDID,
            controller: generatedFullDID,
            name: name,
            label: generatedLabel,  // NEW
            address: addressForServer,
            email: publicEmail.isEmpty ? nil : publicEmail,
            emailVerified: emailVerified,  // NEW
            orcid: orcid.isEmpty ? nil : orcid,  // NEW
            orcidVerified: orcidVerified,  // NEW
            affiliations: publicAffiliations.isEmpty ? nil : publicAffiliations,
            socialLinks: socialMediaLinks.isEmpty ? nil : socialMediaLinks,
            publicKeyBase64: publicKeyBase64,
            storageEndpoints: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            visibility: isPublicPersona ? .public : .private
        )
        
        // ... rest of creation code
    }
}
```

## What This Gives You

### For Users
1. **Optional ORCID field** - Only shown for public personas
2. **Auto-formatting** - ORCID formats as user types
3. **Validation** - Can't submit invalid ORCID format
4. **Verification** - Optional button to verify with ORCID API
5. **Email verification** - Send verification email, verify later
6. **Clear guidance** - Info button explains when to use each field

### For Display
1. **Proper hierarchy** - Label most prominent, DID subtle, ORCID medium
2. **Verification badges** - Visual indicators for verified credentials
3. **Flexible views** - List, card, and detail views available
4. **Credential display** - Shows all verified credentials with badges

### For Backend
1. **New fields** in persona model
2. **Verification tracking** - Separate flags for each credential
3. **Optional verification** - Users can verify now or later
4. **Format validation** - Invalid data never reaches server

## Testing Your Integration

1. **Create persona without credentials**
   - Should work exactly as before
   - No ORCID or email required

2. **Add email only**
   - Enter email
   - Send verification
   - Create persona
   - Verify later via email link

3. **Add ORCID only**
   - Enter ORCID (e.g., 0000-0002-1825-0097)
   - See auto-formatting
   - Verify with API
   - Create persona

4. **Add both**
   - Enter email and ORCID
   - Both show verification options
   - Can verify now or later
   - Create persona with both fields

5. **Test display**
   - View in persona list
   - View in detail view
   - Check credential badges appear
   - Verify hierarchy (label > orcid > did)

## Troubleshooting

### ORCID not formatting
- Check that `String.formatOrcidInput` extension is available
- Verify the `onChange` handler is connected to the binding

### Email verification not sending
- Check that `EmailVerificationService` is configured with your backend URL
- Verify network connectivity
- Check backend logs for errors

### Credentials not showing in display
- Ensure `PersonaIdentityDisplayView` is imported
- Check that persona model has the new fields
- Verify bindings are correct

### Validation not working
- Check regex patterns in validation functions
- Ensure validation is called before save
- Test with known valid values

## Next Steps

1. **Backend Integration**
   - Update API to accept new fields
   - Add database columns
   - Implement verification endpoints

2. **Email Verification Flow**
   - Set up email service (SendGrid, AWS SES, etc.)
   - Create verification token system
   - Handle deep links for verification

3. **ORCID Integration**
   - Test with real ORCID API
   - Handle rate limiting
   - Cache verification results

4. **UI Polish**
   - Add loading states
   - Add error handling
   - Add success animations
   - Test on different screen sizes
