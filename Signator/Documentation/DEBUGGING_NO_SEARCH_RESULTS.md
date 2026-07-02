# Debugging "No Search Results" Issue

## Quick Diagnosis Checklist

When search returns no results, follow this step-by-step diagnostic flow:

### 1. Check Client Logs (Xcode Console)

Filter by: `[ContactsView]`

#### Expected Log Sequence for Successful Search:
```
[ INFO ] [ContactsView] 🔍 Starting search [request-id: ABC123]
[ INFO ] [ContactsView] Query: 'search term' [request-id: ABC123]
[ INFO ] [ContactsView] 📤 Calling resolver.searchWithParams() [request-id: ABC123]
[ DEBUG ] [ContactsView] Parameters: limit=20, publicOnly=true [request-id: ABC123]
[ INFO ] [ContactsView] 📥 Received X result(s) from server [request-id: ABC123]
[ DEBUG ] [ContactsView] Result[0]: Name | DID: did:... [request-id: ABC123]
[ DEBUG ] [ContactsView] Filtering against X saved contact(s) [request-id: ABC123]
[ INFO ] [ContactsView] ✅ Showing X new result(s) [request-id: ABC123]
[ INFO ] [ContactsView] Opening search results sheet [request-id: ABC123]
[ INFO ] [ContactsView] Search results sheet appeared with X result(s)
```

### 2. Identify Where the Flow Breaks

#### Scenario A: Search Never Starts
**Symptoms:**
- No `🔍 Starting search` log appears

**Possible Causes:**
- Search text too short (< 2 characters)
- Debounce timer not completing
- Text field not triggering onChange

**Check:**
```swift
[ DEBUG ] [ContactsView] Search text changed: 'xx'
[ DEBUG ] [ContactsView] Search text too short or empty, clearing results
```

**Solution:**
- Type at least 2 characters
- Wait 300ms for debounce

---

#### Scenario B: API Call Fails
**Symptoms:**
- See `📤 Calling resolver.searchWithParams()` but no `📥 Received`
- See `❌ Search failed:` error log

**Possible Causes:**
1. Network connectivity issue
2. Server not responding
3. Wrong server URL
4. Authentication/authorization error

**Check These Logs:**
```
[ ERROR ] [ContactsView] ❌ Search failed: [error message]
[ ERROR ] [ContactsView] Error type: URLError
[ ERROR ] [ContactsView] URLError code: -1009
```

**Common URLError Codes:**
- `-1009`: No internet connection
- `-1001`: Request timeout
- `-1003`: Cannot find host
- `-1200`: SSL error

**Solution:**
1. Check internet connection
2. Verify server URL in Settings → Server Configuration
3. Check if server is running (ngrok, localhost, etc.)
4. Review `PersonaResolver` DEBUG logs for request details

---

#### Scenario C: Server Returns Empty Results
**Symptoms:**
- See `📥 Received 0 result(s) from server`
- See error message: "No matches found for 'query'"

**Possible Causes:**
1. Search term doesn't match any personas
2. Search index not populated
3. Only private personas match (publicOnly=true filter)

**Check PersonaResolver DEBUG Logs:**

Filter by: `PersonaResolver` (from PersonaResolver.swift)

```
DEBUG: SearchWithParams called query=xyz limit=20 publicOnly=true
DEBUG: GET https://server/api/persona/search?q=xyz&limit=20&publicOnly=true
DEBUG: SearchWithParams response status=200
DEBUG: SearchWithParams raw response: {"hits":[],"totalCount":0}
DEBUG: SearchWithParams decoded hits count=0
```

**Solution:**
1. Try different search terms
2. Verify personas exist on server
3. Check if personas are marked as public
4. Try searching without publicOnly filter (code change needed)

---

#### Scenario D: Results Filtered Out
**Symptoms:**
- See `📥 Received X result(s) from server` with X > 0
- See `Filtered out X already-saved contact(s)`
- See `✅ Showing 0 new result(s)`
- See error: "All matches are already in your contacts"

**Possible Causes:**
- All matching personas are already in your contacts list

**Check These Logs:**
```
[ INFO ] [ContactsView] 📥 Received 3 result(s) from server
[ DEBUG ] [ContactsView] Result[0]: John | DID: did:abc:123
[ DEBUG ] [ContactsView] Result[1]: Jane | DID: did:abc:456
[ DEBUG ] [ContactsView] Result[2]: Bob | DID: did:abc:789
[ DEBUG ] [ContactsView] Filtering against 3 saved contact(s)
[ INFO ] [ContactsView] Filtered out 3 already-saved contact(s)
[ INFO ] [ContactsView] All results were already in contacts
```

**Solution:**
- This is expected behavior
- Search for different personas not in your contacts
- Remove existing contacts to test search

---

#### Scenario E: Response Parsing Error
**Symptoms:**
- See `📥 Received` but then immediate failure
- No `Result[0]:` logs appear
- May see error about JSON decoding

**Check PersonaResolver DEBUG Logs:**
```
DEBUG: SearchWithParams raw response: [actual JSON]
DEBUG: SearchWithParams decoded hits count=0
DEBUG: SearchWithParams decode fallback: returning empty results
```

**Possible Causes:**
1. Server response format changed
2. Response is in unexpected format
3. Response has wrong field names

**Solution:**
1. Check raw response JSON in PersonaResolver logs
2. Verify server is returning PersonaResolvedProfile format
3. Check for API version mismatch

---

#### Scenario F: Sheet Doesn't Open
**Symptoms:**
- See `✅ Showing X new result(s)` with X > 0
- No `Opening search results sheet` log
- No `Search results sheet appeared` log

**Check These Logs:**
```
[ INFO ] [ContactsView] ✅ Showing 5 new result(s) [request-id: ABC123]
# Should see next:
[ INFO ] [ContactsView] Opening search results sheet [request-id: ABC123]
```

**Possible Causes:**
1. UI state not updating on main thread
2. SwiftUI state binding issue
3. Sheet presentation blocked

**Solution:**
1. Check for SwiftUI errors in console
2. Verify `showSearchResultsSheet` state is changing
3. Try dismissing any existing sheets first

---

### 3. Enable PersonaResolver Verbose Logging

PersonaResolver already has DEBUG logging built-in (only active in DEBUG builds):

**To view all PersonaResolver logs:**
1. Filter Xcode console by `PersonaResolver`
2. Look for these key logs:

```
DEBUG: SearchWithParams called query=xyz ...
DEBUG: GET https://... [searchWithParams]
DEBUG: SearchWithParams response status=200
DEBUG: SearchWithParams raw response: {...}
DEBUG: SearchWithParams decoded hits count=X
```

**Raw response logging** shows exactly what the server returned, which is critical for debugging parsing issues.

---

### 4. Test with Known Data

#### Create a Test Persona on Server:
1. Create a public persona with name "TestUser123"
2. Note its DID and short code
3. Search for "TestUser123"
4. Should see it in results

#### Verify Search Endpoint Directly:
Use curl or Postman to test the API:

```bash
# Replace with your server URL
curl "https://your-server/api/persona/search?q=test&limit=20&publicOnly=true"
```

Expected response:
```json
{
  "hits": [
    {
      "dID": "did:example:123",
      "name": "TestUser123",
      "shortId": "ABC-1234",
      ...
    }
  ],
  "totalCount": 1,
  "processingTimeMs": 12.5
}
```

---

### 5. Common Fixes

#### Fix 1: Server URL Incorrect
```swift
// Check in app:
Settings → Server Configuration → Current Server
```

#### Fix 2: Network Issue
```swift
// Try this in Terminal:
ping your-server-hostname
curl https://your-server/api/persona/search?q=test
```

#### Fix 3: Search Index Not Ready
```swift
// Wait a few seconds after persona creation for indexing
// Or use waitForIndexing parameter (code change needed)
```

#### Fix 4: All Results Filtered
```swift
// Temporarily clear contacts to test:
// Delete app and reinstall, or add logic to clear contacts
```

#### Fix 5: Response Format Mismatch
```swift
// Check PersonaResolver.swift response parsing:
// Lines 360-450 in PersonaResolver.swift
// Verify PersonaResolvedProfile struct matches server response
```

---

### 6. Log Interpretation Examples

#### Example 1: Successful Search
```
[ INFO ] [ContactsView] 🔍 Starting search [request-id: A1B2]
[ INFO ] [ContactsView] Query: 'john' [request-id: A1B2]
[ INFO ] [ContactsView] 📤 Calling resolver.searchWithParams() [request-id: A1B2]
[ INFO ] [ContactsView] 📥 Received 2 result(s) from server [request-id: A1B2]
[ DEBUG ] [ContactsView] Result[0]: John Doe | DID: did:abc:123 [request-id: A1B2]
[ DEBUG ] [ContactsView] Result[1]: Johnny Smith | DID: did:abc:456 [request-id: A1B2]
[ INFO ] [ContactsView] ✅ Showing 2 new result(s) [request-id: A1B2]
[ INFO ] [ContactsView] Opening search results sheet [request-id: A1B2]
```
✅ **Diagnosis:** Working perfectly

---

#### Example 2: Network Error
```
[ INFO ] [ContactsView] 🔍 Starting search [request-id: C3D4]
[ INFO ] [ContactsView] Query: 'test' [request-id: C3D4]
[ INFO ] [ContactsView] 📤 Calling resolver.searchWithParams() [request-id: C3D4]
[ ERROR ] [ContactsView] ❌ Search failed: The Internet connection appears to be offline [request-id: C3D4]
[ ERROR ] [ContactsView] Error type: URLError [request-id: C3D4]
[ ERROR ] [ContactsView] URLError code: -1009 [request-id: C3D4]
```
❌ **Diagnosis:** No internet connection
🔧 **Fix:** Check WiFi/cellular connection

---

#### Example 3: No Server Results
```
[ INFO ] [ContactsView] 🔍 Starting search [request-id: E5F6]
[ INFO ] [ContactsView] Query: 'nonexistent' [request-id: E5F6]
[ INFO ] [ContactsView] 📤 Calling resolver.searchWithParams() [request-id: E5F6]
[ INFO ] [ContactsView] 📥 Received 0 result(s) from server [request-id: E5F6]
[ INFO ] [ContactsView] No results found on server [request-id: E5F6]
```
⚠️ **Diagnosis:** Query doesn't match any personas
🔧 **Fix:** Try different search term or verify personas exist

---

#### Example 4: All Filtered
```
[ INFO ] [ContactsView] 🔍 Starting search [request-id: G7H8]
[ INFO ] [ContactsView] Query: 'john' [request-id: G7H8]
[ INFO ] [ContactsView] 📤 Calling resolver.searchWithParams() [request-id: G7H8]
[ INFO ] [ContactsView] 📥 Received 1 result(s) from server [request-id: G7H8]
[ DEBUG ] [ContactsView] Result[0]: John Doe | DID: did:abc:123 [request-id: G7H8]
[ DEBUG ] [ContactsView] Filtering against 5 saved contact(s) [request-id: G7H8]
[ INFO ] [ContactsView] Filtered out 1 already-saved contact(s) [request-id: G7H8]
[ INFO ] [ContactsView] All results were already in contacts [request-id: G7H8]
```
ℹ️ **Diagnosis:** Match found but already saved
🔧 **Fix:** Expected behavior, search for someone else

---

### 7. Quick Test Script

Use this test sequence to verify the entire flow:

```
Test 1: Search too short
1. Type "a"
2. Expected: No search initiated, results cleared

Test 2: Valid search with results
1. Type "test" (assuming test personas exist)
2. Expected: Loading indicator → Results sheet opens → Can select

Test 3: Valid search with no results
1. Type "zzznonexistent"
2. Expected: Error message "No matches found"

Test 4: Network failure
1. Enable airplane mode
2. Type "test"
3. Expected: Error with retry button

Test 5: Already saved
1. Search for existing contact
2. Expected: "All matches are already in your contacts"

Test 6: Clear search
1. Type something
2. Tap X button
3. Expected: Search cleared, errors cleared

Test 7: Retry after error
1. Cause an error (airplane mode)
2. Disable airplane mode
3. Tap Retry button
4. Expected: Search succeeds
```

---

### 8. Enable Maximum Logging

For deep debugging, ensure DEBUG build:

```swift
// Check in ClientLogger.swift:
public static var isEnabled: Bool = {
    #if DEBUG
    return true  // Should be true
    #else
    return false
    #endif
}()
```

And in PersonaResolver.swift, all `debugLog()` calls are active in DEBUG builds.

---

### 9. Contact Developer

If issue persists after all checks, provide:

1. **Request ID** from logs
2. **Full log sequence** from search start to failure
3. **PersonaResolver DEBUG logs** for the same request
4. **Server URL** being used
5. **Search query** attempted
6. **Network conditions** (WiFi, VPN, etc.)
7. **Device info** (iOS version, device model)

This will enable rapid diagnosis of the root cause.
