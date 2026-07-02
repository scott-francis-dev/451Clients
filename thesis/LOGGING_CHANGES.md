# Logging Changes Summary

## Overview
This document describes the logging changes made to reduce console noise while preserving important information.

## Changes Made

### 1. Added `verboseAutoSaveLogs` Flag

**Location:** `DraftEditorView.swift`

Added a private constant that controls detailed autosave logging:

```swift
private let verboseAutoSaveLogs = false  // Set to true to see detailed autosave logs
```

### 2. Conditional Logging

The following logs are now **only shown when `verboseAutoSaveLogs = true`**:

#### DraftEditorView.swift
- `🧵 DraftEditorView.onDisappear -> flushAndSaveCurrentPage()`
- `📄 Page change -> selectedPageIndex = X`
- `⏱️ scheduleAutosave at ...`
- `⏱️ scheduleAutosave firing -> autosave()`
- `⏱️ scheduleAutosave skipped ...`
- `⚠️ autosave: target page id not found`
- `📝 autosave: idx=X, attrLen=X, jsonBytes(before)=X`
- `✅ autosave: flushed jsonBytes(after)=X -> saving book...`
- `💾 autosave: save complete`
- `⚠️ flushAndSave: selectedPageIndex out of bounds`
- `🧼 flushAndSave: idx=X, attrLen=X, jsonBytes(before)=X`
- `🧼 flushAndSave: flushed jsonBytes(after)=X -> saving book...`
- `💾 flushAndSave: save complete`

#### Page.swift
- `🧾 Page.flush -> jsonBytes=X`

### 3. Always Visible Logs

These logs are **always shown** because they're important:

#### DraftsStore.swift
- `📦 DraftsStore.save -> wrote X bytes to filename.json` ✅ **This stays visible**

#### Error Logs (Always Visible)
- `❌ autosave: save failed ...`
- `❌ flushAndSave: save failed ...`
- `❌ Page.flush -> encode failed`

### 4. Activity Trigger Logs

**Location:** `ActivityManager.swift`

The activity trigger logs for "Nicely done!" are **always visible**:

```swift
🧪 triggerIfNeeded called. contains='true/false' len=X Δt=X.Xs
📣 startOrUpdatePraise. areActivitiesEnabled=true/false
🔄 Updating existing activity <UUID>
✅ Live Activity started id=<UUID>
❌ Live Activity request failed: <error>
⏱️ scheduleAutoEnd in X.Xs
ℹ️ endPraise: not active; nothing to end
🛑 Live Activity ended id=<UUID>
```

These logs help you track when the Live Activity is triggered as the user writes.

## How to Enable Verbose Logging

To see detailed autosave logs for debugging:

1. Open `DraftEditorView.swift`
2. Find the line: `private let verboseAutoSaveLogs = false`
3. Change it to: `private let verboseAutoSaveLogs = true`
4. Rebuild and run

## Result

With `verboseAutoSaveLogs = false` (default), you'll only see:
- ✅ `📦 DraftsStore.save -> wrote X bytes to filename.json` (important save confirmation)
- ✅ Activity trigger logs (🧪, 📣, ✅, 🛑, etc.)
- ✅ Error messages (❌)

This dramatically reduces console noise while keeping critical information visible.
