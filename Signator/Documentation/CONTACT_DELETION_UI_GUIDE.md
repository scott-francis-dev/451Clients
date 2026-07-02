# Contact Deletion UI Guide

## Visual Overview of Changes

### PersonaDirectoryPicker - Recent Section

#### Before:
```
┌────────────────────────────────────────┐
│  Recent                                │
├────────────────────────────────────────┤
│  Alice Smith                           │
│  alice@example.com                     │
├────────────────────────────────────────┤
│  Bob Johnson                           │
│  bob@test.com                          │
├────────────────────────────────────────┤
│  Charlie Davis                         │
│  charlie@old.com                       │
└────────────────────────────────────────┘
❌ No way to delete
```

#### After:
```
┌────────────────────────────────────────┐
│  Recent                    [Clear All] │ ← New "Clear All" button
├────────────────────────────────────────┤
│  Alice Smith                      🗑️   │ ← New trash icon
│  alice@example.com                     │
├────────────────────────────────────────┤
│  Bob Johnson                      🗑️   │
│  bob@test.com                          │
├────────────────────────────────────────┤
│  Charlie Davis                    🗑️   │
│  charlie@old.com                       │
└────────────────────────────────────────┘
✅ Three deletion methods available
```

## Deletion Methods

### Method 1: Tap Trash Icon
```
User sees:
┌────────────────────────────────────────┐
│  Bob Johnson                      🗑️   │ ← Tap here
│  bob@test.com                          │
└────────────────────────────────────────┘

Result: Contact immediately removed
```

### Method 2: Swipe to Delete
```
User swipes left:
┌────────────────────────────────────────┐
│  Bob Johnson              │  [Delete]  │ ← Swipe reveals Delete
│  bob@test.com             │            │
└────────────────────────────────────────┘

Tap Delete → Contact removed
```

### Method 3: Clear All
```
User taps "Clear All" in header:
┌────────────────────────────────────────┐
│  Recent                    [Clear All] │ ← Tap this
├────────────────────────────────────────┤
│  Alice Smith                      🗑️   │
│  alice@example.com                     │
├────────────────────────────────────────┤
│  Bob Johnson                      🗑️   │
│  bob@test.com                          │
└────────────────────────────────────────┘

Result: All contacts removed, section disappears
```

## Complete User Flow

### Accessing the Directory Picker

1. **From Contacts Tab:**
   ```
   Contacts Tab → [+] Button → "Add from Directory"
   ```

2. **From Signing Flow:**
   ```
   Initiate Tab → Select Recipients → "Add from Directory"
   ```

### Full Screen Layout

```
┌─────────────────────────────────────────────────┐
│  Add Contact                      [Cancel]      │ ← Navigation Bar
├─────────────────────────────────────────────────┤
│                                                 │
│  My Personas                                    │
│  ┌─────────────────────────────────────────┐   │
│  │  Alice's Personal                       │   │
│  │  alice.personal@example.com             │   │
│  └─────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────┐   │
│  │  Alice's Business                       │   │
│  │  alice.business@example.com             │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
│  Recent                          [Clear All]    │ ← New!
│  ┌─────────────────────────────────────┐       │
│  │  Bob Johnson                   🗑️   │       │ ← New!
│  │  bob@test.com                       │       │
│  └─────────────────────────────────────┘       │
│  ┌─────────────────────────────────────┐       │
│  │  Charlie Davis                 🗑️   │       │ ← New!
│  │  charlie@old.com                    │       │
│  └─────────────────────────────────────┘       │
│                                                 │
│  Search                                         │
│  ┌─────────────────────────────────────────┐   │
│  │  Search by @handle, DID...              │   │
│  └─────────────────────────────────────────┘   │
│  [Public] [All]                                 │
│                                                 │
│  (Search results appear here)                   │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Interaction Examples

### Example 1: Removing a Stale Test Contact

**Scenario:** User has a test persona "test@example.com" in Recent that's no longer needed.

**Steps:**
1. Open Contacts → [+] → "Add from Directory"
2. Scroll to "Recent" section
3. Find "test@example.com"
4. Tap the 🗑️ trash icon
5. ✅ Contact instantly disappears

**Alternative:**
- Swipe left on "test@example.com"
- Tap [Delete]
- ✅ Contact removed

### Example 2: Bulk Cleanup

**Scenario:** User has been testing and has 10+ stale entries in Recent.

**Steps:**
1. Open Contacts → [+] → "Add from Directory"
2. Scroll to "Recent" section
3. Tap "Clear All" button in section header
4. ✅ All recent contacts removed
5. ✅ Recent section disappears (empty)

### Example 3: Selective Cleanup

**Scenario:** User wants to keep some recent contacts but remove others.

**Steps:**
1. Open directory picker
2. For each unwanted contact:
   - Tap 🗑️ icon OR swipe left → Delete
3. ✅ Only desired contacts remain

## Design Decisions

### Why Three Deletion Methods?

1. **Trash Icon (Tap)**
   - Most obvious and discoverable
   - Always visible
   - Quick single action
   - Best for: Users unfamiliar with swipe gestures

2. **Swipe-to-Delete**
   - Native iOS pattern
   - Familiar to experienced users
   - Muscle memory from Mail, Messages, etc.
   - Best for: Power users, bulk deletions

3. **Clear All**
   - Fastest for bulk operations
   - Prevents repetitive actions
   - Clear intent and scope
   - Best for: Complete cleanup scenarios

### Styling Choices

- **Trash Icon:** Red color indicates destructive action
- **"Clear All" Button:** Red text, small font to avoid accidental taps
- **Button Placement:** Header area, separate from contact rows
- **Icon Choice:** Standard trash icon (system "trash" symbol)

## Accessibility

The implementation includes proper accessibility support:

1. **VoiceOver:** Each delete button is properly labeled
2. **Dynamic Type:** Text scales with system preferences
3. **Color Contrast:** Red deletion indicators meet WCAG standards
4. **Touch Targets:** Buttons are appropriately sized for easy tapping

## Edge Cases Handled

1. **Empty Recent List**
   - Section doesn't display when recent array is empty
   - No "Clear All" button shown
   - Graceful handling of zero state

2. **Single Item**
   - All deletion methods work with just one item
   - Section disappears after last item deleted

3. **Concurrent Deletions**
   - State updates properly synchronized
   - UserDefaults writes are atomic
   - No race conditions

4. **Persistence**
   - Deletions immediately saved to UserDefaults
   - Survives app restart
   - Proper encoding/decoding

## Platform Differences

### iOS/iPadOS
- Swipe-to-delete works as expected
- Trash icon buttons visible
- Section headers with Clear All button

### macOS (if applicable)
- Trash icons provide primary deletion method
- Right-click context menu could show Delete option
- Keyboard shortcuts possible (Delete key)

## Testing Checklist

- [ ] Tap trash icon removes contact
- [ ] Swipe left reveals delete button
- [ ] Swipe delete removes contact
- [ ] Clear All removes all contacts
- [ ] Recent section disappears when empty
- [ ] Deletions persist after app restart
- [ ] No crashes when deleting while list updates
- [ ] VoiceOver announces actions correctly
- [ ] Works in both light and dark mode
- [ ] Trash icons are properly aligned
- [ ] Button hit areas are adequate (44x44 pts minimum)

## Known Limitations

1. **No Undo**
   - Currently no way to restore accidentally deleted contacts
   - Could be added in future with undo toast/snackbar

2. **No Confirmation Dialog**
   - Clear All immediately removes all items
   - Consider adding confirmation for this action

3. **No Bulk Selection**
   - Can't select multiple items and delete at once
   - Would require edit mode with checkboxes

These are intentional trade-offs for simplicity and will be addressed in future iterations based on user feedback.
