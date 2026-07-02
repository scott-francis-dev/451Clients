# Connection Request System - Privacy & Security Design

## Overview

This connection request system implements a two-way verification process before sharing full personal information. It prevents unauthorized access to sensitive data like email addresses, physical addresses, and other PII even if someone can guess or obtain a 7-digit short code.

## Visual Flow

```
┌─────────────┐                                    ┌─────────────┐
│   User A    │                                    │   User B    │
│ (Requester) │                                    │ (Recipient) │
└──────┬──────┘                                    └──────┬──────┘
       │                                                   │
       │ 1. Searches for "ABC-1234"                       │
       │────────────────────────────►                     │
       │                            Server                │
       │◄────────────────────────────                     │
       │ Returns: name, shortId, DID only                 │
       │ (NO email, address, etc.)                        │
       │                                                   │
       │ 2. Sends connection request                      │
       │    "Hi, we met at the conference"                │
       │────────────────────────────►                     │
       │                            Server                │
       │                              │                   │
       │                              │ 3. Notifies       │
       │                              ├──────────────────►│
       │                              │   New request     │
       │                              │   Shows: A's name │
       │                              │   & short code    │
       │                              │                   │
       │                              │ 4. B Accepts      │
       │                              │◄──────────────────│
       │                              │                   │
       │ 5. Both notified of acceptance                   │
       │◄────────────────────────────┤──────────────────►│
       │   Full profiles now visible  │                   │
       │                              │                   │
       │ 6. Can now share documents   │                   │
       │◄─────────────────────────────┼──────────────────►│
       │     & collaborate            │                   │
       │                              │                   │
```

## Privacy-First Design

### Information Disclosure Levels

#### Level 1: Public Discovery (Before Connection)
When someone looks up a persona by short code, @handle, or DID, they only see:
- ✅ Name (or display name)
- ✅ Short ID (7-digit code)
- ✅ Pretty DID
- ✅ DID (identifier)
- ❌ Email address
- ❌ Physical address
- ❌ Phone number
- ❌ Social links
- ❌ Affiliations

#### Level 2: Pending Connection
When a connection request is sent but not yet accepted:
- The requester sees only the recipient's basic info (name, short ID)
- The recipient sees only the requester's basic info (name, short ID)
- An optional message can be included with context ("We met at the conference...")
- Both parties can review before accepting

#### Level 3: Accepted Connection (Full Access)
Once both parties accept the connection:
- ✅ Full name
- ✅ Email address
- ✅ Physical address
- ✅ Social links
- ✅ Affiliations
- ✅ All profile information
- ✅ Ability to send documents and collaborate

## Security Flow

### 1. Discovery Phase
```
User A enters User B's short code (ABC-1234)
    ↓
PersonaResolver.resolve() returns PersonaResolvedProfile
    ↓
Only basic info shown: name, shortId, prettyDID
```

### 2. Request Phase
```
User A clicks "Add Colleague"
    ↓
ConnectionManager.sendConnectionRequest(toDID: B's DID, message: "...")
    ↓
Server stores request with status: .pending
    ↓
User B sees pending request with limited info about User A
```

### 3. Verification Phase
```
User B reviews request
    ↓
Option 1: Accept
    - ConnectionManager.acceptConnectionRequest()
    - Both parties added to each other's colleagues list
    - Full profile information now accessible
    
Option 2: Reject
    - ConnectionManager.rejectConnectionRequest()
    - Request marked as rejected
    - No information shared
    
Option 3: Ignore
    - Request remains pending (can optionally expire after time)
```

### 4. Connected Phase
```
Both users now in each other's colleagues list
    ↓
Full profile information accessible
    ↓
Can send documents, collaborate, etc.
```

## Data Models

### ConnectionPreview
A lightweight profile that limits information disclosure:
```swift
struct ConnectionPreview {
    let did: String              // Always shown (needed for identification)
    let name: String             // Always shown
    let shortId: String?         // Always shown
    let prettyDID: String?       // Always shown
    
    // Only populated after connection accepted:
    let handle: String?          // Hidden until accepted
    let email: String?           // Hidden until accepted
    let address: String?         // Hidden until accepted
    let affiliations: String?    // Hidden until accepted
    let socialLinks: String?     // Hidden until accepted
}
```

### ConnectionRequest
Tracks the state of connection requests:
```swift
struct ConnectionRequest {
    let id: String
    let fromDID: String
    let toDID: String
    var status: ConnectionStatus  // pending, accepted, rejected, blocked
    let createdAt: Date
    var respondedAt: Date?
    var message: String?
    
    var requesterPreview: ConnectionPreview?   // Limited info
    var recipientPreview: ConnectionPreview?   // Limited info
}
```

### Colleague
Full access once connection is accepted:
```swift
struct Colleague {
    let did: String
    let name: String
    let email: String?              // Now accessible
    let address: String?            // Now accessible
    let affiliations: String?       // Now accessible
    let socialLinks: String?        // Now accessible
    // ... all profile fields
    
    var notes: String?              // Private notes
    var isFavorite: Bool
    var tags: [String]?
}
```

## API Endpoints (Server Implementation Required)

### POST /api/connections/request
Send a connection request
```json
{
  "toDID": "did:key:...",
  "message": "We met at the conference"
}
```
Headers: `X-DID: did:key:...` (requester's DID)

### POST /api/connections/respond
Accept or reject a request
```json
{
  "requestId": "req_123",
  "accept": true,
  "message": "Great to connect!"
}
```
Headers: `X-DID: did:key:...` (responder's DID)

### GET /api/connections/pending
Get requests awaiting my response
Headers: `X-DID: did:key:...`

### GET /api/connections/sent
Get requests I've sent
Headers: `X-DID: did:key:...`

### GET /api/connections/colleagues
Get all accepted connections
Headers: `X-DID: did:key:...`

## Usage Example

### User A wants to add User B as a colleague:

```swift
// 1. User A searches for User B by short code
let profile = try await resolver.resolveStringWithShortCodeSupport("ABC-1234")
// profile only contains: name, shortId, prettyDID, did
// NO email, address, or other sensitive info

// 2. User A sends connection request
let request = try await connectionManager.sendConnectionRequest(
    toDID: profile.did,
    message: "Hi! We met at the conference last week"
)

// 3. User B sees the request with limited info about User A
// - Shows User A's name and short code only
// - Shows the message

// 4. User B accepts
let colleague = try await connectionManager.acceptConnectionRequest(request)
// NOW colleague object has full profile information

// 5. Both users can now see full details and collaborate
```

## Security Considerations

### Why This Matters

1. **Short codes are guessable**: 7 hex digits = only 268 million combinations
   - Someone could theoretically brute-force search
   - Without connection verification, they'd get immediate access to sensitive data

2. **DID and @handle are public**: By design, these identifiers are discoverable
   - But discovery ≠ access to private information

3. **Mutual consent required**: Both parties must agree to share information
   - User can see who wants to connect
   - User can verify identity before accepting
   - User can reject unwanted connections

### Additional Security Features

- **Blocking**: Users can block specific DIDs from sending future requests
- **Expiration**: Requests can auto-expire after a time period
- **Rate limiting**: Server should limit request frequency per DID
- **Notification system**: Alert users of new connection requests
- **Audit trail**: Track when connections were made for security review

## Integration with Existing Code

### In SendSigningFlowView or DocumentSharingView:

```swift
// Instead of directly resolving and showing full profile:
let profile = try await resolver.resolve(recipientDID)

// Check if they're a colleague first:
if let colleague = connectionManager.colleague(for: recipientDID) {
    // ✅ Show full information, allow sending document
    showFullProfile(colleague)
} else if connectionManager.hasPendingRequest(did: recipientDID) {
    // ⏳ Show limited info, explain connection is pending
    showPendingMessage()
} else {
    // ❌ Prompt user to send connection request first
    showConnectionRequestPrompt()
}
```

## Future Enhancements

1. **Verification levels**: Add "verified" badge for email/phone verification
2. **Connection types**: Distinguish between colleagues, friends, organizations
3. **Privacy settings**: Let users control what info is shared pre-connection
4. **QR codes**: Generate QR codes for in-person connection requests
5. **Push notifications**: Real-time alerts for new requests
6. **Connection suggestions**: Based on mutual connections
7. **Batch operations**: Accept/reject multiple requests at once

## Testing Checklist

- [ ] User can send connection request with short code
- [ ] User can send connection request with @handle
- [ ] User can send connection request with DID
- [ ] Recipient sees request with limited info
- [ ] Recipient can accept request
- [ ] Recipient can reject request
- [ ] After acceptance, full profile is visible
- [ ] Rejected requests don't show full info
- [ ] Can't send duplicate requests
- [ ] Sync properly updates all lists
- [ ] Offline changes persist when back online
- [ ] Rate limiting prevents spam
- [ ] Blocked users can't send requests

---

**Implementation Status**: ✅ Client code complete, ⏳ Server API endpoints needed
