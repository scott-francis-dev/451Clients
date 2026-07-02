# Client Logging Implementation Summary

## Problem Statement

The server-side logs showed extensive information about requests and responses:
```
[ INFO ] [PENDING SIGNATURES] Searching for documents requiring signatures from: long.luke@cool.luke
[ INFO ] [PENDING SIGNATURES] ✅ Returning 0 documents requiring signatures
```

However, the client-side had very limited logging, making it difficult to:
- Trace what the client was doing
- Match client behavior with server logs
- Debug issues when client and server seemed out of sync
- Understand why the UI wasn't updating as expected

## Solution Implemented

### 1. Created `ClientLogger.swift` - Centralized Logging System

**Features:**
- ✅ Structured logging with severity levels (DEBUG, INFO, WARNING, ERROR)
- ✅ Request ID tracking to correlate related operations
- ✅ Component-based logging for easy filtering
- ✅ Configurable enable/disable for production
- ✅ Consistent format matching server logs
- ✅ Automatic file and line number tracking in debug builds

**Example Usage:**
```swift
ClientLogger.info(component: "MyView", "Operation started", requestID: requestID)
```

### 2. Enhanced `MainTabView.swift` with Comprehensive Logging

#### SignRequestsView.loadPendingDocuments()
Now logs:
- Request initiation with unique UUID
- Number of personas being queried  
- Each persona DID
- Service call invocation
- Number of documents returned
- Details of each document (title, status, ID)
- UI update confirmation
- Status breakdown (pending/signed/finalized)
- Detailed error information on failures

#### DocumentSigningDetailView.signDocument()
Now logs:
- Document being signed
- Selected persona
- Private key loading
- Public key (truncated for security)
- Document hash decoding
- Ledger chain linking
- API call to add signature
- Server response (entry ID, index)
- Success or error outcomes

### 3. Updated `DocumentSigningService.swift`

Modified the `debugLog()` function to:
- Use centralized `ClientLogger` instead of direct `print()`
- Work in both DEBUG and RELEASE builds (when enabled)
- Maintain existing log messages while improving consistency

## Log Format

All logs now follow a consistent, grep-friendly format:

```
[ LEVEL ] [Component] [request-id: UUID] Message
```

**Example:**
```
[ INFO ] [SignRequestsView] [request-id: A2FC6EBC-585C-4F01-B432-062B28333091] Starting loadPendingDocuments()
[ INFO ] [SignRequestsView] [request-id: A2FC6EBC-585C-4F01-B432-062B28333091] Found 3 persona(s)
[ DEBUG ] [SignRequestsView] [request-id: A2FC6EBC-585C-4F01-B432-062B28333091] Persona[0]: long.luke@cool.luke
[ DEBUG ] [DocumentSigningService] 📥 Fetching pending documents for signer: long.luke@cool.luke
[ INFO ] [DocumentSigningService] 📥 Pending documents response status: 200
[ INFO ] [DocumentSigningService] ✅ Fetched 2 pending document(s) for long.luke@cool.luke
[ INFO ] [SignRequestsView] [request-id: A2FC6EBC-585C-4F01-B432-062B28333091] ✅ Received 2 pending document(s) from service
[ INFO ] [SignRequestsView] [request-id: A2FC6EBC-585C-4F01-B432-062B28333091] ✅ Updated UI with 2 request(s)
```

## Files Created

1. **`ClientLogger.swift`** - Core logging infrastructure
2. **`CLIENT_LOGGING_GUIDE.md`** - Comprehensive documentation
3. **`CLIENT_LOGGING_QUICK_REFERENCE.md`** - Quick reference card

## Files Modified

1. **`MainTabView.swift`** 
   - Enhanced `loadPendingDocuments()` with 15+ log statements
   - Enhanced `signDocument()` with 12+ log statements
   - Fixed duplicate import statement

2. **`DocumentSigningService.swift`**
   - Updated `debugLog()` to use ClientLogger
   - Now works in both DEBUG and RELEASE builds

## How to Use

### Enable Logging Globally

```swift
// In your App.swift or main entry point
ClientLogger.isEnabled = true  // Enable (default in DEBUG)
ClientLogger.isEnabled = false // Disable
```

### Generate Request IDs for Tracking

```swift
let requestID = RequestIDGenerator.generate()
ClientLogger.info(component: "MyView", "Starting operation", requestID: requestID)
```

### Use Pre-defined Components

```swift
LogComponent.signRequestsView
LogComponent.documentSigningDetail
LogComponent.documentService
LogComponent.personaManager
LogComponent.contactsView
```

## Benefits

### For Development
- **Easier Debugging**: See exactly what the client is doing at each step
- **Request Correlation**: Match client logs with server logs using request IDs
- **Flow Understanding**: Trace the complete path of an operation

### For Production
- **User Support**: Ask users to send console logs from Settings/Diagnostics
- **TestFlight Debugging**: Enable logging in beta builds to catch real-world issues
- **Performance Monitoring**: See timing and counts for operations

### For Team Collaboration
- **Consistent Format**: All developers use the same logging patterns
- **Easy Filtering**: Search by component, level, or request ID
- **Documentation**: Logs serve as runtime documentation

## Example Complete Flow

Here's what you'll now see when loading pending documents:

```
[ INFO ] [SignRequestsView] [request-id: 123ABC] Starting loadPendingDocuments()
[ INFO ] [SignRequestsView] [request-id: 123ABC] Found 3 persona(s)
[ DEBUG ] [SignRequestsView] [request-id: 123ABC] Persona[0]: alice@example.com
[ DEBUG ] [SignRequestsView] [request-id: 123ABC] Persona[1]: bob@example.com
[ DEBUG ] [SignRequestsView] [request-id: 123ABC] Persona[2]: charlie@example.com
[ INFO ] [SignRequestsView] [request-id: 123ABC] Calling DocumentSigningService.fetchAllPendingDocuments() for 3 DID(s)
[ DEBUG ] [DocumentSigningService] 📥 Fetching pending documents for 3 persona(s)
[ DEBUG ] [DocumentSigningService] 🔄 Task started for DID: alice@example.com
[ DEBUG ] [DocumentSigningService] 🔄 Task started for DID: bob@example.com
[ DEBUG ] [DocumentSigningService] 🔄 Task started for DID: charlie@example.com
[ DEBUG ] [DocumentSigningService] 📥 Fetching pending documents for signer: alice@example.com
[ DEBUG ] [DocumentSigningService]    URL: https://api.example.com/api/documents/pending-signatures?signerDID=alice@example.com
[ DEBUG ] [DocumentSigningService] 📥 Pending documents response status: 200
[ DEBUG ] [DocumentSigningService] ✅ Fetched 1 pending document(s) for alice@example.com
[ DEBUG ] [DocumentSigningService] ✅ Task completed for DID: alice@example.com with 1 document(s)
[ DEBUG ] [DocumentSigningService] ✅ Task completed for DID: bob@example.com with 0 document(s)
[ DEBUG ] [DocumentSigningService] ✅ Task completed for DID: charlie@example.com with 2 document(s)
[ DEBUG ] [DocumentSigningService] ✅ Returning 3 total pending document(s)
[ INFO ] [SignRequestsView] [request-id: 123ABC] ✅ Received 3 pending document(s) from service
[ DEBUG ] [SignRequestsView] [request-id: 123ABC] Document[0]: 'Contract.pdf' - Status: pending, DocumentID: doc-001
[ DEBUG ] [SignRequestsView] [request-id: 123ABC] Document[1]: 'Agreement.pdf' - Status: signed, DocumentID: doc-002
[ DEBUG ] [SignRequestsView] [request-id: 123ABC] Document[2]: 'Invoice.pdf' - Status: pending, DocumentID: doc-003
[ INFO ] [SignRequestsView] [request-id: 123ABC] ✅ Updated UI with 3 request(s)
[ INFO ] [SignRequestsView] [request-id: 123ABC] Status breakdown: 2 pending, 1 signed, 0 finalized
[ INFO ] [SignRequestsView] [request-id: 123ABC] Finished loadPendingDocuments()
```

## Debugging Scenarios

### Scenario 1: Server Says Documents Exist, Client Shows Empty

**Before:** No idea what's happening on the client
**After:** Check these logs:
1. "Found X persona(s)" - Are all personas accounted for?
2. "Persona[N]: did:..." - Do the DIDs match what server expects?
3. "✅ Received X pending document(s)" - What count came back?
4. "Status breakdown: X pending, Y signed..." - Are they the wrong status?

### Scenario 2: Document Signing Fails

**Before:** Just see "Failed to sign" error
**After:** See the complete flow:
1. Which persona was selected
2. Whether private key loaded successfully
3. What document hash was used
4. Which previous entry ID we're chaining to
5. Exact error from the service call

### Scenario 3: Network Issues

**Before:** Generic "network error"
**After:** See:
1. Exact URL being called
2. HTTP status code returned
3. Error response body
4. Which persona/document triggered it

## Future Enhancements

Consider adding:
- **Log Persistence**: Save logs to disk for later review
- **Remote Logging**: Send critical errors to analytics
- **Performance Metrics**: Add timing measurements
- **User-Facing Log Viewer**: In-app debug screen
- **Crash Report Integration**: Include logs in crash reports

## Migration Notes

### Existing Code

No changes needed to existing code. The DocumentSigningService continues to work exactly as before, but now with better logging.

### New Code

Use this pattern for new async operations:

```swift
func myNewOperation() async {
    let requestID = RequestIDGenerator.generate()
    ClientLogger.info(component: "MyComponent", "Starting", requestID: requestID)
    
    do {
        let result = try await service.fetch()
        ClientLogger.info(component: "MyComponent", "✅ Success", requestID: requestID)
    } catch {
        ClientLogger.error(component: "MyComponent", "Failed: \(error)", requestID: requestID)
    }
}
```

## Configuration

By default:
- **DEBUG builds**: Logging enabled
- **RELEASE builds**: Logging disabled

To change:
```swift
// Force enable in release for TestFlight
#if DEBUG
ClientLogger.isEnabled = true
#else
ClientLogger.isEnabled = true  // Enable for TestFlight debugging
#endif
```

## Conclusion

You now have comprehensive client-side logging that:
- ✅ Matches your server log format
- ✅ Uses request IDs for correlation
- ✅ Provides detailed visibility into client operations
- ✅ Makes debugging significantly easier
- ✅ Can be enabled/disabled as needed
- ✅ Follows consistent patterns across the codebase

The next time you see server logs showing activity but the client isn't responding as expected, you'll have detailed client logs to compare and identify exactly where the disconnect is occurring!
