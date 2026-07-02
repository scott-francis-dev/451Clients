# Contact Deletion Feature Implementation

## Problem
Users reported that there are stale contacts shown in the "Recent" section when adding contacts via "Pick from Directory". These old entries couldn't be removed, leading to clutter and confusion.

## Solution Implemented

### 1. Enhanced PersonaDirectoryPicker.swift

Added comprehensive deletion functionality to the "Recent" section:

#### Features Added:

1. **Individual Delete Button**
   - Each recent contact now has a trash can icon button on the right side
   - Tapping the trash icon removes that specific contact immediately
   - Uses destructive role styling (red color) to indicate deletion

2. **Swipe-to-Delete**
   - Users can swipe left on any recent contact to reveal a delete button
   - Standard iOS gesture that users are familiar with
   - Uses `.onDelete(perform: deleteRecent)` modifier

3. **Clear All Button**
   - Added a "Clear All" button in the section header
   - Allows users to quickly remove all recent contacts at once
   - Useful for bulk cleanup of stale entries
   - Styled in red to match destructive action

### 2. Code Changes

**New Functions:**
```swift
private func removeRecent(_ profile: PersonaResolvedProfile) {
    recent.removeAll { $0.did.caseInsensitiveCompare(profile.did) == .orderedSame }
    if let data = try? JSONEncoder().encode(recent) {
        UserDefaults.standard.set(data, forKey: recentsKey)
    }
}

private func deleteRecent(at offsets: IndexSet) {
    recent.remove(atOffsets: offsets)
    if let data = try? JSONEncoder().encode(recent) {
        UserDefaults.standard.set(data, forKey: recentsKey)
    }
}

private func clearAllRecent() {
    recent.removeAll()
    UserDefaults.standard.removeObject(forKey: recentsKey)
}
```

**Updated UI:**
```swift
Section {
    ForEach(recent, id: \.id) { r in
        HStack {
            Button { pick(r) } label: {
                VStack(alignment: .leading) {
                    Text(r.displayName).font(.headline)
                    Text(r.did).font(.caption).foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(role: .destructive) {
                removeRecent(r)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
    }
    .onDelete(perform: deleteRecent)
} header: {
    HStack {
        Text("Recent")
        Spacer()
        Button("Clear All") {
            clearAllRecent()
        }
        .font(.caption)
        .foregroundColor(.red)
    }
}
```

## User Experience

### Before:
- Recent contacts accumulated over time
- No way to remove stale entries
- Confusing list of old, possibly incorrect contacts
- Had to scroll through irrelevant entries

### After:
- **Three ways to delete contacts:**
  1. Tap the trash icon next to any contact
  2. Swipe left on a contact and tap Delete
  3. Tap "Clear All" to remove all recent contacts at once

- Clean, manageable list of recent contacts
- Users have full control over their recent picks
- Less clutter and confusion

## Additional Notes

### Existing Deletion Features
The app already had deletion support in other areas:

1. **CollaboratorsListView (Manage Mode)**
   - Already supports both swipe-to-delete and trash button
   - Used in the "Contacts" tab
   - Manages the persistent contacts list (not just recent picks)

2. **ContactsView**
   - Uses CollaboratorsListView in `.manage` mode
   - Already had deletion capabilities for saved contacts

### Why This Was Needed
The "Recent" picks in PersonaDirectoryPicker were stored separately from the main contacts list and served as a quick-access feature. However, this list could become outdated when:
- Testing with temporary personas
- Working with different projects/contexts
- Personas being deleted or changed
- Accidentally selecting wrong contacts

## Testing Scenarios

1. **Delete Individual Recent Contact:**
   - Go to Contacts tab → Add (+) → Add from Directory
   - See Recent section with contacts
   - Tap trash icon next to a contact
   - Verify contact is removed

2. **Swipe to Delete:**
   - Go to the same screen
   - Swipe left on a recent contact
   - Tap Delete button
   - Verify contact is removed

3. **Clear All:**
   - Go to the same screen
   - Tap "Clear All" in Recent section header
   - Verify all recent contacts are removed
   - Verify the Recent section disappears (since it only shows when not empty)

4. **Persistence:**
   - Delete some contacts
   - Close the app completely
   - Reopen the app
   - Verify deleted contacts remain deleted

## Files Modified

- **PersonaDirectoryPicker.swift**
  - Added delete functionality to Recent section
  - Added Clear All button
  - Added helper functions for deletion

## Related Features

- CollaboratorsStore: Manages the main contacts list
- CollaboratorsListView: Displays and manages saved contacts (already had delete)
- PersonaDirectoryPicker: Quick picker with search and recent picks (now has delete)

## Future Enhancements

Potential improvements for the future:
1. Confirmation dialog for "Clear All" action
2. Undo functionality for accidental deletions
3. Export/import contacts feature
4. Merge duplicate contacts automatically
5. Show timestamp of when contact was last used
6. Search/filter within Recent section if list grows large
