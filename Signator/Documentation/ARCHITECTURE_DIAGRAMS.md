# Connection System Architecture Diagrams

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS/iPadOS App                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌──────────────────┐                  │
│  │  PersonaManager │    │ PersonaResolver  │                  │
│  │  (User's IDs)   │◄───┤ (Lookup others)  │                  │
│  └────────┬────────┘    └──────────────────┘                  │
│           │                                                     │
│           │                                                     │
│  ┌────────▼──────────────────────────────────────┐            │
│  │       ConnectionManager                        │            │
│  │  ┌──────────────────────────────────────┐    │            │
│  │  │  Colleagues (Accepted Connections)   │    │            │
│  │  │  • Full profile access                │    │            │
│  │  │  • Can send documents                 │    │            │
│  │  │  • Can collaborate                    │    │            │
│  │  └──────────────────────────────────────┘    │            │
│  │  ┌──────────────────────────────────────┐    │            │
│  │  │  Pending Requests (Incoming)         │    │            │
│  │  │  • Limited info shown                 │    │            │
│  │  │  • Accept/Reject options              │    │            │
│  │  └──────────────────────────────────────┘    │            │
│  │  ┌──────────────────────────────────────┐    │            │
│  │  │  Sent Requests (Outgoing)            │    │            │
│  │  │  • Track request status               │    │            │
│  │  └──────────────────────────────────────┘    │            │
│  └───────────────────┬────────────────────────┬──┘            │
│                      │                        │                │
│  ┌───────────────────▼──────┐   ┌────────────▼──────────┐    │
│  │   ColleaguesView (UI)    │   │  ConnectionGuardView  │    │
│  │  • Manage connections     │   │  • Protect sensitive  │    │
│  │  • Send/Accept requests   │   │    content            │    │
│  │  • View colleagues        │   │  • Require connection │    │
│  └──────────────────────────┘   └───────────────────────┘    │
│                                                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ HTTPS (X-DID header)
                         │
┌────────────────────────▼────────────────────────────────────────┐
│                      Server API                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  POST /api/connections/request        Send connection request   │
│  POST /api/connections/respond        Accept/reject request     │
│  GET  /api/connections/pending        List incoming requests    │
│  GET  /api/connections/sent           List outgoing requests    │
│  GET  /api/connections/colleagues     List accepted connections │
│                                                                  │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │
┌────────────────────────▼────────────────────────────────────────┐
│                       Database                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────┐                   │
│  │  connection_requests                     │                   │
│  │  • id, from_did, to_did, status          │                   │
│  │  • message, created_at, responded_at     │                   │
│  └─────────────────────────────────────────┘                   │
│                                                                  │
│  ┌─────────────────────────────────────────┐                   │
│  │  connections (accepted)                  │                   │
│  │  • id, user1_did, user2_did              │                   │
│  │  • connected_at, last_interaction_at     │                   │
│  └─────────────────────────────────────────┘                   │
│                                                                  │
│  ┌─────────────────────────────────────────┐                   │
│  │  personas                                 │                   │
│  │  • did, name, email, address, etc.       │                   │
│  └─────────────────────────────────────────┘                   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Data Flow: Sending Connection Request

```
┌──────────┐                                      ┌──────────┐
│  User A  │                                      │  User B  │
└────┬─────┘                                      └────┬─────┘
     │                                                 │
     │ 1. Search "ABC-1234"                            │
     │───────────┐                                     │
     │           │                                     │
     │◄──────────┘                                     │
     │ PersonaResolvedProfile                          │
     │ • name: "Bob Smith"                             │
     │ • shortId: "ABC-1234"                           │
     │ • email: NULL (hidden)                          │
     │ • address: NULL (hidden)                        │
     │                                                 │
     │ 2. Click "Send Connection Request"              │
     │──────────────────────────►Server                │
     │                              │                  │
     │                              │ 3. Create request│
     │                              │    status=pending│
     │                              │                  │
     │                              │ 4. Send push     │
     │                              │    notification  │
     │                              ├─────────────────►│
     │                              │                  │
     │                              │                  │ 5. View request
     │                              │                  │    (limited info)
     │                              │                  │
     │                              │ 6. Click Accept  │
     │                              │◄─────────────────┤
     │                              │                  │
     │                              │ 7. Update status │
     │                              │    status=accepted│
     │                              │    Add connection│
     │                              │                  │
     │ 8. Push notification         │                  │
     │◄─────────────────────────────┤                  │
     │                              │                  │
     │ 9. Sync colleagues           │                  │
     │──────────────────────────────►                  │
     │◄─────────────────────────────┤                  │
     │ Colleague object              │                  │
     │ • name: "Bob Smith"           │                  │
     │ • email: "bob@example.com" ✓  │                  │
     │ • address: "123 Main St" ✓    │                  │
     │                              │                  │
     │           CONNECTED          │                  │
     │◄─────────────────────────────┼─────────────────►│
     │     Full access granted       │                  │
     │                              │                  │
```

---

## State Machine: Connection Request Lifecycle

```
                    ┌──────────────┐
                    │  Not Connected│
                    └───────┬───────┘
                            │
                            │ User sends request
                            │
                    ┌───────▼────────┐
                    │    PENDING     │
                    │                │
                    │ • Limited info │
                    │ • Can accept   │
                    │ • Can reject   │
                    └───┬────────┬───┘
                        │        │
            Accept      │        │      Reject/Block
                        │        │
          ┌─────────────▼─┐    ┌▼──────────────┐
          │   ACCEPTED     │    │   REJECTED    │
          │                │    │               │
          │ • Full access  │    │ • No access   │
          │ • Can send docs│    │ • Request ends│
          └────────────────┘    └───────────────┘
                   │
                   │ Either user removes
                   │
          ┌────────▼─────────┐
          │    REMOVED       │
          │                  │
          │ • Access revoked │
          │ • Can re-request │
          └──────────────────┘
```

---

## Information Disclosure Matrix

```
┌─────────────────────┬────────────┬────────────┬──────────────┐
│   Information       │  Public    │  Pending   │  Connected   │
│                     │ (Discovery)│  Request   │  (Accepted)  │
├─────────────────────┼────────────┼────────────┼──────────────┤
│ DID                 │     ✅     │     ✅     │      ✅      │
│ Name                │     ✅     │     ✅     │      ✅      │
│ Short ID            │     ✅     │     ✅     │      ✅      │
│ Pretty DID          │     ✅     │     ✅     │      ✅      │
│ Handle (@username)  │     ❌     │     ❌     │      ✅      │
│ Email               │     ❌     │     ❌     │      ✅      │
│ Phone               │     ❌     │     ❌     │      ✅      │
│ Address             │     ❌     │     ❌     │      ✅      │
│ Affiliations        │     ❌     │     ❌     │      ✅      │
│ Social Links        │     ❌     │     ❌     │      ✅      │
│ Documents           │     ❌     │     ❌     │      ✅      │
└─────────────────────┴────────────┴────────────┴──────────────┘

Legend:
✅ = Visible/Accessible
❌ = Hidden/Protected
```

---

## Component Interaction Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                        App Layer                               │
└────────────────────────────────────────────────────────────────┘
         │                    │                    │
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌──────────────────┐
│ ColleaguesView  │  │DocumentSendView │  │  ProfileView     │
│                 │  │                 │  │                  │
│ • Show list     │  │ • Check conn.   │  │ • Show limited   │
│ • Manage req.   │  │ • Guard send    │  │   or full info   │
└────────┬────────┘  └────────┬────────┘  └────────┬─────────┘
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
                              ▼
                 ┌────────────────────────┐
                 │  ConnectionManager     │
                 │                        │
                 │  • isColleague()       │
                 │  • hasPendingRequest() │
                 │  • sendRequest()       │
                 │  • acceptRequest()     │
                 │  • syncAll()           │
                 └───────────┬────────────┘
                             │
                             │ Uses
                             ▼
           ┌─────────────────────────────────┐
           │     PersonaResolver              │
           │                                  │
           │  • resolve(did)                  │
           │  • resolveString(shortCode)      │
           │  • Returns limited info          │
           └──────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│                       Storage Layer                            │
└────────────────────────────────────────────────────────────────┘

    ┌──────────────────┐         ┌───────────────────┐
    │ SharedContainer  │         │  Server API       │
    │                  │         │                   │
    │ • Colleagues     │         │ • /request        │
    │ • Pending reqs   │         │ • /respond        │
    │ • Sent reqs      │         │ • /pending        │
    │ • Cache          │         │ • /colleagues     │
    └──────────────────┘         └───────────────────┘
```

---

## Security Flow: Protected Operation

```
User wants to send document to someone
           │
           ▼
   ┌───────────────────┐
   │ Is DID connected? │
   └───────┬───────────┘
           │
     ┌─────┴─────┐
     │           │
    YES         NO
     │           │
     ▼           ▼
┌─────────┐  ┌──────────────────┐
│ Allow   │  │ Show Connection  │
│ Send    │  │ Guard Screen     │
│         │  │                  │
│ • Show  │  │ Options:         │
│   full  │  │ 1. Send request  │
│   info  │  │ 2. Cancel        │
│ • Enable│  │                  │
│   send  │  │ Limited info:    │
│   button│  │ • Name visible   │
└─────────┘  │ • Email hidden   │
             └──────────────────┘
                     │
                     │ User sends request
                     ▼
             ┌────────────────┐
             │  Request sent  │
             │  Status: ⏳    │
             │                │
             │ Wait for       │
             │ acceptance     │
             └────────────────┘
                     │
                     │ Notification: Accepted
                     ▼
             ┌────────────────┐
             │ Now connected! │
             │ Retry send?    │
             └────────────────┘
```

---

## Database Schema Relationships

```
┌──────────────────────────────────────────────────────────┐
│                         personas                          │
├──────────────────────────────────────────────────────────┤
│ did (PK)                                                 │
│ name                                                      │
│ email                                                     │
│ address                                                   │
│ ...other fields...                                        │
└────────────┬──────────────────────┬──────────────────────┘
             │                      │
             │                      │
    ┌────────▼───────┐    ┌────────▼────────┐
    │ from_did (FK)  │    │ to_did (FK)     │
    │                │    │                 │
┌───▼────────────────▼────▼─────────────────────────────────┐
│                 connection_requests                        │
├───────────────────────────────────────────────────────────┤
│ id (PK)                                                   │
│ from_did (FK → personas.did)                              │
│ to_did (FK → personas.did)                                │
│ status (pending|accepted|rejected)                        │
│ message                                                    │
│ created_at                                                 │
│ responded_at                                               │
└────────────────────────┬───────────────────────────────────┘
                         │
                         │ request_id (FK)
                         │
┌────────────────────────▼───────────────────────────────────┐
│                     connections                            │
├───────────────────────────────────────────────────────────┤
│ id (PK)                                                   │
│ user1_did (FK → personas.did)                             │
│ user2_did (FK → personas.did)                             │
│ connected_at                                               │
│ last_interaction_at                                        │
│ request_id (FK → connection_requests.id)                  │
└───────────────────────────────────────────────────────────┘

Query Examples:

-- Get all colleagues for a user
SELECT * FROM connections 
WHERE user1_did = ? OR user2_did = ?

-- Get pending requests for a user
SELECT * FROM connection_requests 
WHERE to_did = ? AND status = 'pending'

-- Check if connected
SELECT COUNT(*) FROM connections 
WHERE (user1_did = ? AND user2_did = ?) 
   OR (user1_did = ? AND user2_did = ?)
```

---

## Mobile App Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    451Wallet App                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │               Main Tab View                          │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │  Documents  │  Colleagues  │  Settings               │  │
│  └──────────────┬──────────────┬──────────────┬─────────┘  │
│                 │              │              │            │
│   ┌─────────────▼──┐   ┌───────▼───────┐   ┌▼────────┐   │
│   │ DocumentsView  │   │ColleaguesView │   │Settings │   │
│   │                │   │               │   │View     │   │
│   │ • List docs    │   │ • List ✓      │   └─────────┘   │
│   │ • Send docs    │   │ • Pending (2) │               │
│   │ • Sign docs    │   │ • Sent (1)    │               │
│   └────────┬───────┘   └───────┬───────┘               │
│            │                   │                         │
│            │ Uses              │ Uses                    │
│            │ ┌─────────────────▼───────────────┐        │
│            │ │   ConnectionManager             │        │
│            └─►   (@StateObject shared)         │        │
│              └─────────────────┬───────────────┘        │
│                                │                         │
│  ┌─────────────────────────────▼─────────────────┐      │
│  │        Connection Storage                     │      │
│  │  (UserDefaults / SharedContainer)             │      │
│  ├───────────────────────────────────────────────┤      │
│  │  • colleagues_list.json                       │      │
│  │  • pending_requests_list.json                 │      │
│  │  • sent_requests_list.json                    │      │
│  └───────────────────────────────────────────────┘      │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## Key Takeaways

1. **Three-level privacy**: Public → Pending → Connected
2. **Server controls disclosure**: Returns limited vs full profile based on connection status
3. **Mutual consent required**: Both parties must agree to share full information
4. **Local state + server sync**: App maintains local copy, syncs with server
5. **Guard views protect**: ConnectionGuardView prevents unauthorized access
6. **Rich UI**: Dedicated colleagues management interface
7. **Testable**: Unit tests verify privacy protection

---

For implementation details, see:
- **CONNECTION_SYSTEM_README.md** - Full technical specification
- **INTEGRATION_GUIDE.md** - How to integrate into your code
- **SERVER_API_SPEC.md** - Server API endpoints
- **QUICK_REFERENCE.md** - Developer quick reference
