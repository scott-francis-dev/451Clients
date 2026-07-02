# Server API Specification: Connection Request System

## Overview

This document specifies the server-side API endpoints required to support the client-side connection request system. All endpoints require authentication via the `X-DID` header containing the user's DID.

## Authentication

All endpoints require:
```
X-DID: did:key:z6Mk... (The requesting user's DID)
```

Optional (for signed requests):
```
X-Signature: base64_encoded_signature
X-Signature-Timestamp: unix_timestamp
```

## API Endpoints

### 1. Send Connection Request

**POST** `/api/connections/request`

Create a new connection request from the authenticated user to another persona.

#### Request Headers
```
Content-Type: application/json
X-DID: did:key:sender_did
```

#### Request Body
```json
{
  "toDID": "did:key:recipient_did",
  "message": "Optional message to recipient"
}
```

#### Success Response (201 Created)
```json
{
  "success": true,
  "request": {
    "id": "req_abc123",
    "fromDID": "did:key:sender_did",
    "toDID": "did:key:recipient_did",
    "status": "pending",
    "createdAt": "2026-01-06T10:30:00Z",
    "respondedAt": null,
    "message": "Optional message to recipient",
    "requesterPreview": {
      "did": "did:key:sender_did",
      "name": "Sender Name",
      "shortId": "ABC-1234",
      "prettyDID": "sender.did",
      "handle": null,
      "email": null,
      "address": null,
      "affiliations": null,
      "socialLinks": null
    },
    "recipientPreview": {
      "did": "did:key:recipient_did",
      "name": "Recipient Name",
      "shortId": "XYZ-7890",
      "prettyDID": "recipient.did",
      "handle": null,
      "email": null,
      "address": null,
      "affiliations": null,
      "socialLinks": null
    }
  }
}
```

#### Error Responses

**400 Bad Request** - Already connected or request already exists
```json
{
  "success": false,
  "error": "Connection already exists",
  "code": "ALREADY_CONNECTED"
}
```

**404 Not Found** - Recipient DID doesn't exist
```json
{
  "success": false,
  "error": "Recipient persona not found",
  "code": "RECIPIENT_NOT_FOUND"
}
```

**429 Too Many Requests** - Rate limit exceeded
```json
{
  "success": false,
  "error": "Too many requests. Please try again later.",
  "code": "RATE_LIMIT_EXCEEDED",
  "retryAfter": 3600
}
```

#### Implementation Notes
- Validate that `toDID` exists and is active
- Check for duplicate pending requests
- Check if users are already connected
- Create ConnectionPreview with **limited info only** (no email, address, etc.)
- Store request in database with `pending` status
- Trigger push notification to recipient (if enabled)
- Rate limit: max 10 requests per hour per user

---

### 2. Respond to Connection Request

**POST** `/api/connections/respond`

Accept or reject a connection request. Only the recipient (toDID) can respond.

#### Request Headers
```
Content-Type: application/json
X-DID: did:key:recipient_did
```

#### Request Body
```json
{
  "requestId": "req_abc123",
  "accept": true,
  "message": "Optional response message"
}
```

#### Success Response (200 OK)

**If Accepted:**
```json
{
  "success": true,
  "request": {
    "id": "req_abc123",
    "fromDID": "did:key:sender_did",
    "toDID": "did:key:recipient_did",
    "status": "accepted",
    "createdAt": "2026-01-06T10:30:00Z",
    "respondedAt": "2026-01-06T11:00:00Z",
    "message": "Original message",
    "requesterPreview": {
      "did": "did:key:sender_did",
      "name": "Sender Name",
      "shortId": "ABC-1234",
      "prettyDID": "sender.did",
      "handle": "sender_handle",
      "email": "sender@example.com",
      "address": "123 Sender St",
      "affiliations": "Sender Corp",
      "socialLinks": "sender.com"
    },
    "recipientPreview": {
      "did": "did:key:recipient_did",
      "name": "Recipient Name",
      "shortId": "XYZ-7890",
      "prettyDID": "recipient.did",
      "handle": "recipient_handle",
      "email": "recipient@example.com",
      "address": "456 Recipient Ave",
      "affiliations": "Recipient Inc",
      "socialLinks": "recipient.com"
    }
  }
}
```

**If Rejected:**
```json
{
  "success": true,
  "request": {
    "id": "req_abc123",
    "fromDID": "did:key:sender_did",
    "toDID": "did:key:recipient_did",
    "status": "rejected",
    "createdAt": "2026-01-06T10:30:00Z",
    "respondedAt": "2026-01-06T11:00:00Z",
    "message": "Original message",
    "requesterPreview": {
      "did": "did:key:sender_did",
      "name": "Sender Name",
      "shortId": "ABC-1234",
      "prettyDID": "sender.did",
      "handle": null,
      "email": null,
      "address": null,
      "affiliations": null,
      "socialLinks": null
    },
    "recipientPreview": null
  }
}
```

#### Error Responses

**403 Forbidden** - Not the recipient
```json
{
  "success": false,
  "error": "Only the recipient can respond to this request",
  "code": "FORBIDDEN"
}
```

**404 Not Found** - Request doesn't exist
```json
{
  "success": false,
  "error": "Connection request not found",
  "code": "REQUEST_NOT_FOUND"
}
```

**409 Conflict** - Request already responded to
```json
{
  "success": false,
  "error": "Request has already been responded to",
  "code": "ALREADY_RESPONDED"
}
```

#### Implementation Notes
- Verify requestId exists and status is `pending`
- Verify X-DID header matches request.toDID
- Update request status to `accepted` or `rejected`
- Set respondedAt timestamp
- If accepted:
  - Populate **full profile info** in both previews
  - Create bidirectional colleague relationship
  - Trigger notification to original requester
- If rejected:
  - Keep minimal info in previews
  - Trigger notification to original requester
- Consider auto-expiring old pending requests (e.g., 30 days)

---

### 3. Get Pending Requests

**GET** `/api/connections/pending`

Get all connection requests awaiting the authenticated user's response.

#### Request Headers
```
X-DID: did:key:user_did
```

#### Success Response (200 OK)
```json
{
  "requests": [
    {
      "id": "req_abc123",
      "fromDID": "did:key:sender_did",
      "toDID": "did:key:user_did",
      "status": "pending",
      "createdAt": "2026-01-06T10:30:00Z",
      "respondedAt": null,
      "message": "Let's connect!",
      "requesterPreview": {
        "did": "did:key:sender_did",
        "name": "Sender Name",
        "shortId": "ABC-1234",
        "prettyDID": "sender.did",
        "handle": null,
        "email": null,
        "address": null,
        "affiliations": null,
        "socialLinks": null
      },
      "recipientPreview": null
    }
  ],
  "count": 1
}
```

#### Implementation Notes
- Return only requests where `toDID == X-DID` AND `status == pending`
- Order by createdAt DESC (newest first)
- Include **limited** requester profile info
- Consider pagination for users with many requests

---

### 4. Get Sent Requests

**GET** `/api/connections/sent`

Get all connection requests the authenticated user has sent.

#### Request Headers
```
X-DID: did:key:user_did
```

#### Success Response (200 OK)
```json
{
  "requests": [
    {
      "id": "req_xyz789",
      "fromDID": "did:key:user_did",
      "toDID": "did:key:recipient_did",
      "status": "pending",
      "createdAt": "2026-01-06T09:00:00Z",
      "respondedAt": null,
      "message": "Hi there!",
      "requesterPreview": null,
      "recipientPreview": {
        "did": "did:key:recipient_did",
        "name": "Recipient Name",
        "shortId": "XYZ-7890",
        "prettyDID": "recipient.did",
        "handle": null,
        "email": null,
        "address": null,
        "affiliations": null,
        "socialLinks": null
      }
    },
    {
      "id": "req_def456",
      "fromDID": "did:key:user_did",
      "toDID": "did:key:another_did",
      "status": "accepted",
      "createdAt": "2026-01-05T14:00:00Z",
      "respondedAt": "2026-01-05T15:30:00Z",
      "message": "Let's collaborate",
      "requesterPreview": null,
      "recipientPreview": {
        "did": "did:key:another_did",
        "name": "Another User",
        "shortId": "DEF-4567",
        "prettyDID": "another.did",
        "handle": "anotheruser",
        "email": "another@example.com",
        "address": "789 Another Blvd",
        "affiliations": "Another Org",
        "socialLinks": "another.com"
      }
    }
  ],
  "count": 2
}
```

#### Implementation Notes
- Return requests where `fromDID == X-DID`
- Include all statuses (pending, accepted, rejected)
- For accepted requests, include full recipient profile
- For pending/rejected, only limited recipient profile
- Order by createdAt DESC

---

### 5. Get Colleagues

**GET** `/api/connections/colleagues`

Get all accepted connections (colleagues) for the authenticated user.

#### Request Headers
```
X-DID: did:key:user_did
```

#### Query Parameters
- `limit` (optional): Max number of results (default: 100)
- `offset` (optional): Pagination offset (default: 0)
- `sort` (optional): Sort field - `name`, `connectedAt` (default: `name`)

#### Success Response (200 OK)
```json
{
  "colleagues": [
    {
      "id": "conn_abc123",
      "did": "did:key:colleague_did",
      "name": "Colleague Name",
      "handle": "colleague",
      "email": "colleague@example.com",
      "address": "123 Colleague St",
      "affiliations": "Colleague Corp",
      "socialLinks": "colleague.com",
      "shortId": "COL-1234",
      "prettyDID": "colleague.did",
      "connectedAt": "2026-01-05T15:30:00Z",
      "lastInteractionAt": "2026-01-06T10:00:00Z",
      "notes": null,
      "isFavorite": false,
      "tags": ["work", "conference"]
    }
  ],
  "count": 1,
  "total": 1
}
```

#### Implementation Notes
- Return only connections where status is `accepted` AND user is either fromDID or toDID
- Include **full profile information** for all colleagues
- Support pagination for users with many colleagues
- Consider caching for performance
- Update `lastInteractionAt` when documents are shared

---

### 6. Remove Connection (Optional)

**DELETE** `/api/connections/{connectionId}`

Remove a colleague connection. Both users will no longer have access to each other's full profiles.

#### Request Headers
```
X-DID: did:key:user_did
```

#### Success Response (200 OK)
```json
{
  "success": true,
  "message": "Connection removed successfully"
}
```

#### Implementation Notes
- Verify user is part of the connection
- Mark connection as removed/deleted
- Consider soft delete vs hard delete
- Trigger notification to other party
- Historical documents remain accessible (or not - policy decision)

---

### 7. Block User (Optional)

**POST** `/api/connections/block`

Block a user from sending connection requests.

#### Request Body
```json
{
  "did": "did:key:blocked_user_did"
}
```

#### Success Response (200 OK)
```json
{
  "success": true,
  "message": "User blocked successfully"
}
```

#### Implementation Notes
- Add to blocked_users table
- Reject any pending requests from this user
- Prevent future requests from this user
- User can unblock later if desired

---

## Database Schema Suggestions

### connection_requests table
```sql
CREATE TABLE connection_requests (
  id VARCHAR(255) PRIMARY KEY,
  from_did VARCHAR(255) NOT NULL,
  to_did VARCHAR(255) NOT NULL,
  status VARCHAR(50) NOT NULL, -- pending, accepted, rejected, blocked, expired
  message TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  responded_at TIMESTAMP,
  expires_at TIMESTAMP, -- optional auto-expiration
  INDEX idx_from_did (from_did),
  INDEX idx_to_did (to_did),
  INDEX idx_status (status),
  UNIQUE INDEX idx_unique_pending (from_did, to_did, status)
    WHERE status = 'pending'
);
```

### connections table (accepted colleagues)
```sql
CREATE TABLE connections (
  id VARCHAR(255) PRIMARY KEY,
  user1_did VARCHAR(255) NOT NULL,
  user2_did VARCHAR(255) NOT NULL,
  connected_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_interaction_at TIMESTAMP,
  request_id VARCHAR(255), -- references connection_requests.id
  INDEX idx_user1 (user1_did),
  INDEX idx_user2 (user2_did),
  UNIQUE INDEX idx_unique_connection (user1_did, user2_did)
);
```

### blocked_users table (optional)
```sql
CREATE TABLE blocked_users (
  user_did VARCHAR(255) NOT NULL,
  blocked_did VARCHAR(255) NOT NULL,
  blocked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reason TEXT,
  PRIMARY KEY (user_did, blocked_did),
  INDEX idx_user_did (user_did)
);
```

---

## Security Considerations

### 1. Privacy Protection
- ✅ Never return email, address, or sensitive fields for non-connected users
- ✅ Only return full profiles after mutual acceptance
- ✅ Validate DID ownership before allowing actions

### 2. Rate Limiting
Suggested limits per user:
- Connection requests: 10 per hour
- Pending requests sync: 100 per hour
- Colleagues list: 100 per hour

### 3. Authentication
- Verify X-DID header contains valid DID
- Optional: Require signed requests for sensitive operations
- Check persona exists and is active

### 4. Spam Prevention
- Limit total pending requests per user (e.g., max 50)
- Auto-expire old pending requests (e.g., 30 days)
- Allow users to block spammers
- Track rejection patterns (if user rejects >10 requests from same person, auto-block)

### 5. Data Validation
- Validate DIDs are properly formatted
- Sanitize message content (prevent XSS)
- Limit message length (e.g., 500 characters)

---

## Testing Checklist

- [ ] Send connection request between two users
- [ ] Accept connection request
- [ ] Reject connection request
- [ ] Can't send duplicate request
- [ ] Can't accept request that's not yours
- [ ] Can't send request to already-connected user
- [ ] Pending requests return limited info
- [ ] Accepted connections return full info
- [ ] Rejected requests don't expose sensitive data
- [ ] Rate limiting works
- [ ] Blocked users can't send requests
- [ ] Expired requests are handled
- [ ] Pagination works for large lists
- [ ] Push notifications trigger properly

---

## Sample curl Commands

### Send Request
```bash
curl -X POST https://api.451.info/api/connections/request \
  -H "Content-Type: application/json" \
  -H "X-DID: did:key:sender123" \
  -d '{
    "toDID": "did:key:recipient456",
    "message": "Let'\''s connect!"
  }'
```

### Accept Request
```bash
curl -X POST https://api.451.info/api/connections/respond \
  -H "Content-Type: application/json" \
  -H "X-DID: did:key:recipient456" \
  -d '{
    "requestId": "req_abc123",
    "accept": true
  }'
```

### Get Pending
```bash
curl -X GET https://api.451.info/api/connections/pending \
  -H "X-DID: did:key:user123"
```

### Get Colleagues
```bash
curl -X GET https://api.451.info/api/connections/colleagues \
  -H "X-DID: did:key:user123"
```

---

**Implementation Priority**: High - Required for privacy-protected colleague system to function
**Estimated Backend Work**: 3-5 days (depending on notification system complexity)
