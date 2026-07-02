# Template Text Editor Implementation

## Overview
Added a text editor that appears after selecting a template, allowing users to edit the template content before proceeding to add signers.

## New Flow

### Before:
```
Template Selection → Participants/Metadata
```

### After:
```
Template Selection → Text Editor → Participants/Metadata
```

## What Was Added

### 1. Enhanced Template Structure
Each template now includes `initialContent`:

```swift
struct Template: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let initialContent: String // NEW: Default template content
}
```

**Three templates with real content:**
- **NDA** - Non-Disclosure Agreement
- **Employment Offer** - Job offer letter
- **Sales Contract** - Sales agreement

Each includes placeholder text like `[PARTY A NAME]`, `[DATE]`, etc. for users to fill in.

### 2. New TemplateEditorView

A full-featured text editor with:

#### Edit Mode
- `TextEditor` for editing document content
- Monospaced font for clear editing
- Full-screen editing area

#### Preview Mode
- Toggle between Edit and Preview
- Shows formatted document as it will appear
- Serif font for professional look

#### Features:
- **Preview Toggle**: Switch between editing and preview
- **Reset Button**: Restore original template content
- **Next Button**: Proceed to add signers (disabled if empty)
- **Auto-load**: Template content loads automatically

#### UI Layout:
```
┌────────────────────────────────────────┐
│  [NDA]                     [Cancel]    │ ← Navigation Bar
├────────────────────────────────────────┤
│  Edit Document    [👁️ Preview]         │ ← Toolbar
├────────────────────────────────────────┤
│                                        │
│  [TextEditor or Preview Area]          │
│                                        │
│  (Full height editing space)           │
│                                        │
│                                        │
├────────────────────────────────────────┤
│  [🔄 Reset]    [Next: Add Signers →]   │ ← Bottom Actions
└────────────────────────────────────────┘
```

### 3. Updated ParticipantsAndMetadataView

Now accepts optional `documentContent`:

```swift
struct ParticipantsAndMetadataView: View {
    var documentContent: String? = nil // NEW: Optional document content
    ...
}
```

**New Features:**
- Shows document preview section (collapsed, first 5 lines)
- Improved participant management (swipe to delete)
- Better email field configuration (keyboard type, autocapitalization)
- Centered "Review & Send" button

## Code Changes

### File Modified: `EnhancedSendSigningFlowView.swift`

#### 1. TemplateSelectionFlowView
- Added `initialContent` to Template struct
- Populated three templates with realistic content
- Changed navigation destination to `TemplateEditorView`

#### 2. New TemplateEditorView (Complete new view)
```swift
struct TemplateEditorView: View {
    let template: TemplateSelectionFlowView.Template
    let personaManager: PersonaManager
    @State private var documentText: String = ""
    @State private var showingPreview = false
    // ... implementation
}
```

#### 3. ParticipantsAndMetadataView
- Added optional `documentContent` parameter
- Added document preview section
- Improved participant list (with delete)
- Enhanced form styling

## User Experience

### Step 1: Select Template
User taps on a template (e.g., "NDA")

### Step 2: Edit Document
1. Document loads with template content
2. User can:
   - Edit the text directly
   - Replace placeholders like `[PARTY A NAME]`
   - Toggle to Preview mode to see formatted view
   - Reset if they make mistakes
3. Tap "Next: Add Signers" when ready

### Step 3: Add Participants
1. Document preview shown at top (first 5 lines)
2. Add metadata (title, message)
3. Configure signers
4. Review & Send

## Template Content Examples

### NDA Template
```
NON-DISCLOSURE AGREEMENT

This Non-Disclosure Agreement (the "Agreement") is entered 
into as of [DATE] by and between:

Party A: [PARTY A NAME]
Party B: [PARTY B NAME]
...
```

### Employment Offer Template
```
EMPLOYMENT OFFER LETTER

[DATE]

Dear [CANDIDATE NAME],

We are pleased to offer you the position of [JOB TITLE] 
at [COMPANY NAME].
...
```

### Sales Contract Template
```
SALES AGREEMENT

This Sales Agreement (the "Agreement") is made as of [DATE] 
between:

Seller: [SELLER NAME]
Buyer: [BUYER NAME]
...
```

## Features

### Edit Mode Features
- Full-screen text editing
- Monospaced font for precise editing
- Scroll support for long documents
- Standard iOS text editing gestures (select, copy, paste)

### Preview Mode Features
- Formatted document preview
- Serif font for professional appearance
- Read-only view
- Scroll support

### Toolbar Features
- **Edit/Preview Toggle**: Switch between modes
- **Reset Button**: Restore original template
- **Next Button**: Proceed to next step (disabled when empty)

## Technical Details

### State Management
```swift
@State private var documentText: String = ""
@State private var showingPreview = false
```

### Navigation
Uses SwiftUI NavigationLink to pass content forward:
```swift
NavigationLink {
    ParticipantsAndMetadataView(documentContent: documentText)
} label: {
    Label("Next: Add Signers", systemImage: "arrow.right")
}
```

### Validation
- "Next" button disabled if document is empty (after trimming whitespace)
- Prevents proceeding with blank documents

## Future Enhancements

Potential improvements for later:

1. **Rich Text Editing**
   - Bold, italic, underline
   - Font size control
   - Bullet points and numbering

2. **Smart Placeholders**
   - Highlight `[PLACEHOLDER]` fields
   - Jump between placeholders
   - Auto-complete from contacts

3. **Document Formatting**
   - Headers and footers
   - Page breaks
   - Margin controls

4. **Collaboration**
   - Track changes
   - Comments
   - Version history

5. **Export Options**
   - Export as PDF
   - Export as Word doc
   - Print preview

6. **Templates Library**
   - Save custom templates
   - Share templates
   - Template categories

7. **Validation**
   - Check for unfilled placeholders
   - Spell check
   - Grammar check

## Testing Scenarios

1. **Basic Editing**
   - Select template → Edit text → Preview → Next

2. **Reset Functionality**
   - Edit text → Reset → Verify original content restored

3. **Preview Toggle**
   - Edit mode → Preview mode → Edit mode
   - Verify text persists across toggles

4. **Empty Document Prevention**
   - Delete all text → Verify "Next" button disabled
   - Add text → Verify button enabled

5. **Long Documents**
   - Test scrolling in edit mode
   - Test scrolling in preview mode
   - Verify no content cut-off

6. **Navigation**
   - Complete flow through all screens
   - Verify document content passes to next screen
   - Test back navigation

## Known Limitations

1. **Plain Text Only**
   - No rich text formatting yet
   - No embedded images
   - No tables or complex layouts

2. **No Auto-Save**
   - Changes not saved if user navigates back
   - Consider adding later

3. **No Undo/Redo**
   - System undo may work, but not explicitly implemented
   - Consider custom undo stack

4. **No Search/Replace**
   - Manual editing only
   - Could add find/replace feature

These limitations are intentional for the initial "nothing fancy yet" implementation and can be addressed in future iterations.

## Summary

✅ Created text editor view after template selection
✅ Added three realistic template examples with content
✅ Implemented Edit/Preview toggle
✅ Added Reset functionality
✅ Integrated with existing participant flow
✅ Simple, clean UI focused on core editing

The template workflow is now complete and functional, with room for future enhancements!
