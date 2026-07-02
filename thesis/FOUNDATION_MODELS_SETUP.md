# Foundation Models Integration - Complete Setup

## ✅ What's Been Done

Your `SearchAssistantService` is now fully integrated with Apple Foundation Models! Here's what's been implemented:

### Core Features

1. **Model Availability Checking**
   - Automatically checks if Foundation Models is available
   - Provides clear error messages if unavailable
   - Handles all availability states (device not eligible, not enabled, not ready, etc.)

2. **Smart Search Flow**
   - User types a sentence ending with a period
   - Query is matched to one of 4 scenarios
   - 10 relevant search results are retrieved
   - Results + query sent to Foundation Models
   - AI generates a comprehensive, cited answer

3. **Foundation Models Integration**
   - Creates `LanguageModelSession` with custom instructions
   - Builds formatted prompt with search results
   - Handles responses and errors
   - Optional streaming support for real-time updates

## 🚀 How to Use

### Basic Usage

```swift
import SwiftUI

struct MyView: View {
    @State private var assistant = SearchAssistantService()
    
    var body: some View {
        VStack {
            // Text field that detects period completion
            TextField("Type a question...", text: $assistant.currentText)
                .onChange(of: assistant.currentText) { old, new in
                    assistant.handleTextInput(new)
                }
            
            // Show model availability warning
            if !assistant.isModelAvailable {
                Text(assistant.modelUnavailableReason ?? "Model not available")
                    .foregroundStyle(.red)
            }
            
            // Show loading state
            if assistant.isProcessing {
                ProgressView("Analyzing...")
            }
            
            // Show AI response
            if !assistant.aiResponse.isEmpty {
                Text(assistant.aiResponse)
                    .padding()
            }
            
            // Show matched scenario
            if let scenario = assistant.currentScenario {
                Text("Topic: \(scenario.title)")
                    .font(.caption)
            }
        }
    }
}
```

### Manual Search

```swift
let service = SearchAssistantService()

// Check availability first
guard service.isModelAvailable else {
    print("Model not available: \(service.modelUnavailableReason ?? "Unknown")")
    return
}

// Perform search
Task {
    await service.search(query: "How does climate change affect coastal cities?")
    
    // Access results
    print(service.aiResponse)
    print("Found \(service.currentSearchResults.count) results")
    print("Matched scenario: \(service.currentScenario?.title ?? "None")")
}
```

### Streaming Support (Optional)

For real-time response updates as the AI generates content:

```swift
Task {
    do {
        try await service.analyzeWithStreaming(
            query: "What are the benefits of AI in education?",
            snippets: searchResults
        )
        // The `aiResponse` property updates in real-time during generation
    } catch {
        print("Streaming error: \(error)")
    }
}
```

## 📋 Requirements

### Device Requirements

Foundation Models requires:
- iOS 18.2+ / iPadOS 18.2+ / macOS 15.2+
- Device with Apple Intelligence support
- Apple Intelligence enabled in Settings
- Model downloaded and ready

### Xcode Setup

1. **Import the framework:**
   ```swift
   import FoundationModels
   ```

2. **Add required entitlements** (if needed):
   Check your app's Signing & Capabilities in Xcode

3. **Privacy Settings:**
   Foundation Models runs entirely on-device, so no special privacy configuration is needed

## 🎯 Example Queries

Try these queries to test each scenario:

### Climate Change (10 results)
```swift
"How does climate change affect coastal cities?"
"What are insurance implications of flooding?"
"Tell me about wetland restoration."
"What is managed retreat?"
```

### AI in Education (10 results)
```swift
"What are the benefits of AI in education?"
"How does AI tutoring compare to human tutors?"
"What are privacy concerns with AI in schools?"
"Does AI help special education students?"
```

### Nutrition & Longevity (10 results)
```swift
"What do Blue Zones tell us about longevity?"
"Should I take vitamin D supplements?"
"How much protein do older adults need?"
"What is the gut microbiome?"
```

### Urban Transit (10 results)
```swift
"What are the benefits of protected bike lanes?"
"How effective are electric buses?"
"Should transit be fare-free?"
"What is transit-oriented development?"
```

## 🔧 Customization

### Adjust Model Instructions

Edit the `instructions` in `analyzeWithFoundationModels`:

```swift
let instructions = """
You are a [YOUR ROLE HERE].
[YOUR SPECIFIC INSTRUCTIONS]
Keep responses [LENGTH PREFERENCE].
[ANY OTHER GUIDELINES]
"""
```

### Use Alternative Prompts

The service includes helper methods for different use cases:

```swift
// Summarization
let prompt = service.createSummarizationPrompt(snippets: snippets)

// Q&A
let prompt = service.createQAPrompt(question: query, snippets: snippets)

// Information extraction
let prompt = service.createExtractionPrompt(topic: "flood prevention", snippets: snippets)
```

### Adjust Generation Options

You can customize the model's behavior:

```swift
let options = GenerationOptions(temperature: 0.7) // Default
let response = try await session.respond(to: prompt, options: options)

// Higher temperature (0.8-1.0) = more creative/varied
// Lower temperature (0.3-0.5) = more focused/deterministic
```

## 🛠️ Troubleshooting

### "Model not available" Error

**Check availability:**
```swift
if !service.isModelAvailable {
    print(service.modelUnavailableReason ?? "Unknown")
}
```

**Common reasons:**
- Device doesn't support Apple Intelligence
- Apple Intelligence not enabled in Settings > Apple Intelligence & Siri
- Model still downloading (wait a few minutes)
- iOS version too old (need 18.2+)

### No Matching Topic Found

**Solution:** Add more keywords to `matchScenario(for:)` in `FakeSearchResults.swift`:

```swift
if lowercased.contains("climate") || 
   lowercased.contains("YOUR_NEW_KEYWORD") {
    return .climateChangePolicy
}
```

### Response Too Long/Short

**Adjust the prompt instructions:**
```swift
let instructions = """
...
Keep responses under 150 words.  // Or whatever length you prefer
"""
```

## 📊 Data Flow

```
User Types → "Climate change affects cities."
    ↓
Period Detected
    ↓
Match Scenario → .climateChangePolicy
    ↓
Get Search Results → 10 SearchSnippets
    ↓
Build Context → Formatted string with all snippets
    ↓
Create Session → LanguageModelSession(instructions)
    ↓
Send Prompt → session.respond(to:)
    ↓
Return Response → response.content
    ↓
Update UI → aiResponse = "Based on the search results [1][2]..."
```

## 🎨 SwiftUI Integration

See `SearchAssistantView.swift` for a complete example with:
- Text input field with period detection
- Loading indicators
- Error handling
- Matched scenario display
- AI response formatting
- Search results preview

## 📚 Additional Resources

- [Foundation Models Documentation](https://developer.apple.com/documentation/FoundationModels)
- [Generating content with Foundation Models](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models)
- [LanguageModelSession](https://developer.apple.com/documentation/FoundationModels/LanguageModelSession)
- [SystemLanguageModel](https://developer.apple.com/documentation/FoundationModels/SystemLanguageModel)

## ✨ Next Steps

Your Foundation Models integration is complete! You can now:

1. ✅ Test on a device with Apple Intelligence
2. ✅ Refine keyword matching as needed
3. ✅ Customize the AI instructions for your use case
4. ✅ Try streaming for real-time responses
5. ✅ Add more scenarios or search result types

Everything is ready to go! 🎉
