# QR Scanner & Deep Link Implementation Summary

## Changes Made

### 1. New File: QRScannerView.swift
- Created a fully functional QR code scanner using AVFoundation
- Features:
  - Real-time camera preview
  - Visual scanning frame with corner accents
  - Vibration feedback on successful scan
  - Camera permission handling with alert
  - Support for QR, EAN8, EAN13, and PDF417 codes
  - Automatic dismissal after successful scan

### 2. Updated: RootView.swift

#### Added Deep Link Support
- New `OneTimePersonaData` struct for passing persona information
- URL format: `signator://persona?name=John&email=john@example.com`
- JSON QR code support for structured data
- Automatic parsing and validation

#### Updated UI Layout
- **Two blue buttons** (primary actions, grouped together):
  - "Create a persona for a 1-time signing"
  - "Scan QR Code" (with camera icon)
- **One purple button** (secondary action, separated with spacing):
  - "Create Persistent Persona(s)"
- **Subtle gear icon** in lower-right corner:
  - Changed from `gearshape.fill` to `gearshape`
  - Reduced from `.title2` to `.caption` size
  - Changed from `.primary` to `.secondary` color
  - Added 40% opacity for extra subtlety
  - Removed background circle and shadow

#### New Navigation
- QR scanner opens in a sheet
- One-time signing flow can receive prefilled data
- Deep link handling with URL parsing

### 3. Updated: PersonaCreationView.swift

#### New Initializer Parameter
- Added `prefilledData: OneTimePersonaData?` parameter
- Automatically populates form fields when deep link data is provided:
  - Name (publishingHouse field)
  - Given Name
  - Email (private)
  - Social Security Number
  - Street Address
  - City
  - State/Region
  - Postal Code
  - Country

### 4. New File: DEEP_LINK_SETUP.md
Complete documentation for:
- URL scheme configuration
- Info.plist setup
- Deep link format and examples
- QR code generation
- Testing procedures
- Security considerations

## User Flows

### Flow 1: Manual One-Time Signing
1. User taps "Create a persona for a 1-time signing"
2. Form appears with empty fields
3. User fills in information manually
4. User creates persona

### Flow 2: QR Code Scan
1. User taps "Scan QR Code"
2. Camera opens with viewfinder
3. User points at QR code
4. Code is scanned (with vibration feedback)
5. If valid persona data:
   - One-time signing form opens
   - Fields are pre-filled
   - User reviews and confirms
6. If invalid:
   - Error message in console
   - User can cancel and try again

### Flow 3: Deep Link
1. User clicks link in email/web (e.g., `signator://persona?name=John&email=john@example.com`)
2. iOS prompts to open Signator
3. App opens to welcome screen
4. One-time signing form auto-opens with prefilled data
5. User reviews and confirms

### Flow 4: Persistent Personas
1. User taps "Create Persistent Persona(s)" (purple button)
2. Navigates to PersonaTypeSelectionView
3. User chooses persona type and creates

## Technical Details

### QR Code Scanner
- Uses `AVCaptureSession` for camera access
- `AVCaptureMetadataOutput` for barcode detection
- `AVCaptureVideoPreviewLayer` for camera preview
- Handles all camera permission states
- Graceful error handling

### Deep Link Parsing
- Supports URL-based format: `signator://persona?param=value`
- Supports JSON format in QR codes
- Validates URL scheme and host
- Extracts query parameters
- Builds `OneTimePersonaData` struct
- Passes to PersonaCreationView

### State Management
- `deepLinkPersonaData` binding flows from RootView to WelcomeFlowView
- Data persists across view transitions
- Cleared after persona creation

## Required Info.plist Entries

```xml
<!-- Camera Permission -->
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan QR codes for quick persona setup.</string>

<!-- URL Scheme -->
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

## Testing Commands

### Test Deep Link (Simulator)
```bash
xcrun simctl openurl booted "signator://persona?name=Test+User&email=test@example.com&givenName=Test+Michael+User&street=123+Main+St&city=Springfield&state=IL&zip=62701&country=USA"
```

### Generate Test QR Code (Python)
```python
import qrcode
url = "signator://persona?name=John+Doe&email=john@example.com"
qr = qrcode.make(url)
qr.save("test_qr.png")
```

## Security Notes

1. **SSN Handling**: Consider encrypting SSN data in QR codes
2. **Validation**: All prefilled data should be validated before use
3. **User Review**: Users should always review prefilled data before submission
4. **Transport Security**: Use HTTPS for any URL-based deep links shared over the web

## Future Enhancements

- [ ] Add QR code encryption for sensitive data
- [ ] Implement expiration timestamps
- [ ] Add signature verification for trusted sources
- [ ] Support batch persona creation via deep links
- [ ] Add analytics for tracking deep link usage
- [ ] Implement fallback for failed camera access (manual entry of QR data)
