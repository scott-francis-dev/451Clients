# Client-Side Logging Implementation Guide

## Overview

This document describes the comprehensive client-side logging system implemented to help trace and debug application behavior, particularly around document signing workflows.

## What Was Added

### 1. **ClientLogger.swift** - Centralized Logging Utility

A new centralized logging system that provides:
- **Structured logging** with severity levels (DEBUG, INFO, WARNING, ERROR)
- **Request ID tracking** for correlating related logs (similar to server logs)
- **Component-based logging** for easy filtering
- **Conditional logging** (can be disabled in production)
- **Consistent formatting** matching server-side log format

### 2. **Enhanced MainTabView.swift Logging**

Added comprehensive logging to two critical functions:

#### `loadPendingDocuments()` - Sign Requests View
Logs every step of fetching pending documents:
- Request initiation with unique request ID
- Number of personas being queried
- Each persona DID being checked
- API call to DocumentSigningService
- Number of documents returned
- Document details (title, status, ID)
- Status breakdown (pending/signed/finalized)
- Any errors with detailed context

#### `signDocument()` - Document Signing Detail View
Logs the entire signing process:
- Document being signed
- Selected persona
- Private key loading from keychain
- Document hash decoding
- Ledger chain linking (previous entry ID)
- API call to add signature
- Server response details
- Success or error outcomes

### 3. **DocumentSigningService Enhancement**

Modified the `debugLog()` function to:
- Use the centralized `ClientLogger` instead of direct `print()` statements
- Work in both DEBUG and RELEASE builds (controllable via `ClientLogger.isEnabled`)
- Provide consistent formatting across all service logs

## Log Format

All logs follow this format:

```
[ LEVEL ] [Component] [request-id: UUID] Message (File:Line)
```

Examples:
```
[ INFO ] [SignRequestsView] [request-id: A2FC6EBC-585C-4F01-B432-062B28333091] Starting loadPendingDocuments()
[ INFO ] [SignRequestsView] [request-id: A2FC6EBC-585C-4F01-B432-062B28333091] Found 3 persona(s)
[ DEBUG ] [SignRequestsView] [request-id: A2FC6EBC-585C-4F01-B432-062B28333091] Persona[0]: long.luke@cool.luke
[ INFO ] [DocumentSigningService] 📥 Fetching pending documents for signer: long.luke@cool.luke
[ INFO ] [SignRequestsView] [request-id: A2FC6EBC-585C-4F01-B432-062B28333091] ✅ Received 2 pending document(s) from service
```

## How to Use

### Basic Logging

```swift
// Import is automatic if in same module
ClientLogger.info(component: LogComponent.signRequestsView, "User tapped refresh button")
```

### Logging with Request ID (Recommended for Async Operations)

```swift
func fetchData() async {
    let requestID = RequestIDGenerator.generate()
    
    ClientLogger.info(component: LogComponent.signRequestsView, "Starting fetch", requestID: requestID)
    
    do {
        let data = try await service.fetch()
        ClientLogger.info(component: LogComponent.signRequestsView, "✅ Received \(data.count) items", requestID: requestID)
    } catch {
        ClientLogger.error(component: LogComponent.signRequestsView, "Failed to fetch: \(error)", requestID: requestID)
    }
}
```

### Available Log Levels

```swift
ClientLogger.debug(component: "MyView", "Detailed debug information")
ClientLogger.info(component: "MyView", "General information")
ClientLogger.warning(component: "MyView", "Something unusual happened")
ClientLogger.error(component: "MyView", "An error occurred")
```

### Predefined Component Names

Use the constants in `LogComponent` for consistency:

```swift
LogComponent.signRequestsView
LogComponent.documentSigningDetail
LogComponent.documentService
LogComponent.personaManager
LogComponent.contactsView
LogComponent.networkClient
```

## Controlling Logging

### Enable/Disable Globally

```swift
// In AppDelegate or main App struct
ClientLogger.isEnabled = false  // Disable all logging
ClientLogger.isEnabled = true   // Enable logging
```

By default, logging is:
- **Enabled** in DEBUG builds
- **Disabled** in RELEASE builds

You can override this by setting `ClientLogger.isEnabled` explicitly.

## Comparison with Server Logs

Your client logs now match the server log format:

**Server:**
```
[ INFO ] [PENDING SIGNATURES] Searching for documents requiring signatures from: long.luke@cool.luke [request-id: 87690075-B060-4498-80C6-31E8BAA3374A]
[ INFO ] [PENDING SIGNATURES] ✅ Returning 0 documents requiring signatures [request-id: 87690075-B060-4498-80C6-31E8BAA3374A]
```

**Client:**
```
[ INFO ] [SignRequestsView] [request-id: 87690075-B060-4498-80C6-31E8BAA3374A] Calling DocumentSigningService.fetchAllPendingDocuments() for 3 DID(s)
[ INFO ] [SignRequestsView] [request-id: 87690075-B060-4498-80C6-31E8BAA3374A] ✅ Received 0 pending document(s) from service
```

## Debugging Tips

### 1. Finding Missing Documents

When the server says documents exist but the client doesn't see them:

**Check these logs:**
- Client: "Found X persona(s)" - Are all personas being checked?
- Client: "Persona[0]: did:example..." - Are the DIDs correct?
- Server: "Searching for documents requiring signatures from: ..." - Does it match client DIDs?
- Client: "✅ Received X pending document(s)" - What's the count?
- Client: Status breakdown - Are they in the wrong status?

### 2. Tracking Request Flow

Use request IDs to trace a single operation:

```bash
# Filter logs for a specific request
grep "request-id: A2FC6EBC" client.log server.log
```

### 3. Common Issues

**No logs appearing:**
- Check that you're in DEBUG mode or have set `ClientLogger.isEnabled = true`
- Verify console output is not being filtered

**Logs appear but no server response:**
- Check the "Calling DocumentSigningService..." log
- Look for network errors in the catch block
- Verify ServerConfig.baseURL is correct

**Server returns data but UI doesn't update:**
- Check "Updated UI with X request(s)" log
- Verify status breakdown matches expectations
- Look for SwiftUI update issues on main thread

## Example Complete Flow

Here's what a successful pending document fetch looks like:

```
[ INFO ] [SignRequestsView] [request-id: ABC123] Starting loadPendingDocuments()
[ INFO ] [SignRequestsView] [request-id: ABC123] Found 3 persona(s)
[ DEBUG ] [SignRequestsView] [request-id: ABC123] Persona[0]: alice@example.com
[ DEBUG ] [SignRequestsView] [request-id: ABC123] Persona[1]: bob@example.com
[ DEBUG ] [SignRequestsView] [request-id: ABC123] Persona[2]: charlie@example.com
[ INFO ] [SignRequestsView] [request-id: ABC123] Calling DocumentSigningService.fetchAllPendingDocuments() for 3 DID(s)
[ DEBUG ] [DocumentSigningService] 📥 Fetching pending documents for 3 persona(s)
[ DEBUG ] [DocumentSigningService] 🔄 Task started for DID: alice@example.com
[ DEBUG ] [DocumentSigningService] 🔄 Task started for DID: bob@example.com
[ DEBUG ] [DocumentSigningService] 🔄 Task started for DID: charlie@example.com
[ DEBUG ] [DocumentSigningService] 📥 Fetching pending documents for signer: alice@example.com
[ DEBUG ] [DocumentSigningService] 📥 Fetching pending documents for signer: bob@example.com
[ DEBUG ] [DocumentSigningService] 📥 Fetching pending documents for signer: charlie@example.com
[ DEBUG ] [DocumentSigningService] ✅ Task completed for DID: alice@example.com with 1 document(s)
[ DEBUG ] [DocumentSigningService] ✅ Task completed for DID: bob@example.com with 0 document(s)
[ DEBUG ] [DocumentSigningService] ✅ Task completed for DID: charlie@example.com with 2 document(s)
[ DEBUG ] [DocumentSigningService] ✅ Returning 3 total pending document(s)
[ INFO ] [SignRequestsView] [request-id: ABC123] ✅ Received 3 pending document(s) from service
[ DEBUG ] [SignRequestsView] [request-id: ABC123] Document[0]: 'Contract.pdf' - Status: pending, DocumentID: doc-001
[ DEBUG ] [SignRequestsView] [request-id: ABC123] Document[1]: 'Agreement.pdf' - Status: signed, DocumentID: doc-002
[ DEBUG ] [SignRequestsView] [request-id: ABC123] Document[2]: 'Invoice.pdf' - Status: pending, DocumentID: doc-003
[ INFO ] [SignRequestsView] [request-id: ABC123] ✅ Updated UI with 3 request(s)
[ INFO ] [SignRequestsView] [request-id: ABC123] Status breakdown: 2 pending, 1 signed, 0 finalized
[ INFO ] [SignRequestsView] [request-id: ABC123] Finished loadPendingDocuments()
```

## Adding Logging to New Code

When adding new async operations, follow this pattern:

```swift
func myAsyncOperation() async {
    // 1. Generate request ID for tracking
    let requestID = RequestIDGenerator.generate()
    
    // 2. Log start
    ClientLogger.info(component: "MyComponent", "Starting operation", requestID: requestID)
    
    // 3. Log key parameters
    ClientLogger.debug(component: "MyComponent", "Parameter: \(someValue)", requestID: requestID)
    
    // 4. Wrap in do-catch
    do {
        // 5. Log before external calls
        ClientLogger.info(component: "MyComponent", "Calling external service", requestID: requestID)
        
        let result = try await externalService.fetch()
        
        // 6. Log success with details
        ClientLogger.info(component: "MyComponent", "✅ Operation succeeded with \(result.count) items", requestID: requestID)
        
    } catch {
        // 7. Log errors with context
        ClientLogger.error(component: "MyComponent", "Operation failed: \(error)", requestID: requestID)
    }
    
    // 8. Log completion
    ClientLogger.info(component: "MyComponent", "Finished operation", requestID: requestID)
}
```

## Benefits

1. **Easier Debugging**: Trace issues from client logs without needing server access
2. **Request Correlation**: Match client and server logs using request IDs
3. **Production Debugging**: Can enable logging in TestFlight builds for real-world issues
4. **Performance Monitoring**: See how long operations take
5. **User Support**: Ask users to send console logs for troubleshooting

## Future Enhancements

Consider adding:
- Log file persistence (save logs to disk)
- Remote logging (send logs to analytics service)
- Performance metrics (timing measurements)
- User-friendly log viewer UI
- Log filtering and search
