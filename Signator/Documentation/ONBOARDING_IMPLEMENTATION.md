# Onboarding Implementation Guide

## Overview
I've created a complete onboarding flow for Signator that shows on first launch. The system includes:

1. **OnboardingView.swift** - Swipeable video walkthrough screens
2. **RootView.swift** - Navigation coordinator that manages the flow

## How It Works

### Flow Diagram
```
App Launch
    ↓
RootView checks hasCompletedOnboarding flag
    ↓
    ├─ NO → Show OnboardingView (4 video screens)
    │         ↓
    │         User completes onboarding
    │         ↓
    │         Sets hasCompletedOnboarding = true
    │         ↓
    ├─ YES → Check if personas exist
              ↓
              ├─ NO → Show PersonaCreationView
              │         ↓
              │         User creates persona
              │         ↓
              └─ YES → Show MainTabView (main app)
```

### Key Features

#### OnboardingView
- **Swipeable pages**: Users swipe left/right to navigate through 4 screens
- **Video players**: Each page shows a looping video
- **Skip button**: Users can skip onboarding at any time
- **Progress indicator**: Shows "1 of 4", "2 of 4", etc.
- **Get Started button**: On the last page, button says "Get Started" instead of "Next"
- **Persists state**: Uses @AppStorage to remember completion

#### RootView
- **Smart navigation**: Automatically shows the right screen based on state:
  - First launch → Onboarding
  - After onboarding, no personas → Persona Creation
  - Has personas → Main App
- **Manages PersonaManager**: Passes it down to child views

## Videos to Add

You mentioned you're adding 3 videos to the Resources folder. The current implementation expects 4 videos, but you can easily adjust this.

### Current Configuration (4 videos)
The onboarding expects these video files in your app bundle:
1. `onboarding1.mp4` - Welcome/intro screen
2. `onboarding2.mp4` - Create persona explanation
3. `onboarding3.mp4` - Document signing explanation
4. `onboarding4.mp4` - Data control/security explanation

### To Use 3 Videos Instead
Open `/repo/OnboardingView.swift` and modify the `pages` array around line 26 to have only 3 entries. For example:

```swift
private let pages: [OnboardingPage] = [
    OnboardingPage(
        id: 0,
        videoName: "onboarding1",
        title: "Welcome to Signator",
        description: "Your secure digital identity and document signing solution."
    ),
    OnboardingPage(
        id: 1,
        videoName: "onboarding2",
        title: "Create & Sign",
        description: "Build your decentralized identity and sign documents securely."
    ),
    OnboardingPage(
        id: 2,
        videoName: "onboarding3",
        title: "Control Your Data",
        description: "Your keys, your identity, your control."
    )
]
```

## Adding Videos to Your Project

1. **In Xcode**, select your project in the navigator
2. Right-click on your main folder → **Add Files to "Signator"...**
3. Select your three video files
4. Make sure **"Copy items if needed"** is checked
5. Make sure your target is selected in "Add to targets"
6. Click **Add**

### Video Naming
You can name your videos anything you want. Just update the `videoName` field in the `OnboardingPage` entries to match your actual filenames (without the .mp4 extension).

Example: If your videos are named:
- `intro.mp4`
- `features.mp4`  
- `security.mp4`

Then change the `videoName` values to `"intro"`, `"features"`, and `"security"`.

## Customization Options

### Change Colors/Styling
In `OnboardingView.swift`:
- **Background gradient** (line ~38): Adjust colors
- **Button color** (line ~87): Change `.background(Color.blue)` to your brand color
- **Skip button color** (line ~45): Change `.foregroundColor(.blue)`

### Change Text Content
In `OnboardingView.swift`, edit the `pages` array to customize:
- `title` - Main headline for each screen
- `description` - Supporting text below the title

### Video Player Settings
- Videos automatically **loop** when they finish
- Videos **auto-play** when the page appears
- Videos **pause** when user swipes to next page

## Testing the Onboarding

### Test First-Run Experience
1. Run the app in Simulator or on device
2. You should see the onboarding screens
3. Swipe through them or tap "Skip"
4. After completing, you'll see PersonaCreationView

### Test Again (Reset)
To see the onboarding again during development:
1. In Xcode, go to **Product** → **Scheme** → **Edit Scheme**
2. Under **Run** → **Arguments**, add a launch argument: `-hasCompletedOnboarding NO`

Or programmatically reset by deleting the UserDefaults key:
```swift
UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
```

### Test Without Videos (Fallback)
If videos aren't found, the app shows a gray placeholder with a slash icon. This prevents crashes if videos are missing.

## Files Modified/Created

### New Files
- `/repo/OnboardingView.swift` - Onboarding screens with video players
- `/repo/RootView.swift` - Navigation coordinator

### Existing Files (No Changes Needed)
- `SignatorApp.swift` - Already uses `RootView()` ✅
- `PersonaCreationView.swift` - Works as-is ✅
- `MainTabView.swift` - Works as-is ✅

## Next Steps

1. **Add your 3 video files** to the Xcode project (in Resources or main bundle)
2. **Update the `pages` array** in `OnboardingView.swift` to match your video count and filenames
3. **Customize titles and descriptions** to match your messaging
4. **Test the flow** by running the app
5. **Adjust colors/styling** to match your brand (optional)

## Architecture Notes

The implementation uses:
- **@AppStorage** - Persists onboarding completion across app launches
- **AVKit** - Native video playback with VideoPlayer
- **TabView with page style** - Native iOS swipe gesture and page indicators
- **Conditional navigation** - RootView decides what to show based on app state

This follows iOS best practices and provides a smooth, native-feeling experience.
