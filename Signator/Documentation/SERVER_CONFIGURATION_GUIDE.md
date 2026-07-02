# Server Configuration Guide

## Overview

The app now supports configurable server URLs, making it easy to use ngrok during development to test on physical devices while running a local server.

## Files Modified

1. **ServerConfig.swift** - Enhanced with runtime configuration support
   - Added `setCustomServer(_:)` to set a custom URL
   - Added `isUsingCustomServer` to check if custom URL is active
   - Added `defaultURL` to get the build-time default
   - Configuration is persisted in UserDefaults

2. **WalletAPI.swift** - Fixed hardcoded localhost
   - Changed `serverBaseURL` from `let` to computed `var`
   - Now uses `ServerConfig.baseURL` instead of hardcoded value

3. **ServerSettingsView.swift** (NEW) - UI for server configuration
   - Toggle between default and custom server
   - Text field for entering custom URL (e.g., ngrok)
   - Shows current configuration
   - Save/reset functionality

4. **ServerIndicatorView.swift** (NEW) - Visual indicator (DEBUG only)
   - Shows orange banner when using custom server
   - Displays the current server URL
   - Only visible in DEBUG builds

5. **EditPersonaView.swift** - Added access to server settings
   - New toolbar button (DEBUG only) to open ServerSettingsView
   - Uses `#if DEBUG` to keep it out of production builds

## How to Use with ngrok

### Step 1: Start your local server
```bash
# Start your server on port 8080 (or whatever port you're using)
cd server
npm start
# or
./start-server.sh
```

### Step 2: Start ngrok
```bash
ngrok http 8080
```

This will give you output like:
```
Forwarding  https://abc123def456.ngrok-free.app -> http://localhost:8080
```

### Step 3: Configure the app

1. **Launch the app** on your iPhone (or simulator)

2. **Open Persona Settings**
   - Tap the persona button (person icon in toolbar)
   - This opens your persona/profile view

3. **Open Server Settings** (DEBUG builds only)
   - Tap the "..." menu or look for the server rack icon in the toolbar
   - This opens the Server Settings view

4. **Enter your ngrok URL**
   - Toggle "Use Custom Server" to ON
   - Paste your ngrok URL: `https://abc123def456.ngrok-free.app`
   - Tap "Save Configuration"

5. **Verify connection**
   - You should see an orange banner at the top of screens showing your custom server
   - This banner only appears in DEBUG builds

### Step 4: Test your app
The app will now connect to your local server through ngrok!

## Resetting to Default

To go back to the default server:
1. Open Server Settings
2. Tap "Reset to Default"
   - OR -
   Toggle "Use Custom Server" to OFF and save

## Production Builds

- The server settings UI is automatically hidden in production builds (`#if DEBUG`)
- The server indicator banner only shows in DEBUG builds
- Custom server URLs are stored in UserDefaults and will persist across app launches
- Production builds automatically use `https://the451project.org`

## Technical Details

### URL Validation
- URLs without a scheme automatically get `https://` prepended
- Whitespace is trimmed automatically
- Empty URLs reset to default

### Persistence
- Custom URLs are stored in UserDefaults key: `"customServerURL"`
- The setting persists across app launches
- Works on both simulator and physical devices

### All Network Requests Updated
The following now use `ServerConfig.baseURL`:
- PersonaCreationView (persona creation)
- EditPersonaView (persona updates)
- WalletAPI (document submission)
- DocumentSigningService
- ProductionSSEClient (SSE connections)
- PersonaResolver
- All other API calls throughout the app

## Troubleshooting

### App can't connect to ngrok URL
1. Make sure your server is running (`localhost:8080` responds)
2. Verify ngrok is running and shows the forwarding URL
3. Check that you copied the full HTTPS URL (not the HTTP one)
4. Try accessing the ngrok URL in Safari on your iPhone to verify it works

### ngrok "Visit Site" button appears
- This is normal for free ngrok accounts
- Just click "Visit Site" once in Safari to whitelist your IP
- Then the app should work

### Server indicator doesn't show
- The indicator only shows in DEBUG builds
- It only shows when a custom server is configured
- Make sure you saved the configuration

### Can't find Server Settings
- Server Settings is only available in DEBUG builds
- Look in the persona/profile view toolbar
- The icon looks like a server rack

## Example Workflow

```bash
# Terminal 1: Start local server
cd server && npm start

# Terminal 2: Start ngrok
ngrok http 8080

# Copy the https URL from ngrok output
# Example: https://abc123.ngrok-free.app

# In the app:
# 1. Tap persona button
# 2. Tap server settings (DEBUG only)
# 3. Toggle "Use Custom Server"
# 4. Paste: https://abc123.ngrok-free.app
# 5. Tap "Save Configuration"
# 6. You should see orange banner showing custom server

# Now test your app - all requests go through ngrok to your local server!
```

## Benefits

✅ Test on real iPhone hardware with local development server
✅ No need to deploy to staging for every test
✅ See server logs in real-time in your terminal
✅ Hot reload server changes without rebuilding the app
✅ Easy to switch between local, ngrok, and production servers
✅ Configuration persists across app launches
✅ Visual indicator shows which server you're using
✅ Automatically hidden in production builds

## Future Enhancements

Consider adding:
- Recent server URLs dropdown
- Server health check / ping test
- Quick switch between multiple saved servers
- Environment presets (dev, staging, production)
- QR code scanning for server URLs
