# Troubleshooting: Document Not Appearing in Sign Tab

## Problem
You added persona `314-3943` as a signer on a document, but it's not showing up in the Sign tab.

## What to Check

### 1. **Verify the Full DID**

The short code `314-3943` needs to be resolved to a full DID like `did:451:xxxxx`.

**Check the logs for:**
```
Persona[0]: {Name} | DID: did:451:xxxxx | Short: 314-3943
```

Make sure the full DID was used when adding the signer to the document.

### 2. **Check Server Logs**

The client will now log:
```
📞 Calling DocumentSigningService.fetchAllPendingDocuments()
🔍 Looking for documents assigned to these DIDs:
   • did:451:xxxxx
   • did:451:yyyyy
```

Then check the server logs to see if the document is being returned for that DID.

### 3. **Verify Document Was Created with Correct Signer**

When the document was uploaded/created, check:
- Was the signer added with the **full DID** (did:451:xxxxx)?
- Or was it added with just the short code (314-3943)?

**The server expects full DIDs, not short codes.**

### 4. **Check Server Search Index**

The endpoint `/api/documents/pending-signatures?signerDID=xxx` queries a search index.

Possible issues:
- **Index not updated yet** - The document might need a few seconds to be indexed
- **Index configuration error** - The server's search index might not be properly configured
- **Wrong DID format** - The document might have been indexed with a different DID format

### 5. **Manual Refresh**

The Sign tab now has a **refresh button** (🔄) in the header. Use it to manually reload documents after:
- Adding a signer to a document
- Waiting for server indexing
- Making server configuration changes

## Debugging Steps

### Step 1: Check the Console Logs

Look for these log entries when you open the Sign tab:

```
🔍 Starting loadPendingDocuments()
Found 2 persona(s)
Persona[0]: John Doe | DID: did:451:qn9nhu6rncquict7 | Short: ABC-1234
Persona[1]: Jane Smith | DID: did:451:314394a | Short: 314-3943
📞 Calling DocumentSigningService.fetchAllPendingDocuments() for 2 DID(s)
🔍 Looking for documents assigned to these DIDs:
   • did:451:qn9nhu6rncquict7
   • did:451:314394a
📥 Received 0 pending document(s) from service
```

If you see **0 documents**, the server isn't returning any documents for those DIDs.

### Step 2: Check Server Response

Look for these in the DocumentSigningService logs:

```
📥 Fetching pending documents for signer: did:451:314394a
   URL: https://your-server.com/api/documents/pending-signatures?signerDID=did:451:314394a
📥 Pending documents response status: 200
📄 Pending documents response: {"documents":[]}
✅ Fetched 0 pending document(s) for did:451:314394a
```

This tells you the server is returning an empty array.

### Step 3: Check How the Document Was Created

When the document was uploaded, check if signers were added correctly:

1. Go to the server and find the document by its ID
2. Check the `signers` or `requiredSignatures` field
3. Verify it contains: `"did:451:314394a"` (not just `"314-3943"`)

### Step 4: Check Server Search Index

On the server:
- Is the search index running?
- Is it configured to index the `signers` field?
- Was the document indexed after being created?

## Common Issues & Solutions

### Issue 1: Short Code Used Instead of Full DID

**Problem:** Document was created with `"314-3943"` instead of `"did:451:314394a"`

**Solution:** 
- When adding signers, always resolve the short code to the full DID first
- Use `PersonaResolver` to convert short codes to DIDs
- Update the document with the correct DID

### Issue 2: Server Index Not Updated

**Problem:** Document was just created, but index hasn't updated yet

**Solution:**
- Wait 5-10 seconds
- Tap the refresh button (🔄) in the Sign tab
- Or use pull-to-refresh gesture

### Issue 3: Wrong DID Format

**Problem:** DID was stored in a different format (e.g., without the `did:451:` prefix)

**Solution:**
- Check server database for the document
- Verify the DID format matches exactly
- Update server to normalize DIDs on ingestion

### Issue 4: Document Status Wrong

**Problem:** Document might be in the wrong state (draft, finalized, etc.)

**Solution:**
- Check document `status` field
- Pending documents should have `status: "pending"` or similar
- Finalized documents won't show up in the Sign tab

## Quick Test

1. **Create a test document** with a known signer DID
2. **Check the logs** to see what DID the Sign tab is querying for
3. **Query the server directly** with that DID:
   ```bash
   curl "https://your-server.com/api/documents/pending-signatures?signerDID=did:451:314394a"
   ```
4. **Compare** the server response with what appears in the app

## Enhanced Logging

The Sign tab now has enhanced logging that shows:
- ✅ Each persona with name, DID, and short code
- ✅ All DIDs being queried
- ✅ Number of documents returned
- ✅ Details of each document found
- ✅ Status breakdown (pending/signed/finalized)

Check the Xcode console for these logs!

## Need More Help?

If the document still isn't appearing:

1. **Copy the console logs** from when you tap the Sign tab
2. **Copy the server response** from the pending-signatures endpoint
3. **Check the document on the server** to see how signers are stored
4. **Verify the DID format** matches exactly between client and server
