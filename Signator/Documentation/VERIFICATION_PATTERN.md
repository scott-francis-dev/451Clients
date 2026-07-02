# Generic Verification Pattern

## Overview

This document describes a reusable pattern for implementing bidirectional verification flows across the 451Wallet app. This pattern is used for colleague verification and can be extended to document validation, author verification, and human-to-persona verification.

## Core Components

### 1. Verification Status Enum

```swift
enum VerificationStatus: String, Codable, Equatable {
    case unverified = "unverified"         // Added but not verified
    case pendingVerification = "pending"   // Verification request sent
    case verified = "verified"             // Mutually verified
    case rejected = "rejected"             // Verification rejected
}
```

This can be adapted for different verification contexts:
- **Colleague Verification**: Person-to-person identity confirmation
- **Document Verification**: Document integrity and authorship
- **Human-to-Persona**: Linking a real human to a digital persona
- **Witness Attestation**: Third-party verification of facts

### 2. Verification Flow States

```
┌─────────────┐
│ Unverified  │ ──┐
└─────────────┘   │
                  │ User taps "Verify"
                  ↓
          ┌───────────────────┐
          │ Send Verification │
          │     Request       │
          └───────────────────┘
                  │
                  ↓
       ┌─────────────────────┐
       │ Pending Verification│
       └─────────────────────┘
                  │
         ┌────────┴────────┐
         ↓                 ↓
    ┌──────────┐      ┌──────────┐
    │ Verified │      │ Rejected │
    └──────────┘      └──────────┘
```

### 3. UI Pattern

#### Visual Indicators
- **Unverified**: Orange badge with exclamation mark + "Tap to Verify" label
- **Pending**: Blue badge with clock icon + "Verification Pending" label
- **Verified**: Green badge with checkmark + verified indicator
- **Rejected**: Red badge with X mark + rejected indicator

#### Interaction Pattern
1. Display item with verification status badge
2. Make item tappable when unverified
3. Show confirmation alert explaining the verification
4. Send verification request through server
5. Update local state to "pending"
6. Listen for server response via notifications/polling
7. Update state to "verified" or "rejected"

### 4. Backend Integration

#### Request Flow
```
Client A (Requester)          Server                Client B (Recipient)
      |                         |                           |
      |---Send Request--------->|                           |
      |                         |----Notification---------->|
      |                         |                           |
      |                         |<---Accept/Reject----------|
      |<--Update Status---------|                           |
```

#### API Endpoints (Generic Pattern)
```
POST /api/{resource}/verification/request
- Body: { targetDID, message?, context? }
- Returns: { requestId, status }

GET /api/{resource}/verification/pending
- Returns: { requests: [...] }

POST /api/{resource}/verification/respond
- Body: { requestId, accept: boolean, message? }
- Returns: { success: boolean }
```

## Implementation Example: Colleague Verification

### Model Updates
```swift
struct Colleague: Identifiable, Codable {
    let id: String
    let did: String
    let name: String
    var verificationStatus: VerificationStatus = .unverified
    // ... other properties
}
```

### Manager Methods
```swift
func addUnverifiedColleague(...) {
    let colleague = Colleague(
        id: UUID().uuidString,
        verificationStatus: .unverified
        // ...
    )
    colleagues.append(colleague)
}

func sendVerificationRequest(to colleague: Colleague) async throws {
    _ = try await connectionManager.sendConnectionRequest(
        toDID: colleague.did,
        message: "Verification request"
    )
    
    var updated = colleague
    updated.verificationStatus = .pendingVerification
    updateColleague(updated)
}
```

### UI Components
```swift
// Row with verification badge
struct ItemRow: View {
    let item: Item
    
    var body: some View {
        HStack {
            // Avatar with badge overlay
            ZStack(alignment: .bottomTrailing) {
                Avatar(...)
                VerificationBadge(status: item.verificationStatus)
            }
            
            // Content with status label
            VStack(alignment: .leading) {
                Text(item.name)
                if item.verificationStatus != .verified {
                    StatusLabel(status: item.verificationStatus)
                }
            }
        }
    }
}

// List with tap handling
List {
    ForEach(items) { item in
        Button {
            handleItemTap(item)
        } label: {
            ItemRow(item: item)
        }
    }
}

private func handleItemTap(_ item: Item) {
    switch item.verificationStatus {
    case .unverified:
        showVerificationAlert(for: item)
    case .pendingVerification:
        showPendingInfo(for: item)
    case .verified:
        showDetails(for: item)
    case .rejected:
        showRejectedInfo(for: item)
    }
}
```

## Extending to Other Validation Types

### Document Integrity Validation
```swift
struct Document {
    let guid: String
    var integrityStatus: VerificationStatus = .unverified
}

// Tap unverified document → Send to server for validation
// Server checks signatures, hashes, timestamps
// Return verified or rejected status
```

### Author/Signer Validation
```swift
struct DocumentAuthor {
    let documentDID: String
    let personaDID: String
    var authorshipStatus: VerificationStatus = .unverified
}

// Tap unverified author → Send verification request
// Other party confirms they signed the document
// Status updates to verified
```

### Human-to-Persona Validation
```swift
struct PersonaIdentity {
    let personaDID: String
    var humanVerificationStatus: VerificationStatus = .unverified
    var verificationMethod: String? // "ID Card", "Biometric", "In-Person"
}

// Tap unverified persona → Request verification
// Send to verification service (ID check, video call, etc.)
// Return verified status with method used
```

## Notification Integration

When verification requests are received, use the notification system to:

1. **Push Notification**: Alert user of incoming verification request
2. **In-App Badge**: Show count on relevant tab
3. **Request List**: Display in dedicated "Requests" section
4. **Action Buttons**: Accept/Decline directly from notification or list

Example notification payload:
```json
{
  "type": "verification_request",
  "resourceType": "colleague",
  "requestId": "req_123",
  "fromDID": "did:example:alice",
  "message": "Alice wants to verify your connection",
  "timestamp": "2026-01-06T10:30:00Z"
}
```

## Best Practices

1. **Always Show Status**: Make verification state visible at a glance
2. **Make It Tappable**: Unverified items should invite interaction
3. **Explain the Process**: Use clear language in alerts/sheets
4. **Provide Context**: Include optional messages with requests
5. **Handle Edge Cases**: Network failures, timeouts, duplicate requests
6. **Update Optimistically**: Show pending state immediately, revert on failure
7. **Sync Regularly**: Fetch latest verification statuses on app launch/tab selection
8. **Cache Locally**: Store verification state for offline viewing

## Server Requirements

For this pattern to work fully, the server needs:

1. **Request Storage**: Store verification requests with status
2. **Notification System**: Push notifications for new requests
3. **Status Updates**: Broadcast status changes to both parties
4. **Request Expiry**: Optional timeout for pending requests
5. **Duplicate Prevention**: Check for existing requests before creating new ones

## Future Enhancements

- **Multi-Step Verification**: Chain multiple verification types (e.g., colleague → document → author)
- **Verification Levels**: Different trust levels (basic, enhanced, in-person)
- **Verification History**: Log of all verification attempts and outcomes
- **Batch Verification**: Verify multiple items at once
- **QR Code Verification**: Scan QR code for in-person verification
- **Time-Limited Verification**: Verifications that expire after a period
