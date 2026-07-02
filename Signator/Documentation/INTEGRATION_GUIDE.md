# Integration Guide: Adding Connection Guards to Existing Views

## Quick Start

The connection system protects sensitive information by requiring mutual consent before sharing full profile details. Here's how to integrate it into your existing views.

## Basic Integration Pattern

### Before (Unsafe - Shows all info immediately)

```swift
struct SendDocumentView: View {
    let recipientDID: String
    @State private var recipientProfile: PersonaResolvedProfile?
    
    var body: some View {
        VStack {
            if let profile = recipientProfile {
                // ❌ Shows email, address, etc. without verification
                Text(profile.email ?? "")
                Text(profile.address ?? "")
                
                Button("Send Document") {
                    sendDocument()
                }
            }
        }
        .task {
            recipientProfile = try? await resolver.resolve(.raw(recipientDID))
        }
    }
}
```

### After (Safe - Requires connection first)

```swift
struct SendDocumentView: View {
    let recipientDID: String
    @ObservedObject var personaManager: PersonaManager
    
    var body: some View {
        ConnectionGuardView(
            recipientDID: recipientDID,
            recipientName: "Recipient Name",
            personaManager: personaManager
        ) {
            // ✅ This content only shows if connected
            VStack {
                Text("Send document to colleague")
                
                Button("Send Document") {
                    sendDocument()
                }
            }
        }
    }
}
```

## Integration Examples

### 1. Document Sending Flow

```swift
// SendSigningFlowView.swift
struct SendSigningFlowView: View {
    @StateObject private var connectionManager: ConnectionManager
    let document: Document
    
    var body: some View {
        NavigationStack {
            // Search for recipient
            RecipientSearchView { selectedDID in
                // Show connection guard
                ConnectionGuardView(
                    recipientDID: selectedDID,
                    personaManager: personaManager
                ) {
                    // Only shown if connected
                    DocumentSendConfirmation(
                        document: document,
                        recipientDID: selectedDID
                    )
                }
            }
        }
    }
}
```

### 2. Profile Viewing

```swift
struct PersonaDetailView: View {
    let did: String
    @ObservedObject var personaManager: PersonaManager
    @StateObject private var connectionManager: ConnectionManager
    
    init(did: String, personaManager: PersonaManager) {
        self.did = did
        self.personaManager = personaManager
        _connectionManager = StateObject(
            wrappedValue: ConnectionManager(personaManager: personaManager)
        )
    }
    
    var body: some View {
        VStack {
            // Always show basic info
            PublicProfileSection(did: did)
            
            // Protected information
            if let colleague = connectionManager.colleague(for: did) {
                // ✅ Connected - show full details
                PrivateProfileSection(colleague: colleague)
            } else if connectionManager.hasPendingRequest(did: did) {
                PendingConnectionBanner()
            } else {
                // Not connected - show request button
                Button("Connect to View Full Profile") {
                    showConnectionRequest = true
                }
            }
        }
    }
}
```

### 3. Colleague List Integration

Add to your main tab view:

```swift
// MainTabView.swift
struct MainTabView: View {
    @StateObject var personaManager = PersonaManager()
    
    var body: some View {
        TabView {
            DocumentsView()
                .tabItem { Label("Documents", systemImage: "doc.fill") }
            
            // Add colleagues tab
            ColleaguesView(personaManager: personaManager)
                .tabItem { Label("Colleagues", systemImage: "person.2.fill") }
            
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
```

### 4. Smart Contact Picker

```swift
struct SmartRecipientPicker: View {
    @StateObject private var connectionManager: ConnectionManager
    @State private var selectedRecipient: Colleague?
    
    var body: some View {
        VStack {
            // Show connected colleagues first
            Section("Colleagues") {
                ForEach(connectionManager.colleagues) { colleague in
                    Button {
                        selectedRecipient = colleague
                    } label: {
                        ColleagueRow(colleague: colleague)
                    }
                }
            }
            
            // Then allow manual search
            Section("Search Others") {
                RecipientSearchField { did in
                    // This will trigger connection guard if not connected
                    handleManualSearch(did)
                }
            }
        }
    }
}
```

## Conditional Information Display

Show different info based on connection status:

```swift
struct PersonaCard: View {
    let profile: PersonaResolvedProfile
    let connectionManager: ConnectionManager
    
    private var connectionStatus: ConnectionStatus {
        if connectionManager.isColleague(did: profile.did) {
            return .connected
        } else if connectionManager.hasPendingRequest(did: profile.did) {
            return .pending
        } else {
            return .notConnected
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            // Always show
            Text(profile.displayName)
                .font(.headline)
            
            if let shortId = profile.shortId {
                Text(shortId)
                    .font(.caption)
            }
            
            // Conditionally show based on connection
            switch connectionStatus {
            case .connected:
                if let colleague = connectionManager.colleague(for: profile.did) {
                    // ✅ Show everything
                    if let email = colleague.email {
                        Label(email, systemImage: "envelope")
                    }
                    if let address = colleague.address {
                        Label(address, systemImage: "location")
                    }
                }
                
            case .pending:
                Label("Connection pending...", systemImage: "clock")
                    .foregroundStyle(.orange)
                
            case .notConnected:
                Button("Connect to View Details") {
                    showConnectionRequest = true
                }
            }
        }
    }
}

enum ConnectionStatus {
    case connected
    case pending
    case notConnected
}
```

## Testing Checklist

Before deploying, test these scenarios:

### Basic Flow
- [ ] Search for colleague by short code shows limited info
- [ ] Connection request can be sent
- [ ] Recipient sees request notification
- [ ] Recipient can accept/reject
- [ ] After acceptance, full info is visible
- [ ] Rejected requests don't show sensitive data

### Edge Cases
- [ ] Can't send duplicate requests
- [ ] Can't send request to already-connected colleague
- [ ] Offline requests sync when back online
- [ ] Deleted personas handle gracefully
- [ ] Invalid DIDs show proper error

### Privacy Verification
- [ ] Email not visible before connection
- [ ] Address not visible before connection
- [ ] Phone not visible before connection
- [ ] Social links not visible before connection
- [ ] Only name/shortID/DID visible in search

### UI/UX
- [ ] Loading states show properly
- [ ] Error messages are user-friendly
- [ ] Success confirmations display
- [ ] Badge counts update for pending requests
- [ ] Navigation flows naturally

## Common Patterns

### Pattern 1: Check Before Showing Sensitive UI

```swift
func showDocumentSendSheet(recipientDID: String) {
    if connectionManager.isColleague(did: recipientDID) {
        // ✅ Show send sheet
        presentSendSheet()
    } else {
        // Show connection requirement
        presentConnectionGuard()
    }
}
```

### Pattern 2: Filter Lists by Connection Status

```swift
var availableRecipients: [Colleague] {
    connectionManager.colleagues.filter { colleague in
        // Only show colleagues who meet your criteria
        colleague.email != nil && !colleague.isBlocked
    }
}
```

### Pattern 3: Pre-check Before Navigation

```swift
NavigationLink {
    ConnectionGuardView(
        recipientDID: recipient.did,
        recipientName: recipient.name,
        personaManager: personaManager
    ) {
        DocumentDetailView(recipient: recipient)
    }
} label: {
    RecipientRow(recipient: recipient)
}
```

## Server Implementation Notes

Your server needs these endpoints (see CONNECTION_SYSTEM_README.md for details):

1. `POST /api/connections/request` - Send request
2. `POST /api/connections/respond` - Accept/reject request
3. `GET /api/connections/pending` - List incoming requests
4. `GET /api/connections/sent` - List outgoing requests
5. `GET /api/connections/colleagues` - List accepted connections

Each endpoint should:
- Authenticate using X-DID header
- Validate the requesting persona has permission
- Return limited profile info for non-connected personas
- Return full profile info only for connected colleagues
- Rate limit to prevent spam

## Migration Path

If you have existing code that doesn't use connections:

### Phase 1: Add Connection System
- Add ConnectionManager to your app
- Add ColleaguesView to navigation
- Don't enforce connections yet

### Phase 2: Add Guards to New Features
- Use ConnectionGuardView for new sensitive flows
- Let users build their colleague network

### Phase 3: Migrate Existing Features
- Add connection checks to existing document send flows
- Update profile views to respect connections
- Communicate changes to users

### Phase 4: Enforce Everywhere
- All sensitive operations require connections
- Remove direct DID-to-profile lookups that bypass connections
- Update documentation

## Troubleshooting

### "Connection required" shows for my own persona
- Check that PersonaResolver properly handles `@me`
- Ensure activePersona is set correctly

### Requests not syncing
- Check network connectivity
- Verify X-DID header is being sent
- Check server logs for authentication issues

### Full profile showing before connection
- Search for direct PersonaResolvedProfile usage
- Ensure all profile views check connection status
- Use ConnectionGuardView wrapper

### Can't connect to anyone
- Verify server endpoints are responding
- Check that DID is properly authenticated
- Test with curl/Postman first

---

**Remember**: The goal is to protect user privacy while still enabling discovery and collaboration. Always prefer requiring explicit connection over exposing sensitive information.
