# Quick Reference: Updating Onboarding Videos

## Adding Your 3 Videos

### Step 1: Add Videos to Xcode
1. In Xcode, find your video files in Finder
2. Drag them into the Xcode project navigator
3. Or: Right-click project folder → "Add Files to Signator..."
4. ✅ Check "Copy items if needed"
5. ✅ Check your app target under "Add to targets"

### Step 2: Note Your Video Filenames
Example filenames:
- `intro.mp4`
- `signing.mp4`
- `security.mp4`

### Step 3: Update OnboardingView.swift

Find the `pages` array around **line 26** and change it to match your 3 videos:

```swift
private let pages: [OnboardingPage] = [
    OnboardingPage(
        id: 0,
        videoName: "intro",  // ← Your first video filename (no .mp4)
        title: "Welcome to Signator",
        description: "Your secure digital identity solution."
    ),
    OnboardingPage(
        id: 1,
        videoName: "signing",  // ← Your second video filename
        title: "Sign Documents",
        description: "Cryptographically sign documents with your secure identity."
    ),
    OnboardingPage(
        id: 2,
        videoName: "security",  // ← Your third video filename
        title: "Your Data, Your Control",
        description: "Everything is secured in your device's Secure Enclave."
    )
]
```

### Step 4: Update Page Counter (Optional)

If you want the counter to say "1 of 3" instead of "1 of 4", it will automatically update when you change the pages array. No extra work needed! ✨

### Step 5: Test

1. Run the app
2. Videos should play automatically on each page
3. Swipe left/right to navigate
4. Videos loop when they finish

## Troubleshooting

### Videos Don't Show
- ✅ Check that videos are in the Xcode project (not just in a folder)
- ✅ Check that videos are added to the target (select video → File Inspector → Target Membership)
- ✅ Check video filenames match exactly (case-sensitive, no .mp4 in code)
- ✅ Videos must be .mp4 format (H.264 codec works best)

### Videos Show but Don't Play
- Try a different video codec (H.264 is most compatible)
- Check that videos aren't corrupted
- Test videos in QuickTime Player first

### Onboarding Doesn't Show Again
- Kill and relaunch the app after resetting
- Use the OnboardingDebugHelpers.swift view to reset state
- Or delete and reinstall the app

## Video Specifications (Recommended)

- **Format**: MP4 (H.264 codec)
- **Resolution**: 1080p or 720p
- **Orientation**: Landscape or portrait (adjust frame height in code if needed)
- **Duration**: 10-30 seconds recommended (will loop)
- **File size**: Keep under 5MB each for best performance

## Customizing Video Display

### Change Video Size
In `OnboardingPageView` (line ~137), adjust the height:

```swift
.frame(height: 300)  // ← Change this number
```

### Stop Auto-play
Remove or comment out line ~152:
```swift
// player?.play()  // ← Comment this out
```

### Disable Looping
Remove the NotificationCenter observer block (lines ~154-161)

## Need Help?

Check the full documentation in `ONBOARDING_IMPLEMENTATION.md` for detailed information about the architecture and customization options.
