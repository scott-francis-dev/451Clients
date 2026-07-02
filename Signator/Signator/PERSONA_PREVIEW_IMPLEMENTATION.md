# Persona Identity Preview Implementation

## Summary
Added live persona identity preview with blue sphere formatting (signature look) to all persona creation flows.

## Changes Made

### 1. New Component: `PersonaIdentityPreviewView`
Created a reusable preview component that displays:
- **Blue gradient sphere avatar** (44x44) with person icon - our signature look
- **Name** in semibold
- **Blue dot separator** (4x4 circle)
- **Publisher/Domain** in medium weight
- **Light blue background** with blue border for visual consistency

### 2. Integration in Three Creation Flows

#### A. **Publishing House Flow** (`StartPublishingHouseView`)
- Shows preview after user enters Name or Publishing House
- Format: `Name · Publishing House`
- Example: "Jane Wu · Long Publishing"

#### B. **Custom Domain Flow** (`HaveMyOwnDomainView`)
- Shows preview after user enters Name
- Format: `Name · domain.com` (if domain entered)
- Example: "Jane Wu · university.wisc.edu"

#### C. **One-Time Signing Flow** (`OneTimeSigningView`)
- Shows preview when user enters optional persona name
- Format: `Name · Private`
- Example: "Contract Signing · Private"

## Visual Design

The preview uses the signature blue sphere design that appears throughout the app:

```
┌────────────────────────────────────┐
│  🔵    Identity Preview            │
│  (44)  Name · Publisher            │
│                                     │
└────────────────────────────────────┘
```

**Blue sphere avatar:**
- Gradient from blue to lighter blue (topLeading → bottomTrailing)
- White person icon
- Subtle blue shadow for depth

**Background styling:**
- Light blue background (5% opacity)
- Blue border (20% opacity, 1.5pt)
- 12pt corner radius

## Benefits

1. **Live feedback** - Users see their persona identity as they type
2. **Consistent branding** - Blue sphere appears everywhere in the app
3. **Visual clarity** - Shows exactly how Name · Publisher will display
4. **Better UX** - Reduces confusion about field relationships

## Location in Code

- Component definition: `PersonaCreationView.swift` (lines ~3074-3128)
- Publishing House integration: line ~1010
- Custom Domain integration: line ~945
- One-Time Signing integration: line ~1088

## Testing Recommendations

1. Enter name only → should show just name
2. Enter name + publisher → should show "Name · Publisher"
3. Clear fields → preview should disappear
4. Verify blue sphere matches other app components
5. Check in light/dark mode
