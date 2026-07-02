# Visual Guide: What Users See

## 1. Persona List with Wallet Icon

```
┌─────────────────────────────────────────────────┐
│  ← Personas                              + Edit │
├─────────────────────────────────────────────────┤
│                                                 │
│  ● John Smith                    🎫  ⋯         │
│    Updated: 2024-12-30                         │
│    did:451:a8k7m4p9n2q1x5z3                   │
│                                                 │
│  ○ Sara Silver                   🎫  ⋯         │
│    Updated: 2024-12-29                         │
│    did:451:x7b2m1k8p4q9                       │
│                                                 │
└─────────────────────────────────────────────────┘
       ↑
   New wallet icon! Tap to view pass
```

## 2. Pass Preview Screen

```
┌─────────────────────────────────────────────────┐
│  ← Wallet Pass                                  │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌────────────────────────────────────────┐   │
│  │                                        │   │
│  │  🔐              Signator              │   │
│  │                                        │   │
│  │                                        │   │
│  │  John Smith                           │   │
│  │  a8k7m4p9                             │   │
│  │                                        │   │
│  │  🌐 Public              ACTIVE        │   │
│  │                                        │   │
│  └────────────────────────────────────────┘   │
│         ↑                                      │
│    Beautiful gradient card                     │
│    (Blue for public, Purple for private)       │
│                                                 │
│  ┌─────────────────────────────────────────┐  │
│  │  🎫 Add to Apple Wallet               │  │
│  └─────────────────────────────────────────┘  │
│                                                 │
│  ┌─────────────────────────────────────────┐  │
│  │  ↗️ Share Persona Info                  │  │
│  └─────────────────────────────────────────┘  │
│                                                 │
│  ┌────────────────────────────────────────┐   │
│  │        QR Code                         │   │
│  │                                        │   │
│  │     ████████████████████              │   │
│  │     ████      ██  ██████              │   │
│  │     ████  ██████    ████              │   │
│  │     ████████████████████              │   │
│  │                                        │   │
│  │  Scan to verify persona               │   │
│  └────────────────────────────────────────┘   │
│                                                 │
│  ╭─ Pass Details ─────────────────────────╮   │
│  │                                         │   │
│  │  Full DID                              │   │
│  │  did:451:a8k7m4p9n2q1x5z3             │   │
│  │                                         │   │
│  │  Public Key                            │   │
│  │  BG4h2+3abcdefghijklmnopqrstuvwx...   │   │
│  │                                         │   │
│  │  Email                                 │   │
│  │  john@example.com                      │   │
│  │                                         │   │
│  │  Created                               │   │
│  │  Dec 30, 2024                          │   │
│  │                                         │   │
│  │  Security                              │   │
│  │  🔒 Secured by Secure Enclave         │   │
│  │     Private keys never leave device    │   │
│  │                                         │   │
│  ╰─────────────────────────────────────────╯   │
│                                                 │
└─────────────────────────────────────────────────┘
```

## 3. After Tapping "Add to Apple Wallet"

### If Server Is Ready:
```
┌─────────────────────────────────────────────────┐
│                                                 │
│         Apple Wallet Add Pass Screen            │
│                                                 │
│  ┌────────────────────────────────────────┐   │
│  │  🔐          Signator                  │   │
│  │                                        │   │
│  │  John Smith                           │   │
│  │  a8k7m4p9                             │   │
│  │                                        │   │
│  │  🌐 Public         ACTIVE             │   │
│  └────────────────────────────────────────┘   │
│                                                 │
│              [Add to Wallet]                    │
│                  [Cancel]                       │
│                                                 │
└─────────────────────────────────────────────────┘
```

### If Server Not Ready:
```
┌─────────────────────────────────────────────────┐
│  Error                                     [OK] │
├─────────────────────────────────────────────────┤
│                                                 │
│  Failed to add to wallet                       │
│                                                 │
│  Note: Your server needs to implement          │
│  the pass signing endpoint.                    │
│                                                 │
│  See SERVER_WALLET_PASS_ENDPOINT.md            │
│  for implementation details.                    │
│                                                 │
└─────────────────────────────────────────────────┘
```

## 4. In Apple Wallet App

### Front of Pass
```
┌─────────────────────────────────────────────────┐
│                   WALLET                        │
├─────────────────────────────────────────────────┤
│                                                 │
│  ╔═════════════════════════════════════════╗  │
│  ║                                         ║  │
│  ║  🔐              Signator               ║  │
│  ║                                         ║  │
│  ║                                         ║  │
│  ║                                         ║  │
│  ║  John Smith                            ║  │
│  ║  a8k7m4p9                              ║  │
│  ║                                         ║  │
│  ║  🌐 Public              ACTIVE         ║  │
│  ║                                         ║  │
│  ╚═════════════════════════════════════════╝  │
│                                                 │
│  [Tap for more info]                           │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Expanded View (Tap on Pass)
```
┌─────────────────────────────────────────────────┐
│  ✕                                              │
├─────────────────────────────────────────────────┤
│                                                 │
│  ╔═════════════════════════════════════════╗  │
│  ║  🔐          Signator                   ║  │
│  ║                                         ║  │
│  ║  John Smith                            ║  │
│  ║  a8k7m4p9                              ║  │
│  ║                                         ║  │
│  ║  🌐 Public         ACTIVE              ║  │
│  ╚═════════════════════════════════════════╝  │
│                                                 │
│  ┌────────────────────────────────────────┐   │
│  │                                        │   │
│  │     ████████████████████              │   │
│  │     ████      ██  ██████              │   │
│  │     ████  ██████    ████              │   │
│  │     ████████████████████              │   │
│  │                                        │   │
│  │      did:451:a8k7m4p9n2q1x5z3        │   │
│  │                                        │   │
│  └────────────────────────────────────────┘   │
│                                                 │
│  [Toggle to show back of pass]                 │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Back of Pass (Flip Over)
```
┌─────────────────────────────────────────────────┐
│  ✕                                              │
├─────────────────────────────────────────────────┤
│                                                 │
│  Full DID                                      │
│  did:451:a8k7m4p9n2q1x5z3                     │
│                                                 │
│  Public Key                                    │
│  BG4h2+3abcdefghijklmnopqrstuvwxyz...         │
│                                                 │
│  Email                                         │
│  john@example.com                              │
│                                                 │
│  Created                                       │
│  Dec 30, 2024                                  │
│                                                 │
│  Security                                      │
│  🔐 Secured by Secure Enclave                 │
│  Private keys never leave your device          │
│                                                 │
│  [Toggle to show front of pass]                │
│                                                 │
└─────────────────────────────────────────────────┘
```

## 5. Sharing the Pass

### Share Sheet
```
┌─────────────────────────────────────────────────┐
│  Share                                   Cancel │
├─────────────────────────────────────────────────┤
│                                                 │
│  📱 AirDrop    💬 Messages    📧 Mail          │
│                                                 │
│  📋 Copy       🔗 Copy Link   📤 More Apps     │
│                                                 │
│  ───────────────────────────────────────────   │
│                                                 │
│  Signator Digital Persona                      │
│                                                 │
│  Name: John Smith                              │
│  DID: did:451:a8k7m4p9n2q1x5z3                │
│  Type: Public                                  │
│  Status: active                                │
│  Email: john@example.com                       │
│                                                 │
│  Secured by Apple Secure Enclave              │
│                                                 │
└─────────────────────────────────────────────────┘
```

## 6. Scanning Someone Else's Pass

```
┌─────────────────────────────────────────────────┐
│  QR Scanner                              [Done] │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌────────────────────────────────────────┐   │
│  │                                        │   │
│  │        ┌──────────────────┐           │   │
│  │        │  ████████████  │             │   │
│  │        │  ██  ████  ██  │             │   │
│  │        │  ████████████  │             │   │
│  │        └──────────────────┘           │   │
│  │                                        │   │
│  │   Aim camera at QR code               │   │
│  │                                        │   │
│  └────────────────────────────────────────┘   │
│                                                 │
│  ↓ After scanning ↓                            │
│                                                 │
│  ┌─────────────────────────────────────────┐  │
│  │  Persona Detected                       │  │
│  │                                         │  │
│  │  DID: did:451:a8k7m4p9n2q1x5z3        │  │
│  │                                         │  │
│  │  [Verify] [Import] [Cancel]           │  │
│  └─────────────────────────────────────────┘  │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Key Visual Elements

### Color Scheme

**Public Personas:**
- Gradient: Blue → Purple
- Accent: Electric Blue (#3C41DC)

**Private Personas:**
- Gradient: Purple → Pink
- Accent: Deep Purple (#5A288C)

### Typography

- **Pass Title (Name):** SF Pro Display, Bold, 24pt
- **DID:** SF Mono, Regular, 10pt
- **Labels:** SF Pro Text, Semibold, 11pt
- **Values:** SF Pro Text, Regular, 13pt

### Icons

- 🔐 Person with key: `person.badge.key.fill`
- 🎫 Wallet: `wallet.pass`
- 🌐 Public: `globe`
- 🔒 Private: `lock`
- ✓ Active: `checkmark.circle.fill`
- 📤 Share: `square.and.arrow.up`

### Spacing

- Card corner radius: 20pt
- Button corner radius: 12pt
- Section spacing: 24pt
- Content padding: 20pt

## Responsive Behavior

### iPhone SE (Small)
- Single column layout
- Smaller QR code (180x180)
- Compact buttons

### iPhone Pro (Medium)
- Full layout as shown
- QR code (200x200)
- Standard spacing

### iPad (Large)
- Centered content (max width 600pt)
- Larger QR code (300x300)
- More whitespace

## Dark Mode

All views automatically adapt to dark mode:
- Background gradients adjust brightness
- Text inverts appropriately
- QR codes maintain contrast
- Card shadows lighten

## Accessibility

- ✅ VoiceOver labels on all elements
- ✅ Dynamic Type support
- ✅ High contrast support
- ✅ Minimum touch targets: 44x44pt
- ✅ Semantic colors

## Animations

### Card Entry
- Slide up + fade in
- Duration: 0.3s
- Easing: ease-out

### Button Press
- Scale to 0.95
- Duration: 0.1s
- Spring animation

### QR Code Generation
- Fade in
- Duration: 0.2s
- After generation complete

## What Users Love

1. **Visual Identity** - Something tangible to represent their persona
2. **Professional Look** - Looks official in Wallet
3. **Easy Verification** - Just scan the QR code
4. **Secure Feel** - "Secured by Secure Enclave" badge
5. **Share-ability** - Can share via AirDrop, Messages, etc.

## Implementation Complete!

All the views are ready. Just need:
1. Server endpoint for signing
2. Apple Developer certificates
3. Update Team ID in code

Then users can add beautiful, secure passes to their Wallet! 🎉
