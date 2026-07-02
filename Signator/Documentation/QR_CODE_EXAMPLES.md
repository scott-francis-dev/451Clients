# Quick QR Code Generation Examples

## Example 1: Basic One-Time Signing

### URL Format
```
signator://persona?name=John+Doe&givenName=John+Michael+Doe&email=john@example.com
```

### Python Code
```python
import qrcode

url = "signator://persona?name=John+Doe&givenName=John+Michael+Doe&email=john@example.com"
qr = qrcode.make(url)
qr.save("basic_persona.png")
```

## Example 2: Complete Identity Data

### URL Format
```
signator://persona?name=Sarah+Smith&givenName=Sarah+Elizabeth+Smith&email=sarah@example.com&ssn=123-45-6789&street=456+Oak+Avenue&city=Portland&state=OR&zip=97201&country=USA&documentID=CONTRACT-2024-001&requestID=REQ-789
```

### Python Code
```python
import qrcode
from urllib.parse import urlencode

params = {
    'name': 'Sarah Smith',
    'givenName': 'Sarah Elizabeth Smith',
    'email': 'sarah@example.com',
    'ssn': '123-45-6789',
    'street': '456 Oak Avenue',
    'city': 'Portland',
    'state': 'OR',
    'zip': '97201',
    'country': 'USA',
    'documentID': 'CONTRACT-2024-001',
    'requestID': 'REQ-789'
}

url = f"signator://persona?{urlencode(params)}"
qr = qrcode.make(url)
qr.save("complete_persona.png")
```

## Example 3: JSON Format QR Code

### JSON Structure
```json
{
  "name": "Robert Johnson",
  "givenName": "Robert James Johnson",
  "email": "robert@example.com",
  "ssn": "987-65-4321",
  "address": {
    "street": "789 Maple Drive",
    "city": "Seattle",
    "state": "WA",
    "zip": "98101",
    "country": "USA"
  },
  "documentID": "LEASE-2024-042",
  "requestID": "REQ-456"
}
```

### Python Code
```python
import qrcode
import json

data = {
    "name": "Robert Johnson",
    "givenName": "Robert James Johnson",
    "email": "robert@example.com",
    "ssn": "987-65-4321",
    "address": {
        "street": "789 Maple Drive",
        "city": "Seattle",
        "state": "WA",
        "zip": "98101",
        "country": "USA"
    },
    "documentID": "LEASE-2024-042",
    "requestID": "REQ-456"
}

qr = qrcode.make(json.dumps(data))
qr.save("json_persona.png")
```

## Example 4: Minimal Data (Name & Email Only)

### URL Format
```
signator://persona?name=Quick+Sign&email=quick@example.com
```

### Python Code
```python
import qrcode

url = "signator://persona?name=Quick+Sign&email=quick@example.com"
qr = qrcode.make(url)
qr.save("minimal_persona.png")
```

## Example 5: Contract Signing Request

### URL Format (with tracking IDs)
```
signator://persona?name=Alice+Williams&email=alice@example.com&documentID=EMPLOYMENT-2024-099&requestID=HR-2024-12-27-001
```

### Python Code
```python
import qrcode
from datetime import datetime

# Generate unique request ID with timestamp
request_id = f"HR-{datetime.now().strftime('%Y-%m-%d-%H%M%S')}"

params = {
    'name': 'Alice Williams',
    'email': 'alice@example.com',
    'documentID': 'EMPLOYMENT-2024-099',
    'requestID': request_id
}

url = f"signator://persona?{urlencode(params)}"
qr = qrcode.make(url)
qr.save(f"contract_{request_id}.png")
print(f"Generated QR code with request ID: {request_id}")
```

## Example 6: Batch Generation

### Python Code
```python
import qrcode
from urllib.parse import urlencode
import os

# Create output directory
os.makedirs("qr_codes", exist_ok=True)

# List of users to generate QR codes for
users = [
    {"name": "John Doe", "email": "john@example.com", "documentID": "DOC-001"},
    {"name": "Jane Smith", "email": "jane@example.com", "documentID": "DOC-002"},
    {"name": "Bob Wilson", "email": "bob@example.com", "documentID": "DOC-003"},
]

for user in users:
    url = f"signator://persona?{urlencode(user)}"
    qr = qrcode.make(url)
    filename = f"qr_codes/{user['name'].replace(' ', '_')}_{user['documentID']}.png"
    qr.save(filename)
    print(f"Generated: {filename}")
```

## Example 7: Server-Side Generation (Node.js)

```javascript
const QRCode = require('qrcode');

async function generatePersonaQR(personaData) {
    const params = new URLSearchParams(personaData);
    const url = `signator://persona?${params.toString()}`;
    
    try {
        await QRCode.toFile(`persona_${personaData.name}.png`, url, {
            errorCorrectionLevel: 'H',
            width: 400
        });
        console.log(`QR code generated for ${personaData.name}`);
    } catch (err) {
        console.error('Error generating QR code:', err);
    }
}

// Usage
const personaData = {
    name: 'Emma Davis',
    givenName: 'Emma Louise Davis',
    email: 'emma@example.com',
    documentID: 'PROPOSAL-2024-055'
};

generatePersonaQR(personaData);
```

## Testing QR Codes

### 1. Print and scan with physical device
```bash
# Generate QR code
python3 generate_qr.py

# Print the resulting PNG file
# Scan with iPhone camera or Signator app
```

### 2. Display on screen and scan
```bash
# Generate and open
python3 -c "import qrcode; qrcode.make('signator://persona?name=Test').show()"
```

### 3. Test without QR code (simulator)
```bash
# Directly open deep link in simulator
xcrun simctl openurl booted "signator://persona?name=Test+User&email=test@example.com"
```

## QR Code Best Practices

1. **Error Correction**: Use high error correction level for printed QR codes
```python
qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_H)
```

2. **Size**: Ensure QR codes are at least 2cm x 2cm when printed
```python
qr.save("output.png", scale=10)  # Larger scale for better scanning
```

3. **Testing**: Always test generated QR codes before distribution
4. **Version Control**: Include QR code generation date in filename
5. **Security**: Never include sensitive data in clear text for production use

## Installation of Required Python Packages

```bash
pip install qrcode[pil]
```

Or with Pillow explicitly:
```bash
pip install qrcode pillow
```
