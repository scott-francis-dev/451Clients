# Persona Handle Card - The Signator Calling Card

## Overview

The **Persona Handle Card** is the consistent visual identity component for displaying persona handles throughout the 451Wallet app. It uses the "blue sphere" (Liquid Glass) design to create a recognizable signature that users associate with their digital identity.

## Why This Matters

**Consistency is Trust**: Just like a business card or signature, the Persona Handle Card creates visual consistency that helps users:
- ✅ Instantly recognize their persona
- ✅ Build trust through familiar design
- ✅ Understand the context (signing, viewing, selecting)
- ✅ Differentiate between public and private personas

## Components

### 1. `PersonaHandleCard` - Simple Handle Display

Use when you just need to show the handle (no name, no DID).

```swift
PersonaHandleCard(
    handle: "sara.silver.silver.publishing.451.info",
    isPublic: true,
    size: .standard,
    showCopyButton: true
)
```

**Sizes:**
- `.compact` - For lists, small spaces (12pt padding)
- `.standard` - Default size (16pt padding)
- `.prominent` - Large, for signing/verification (20pt padding)

### 2. `PersonaHandleDetailCard` - Full Persona Display

Use when you need to show name, handle, and DID together.

```swift
PersonaHandleDetailCard(
    persona: myPersona,
    size: .prominent,
    showDID: true,
    showCopyButton: true
)
```

## Handle Construction Rules

Handles are constructed from user input:

### Format: `[name].[publishing.house].451.info`

**Name Examples:**
- `Ron John Flabber Egassi III` → `ron.john.flabber.egassi.iii`
- `Sara Silver` → `sara.silver`
- `John` → `john`

**Publishing House Examples:**
- `Flabber Egassi Design Studio` → `flabber.egassi.design.studio`
- `Silver Publishing` → `silver.publishing`
- `McMillan` → `mcmillan`

**Full Handle Examples:**
- `ron.john.flabber.egassi.iii.flabber.egassi.design.studio.451.info`
- `sara.silver.silver.publishing.451.info`
- `john.mcmillan.451.info`

### Normalization Rules (from PersonaCreationView):
```swift
private func normalizePart(_ s: String) -> String {
    let normalized = s.trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
        .replacingOccurrences(of: " ", with: ".")
    // Collapse multiple periods into a single period
    return normalized.replacingOccurrences(of: "\\.+", with: ".", options: .regularExpression)
}
```

## Where to Use

Use the Persona Handle Card **everywhere** a persona handle is displayed:

### ✅ Currently Implemented:
- [x] Persona creation success sheet
- [x] PersonaManagerView (My Personas list)
- [x] PersonaListView (detailed persona list)

### 📋 Should Be Used In:

#### Document Signing
- [ ] SendSigningFlowView - When selecting signer persona
- [ ] MultiPartySigningView - Showing all signers
- [ ] Document signature display - After signing

#### Persona Selection
- [ ] PersonaDirectoryPicker - Selecting from multiple personas
- [ ] Colleague persona display
- [ ] Contact cards

#### Identity Verification
- [ ] Login/authentication screens
- [ ] Signature verification views
- [ ] Document ownership display

#### Settings & Management
- [ ] Persona edit views
- [ ] Active persona indicator
- [ ] Persona switching UI

## Visual Characteristics

### Liquid Glass Effect (iOS 26+)
- Blurs content behind the card
- Reflects ambient colors
- Interactive (responds to touch)
- Blue tint for public personas
- Purple tint for private personas

### Fallback (iOS < 26)
- Ultra-thin material background
- Color overlay (blue/purple)
- Subtle border and shadow
- Maintains the same visual hierarchy

## Color Coding

| Persona Type | Color  | Meaning |
|-------------|--------|---------|
| Public      | Blue   | Visible, searchable, for publishing |
| Private     | Purple | Anonymous, for contracts only |

## Examples

### Document Signing View
```swift
// Show who is signing the document
VStack(alignment: .leading, spacing: 12) {
    Text("Sign as:")
        .font(.headline)
    
    PersonaHandleDetailCard(
        persona: selectedPersona,
        size: .prominent,
        showDID: true,
        showCopyButton: false
    )
    
    Button("Sign Document") {
        // Signing logic
    }
}
```

### Persona Selection List
```swift
List(personas) { persona in
    Button {
        selectedPersona = persona
    } label: {
        PersonaHandleDetailCard(
            persona: persona,
            size: .compact,
            showDID: false,
            showCopyButton: false
        )
    }
}
```

### Signature Verification
```swift
VStack(alignment: .leading, spacing: 8) {
    Text("Signed by:")
        .font(.subheadline)
        .foregroundColor(.secondary)
    
    PersonaHandleCard(
        handle: document.signerHandle,
        isPublic: true,
        size: .standard,
        showCopyButton: true
    )
}
```

## Implementation Checklist

When adding persona display to a new view:

1. Import the component (it's in `PersonaHandleCard.swift`)
2. Replace any custom persona display code
3. Choose the appropriate size:
   - **Compact**: Lists, small spaces
   - **Standard**: Default, most common
   - **Prominent**: Signing, verification, emphasis
4. Decide if DID should be shown (technical reference)
5. Decide if copy button is needed (user convenience)
6. Test with both public and private personas
7. Verify color coding (blue vs purple)

## Benefits

✅ **Consistency**: Same visual across the entire app  
✅ **Recognition**: Users learn to identify their persona  
✅ **Trust**: Professional, polished appearance  
✅ **Accessibility**: Clear hierarchy, proper contrast  
✅ **Maintainability**: One component, update everywhere  

## Future Enhancements

Potential improvements:
- [ ] Animation on selection
- [ ] Hover states (macOS/iPadOS)
- [ ] QR code generation for sharing
- [ ] NFC card integration
- [ ] Custom color themes
- [ ] Avatar/icon support
