# Template Editor Visual Guide

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Start a New Request                          │
├─────────────────────────────────────────────────────────────────┤
│  📄 Sign existing document                                      │
│  📋 Choose from template                    ← USER SELECTS THIS │
│  ✓ Notarize/Verify an Event                                    │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│                        Templates                                │
├─────────────────────────────────────────────────────────────────┤
│  Choose a template                                              │
│  ┌──────────────────────────────────────────────────┐          │
│  │  NDA                                             │          │
│  │  Mutual Non-Disclosure Agreement                 │          │
│  └──────────────────────────────────────────────────┘          │
│  ┌──────────────────────────────────────────────────┐          │
│  │  Employment Offer                                │          │
│  │  Offer letter template                           │          │
│  └──────────────────────────────────────────────────┘          │
│  ┌──────────────────────────────────────────────────┐          │
│  │  Sales Contract                                  │          │
│  │  Standard sales agreement                        │          │
│  └──────────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  NDA                                          [Cancel]          │
├─────────────────────────────────────────────────────────────────┤
│  Edit Document                        [👁️ Preview]              │
├─────────────────────────────────────────────────────────────────┤
│  NON-DISCLOSURE AGREEMENT                                       │
│                                                                 │
│  This Non-Disclosure Agreement (the "Agreement")                │
│  is entered into as of [DATE] by and between:                   │
│                                                                 │
│  Party A: [PARTY A NAME]                                        │
│  Party B: [PARTY B NAME]                                        │
│                                                                 │
│  WHEREAS, the parties wish to explore a business                │
│  opportunity together and will need to disclose                 │
│  confidential information;                                      │
│                                                                 │
│  NOW, THEREFORE, the parties agree as follows:                  │
│                                                                 │
│  1. CONFIDENTIAL INFORMATION                                    │
│  "Confidential Information" means any information               │
│  disclosed by one party to the other...                         │
│                                                                 │
│  [User can scroll and edit this text]                           │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  [🔄 Reset]                      [Next: Add Signers →]          │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  Details & Signers                            [< Back]          │
├─────────────────────────────────────────────────────────────────┤
│  Document Preview                                               │
│  ┌──────────────────────────────────────────────────┐          │
│  │  NON-DISCLOSURE AGREEMENT                        │          │
│  │  This Non-Disclosure Agreement...                │          │
│  │  (First 5 lines shown)                           │          │
│  └──────────────────────────────────────────────────┘          │
│                                                                 │
│  Document Metadata                                              │
│  Title: [_________________]                                     │
│  Message: [_______________]                                     │
│                                                                 │
│  Participants / Signers                                         │
│  Name:  [Alice____________]                                     │
│  Email: [alice@example.com]                                     │
│  ───────────────────────────                                    │
│  Name:  [Bob______________]                                     │
│  Email: [bob@example.com__]                                     │
│  [+ Add Participant]                                            │
│                                                                 │
│  [📤 Review & Send]                                             │
└─────────────────────────────────────────────────────────────────┘
```

## Screen-by-Screen Details

### Screen 1: Template Selection

```
┌────────────────────────────────┐
│  Templates              [< Back]│
├────────────────────────────────┤
│                                │
│  Choose a template             │
│  ┌──────────────────────────┐ │
│  │ 📄 NDA              →    │ │
│  │ Mutual Non-Disclosure    │ │
│  │ Agreement                │ │
│  └──────────────────────────┘ │
│  ┌──────────────────────────┐ │
│  │ 📄 Employment Offer  →   │ │
│  │ Offer letter template    │ │
│  └──────────────────────────┘ │
│  ┌──────────────────────────┐ │
│  │ 📄 Sales Contract    →   │ │
│  │ Standard sales agreement │ │
│  └──────────────────────────┘ │
│                                │
└────────────────────────────────┘

User Action: Tap any template
```

### Screen 2: Text Editor (Edit Mode)

```
┌────────────────────────────────────┐
│  NDA                      [Cancel] │
├────────────────────────────────────┤
│  Edit Document      [👁️ Preview]   │ ← Toggle button
├────────────────────────────────────┤
│ ┌────────────────────────────────┐ │
│ │ NON-DISCLOSURE AGREEMENT       │ │
│ │                                │ │
│ │ This Non-Disclosure Agreement  │ │
│ │ (the "Agreement") is entered   │ │
│ │ into as of [DATE] by and       │ │
│ │ between:                       │ │
│ │                                │ │
│ │ Party A: [PARTY A NAME]     ← │ │ User edits
│ │ Party B: [PARTY B NAME]        │ │ placeholders
│ │                                │ │
│ │ WHEREAS, the parties wish...   │ │
│ │                                │ │
│ │ [Scrollable editing area]      │ │
│ │                                │ │
│ │ Signatures:                    │ │
│ │ _______________________        │ │
│ │ Party A                        │ │
│ └────────────────────────────────┘ │
│                                    │
├────────────────────────────────────┤
│  [🔄 Reset]    [Next: Add Signers →]│
└────────────────────────────────────┘

Features:
• Monospaced font for editing
• Full keyboard support
• Standard text editing (cut/copy/paste)
• Scrollable content
```

### Screen 2b: Text Editor (Preview Mode)

```
┌────────────────────────────────────┐
│  NDA                      [Cancel] │
├────────────────────────────────────┤
│  Edit Document      [✏️ Edit]      │ ← Toggle to edit
├────────────────────────────────────┤
│ ┌────────────────────────────────┐ │
│ │                                │ │
│ │   NON-DISCLOSURE AGREEMENT     │ │
│ │                                │ │
│ │ This Non-Disclosure Agreement  │ │
│ │ (the "Agreement") is entered   │ │
│ │ into as of March 15, 2025 by   │ │
│ │ and between:                   │ │
│ │                                │ │
│ │ Party A: Acme Corporation      │ │
│ │ Party B: TechCo Industries     │ │
│ │                                │ │
│ │ WHEREAS, the parties wish to   │ │
│ │ explore a business opportunity │ │
│ │ together and will need to      │ │
│ │ disclose confidential...       │ │
│ │                                │ │
│ │ [Scrollable preview]           │ │
│ │                                │ │
│ └────────────────────────────────┘ │
│                                    │
├────────────────────────────────────┤
│  [🔄 Reset]    [Next: Add Signers →]│
└────────────────────────────────────┘

Features:
• Serif font for professional look
• Read-only view
• Shows how document will appear
• Scrollable content
```

### Screen 3: Participants & Metadata

```
┌────────────────────────────────────┐
│  Details & Signers        [< Back] │
├────────────────────────────────────┤
│  Document Preview                  │
│  ┌──────────────────────────────┐ │
│  │ NON-DISCLOSURE AGREEMENT     │ │
│  │ This Non-Disclosure Agre...  │ │
│  │ (First 5 lines)              │ │
│  │ Full document will be        │ │
│  │ included when sent           │ │
│  └──────────────────────────────┘ │
│                                    │
│  Document Metadata                 │
│  Title                             │
│  ┌──────────────────────────────┐ │
│  │ Acme-TechCo NDA 2025         │ │
│  └──────────────────────────────┘ │
│  Message to recipients             │
│  ┌──────────────────────────────┐ │
│  │ Please review and sign       │ │
│  │ this NDA at your earliest... │ │
│  └──────────────────────────────┘ │
│                                    │
│  Participants / Signers            │
│  ┌──────────────────────────────┐ │
│  │ Name: John Smith             │ │
│  │ Email: john@acme.com         │ │
│  │ ─────────────────────────    │ │ ← Swipe to delete
│  │ Name: Jane Doe               │ │
│  │ Email: jane@techco.com       │ │
│  │ ─────────────────────────    │ │
│  └──────────────────────────────┘ │
│  [➕ Add Participant]              │
│                                    │
│  ┌──────────────────────────────┐ │
│  │    📤 Review & Send          │ │
│  └──────────────────────────────┘ │
└────────────────────────────────────┘
```

## Interaction Examples

### Example 1: Editing an NDA

**Step 1:** User selects "NDA" template
```
Template loads with:
Party A: [PARTY A NAME]
Party B: [PARTY B NAME]
```

**Step 2:** User edits placeholders
```
User changes:
[PARTY A NAME] → "Acme Corporation"
[PARTY B NAME] → "TechCo Industries"
[DATE] → "March 15, 2025"
[DURATION] → "2 years"
```

**Step 3:** User previews
```
Taps "Preview" button
Sees formatted document with actual values
```

**Step 4:** User proceeds
```
Taps "Next: Add Signers"
Moves to participant screen
```

### Example 2: Reset After Mistake

**Scenario:** User accidentally deletes important text

```
Step 1: User is editing
Step 2: Accidentally selects all and deletes
Step 3: Taps "Reset" button
Step 4: Original template content restored
Step 5: User can start editing again
```

### Example 3: Preview Toggle

```
Edit Mode:
┌──────────────────┐
│ Party A: [NAME]  │ ← Monospaced, editable
│ Party B: [NAME]  │
└──────────────────┘

[Tap Preview]

Preview Mode:
┌──────────────────┐
│ Party A: [NAME]  │ ← Serif font, read-only
│ Party B: [NAME]  │
└──────────────────┘

[Tap Edit]

Back to Edit Mode
```

## Button States

### Next Button States

**Enabled:**
```
[Next: Add Signers →]
• Blue/prominent styling
• Tappable
• User can proceed
```

**Disabled:**
```
[Next: Add Signers →]
• Gray/muted styling
• Not tappable
• Document is empty
```

### Reset Button
```
[🔄 Reset]
• Always enabled
• Bordered style
• Confirmation not required (can be added later)
```

### Preview/Edit Toggle
```
In Edit mode:    [👁️ Preview]
In Preview mode: [✏️ Edit]
• Always enabled
• Bordered style
• Toggles between modes
```

## Empty State Handling

### Empty Document
```
┌────────────────────────────────────┐
│  Edit Document      [👁️ Preview]   │
├────────────────────────────────────┤
│ ┌────────────────────────────────┐ │
│ │                                │ │
│ │ (Empty - text deleted)         │ │
│ │                                │ │
│ └────────────────────────────────┘ │
├────────────────────────────────────┤
│  [🔄 Reset]    [Next: Add Signers] │ ← Disabled
└────────────────────────────────────┘
```

## Platform-Specific Notes

### iOS
- TextEditor uses native iOS keyboard
- Swipe gestures work as expected
- Standard iOS text selection UI

### iPadOS
- Full keyboard support
- Split view compatible
- Larger editing area

### macOS (if applicable)
- Desktop keyboard shortcuts
- Mouse/trackpad selection
- Larger screen real estate

## Accessibility Features

✓ VoiceOver support for all buttons
✓ Dynamic Type scaling
✓ Sufficient color contrast
✓ Keyboard navigation
✓ Touch target sizes (44x44 minimum)

## Tips for Users

1. **Use Preview Mode** to check formatting before proceeding
2. **Reset Button** is your friend if you make mistakes
3. **Placeholders** in [brackets] are meant to be replaced
4. **Scroll** to see the entire document
5. **Take your time** editing - nothing is saved until you proceed
