# Connection System Quick Reference

## 🚀 Quick Start (3 Steps)

### 1. Add Colleagues Tab
```swift
// In MainTabView.swift
TabView {
    // ... existing tabs
    
    ColleaguesView(personaManager: personaManager)
        .tabItem { Label("Colleagues", systemImage: "person.2.fill") }
}
```

### 2. Protect Sensitive Content
```swift
// Wrap any view that shows sensitive info
ConnectionGuardView(
    recipientDID: theirDID,
    recipientName: theirName,
    personaManager: personaManager
) {
    YourProtectedContentView()
}
```

### 3. Check Connection Status
```swift
let manager = ConnectionManager(personaManager: personaManager)

if manager.isColleague(did: someDID) {
    // ✅ Connected - show full info
} else {
    // ❌ Not connected - prompt to connect
}
```

---

## 📋 Common Patterns

### Pattern: Check Before Sending Document
```swift
struct SendDocumentView: View {
    let recipientDID: String
    @ObservedObject var connectionManager: ConnectionManager
    
    var body: some View {
        if connectionManager.isColleague(did: recipientDID) {
            // ✅ Allow sending
            DocumentSendForm()
        } else {
            // Show connection requirement
            ConnectionRequiredView(recipientDID: recipientDID)
        }
    }
}
```

### Pattern: Show Limited vs Full Profile
```swift
struct ProfileView: View {
    let profile: PersonaResolvedProfile
    @ObservedObject var connectionManager: ConnectionManager
    
    var body: some View {
        VStack {
            // Always show
            Text(profile.displayName)
            if let shortId = profile.shortId {
                Text(shortId)
            }
            
            // Only show if connected
            if let colleague = connectionManager.colleague(for: profile.did) {
                if let email = colleague.email {
                    Label(email, systemImage: "envelope")
                }
                if let address = colleague.address {
                    Label(address, systemImage: "location")
                }
            } else {
                Button("Connect to View Full Profile") {
                    showConnectionRequest = true
                }
            }
        }
    }
}
```

### Pattern: Pre-filter Lists
```swift
// Only show connected colleagues in picker
var availableRecipients: [Colleague] {
    connectionManager.colleagues
        .filter { $0.email != nil }
        .sorted { $0.name < $1.name }
}

Picker("Recipient", selection: $selectedColleague) {
    ForEach(availableRecipients) { colleague in
        Text(colleague.displayName).tag(colleague)
    }
}
```

---

## 🔒 Privacy Rules

### ❌ Never Do This
```swift
// BAD: Shows sensitive info without checking connection
let profile = try await resolver.resolve(.raw(someDID))
Text(profile.email ?? "")  // ❌ Privacy violation!
```

### ✅ Always Do This
```swift
// GOOD: Check connection first
if let colleague = connectionManager.colleague(for: someDID) {
    Text(colleague.email ?? "No email")  // ✅ Safe
} else {
    Text("Connect to view email")
}
```

---

## 🎯 What's Protected

### Public (Before Connection)
- ✅ Name
- ✅ Short ID (ABC-1234)
- ✅ DID
- ✅ Pretty DID

### Protected (Requires Connection)
- 🔒 Email address
- 🔒 Physical address
- 🔒 Phone number
- 🔒 Social links
- 🔒 Affiliations
- 🔒 Any custom sensitive fields

---

## 🛠️ Key Classes

### ConnectionManager
```swift
// Create (usually once per app)
let manager = ConnectionManager(personaManager: personaManager)

// Check status
manager.isColleague(did: String) -> Bool
manager.hasPendingRequest(did: String) -> Bool
manager.colleague(for: String) -> Colleague?

// Send request
try await manager.sendConnectionRequest(toDID: String, message: String?)

// Respond
try await manager.acceptConnectionRequest(ConnectionRequest)
try await manager.rejectConnectionRequest(ConnectionRequest)

// Sync with server
try await manager.syncAll()
```

### ConnectionGuardView
```swift
ConnectionGuardView(
    recipientDID: "did:key:...",
    recipientName: "Optional Name",
    personaManager: personaManager
) {
    // Content only shown if connected
    ProtectedContent()
}
```

---

## 🔄 Request Flow

```
User A                     Server                      User B
  |                          |                           |
  |--Search "ABC-1234"------>|                           |
  |<-Return limited info-----|                           |
  |                          |                           |
  |--Send request----------->|                           |
  |                          |--Notify------------------>|
  |                          |                           |
  |                          |<-Accept/Reject-----------|
  |<-Notify------------------|                           |
  |                          |                           |
  |<---Full info now accessible------------------------>|
```

---

## 📊 Data Models

### ConnectionRequest
```swift
struct ConnectionRequest {
    let id: String
    let fromDID: String
    let toDID: String
    var status: ConnectionStatus  // pending, accepted, rejected
    let createdAt: Date
    var requesterPreview: ConnectionPreview?  // Limited info
    var recipientPreview: ConnectionPreview?  // Limited info
}
```

### Colleague
```swift
struct Colleague {
    let did: String
    let name: String
    let email: String?        // Full info available
    let address: String?      // Full info available
    // ... all profile fields
    var notes: String?        // Private notes
    var isFavorite: Bool
}
```

---

## 🧪 Testing

```swift
@Test("Privacy protection before connection")
func testPrivacyProtection() async throws {
    let profile = try await resolver.resolve(.raw("ABC-1234"))
    
    // Should NOT have sensitive info
    #expect(profile.email == nil)
    #expect(profile.address == nil)
    
    // Should have public info
    #expect(profile.name != nil)
    #expect(profile.shortId != nil)
}

@Test("Full access after connection")
func testFullAccess() async throws {
    let manager = ConnectionManager(personaManager: personaManager)
    let colleague = manager.colleague(for: someDID)
    
    // Should have full info
    #expect(colleague?.email != nil)
    #expect(colleague?.address != nil)
}
```

---

## ⚡ Performance Tips

1. **Cache ConnectionManager**: Create once, reuse everywhere
```swift
// In your App or root view
@StateObject private var connectionManager: ConnectionManager
```

2. **Sync in background**: Don't block UI
```swift
Task.detached {
    try? await connectionManager.syncAll()
}
```

3. **Use local checks first**: Don't hit server unnecessarily
```swift
// Fast local check
if manager.isColleague(did: did) {
    // Show immediately
}
// Then sync in background
Task { try? await manager.syncColleagues() }
```

---

## 🚨 Common Errors

### "No active persona for @me"
**Fix**: Ensure user has selected an active persona
```swift
guard personaManager.activePersona() != nil else {
    // Prompt user to select/create persona
    return
}
```

### "Connection already exists"
**Fix**: Check before sending request
```swift
if !manager.isColleague(did: did) && !manager.hasPendingRequest(did: did) {
    try await manager.sendConnectionRequest(toDID: did)
}
```

### "Request has already been responded to"
**Fix**: Sync before showing request
```swift
try await manager.syncPendingRequests()
```

---

## 📱 UI Patterns

### Badge for Pending Requests
```swift
TabView {
    ColleaguesView()
        .tabItem { Label("Colleagues", systemImage: "person.2") }
        .badge(connectionManager.pendingRequests.count)
}
```

### Connection Status Indicator
```swift
func statusIcon(for did: String) -> String {
    if connectionManager.isColleague(did: did) {
        return "checkmark.circle.fill"  // Connected
    } else if connectionManager.hasPendingRequest(did: did) {
        return "clock.fill"  // Pending
    } else {
        return "person.badge.plus"  // Not connected
    }
}
```

### Inline Connection Button
```swift
HStack {
    Text(profile.displayName)
    Spacer()
    if !connectionManager.isColleague(did: profile.did) {
        Button("Connect") {
            showConnectionRequest = true
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
```

---

## 🎨 SwiftUI Modifiers

### Custom Connection Badge
```swift
extension View {
    func connectionBadge(for did: String, manager: ConnectionManager) -> some View {
        self.overlay(alignment: .topTrailing) {
            if manager.isColleague(did: did) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                    .padding(4)
            }
        }
    }
}

// Usage
ProfileImage()
    .connectionBadge(for: did, manager: connectionManager)
```

---

## 📚 Files to Reference

| Need | See File |
|------|----------|
| How it works | `CONNECTION_SYSTEM_README.md` |
| Integration examples | `INTEGRATION_GUIDE.md` |
| API details | `SERVER_API_SPEC.md` |
| Complete overview | `IMPLEMENTATION_SUMMARY.md` |
| This card | `QUICK_REFERENCE.md` |

---

## ✅ Pre-Flight Checklist

Before going live:
- [ ] Server API endpoints implemented
- [ ] ConnectionManager integrated into app
- [ ] ColleaguesView added to navigation
- [ ] Sensitive views wrapped with ConnectionGuardView
- [ ] Document send flow checks connections
- [ ] Profile views respect connection status
- [ ] Tests passing
- [ ] Privacy policy updated
- [ ] User documentation ready

---

**Remember**: When in doubt, require connection first! Better to ask permission than expose private data.
