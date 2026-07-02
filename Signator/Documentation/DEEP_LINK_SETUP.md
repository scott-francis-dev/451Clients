# Deep Link Setup Guide for Signator

## Overview
The app now supports deep links and QR codes to prefill one-time signing personas. This enables external systems to launch the app with persona data already filled in.

## URL Scheme Setup

### 1. Add URL Scheme to Info.plist
Add the following to your `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>signator</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.signator</string>
    </dict>
</array>
```

### 2. Add Scene Delegate Support (if needed)
If your app uses `SceneDelegate`, add:

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    // Handle the URL - this is automatically passed to SwiftUI via onOpenURL
}
```

### 3. Handle Deep Links in SwiftUI
Add to your root `App` struct:

```swift
@main
struct SignatorApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    // Deep link is automatically handled by RootView
                    print("📱 Deep link opened: \(url)")
                }
        }
    }
}
```

## Deep Link Format

### URL Structure
```
signator://persona?<parameters>
```

### Supported Parameters
- `name` - Persona display name (for one-time signing)
- `givenName` - Person's full legal name
- `email` - Email address
- `ssn` - Social Security Number (format: XXX-XX-XXXX)
- `documentID` - Associated document identifier
- `requestID` - Request tracking identifier
- `street` - Street address
- `city` - City
- `state` - State/Region
- `zip` - ZIP/Postal code
- `country` - Country

### Example URLs

#### Basic Example
```
signator://persona?name=John+Doe&email=john@example.com
```

#### Complete Example
```
signator://persona?name=John+Doe&givenName=John+Michael+Doe&email=john@example.com&ssn=123-45-6789&street=123+Main+St&city=Springfield&state=IL&zip=62701&country=USA&documentID=DOC-12345&requestID=REQ-67890
```

## QR Code Format

### Option 1: URL-based QR Code
Generate a QR code containing the deep link URL:
```
signator://persona?name=John+Doe&email=john@example.com
```

### Option 2: JSON-based QR Code
Generate a QR code containing JSON:
```json
{
  "name": "John Doe",
  "givenName": "John Michael Doe",
  "email": "john@example.com",
  "ssn": "123-45-6789",
  "address": {
    "street": "123 Main St",
    "city": "Springfield",
    "state": "IL",
    "zip": "62701",
    "country": "USA"
  },
  "documentID": "DOC-12345",
  "requestID": "REQ-67890"
}
```

## Camera Permissions

### Add Privacy Description to Info.plist
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan QR codes for quick persona setup.</string>
```

## Testing Deep Links

### From Safari (iOS)
1. Open Safari
2. Type the deep link URL in the address bar
3. Press Go
4. Tap "Open" when prompted

### From Terminal (iOS Simulator)
```bash
xcrun simctl openurl booted "signator://persona?name=Test+User&email=test@example.com"
```

### From Command Line (Physical Device via adb equivalent)
```bash
# Using xcrun with connected device
xcrun devicectl device process launch --device <device-id> --url "signator://persona?name=Test"
```

## Generating QR Codes

### Using Python
```python
import qrcode
import json

# JSON-based
data = {
    "name": "John Doe",
    "givenName": "John Michael Doe",
    "email": "john@example.com",
    "ssn": "123-45-6789",
    "address": {
        "street": "123 Main St",
        "city": "Springfield",
        "state": "IL",
        "zip": "62701",
        "country": "USA"
    }
}

qr = qrcode.make(json.dumps(data))
qr.save("persona_qr.png")

# URL-based
url = "signator://persona?name=John+Doe&email=john@example.com"
qr = qrcode.make(url)
qr.save("persona_url_qr.png")
```

### Using Online Tools
1. Go to https://www.qr-code-generator.com/
2. Select "URL" type
3. Enter your deep link URL
4. Generate and download

## Security Considerations

1. **Never transmit SSN in plain text over insecure channels**
   - Consider encrypting sensitive data in QR codes
   - Use HTTPS for URL-based deep links

2. **Validate all incoming data**
   - The app should validate all prefilled data
   - Users should always review before submitting

3. **Consider adding authentication**
   - For production, consider requiring authentication before accepting deep link data
   - Add signature verification for QR codes containing sensitive information

## Implementation Details

### Data Flow
1. User scans QR code or clicks deep link
2. `QRScannerView` captures the code/URL
3. `WelcomeFlowView.handleQRCode()` parses the data
4. Data is stored in `deepLinkPersonaData` binding
5. `PersonaCreationView` receives `prefilledData` parameter
6. Form fields are auto-populated in the initializer
7. User reviews and submits

### Supported Scenarios
- ✅ One-time document signing with prefilled identity
- ✅ Contract signing requests via QR code
- ✅ Third-party integrations via deep links
- ✅ Email-based signing invitations

## Future Enhancements
- [ ] Add encryption for sensitive QR code data
- [ ] Support for multiple persona types in deep links
- [ ] Add expiration timestamps to QR codes
- [ ] Implement signature verification for trusted sources
- [ ] Support for batch persona creation
