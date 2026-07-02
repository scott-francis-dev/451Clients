# Server Endpoint for Wallet Pass Signing

## Overview

The iOS app generates wallet passes locally, but Apple requires them to be cryptographically signed with a Pass Type ID certificate. This endpoint handles the signing process.

## Endpoint

```
POST /api/wallet/sign-pass
```

## Request

### Headers
```
Content-Type: application/json
```

### Body
```json
{
  "passJSON": {
    "formatVersion": 1,
    "passTypeIdentifier": "pass.org.the451project.signator",
    "serialNumber": "did:451:a8k7m4p9n2q1x5z3",
    "teamIdentifier": "YOUR_TEAM_ID",
    "organizationName": "Signator",
    "description": "Digital Signing Persona",
    // ... rest of pass.json
  },
  "personaDID": "did:451:a8k7m4p9n2q1x5z3",
  "qrCodeImage": "base64-encoded-png",
  "logoImage": "base64-encoded-png",
  "iconImage": "base64-encoded-png"
}
```

## Response

### Success (200 OK)
```json
{
  "passURL": "https://yourserver.com/passes/did:451:a8k7m4p9n2q1x5z3.pkpass",
  "expiresAt": "2024-12-31T23:59:59Z"
}
```

### Error (400 Bad Request)
```json
{
  "error": "invalid_pass_data",
  "message": "Pass JSON is malformed"
}
```

## Server Implementation Steps

### 1. Prerequisites

You need:
- **Pass Type ID certificate** from Apple Developer Portal
- **WWDR certificate** (Worldwide Developer Relations)
- **Apple Team ID**

### 2. Pass Signing Process

```python
# Pseudo-code for server implementation

def sign_pass(request):
    # 1. Validate the request
    pass_json = request['passJSON']
    persona_did = request['personaDID']
    qr_code = base64.decode(request['qrCodeImage'])
    logo = base64.decode(request['logoImage'])
    icon = base64.decode(request['iconImage'])
    
    # 2. Verify persona is registered (optional, but recommended)
    if not is_persona_registered(persona_did):
        return error("Persona not registered")
    
    # 3. Create pass bundle directory structure
    """
    pass.bundle/
    ├── pass.json
    ├── icon.png
    ├── icon@2x.png
    ├── logo.png
    ├── logo@2x.png
    ├── strip.png (QR code)
    ├── strip@2x.png
    ├── manifest.json
    └── signature
    """
    
    # 4. Write pass.json
    write_file('pass.bundle/pass.json', json.dumps(pass_json))
    
    # 5. Write images at different resolutions
    write_image('pass.bundle/icon.png', resize(icon, 29))
    write_image('pass.bundle/icon@2x.png', resize(icon, 58))
    write_image('pass.bundle/logo.png', resize(logo, 40))
    write_image('pass.bundle/logo@2x.png', resize(logo, 80))
    write_image('pass.bundle/strip.png', resize(qr_code, 375, 123))
    write_image('pass.bundle/strip@2x.png', resize(qr_code, 750, 246))
    
    # 6. Create manifest.json (SHA-1 hash of each file)
    manifest = {}
    for file in list_files('pass.bundle/'):
        manifest[file] = sha1(read_file(file))
    write_file('pass.bundle/manifest.json', json.dumps(manifest))
    
    # 7. Sign manifest with Pass Type ID certificate
    signature = sign_with_certificate(
        data=read_file('pass.bundle/manifest.json'),
        certificate='pass_certificate.pem',
        private_key='pass_private_key.pem',
        wwdr_cert='wwdr.pem'
    )
    write_file('pass.bundle/signature', signature)
    
    # 8. Create .pkpass file (ZIP archive)
    pkpass_path = create_zip('pass.bundle/', f'{persona_did}.pkpass')
    
    # 9. Upload to publicly accessible URL
    pass_url = upload_to_storage(pkpass_path)
    
    # 10. Return URL to client
    return {
        'passURL': pass_url,
        'expiresAt': datetime.now() + timedelta(hours=24)
    }
```

### 3. Node.js Example

```javascript
const express = require('express');
const { PassGenerator } = require('passkit-generator');

app.post('/api/wallet/sign-pass', async (req, res) => {
    try {
        const { passJSON, personaDID, qrCodeImage, logoImage, iconImage } = req.body;
        
        // Decode base64 images
        const qrCode = Buffer.from(qrCodeImage, 'base64');
        const logo = Buffer.from(logoImage, 'base64');
        const icon = Buffer.from(iconImage, 'base64');
        
        // Create pass
        const pass = await PassGenerator.from({
            model: './passModels/Signator.pass', // Template directory
            certificates: {
                wwdr: './certs/wwdr.pem',
                signerCert: './certs/signerCert.pem',
                signerKey: './certs/signerKey.pem'
            }
        }, passJSON);
        
        // Add images
        pass.addBuffer('icon.png', icon);
        pass.addBuffer('logo.png', logo);
        pass.addBuffer('strip.png', qrCode);
        
        // Generate the .pkpass file
        const buffer = pass.getAsBuffer();
        
        // Save to public storage
        const filename = `${personaDID}.pkpass`;
        const passURL = await uploadToStorage(buffer, filename);
        
        res.json({
            passURL: passURL,
            expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
        });
        
    } catch (error) {
        console.error('Error signing pass:', error);
        res.status(500).json({
            error: 'pass_signing_failed',
            message: error.message
        });
    }
});
```

### 4. Python Example (using signpass library)

```python
from flask import Flask, request, jsonify
from signpass import Pass
import base64
import os
from datetime import datetime, timedelta

app = Flask(__name__)

@app.route('/api/wallet/sign-pass', methods=['POST'])
def sign_pass():
    try:
        data = request.json
        pass_json = data['passJSON']
        persona_did = data['personaDID']
        qr_code = base64.b64decode(data['qrCodeImage'])
        logo = base64.b64decode(data['logoImage'])
        icon = base64.b64decode(data['iconImage'])
        
        # Create pass
        pass_obj = Pass(
            pass_type_identifier='pass.org.the451project.signator',
            organization_name='Signator',
            team_identifier=os.getenv('APPLE_TEAM_ID')
        )
        
        # Set pass data
        pass_obj.set_pass_information(pass_json)
        
        # Add images
        pass_obj.add_file('icon.png', icon)
        pass_obj.add_file('logo.png', logo)
        pass_obj.add_file('strip.png', qr_code)
        
        # Sign the pass
        signed_pass = pass_obj.create(
            certificate='certs/pass_certificate.pem',
            key='certs/pass_key.pem',
            wwdr_certificate='certs/wwdr.pem',
            password=os.getenv('CERT_PASSWORD')
        )
        
        # Upload to storage
        filename = f"{persona_did}.pkpass"
        pass_url = upload_to_storage(signed_pass, filename)
        
        return jsonify({
            'passURL': pass_url,
            'expiresAt': (datetime.now() + timedelta(hours=24)).isoformat()
        })
        
    except Exception as e:
        return jsonify({
            'error': 'pass_signing_failed',
            'message': str(e)
        }), 500
```

## Certificate Setup

### 1. Create Pass Type ID in Apple Developer Portal

1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Identifiers** → **Pass Type IDs**
4. Click **+** to create new
5. Enter identifier: `pass.org.the451project.signator`
6. Register it

### 2. Create Pass Type ID Certificate

1. In **Certificates** section, click **+**
2. Select **Pass Type ID Certificate**
3. Choose your Pass Type ID
4. Create a Certificate Signing Request (CSR):
   ```bash
   openssl req -newkey rsa:2048 -nodes -keyout pass_key.pem -out pass_request.csr
   ```
5. Upload CSR and download certificate
6. Convert to PEM:
   ```bash
   openssl x509 -in pass_certificate.cer -inform DER -out pass_certificate.pem
   ```

### 3. Download WWDR Certificate

1. Download from [Apple PKI](https://www.apple.com/certificateauthority/)
2. Get "Worldwide Developer Relations - G4"
3. Convert to PEM:
   ```bash
   openssl x509 -in AppleWWDRCA.cer -inform DER -out wwdr.pem
   ```

## Testing

### Test with curl

```bash
curl -X POST https://yourserver.com/api/wallet/sign-pass \
  -H "Content-Type: application/json" \
  -d '{
    "passJSON": {...},
    "personaDID": "did:451:test123",
    "qrCodeImage": "base64-encoded-image...",
    "logoImage": "base64-encoded-image...",
    "iconImage": "base64-encoded-image..."
  }'
```

### Expected Response

```json
{
  "passURL": "https://yourserver.com/passes/did:451:test123.pkpass"
}
```

You can then download the .pkpass file and test it:
- On iOS: Tap the file in Files app or Mail
- On Mac: Double-click to open in Wallet simulator

## Security Considerations

1. **Validate persona registration** - Only sign passes for registered personas
2. **Rate limiting** - Prevent abuse of the signing endpoint
3. **Expiring URLs** - Make signed pass URLs expire after 24 hours
4. **Certificate protection** - Keep signing certificates secure
5. **Logging** - Log all pass signing requests for audit

## Alternative: Client-Side Signing

If you want to avoid server signing entirely, you could:

1. **Distribute certificates via MDM** (enterprise only)
2. **Use web-based signing** with JavaScript crypto libraries
3. **Generate unsigned passes** and have users manually add them

However, **Apple requires proper signing** for passes to work in Wallet, so server-side signing is the recommended approach.

## Resources

- [Apple Wallet Developer Guide](https://developer.apple.com/wallet/)
- [PassKit Package Format Reference](https://developer.apple.com/documentation/walletpasses/creating-the-source-for-a-pass)
- [signpass npm package](https://www.npmjs.com/package/signpass)
- [passkit-generator npm package](https://www.npmjs.com/package/passkit-generator)
