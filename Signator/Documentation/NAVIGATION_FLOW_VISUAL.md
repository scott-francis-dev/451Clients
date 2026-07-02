# App Navigation Flow - Visual Guide

## Complete User Journey

```
┌─────────────────────────────────────────────────────────────────┐
│                         App Launch                              │
│                             ↓                                    │
│                        RootView                                  │
│                (Navigation Coordinator)                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                ┌─────────────┴──────────────┐
                │                            │
        hasCompletedOnboarding?              │
                │                            │
        ┌───────┴───────┐                    │
        │               │                    │
      ❌ NO           ✅ YES                 │
        │               │                    │
        ↓               ↓                    │
┌──────────────┐  ┌──────────────┐          │
│ Onboarding   │  │ Check if     │          │
│ View         │  │ personas     │          │
│              │  │ exist        │          │
│ [4 screens]  │  └──────┬───────┘          │
│ [swipeable]  │         │                  │
└──────┬───────┘         │                  │
       │         ┌───────┴────────┐         │
       │         │                │         │
       │    personas.isEmpty?     │         │
       │         │                │         │
       │   ┌─────┴─────┐          │         │
       │   │           │          │         │
       │ ✅ YES      ❌ NO        │         │
       │   │           │          │         │
       ↓   ↓           ↓          │         │
   ┌────────────┐  ┌────────┐    │         │
   │  Persona   │  │  Main  │    │         │
   │  Creation  │  │  Tab   │    │         │
   │   View     │  │  View  │    │         │
   └─────┬──────┘  └────────┘    │         │
         │              ↑         │         │
         └──────────────┘         │         │
                                  │         │
                                  └─────────┘
```

## Screen-by-Screen Breakdown

### 🎬 Onboarding Screens (First Launch Only)

```
╔═══════════════════════════════════════════╗
║           OnboardingView.swift            ║
╠═══════════════════════════════════════════╣
║                                           ║
║  ┌─────────────────────────────┐ [Skip]  ║
║  │                             │          ║
║  │      🎥 Video Player        │          ║
║  │    (auto-play, loops)       │          ║
║  │                             │          ║
║  └─────────────────────────────┘          ║
║                                           ║
║        Welcome to Signator                ║
║                                           ║
║   Your secure digital identity and        ║
║   document signing solution.              ║
║                                           ║
║                                           ║
║             ●  ○  ○  ○                    ║
║            1 of 4                         ║
║                                           ║
║     ┌──────────────────────────┐          ║
║     │         Next             │          ║
║     └──────────────────────────┘          ║
║                                           ║
╚═══════════════════════════════════════════╝

         ← Swipe left/right →

╔═══════════════════════════════════════════╗
║              Screen 2                     ║
║  [Video + "Create Your Persona"]          ║
║           ○  ●  ○  ○                      ║
╚═══════════════════════════════════════════╝

╔═══════════════════════════════════════════╗
║              Screen 3                     ║
║  [Video + "Sign Documents"]               ║
║           ○  ○  ●  ○                      ║
╚═══════════════════════════════════════════╝

╔═══════════════════════════════════════════╗
║              Screen 4                     ║
║  [Video + "Control Your Data"]            ║
║           ○  ○  ○  ●                      ║
║     ┌──────────────────────────┐          ║
║     │     Get Started  🟢      │          ║
║     └──────────────────────────┘          ║
╚═══════════════════════════════════════════╝
```

### 👤 Persona Creation Screen

```
╔═══════════════════════════════════════════╗
║      PersonaCreationView.swift            ║
╠═══════════════════════════════════════════╣
║                                           ║
║  Create Your Digital Identity             ║
║                                           ║
║  ┌─────────────────────────────┐          ║
║  │ Name:                       │          ║
║  └─────────────────────────────┘          ║
║                                           ║
║  ┌─────────────────────────────┐          ║
║  │ Publishing House:           │          ║
║  └─────────────────────────────┘          ║
║                                           ║
║  [ ] Public   [✓] Private                 ║
║                                           ║
║  ... more fields ...                      ║
║                                           ║
║     ┌──────────────────────────┐          ║
║     │    Create Persona        │          ║
║     └──────────────────────────┘          ║
║                                           ║
╚═══════════════════════════════════════════╝
```

### 🏠 Main App (Tab View)

```
╔═══════════════════════════════════════════╗
║         MainTabView.swift                 ║
╠═══════════════════════════════════════════╣
║                                           ║
║         [Tab Content Area]                ║
║                                           ║
║                                           ║
║                                           ║
║                                           ║
╠═══════════════════════════════════════════╣
║  📝 Sign  ✉️ Initiate  👥 Contacts ⚙️ Settings  ║
╚═══════════════════════════════════════════╝
```

## State Management

### Key State Variables

```swift
// Persisted across app launches
@AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

// In-memory state
@StateObject var personaManager = PersonaManager.shared
```

### State Transitions

```
Initial State:
├─ hasCompletedOnboarding = false
├─ personaManager.personas = []
└─ Shows: OnboardingView

After Onboarding:
├─ hasCompletedOnboarding = true
├─ personaManager.personas = []
└─ Shows: PersonaCreationView

After Persona Creation:
├─ hasCompletedOnboarding = true
├─ personaManager.personas = [persona1]
└─ Shows: MainTabView

Subsequent Launches:
├─ hasCompletedOnboarding = true (persisted)
├─ personaManager.personas = [persona1] (loaded)
└─ Shows: MainTabView (skips onboarding)
```

## User Interactions

### Onboarding Screen Actions

| Action | Result |
|--------|--------|
| Swipe left | Go to next page |
| Swipe right | Go to previous page |
| Tap "Skip" | Complete onboarding → Show persona creation |
| Tap "Next" | Animate to next page |
| Tap "Get Started" | Complete onboarding → Show persona creation |

### Haptic Feedback

| Trigger | Haptic Type |
|---------|-------------|
| Swipe to new page | Light impact |
| Tap "Next" button | Light impact |
| Tap "Get Started" | Success notification |
| Tap "Skip" | (none) |

## File Dependencies

```
SignatorApp.swift
    └── RootView.swift
            ├── OnboardingView.swift
            │       └── OnboardingPageView.swift
            │               └── AVKit (VideoPlayer)
            │
            ├── PersonaCreationView.swift
            │       └── PersonaManager.shared
            │
            └── MainTabView.swift
                    └── PersonaManager.shared
```

## Debug & Testing Flow

```
Development Mode:
    │
    ├─ Want to see onboarding again?
    │   └─ Use OnboardingDebugHelpers.swift
    │       └─ Tap "Reset Onboarding"
    │           └─ Relaunch app
    │               └─ Onboarding appears!
    │
    └─ Want to test different states?
        ├─ No personas: Delete personas in app
        ├─ Has personas: Create at least one
        └─ First launch: Reset onboarding + delete personas
```

## Code Locations Reference

| Feature | File | Line # (approx) |
|---------|------|-----------------|
| Page content | OnboardingView.swift | ~33 |
| Video filenames | OnboardingView.swift | ~36, 42, 48, 54 |
| Background colors | OnboardingView.swift | ~63 |
| Button colors | OnboardingView.swift | ~122 |
| Video size | OnboardingView.swift | ~162 |
| Root logic | RootView.swift | ~14-26 |
| Debug tools | OnboardingDebugHelpers.swift | Throughout |

---

## Quick Customization Checklist

- [ ] Add 3 videos to Xcode project
- [ ] Update `videoName` in OnboardingView.swift (line ~36, 42, 48)
- [ ] Remove 4th page from `pages` array (line ~51-57)
- [ ] Update titles and descriptions (line ~37, 43, 49)
- [ ] Test in Simulator or device
- [ ] Optionally customize colors (line ~63, ~122)
- [ ] Optionally adjust video size (line ~162)
