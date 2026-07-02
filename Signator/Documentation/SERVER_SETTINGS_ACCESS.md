# Server Settings Access Improvements

## Problem
Previously, the Server Settings configuration was only accessible from `EditPersonaView`, which meant:
- Users couldn't access server settings before creating their first persona
- If the ngrok URL changed, users with no persona had no way to update it
- This created a "chicken and egg" problem for development

## Solutions Implemented

### Solution 1: Added to "No Persona" State
When users tap the persona button but haven't created a persona yet, they now see:
- A toolbar button (in DEBUG builds) to access Server Settings
- A small server info display at the bottom with a "Change Server" button
- This allows server configuration before persona creation

**Location**: `MainTabView.swift` → `PersonaSheetView`

### Solution 2: New Settings Tab (Recommended)
Added a dedicated Settings tab to the main TabView:
- Always accessible, regardless of persona status
- Shows your current persona (or "Not Created" if none exists)
- Server Configuration section (DEBUG builds only)
- Current server display
- Version and build information

**Location**: `MainTabView.swift` → `SettingsListView`

## Usage

### For Development (ngrok)
1. Start your ngrok tunnel: `ngrok http 8080`
2. Copy the https URL (e.g., `https://abc123.ngrok.io`)
3. Open the app → Go to Settings tab → Server Configuration
4. Enter your ngrok URL and save
5. Now you can create or update personas using the new server

### For Testing Multiple Servers
The settings persist in `UserDefaults`, so you can easily switch between:
- Local development server (`http://127.0.0.1:8080`)
- ngrok tunnel
- Production server (when ready)

## Build Configuration
Server settings UI is only visible in DEBUG builds using `#if DEBUG` compilation conditions. This prevents users from accidentally changing servers in production.

## Files Modified
- `MainTabView.swift` - Added Settings tab and updated PersonaSheetView
- `ServerSettingsView.swift` - Already existed, now more accessible
- `ServerConfig.swift` - No changes needed (already supported custom servers)

## Benefits
✅ Server configuration accessible before persona creation
✅ Dedicated, discoverable Settings tab
✅ Server info visible at a glance
✅ Easy switching between development environments
✅ Still maintains server settings in EditPersonaView for convenience

