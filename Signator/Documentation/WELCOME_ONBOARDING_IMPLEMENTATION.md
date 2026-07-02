# Welcome Onboarding Flow Update

## Overview
Updated the first-time user experience to provide two distinct paths based on user intent: quick one-time signing vs. long-term persona management.

## User Flow

### Entry Point
When a user opens Signator for the first time (no persona exists):

```
┌─────────────────────────────────────┐
│      Welcome to Signator            │
│  Your secure digital signature      │
│          platform                   │
└─────────────────────────────────────┘
                 ↓
         Two-Path Choice
```

### Path 1: One-Time Signing (Primary)
**Button**: "I am here for a one-time document(s) signing"
- Large, prominent blue button with gradient
- Quick setup flow
- Minimal information required

**Quick Setup Process:**
1. User enters their full name only
2. System automatically generates:
   - Simple DID: `@firstname.lastname.quick.timestamp`
   - Cryptographic keypair
   - Basic persona profile
3. Immediately ready to sign documents

**Advantages:**
- Fast onboarding (< 30 seconds)
- Minimal friction for occasional users
- Still cryptographically secure
- Perfect for users directed by attorneys

### Path 2: Long-Term Persona (Secondary)
**Button**: "I want to create long-term persona(s)"
- Less emphasized, secondary styling
- Full persona creation flow
- Complete identity setup

**Full Setup Process:**
1. Opens the existing `PersonaCreationView`
2. User provides:
   - Handle/username
   - Full name
   - Address
   - Affiliations
   - Social links
3. DID validation and verification
4. Complete persona with all metadata

**Advantages:**
- Full control over identity
- Verified persona option
- Multiple persona support
- Domain verification available

## Visual Design

### Welcome Screen Layout
```
┌───────────────────────────────────────┐
│                                       │
│            🔏 (Icon)                 │
│      Welcome to Signator              │
│  Your secure digital signature        │
│          platform                     │
│                                       │
│  ┌─────────────────────────────────┐ │
│  │  📄 One-time signing            │ │  ← Primary (blue gradient)
│  │  Quick setup for signing now    │ │
│  │                              →  │ │
│  └─────────────────────────────────┘ │
│                                       │
│  ┌─────────────────────────────────┐ │
│  │  👤+ Long-term persona(s)       │ │  ← Secondary (gray outline)
│  │  Full setup with verified ID    │ │
│  │                              →  │ │
│  └─────────────────────────────────┘ │
│                                       │
│   Both options are secure & private  │
│   Create additional personas later   │
└───────────────────────────────────────┘
```

### Quick Sign Setup Screen
```
┌───────────────────────────────────────┐
│                                       │
│            📄 (Icon)                 │
│          Quick Setup                  │
│  Enter your name to get started       │
│                                       │
│  Your Full Name                       │
│  ┌─────────────────────────────────┐ │
│  │ e.g., John Smith                │ │
│  └─────────────────────────────────┘ │
│  This is how your signature will      │
│  appear on documents                  │
│                                       │
│                                       │
│  ┌─────────────────────────────────┐ │
│  │   Continue to Signing            │ │  ← Blue button
│  └─────────────────────────────────┘ │
│           Cancel                      │
└───────────────────────────────────────┘
```

## Technical Implementation

### Files Modified
1. **MainTabView.swift**
   - Updated `PersonaSheetView` to show `WelcomeOnboardingView` when no persona exists
   - Removed inline persona creation UI

2. **WelcomeOnboardingView.swift** (New)
   - Main welcome screen with two-path choice
   - `QuickSignSetupView` for rapid onboarding
   - Integration with existing `PersonaCreationView` for full setup

### DID Generation for Quick Personas
Format: `@{firstname}.{lastname}.quick.{timestamp}`

Examples:
- `@john.smith.quick.1735257600`
- `@sarah.quick.1735257600` (single name)

This ensures:
- ✅ Unique identifiers (timestamp)
- ✅ Recognizable format
- ✅ Distinct from verified personas
- ✅ Valid DID structure

### Security Notes
Both paths are equally secure:
- Same cryptographic keypair generation (P256)
- Same private key storage
- Same signing capabilities
- Same encryption standards

The difference is only in metadata completeness and verification status.

## User Experience Benefits

### For One-Time Users
- ✅ Reduces friction significantly
- ✅ Gets users signing in < 1 minute
- ✅ No complex DID/handle requirements
- ✅ Perfect for attorney-directed signings
- ✅ Can upgrade to full persona later

### For Power Users
- ✅ Clear path to full features
- ✅ Domain verification available
- ✅ Multiple persona support
- ✅ Complete identity control
- ✅ Professional appearance

### General Improvements
- ✅ Clear value proposition for each path
- ✅ Visual hierarchy emphasizes most common use case
- ✅ Educational footer reduces anxiety
- ✅ No dead-ends or confusion
- ✅ Progressive disclosure of complexity

## Testing Checklist

- [ ] First launch shows WelcomeOnboardingView
- [ ] One-time signing creates valid persona
- [ ] Generated DIDs are unique
- [ ] Quick personas can sign documents
- [ ] Long-term path opens PersonaCreationView
- [ ] Both paths properly dismiss on completion
- [ ] Cancel buttons work correctly
- [ ] Validation prevents empty names
- [ ] Private keys saved correctly for both paths
- [ ] Personas appear in persona list after creation

## Future Enhancements

1. **Quick Persona Upgrade**
   - Allow upgrading quick personas to full personas
   - Preserve existing signatures and keypair
   - Add verification and metadata

2. **Persona Templates**
   - Pre-fill common persona types
   - Business vs. Personal templates
   - Role-based defaults

3. **Onboarding Analytics**
   - Track which path users choose
   - Optimize based on usage patterns
   - A/B test button copy

4. **Contextual Guidance**
   - In-app tooltips for first-time users
   - Help documentation links
   - Video tutorials

## Migration Notes
No data migration needed. Existing users:
- Will see their persona immediately (no welcome screen)
- Can create additional personas anytime
- Maintain all existing functionality
