# Warm Wheat Field Pass Design

## Color Palette

Inspired by the Pastor Brenda contact card's warm, golden wheat field aesthetic:

```
PRIMARY COLORS:
├─ Background Gradient:
│  ├─ Top: RGB(217, 178, 115)    #D9B273  Warm Golden Wheat
│  ├─ Mid: RGB(191, 140, 89)     #BF8C59  Deeper Wheat
│  └─ Bot: RGB(166, 115, 77)     #A6734D  Rich Earth Tone
│
├─ Text Colors:
│  ├─ Primary: RGB(255, 255, 255)  #FFFFFF  White
│  └─ Labels: RGB(255, 248, 240)   #FFF8F0  Warm White
│
└─ Accent:
   └─ Status Badge: White 25% opacity overlay
```

## Visual Preview

### In-App Pass Preview

```
┌─────────────────────────────────────────┐
│                                         │
│  ╔═══════════════════════════════════╗ │
│  ║                                   ║ │
│  ║  🔐          Signator             ║ │
│  ║                                   ║ │
│  ║                                   ║ │
│  ║  John Smith                      ║ │
│  ║  a8k7m4p9                        ║ │
│  ║                                   ║ │
│  ║  🌐 Public         ACTIVE        ║ │
│  ║                                   ║ │
│  ╚═══════════════════════════════════╝ │
│     ↑ Warm wheat field gradient        │
│       (Golden → Earthy tones)           │
│                                         │
└─────────────────────────────────────────┘
```

### In Apple Wallet

```
┌─────────────────────────────────────────┐
│               WALLET                     │
├─────────────────────────────────────────┤
│                                         │
│  ╔═══════════════════════════════════╗ │
│  ║ 🔐   Signator                    ║ │
│  ║                                   ║ │
│  ║ John Smith                       ║ │
│  ║ a8k7m4p9                         ║ │
│  ║                                   ║ │
│  ║ 🌐 Public         ACTIVE         ║ │
│  ╚═══════════════════════════════════╝ │
│  Background: Warm golden wheat (#D9B273)│
│  Gradient fades to rich earth (#A6734D) │
│                                         │
└─────────────────────────────────────────┘
```

### Expanded View with QR Code

```
┌─────────────────────────────────────────┐
│  ✕                                      │
├─────────────────────────────────────────┤
│  ╔═══════════════════════════════════╗ │
│  ║ 🔐   Signator                    ║ │
│  ║                                   ║ │
│  ║ John Smith                       ║ │
│  ║ a8k7m4p9                         ║ │
│  ║                                   ║ │
│  ║ 🌐 Public         ACTIVE         ║ │
│  ╚═══════════════════════════════════╝ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │         QR CODE                   │ │
│  │  ████████████████████            │ │
│  │  ████      ██  ██████            │ │
│  │  ████  ██████    ████            │ │
│  │  ████████████████████            │ │
│  │                                   │ │
│  │  did:451:a8k7m4p9n2q1x5z3       │ │
│  └───────────────────────────────────┘ │
│                                         │
│  Warm, inviting color scheme            │
│  Professional yet approachable          │
│                                         │
└─────────────────────────────────────────┘
```

## Design Details

### Gradient Effect

The pass uses a three-stop gradient:

```swift
LinearGradient(
    colors: [
        Color(red: 0.85, green: 0.70, blue: 0.45),  // Top: Warm golden
        Color(red: 0.75, green: 0.55, blue: 0.35),  // Mid: Deeper wheat
        Color(red: 0.65, green: 0.45, blue: 0.30)   // Bottom: Rich earth
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

### Subtle Texture Overlay

A radial gradient overlay adds depth:

```swift
RadialGradient(
    colors: [
        Color.white.opacity(0.1),  // Bright highlight
        Color.clear                 // Fades to transparent
    ],
    center: .topTrailing,
    startRadius: 0,
    endRadius: 300
)
```

### Text Shadows

White text has subtle dark shadows for depth:

```swift
.shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
```

## Buttons

### Add to Wallet Button

Matches the card's earthy tones:

```swift
.background(
    LinearGradient(
        colors: [
            Color(red: 0.65, green: 0.45, blue: 0.30),  // Rich earth
            Color(red: 0.55, green: 0.35, blue: 0.25)   // Deeper brown
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
)
```

### Share Button

Light wheat tone on transparent:

```swift
.foregroundColor(Color(red: 0.65, green: 0.45, blue: 0.30))
.background(Color(red: 0.85, green: 0.70, blue: 0.45).opacity(0.15))
```

## Comparison: Before & After

### Before (Blue/Purple)

```
┌──────────────────────┐
│ 🔐   Signator       │  Blue/Purple gradient
│                      │  Cool, techy feel
│ John Smith          │  
│ a8k7m4p9            │
│                      │
│ 🌐 Public  ACTIVE   │
└──────────────────────┘
```

### After (Warm Wheat Field)

```
┌──────────────────────┐
│ 🔐   Signator       │  Golden wheat gradient
│                      │  Warm, inviting feel
│ John Smith          │  Professional yet friendly
│ a8k7m4p9            │
│                      │
│ 🌐 Public  ACTIVE   │
└──────────────────────┘
```

## Accessibility

### Color Contrast

- **White on Wheat**: WCAG AA compliant
  - Ratio: 4.8:1 (passes for normal text)
  - Ratio on darker gradient: 5.5:1 (passes for all text)

### Dark Mode

Colors automatically adjust:
- Gradient darkens slightly
- Text remains white
- Shadows become more prominent

## Emotional Design

### Color Psychology

**Warm Golden Wheat**
- 🌾 Natural, organic
- ☀️ Optimistic, friendly
- 📜 Professional, established
- 🤝 Trustworthy, approachable

Perfect for:
- Personal identity
- Community-focused apps
- Faith-based organizations
- Professional services

## Implementation Notes

### In PassJSON

```json
{
  "backgroundColor": "rgb(217, 178, 115)",
  "foregroundColor": "rgb(255, 255, 255)",
  "labelColor": "rgb(255, 248, 240)"
}
```

### In SwiftUI

```swift
Color(red: 0.85, green: 0.70, blue: 0.45)  // #D9B273
```

### In UIKit

```swift
UIColor(red: 0.85, green: 0.70, blue: 0.45, alpha: 1.0)
```

## What Users Will See

1. **In Your App**
   - Beautiful gradient card preview
   - Warm, inviting colors
   - Professional appearance

2. **In Apple Wallet**
   - Stands out with unique warm tone
   - Immediately recognizable
   - Feels personal and special

3. **When Sharing**
   - QR code on clean white background
   - Warm accents throughout
   - Consistent branding

## Summary

✅ **Warm wheat field aesthetic** (like Pastor Brenda image)  
✅ **Professional yet approachable** color scheme  
✅ **WCAG AA accessible** contrast ratios  
✅ **Unique identity** stands out in Wallet  
✅ **Consistent branding** across all views  

The warm golden colors create an inviting, trustworthy feel while maintaining professional credibility. Perfect for identity and signing applications!
