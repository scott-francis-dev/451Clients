# Client Logging Quick Reference

## 🚀 Quick Start

```swift
// 1. Generate a request ID for tracking
let requestID = RequestIDGenerator.generate()

// 2. Log your operations
ClientLogger.info(component: "MyView", "Starting operation", requestID: requestID)

// 3. Log results
ClientLogger.info(component: "MyView", "✅ Completed successfully", requestID: requestID)
```

## 📊 Log Levels

| Level | Usage | Example |
|-------|-------|---------|
| `.debug` | Detailed debugging info | Variable values, state changes |
| `.info` | General flow tracking | "Starting fetch", "Received 5 items" |
| `.warning` | Unusual but handled | "Retrying after timeout" |
| `.error` | Errors and failures | "Failed to decode response" |

## 🔍 Common Patterns

### Async Operation Logging
```swift
func loadData() async {
    let requestID = RequestIDGenerator.generate()
    ClientLogger.info(component: "DataView", "Loading data", requestID: requestID)
    
    do {
        let data = try await service.fetch()
        ClientLogger.info(component: "DataView", "✅ Loaded \(data.count) items", requestID: requestID)
    } catch {
        ClientLogger.error(component: "DataView", "Load failed: \(error)", requestID: requestID)
    }
}
```

### Network Request Logging
```swift
ClientLogger.info(component: "NetworkClient", "📤 POST /api/documents", requestID: requestID)
ClientLogger.debug(component: "NetworkClient", "URL: \(url)", requestID: requestID)
ClientLogger.debug(component: "NetworkClient", "Params: \(params)", requestID: requestID)

let response = try await URLSession.shared.data(for: request)

ClientLogger.info(component: "NetworkClient", "📥 Response: \(httpResponse.statusCode)", requestID: requestID)
```

### UI Event Logging
```swift
Button("Refresh") {
    ClientLogger.info(component: "DocumentList", "User tapped refresh button")
    Task { await refresh() }
}
```

## 🎯 Pre-defined Components

Use these constants for consistency:

```swift
LogComponent.signRequestsView
LogComponent.documentSigningDetail
LogComponent.documentService
LogComponent.personaManager
LogComponent.contactsView
LogComponent.networkClient
```

## 🎛️ Enable/Disable Logging

```swift
// In App.swift or AppDelegate
ClientLogger.isEnabled = false  // Disable all logging
ClientLogger.isEnabled = true   // Enable logging
```

## 🔬 Debugging with Logs

### Finding Issues

**Problem: UI not updating**
1. Check for "✅ Received X items" log
2. Check for "✅ Updated UI" log
3. Verify request IDs match across logs

**Problem: Network failures**
1. Check for "📤 Calling service" log
2. Check for error logs with HTTP status
3. Check server logs with same request ID

### Filtering Console Output

```bash
# macOS/iOS Console.app
process:YourApp category:ClientLogger

# Xcode Console
# Use the filter box: [INFO] or [ERROR] or request-id:ABC123
```

## 📋 Example Output

```
[ INFO ] [SignRequestsView] [request-id: A2FC6EBC-585C-4F01-B432] Starting loadPendingDocuments()
[ INFO ] [SignRequestsView] [request-id: A2FC6EBC-585C-4F01-B432] Found 3 persona(s)
[ DEBUG ] [SignRequestsView] [request-id: A2FC6EBC-585C-4F01-B432] Persona[0]: alice@example.com
[ INFO ] [DocumentSigningService] 📥 Fetching pending documents for signer: alice@example.com
[ INFO ] [SignRequestsView] [request-id: A2FC6EBC-585C-4F01-B432] ✅ Received 2 document(s)
[ INFO ] [SignRequestsView] [request-id: A2FC6EBC-585C-4F01-B432] ✅ Updated UI with 2 request(s)
```

## ⚠️ Best Practices

1. **Always use request IDs** for async operations
2. **Log at entry and exit** of important functions
3. **Include counts and IDs** for collections and entities
4. **Log both success and failure** paths
5. **Use emojis** for visual scanning (✅, ❌, 📤, 📥, 🔄)
6. **Don't log sensitive data** (passwords, tokens, PII)

## 🚫 What NOT to Log

```swift
// ❌ Bad - Sensitive data
ClientLogger.debug(component: "Auth", "Password: \(password)")
ClientLogger.debug(component: "Auth", "Private key: \(privateKey)")

// ✅ Good - Sanitized
ClientLogger.debug(component: "Auth", "Password length: \(password.count)")
ClientLogger.debug(component: "Auth", "Private key loaded successfully")
```

## 🔗 Related Files

- `ClientLogger.swift` - Main logging implementation
- `CLIENT_LOGGING_GUIDE.md` - Comprehensive guide
- `MainTabView.swift` - Example usage in SignRequestsView and DocumentSigningDetailView
- `DocumentSigningService.swift` - Service-level logging
