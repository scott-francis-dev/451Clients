# Apple Wallet Pass Integration (If You Want Visible Cards)

## Overview
If you want **visible cards in Apple Wallet** (not just Secure Enclave keys), you need to implement **PassKit**.

## What Wallet Passes Look Like

```
📱 IN THE WALLET APP:

┌─────────────────────────────────┐
│                                 │
│    🔐 SIGNATOR PERSONA          │
│                                 │
│    John Smith                   │
│    did:451:a8k7m4p9            │
│                                 │
│    ┌─────────────────┐         │
│    │   QR CODE      │         │
│    │   ██████       │         │
│    │   ██  ██       │         │
│    └─────────────────┘         │
│                                 │
│    Tap to use for signing       │
│                                 │
└─────────────────────────────────┘
```

## Implementation Steps

### 1. Get Apple Developer Certificates
- Pass Type ID certificate
- WWDR (Worldwide Developer Relations) certificate

### 2. Create Pass Definition
```json
{
  "formatVersion": 1,
  "passTypeIdentifier": "pass.org.the451project.signator",
  "serialNumber": "did:451:a8k7m4p9n2q1x5z3",
  "teamIdentifier": "YOUR_TEAM_ID",
  "organizationName": "Signator",
  "description": "Digital Signing Persona",
  
  "foregroundColor": "rgb(255, 255, 255)",
  "backgroundColor": "rgb(60, 65, 220)",
  "labelColor": "rgb(255, 255, 255)",
  
  "logoText": "Signator",
  
  "generic": {
    "primaryFields": [
      {
        "key": "name",
        "label": "PERSONA",
        "value": "John Smith"
      }
    ],
    "secondaryFields": [
      {
        "key": "did",
        "label": "DID",
        "value": "did:451:a8k7m4p9"
      }
    ],
    "auxiliaryFields": [
      {
        "key": "type",
        "label": "TYPE",
        "value": "Public Persona"
      }
    ],
    "backFields": [
      {
        "key": "publicKey",
        "label": "Public Key",
        "value": "BG4h2+3...truncated..."
      }
    ]
  },
  
  "barcode": {
    "message": "did:451:a8k7m4p9n2q1x5z3",
    "format": "PKBarcodeFormatQR",
    "messageEncoding": "iso-8859-1"
  }
}
```

### 3. Swift Code to Add Pass to Wallet

```swift
import PassKit

func addPersonaToWallet(persona: Persona) {
    // 1. Generate the pass on your server (it must be signed)
    // 2. Download the .pkpass file
    // 3. Present it to the user
    
    guard let passURL = generatePassURL(for: persona) else {
        print("Failed to generate pass")
        return
    }
    
    // Present the pass to the user
    if PKAddPassesViewController.canAddPasses() {
        do {
            let passData = try Data(contentsOf: passURL)
            if let pass = try PKPass(data: passData) {
                let addPassVC = PKAddPassesViewController(pass: pass)
                present(addPassVC, animated: true)
            }
        } catch {
            print("Error creating pass: \(error)")
        }
    } else {
        print("Device cannot add passes")
    }
}

func generatePassURL(for persona: Persona) -> URL? {
    // Call your server to generate a signed .pkpass file
    // Server must:
    // 1. Create pass.json
    // 2. Sign it with your certificate
    // 3. Package as .pkpass (zip file)
    // 4. Return URL to download
    
    // For now, placeholder:
    return URL(string: "https://yourserver.com/api/pass/\(persona.id)")
}
```

### 4. Server-Side Pass Generation

Your server needs to:
```python
# Pseudo-code
def generate_pass(persona):
    # 1. Create pass.json with persona data
    pass_data = {
        "serialNumber": persona.did,
        "generic": {
            "primaryFields": [
                {"key": "name", "value": persona.name}
            ]
        },
        "barcode": {
            "message": persona.did,
            "format": "PKBarcodeFormatQR"
        }
    }
    
    # 2. Create manifest.json (hash of all files)
    # 3. Sign manifest with your Pass Type ID certificate
    # 4. Package as .pkpass (zip with specific structure)
    
    return signed_pass_file
```

## Pros & Cons

### PassKit (Visible Cards)
✅ Users can see and share cards  
✅ QR codes for easy scanning  
✅ Familiar Wallet UI  
❌ More complex to implement  
❌ Requires server infrastructure  
❌ Keys still need Secure Enclave separately  

### Secure Enclave Only (Current)
✅ Maximum security  
✅ No server needed for passes  
✅ Already implemented  
❌ No visible cards  
❌ Users can't "show" their persona  

## Recommendation

**For your use case (document signing):**

I recommend **keeping Secure Enclave only** because:
1. You don't need users to "show" a card
2. Security is more important than visibility
3. Simpler architecture
4. No server infrastructure for pass generation

**Only add PassKit if:**
- Users need to present QR codes to verifiers
- You want branding in the Wallet app
- You're building a public-facing identity system

## Do You Want to Add PassKit?

Let me know if you want to proceed with PassKit integration for visible cards, or if you're happy with the current Secure Enclave-only approach!
