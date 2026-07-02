# Persona Creation Flow - Complete Navigation Path

## Overview
The persona creation process now follows a logical, multi-step flow that guides users through:
1. Public vs Private decision
2. Purpose selection (what they'll use it for)
3. Identity method (domain or publishing house)
4. Final persona creation

## Navigation Flow

```
WelcomeOnboardingView
    ↓
    [User chooses "Create long-term persona"]
    ↓
PublicOrPrivateSelectionView
    ├─ Public Persona (discoverable, listed in directories)
    └─ Private Persona (not listed, share via codes only)
        ↓
PersonaPurposeSelectionView
    ├─ Publishing Content (authors, creators)
    ├─ Attorney/Agency (legal professionals)
    └─ Auditor/Compliance (oversight)
        ↓
IdentityMethodSelectionView
    ├─ I have my own domain (DNS verification)
    ├─ I don't have a domain (publishing house)
    └─ One-time signing ceremony (only for private)
        ↓
PersonaCreationView
    (Final form with all context)
```

## New Files Created

### 1. `PersonaPurposeSelectionView.swift`
**Purpose:** Asks user what they'll primarily use the persona for

**Three Options:**
1. **Publishing Content**
   - Icon: `doc.text.fill`
   - Color: Blue
   - For: Authors, content creators, individuals
   - Features: Sign documents, establish authorship, build identity

2. **Attorney or Agency Persona**
   - Icon: `briefcase.fill`
   - Color: Purple
   - For: Legal professionals, agencies
   - Features: Execute legal docs, maintain credentials, represent clients

3. **Auditor/Compliance Representative**
   - Icon: `checkmark.seal.fill`
   - Color: Green
   - For: Auditors, compliance officers
   - Features: Verify chains, ensure compliance, provide oversight

**Key Type:**
```swift
enum PersonaPurpose: String, CaseIterable {
    case publishing = "publishing"
    case legal = "legal"
    case compliance = "compliance"
    
    var title: String { /* ... */ }
    var subtitle: String { /* ... */ }
    var systemImage: String { /* ... */ }
    var color: Color { /* ... */ }
    var detailedDescription: String { /* ... */ }
}
```

### 2. `PublicOrPrivateSelectionView.swift`
**Purpose:** Determines persona visibility

**Two Options:**
1. **Public Persona**
   - Icon: `globe`
   - Discoverable by others
   - Listed in directories
   - Verifiable by anyone

2. **Private Persona**
   - Icon: `lock.shield.fill`
   - Not listed publicly
   - Share via codes only
   - More privacy-focused

## Updated Files

### `IdentityMethodSelectionView.swift`
**Changes:**
- Now accepts `personaPurpose: PersonaPurpose` parameter
- Shows purpose context at top of view
- Displays purpose icon, color, and title
- User can see what they're creating the persona for

**New Context Card:**
```swift
HStack(spacing: 12) {
    Image(systemName: personaPurpose.systemImage)
        .font(.system(size: 20))
        .foregroundColor(personaPurpose.color)
    
    VStack(alignment: .leading, spacing: 2) {
        Text("Creating persona for:")
            .font(.caption)
        Text(personaPurpose.title)
            .font(.subheadline)
            .fontWeight(.medium)
    }
}
```

### `WelcomeOnboardingView.swift`
**Changes:**
- Updated full persona creation sheet to start with `PublicOrPrivateSelectionView`
- Removed direct navigation to `PersonaCreationView`
- Now follows the complete flow

## User Experience Benefits

1. **Clearer Intent**: Users understand what they're creating before diving into details
2. **Better Guidance**: Purpose-specific messaging helps users make informed decisions
3. **Contextual Help**: Each step shows relevant information for that stage
4. **Flexibility**: Users can go back and change choices at any time
5. **Progressive Disclosure**: Information revealed step-by-step, not overwhelming

## Visual Design

Each selection screen features:
- **Large, colorful icons** for visual clarity
- **Descriptive titles and subtitles** for context
- **Detailed descriptions** when needed
- **Consistent button styling** throughout
- **Clear navigation indicators** (chevrons, back buttons)

## Integration Points

The purpose is carried through the entire flow and can be used to:
- Customize the creation form
- Set default values
- Provide contextual help
- Filter available options
- Guide template selection

## Next Steps

Consider using the `PersonaPurpose` to:
1. Pre-fill suggested affiliations based on purpose
2. Recommend specific identity verification methods
3. Customize the final persona profile fields
4. Suggest relevant templates or workflows
5. Show purpose-specific onboarding tips

## Code Example: Using Purpose in Creation

```swift
PersonaCreationView(
    personaManager: personaManager,
    onCreate: { created in
        // Handle based on purpose
        switch personaPurpose {
        case .publishing:
            // Show content creation tips
        case .legal:
            // Show legal compliance checklist
        case .compliance:
            // Show audit trail features
        }
    },
    initialIsPublicPersona: isPublicPersona,
    initialUseCustomDomain: selectedUseCustomDomain,
    personaPurpose: personaPurpose  // Pass it through!
)
```
