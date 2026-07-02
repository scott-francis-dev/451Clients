# Foundation Models Integration for Words Matter

This guide explains how to integrate Apple's on-device language model (Foundation Models framework) into the Words Matter app.

## Overview

Foundation Models provides access to Apple Intelligence's on-device LLM capabilities, enabling:
- ✨ **Writing assistance** (improve, expand, make concise)
- 🎨 **Tone adjustment** (professional, casual, friendly, etc.)
- 📝 **Content summarization**
- 🏷️ **Smart tag generation**
- ✍️ **Writing continuation**
- 🎯 **Structured content generation** (outlines, sections)

## Requirements

### System Requirements
- **iOS**: 18.2+ (iPhone 15 Pro or later)
- **iPadOS**: 18.2+ (iPad with M1 or later)
- **macOS**: 15.2+ (Mac with Apple silicon)

### User Requirements
Users must have Apple Intelligence enabled in Settings > Apple Intelligence & Siri.

## Setup Instructions

### 1. Add Framework Import

The Foundation Models framework is part of the system. Simply import it:

```swift
import FoundationModels
```

### 2. Configure Info.plist (Optional)

Add a usage description to explain to users why your app uses Apple Intelligence:

```xml
<key>NSAppleIntelligenceUsageDescription</key>
<string>Words Matter uses Apple Intelligence to help improve your writing with suggestions, summaries, and smart tag generation.</string>
```

### 3. Files Added

The following files have been created in your project:

1. **LanguageModelManager.swift** - Core manager for LLM interactions
2. **WritingAssistantView.swift** - Full-featured writing assistant UI
3. **StreamingWritingAssistantView.swift** - Real-time streaming responses
4. **SmartTagGeneratorView.swift** - AI-powered tag generation

### 4. Integration Points

#### DiscoveryView
The writing assistant button has been added to the toolbar:
- Purple sparkles icon (✨)
- Opens `WritingAssistantView` as a sheet
- Available alongside the create (+) button

#### Usage Example

```swift
// Check availability
let manager = LanguageModelManager.shared
if manager.isAvailable {
    // Use the model
    let improved = try await manager.improveWriting("Your text here")
}

// Generate tags
let tags = try await manager.generateTags("Article content", maxTags: 5)

// Stream responses
let stream = manager.streamWritingImprovement("Text to improve")
for try await snapshot in stream {
    print(snapshot) // Real-time updates
}
```

## Features

### Writing Assistance Actions

1. **Improve Writing** - Enhance grammar, style, and clarity
2. **Make Concise** - Reduce length while preserving meaning
3. **Expand** - Add detail and elaboration
4. **Change Tone** - Adjust to professional, casual, friendly, formal, or creative
5. **Summarize** - Create short, medium, or detailed summaries
6. **Continue Writing** - Generate next sentences based on context

### Smart Tag Generation

Automatically generate relevant tags for articles and content:
- Contextually appropriate
- Customizable count (default: 5)
- Quick integration into drafts

### Structured Generation

Generate outlines and structured content using the `@Generable` macro:

```swift
@Generable(description: "An outline for a writing draft")
struct DraftOutline {
    @Guide(description: "The main title of the outline")
    var title: String
    
    @Guide(description: "Main sections of the outline", .count(3...5))
    var sections: [OutlineSection]
}

// Usage
let outline = try await manager.generateOutline(
    title: "My Article",
    description: "An article about..."
)
```

## Error Handling

The manager handles common errors:

```swift
enum LanguageModelError: LocalizedError {
    case modelUnavailable      // Model not available on device
    case generationFailed      // Generation failed
    case invalidResponse       // Unexpected response format
}
```

Always check `isAvailable` before making requests:

```swift
guard manager.isAvailable else {
    // Show error message to user
    print(manager.availabilityMessage)
    return
}
```

## Privacy & Performance

### Privacy
- All processing happens **on-device**
- No data sent to external servers
- Maintains user privacy standards
- Respects Apple Intelligence settings

### Performance
- Model supports up to 4,096 tokens per session
- A token ≈ 3-4 characters in English
- For large text, split into chunks
- Use streaming for real-time feedback

## Best Practices

### 1. Always Check Availability
```swift
let manager = LanguageModelManager.shared
if manager.isAvailable {
    // Safe to use
} else {
    // Show appropriate message
    print(manager.availabilityMessage)
}
```

### 2. Use Clear Instructions
```swift
let instructions = """
You are a helpful writing assistant.
Improve grammar and clarity.
Maintain the original tone.
Keep the length similar.
"""
```

### 3. Handle Errors Gracefully
```swift
do {
    let result = try await manager.improveWriting(text)
} catch {
    // Show user-friendly error message
    showError(error.localizedDescription)
}
```

### 4. Use Streaming for Long Operations
For better UX, use streaming to show progress:

```swift
let stream = manager.streamWritingImprovement(text)
for try await snapshot in stream {
    updateUI(with: snapshot)
}
```

## Testing

### On Device
1. Use iPhone 15 Pro or later with iOS 18.2+
2. Enable Apple Intelligence in Settings
3. Test all writing assistant features
4. Verify error handling when model unavailable

### In Simulator
- The model may not be available in Simulator
- Test UI with mock data
- Ensure error states display correctly

### Preview Support
Use SwiftUI previews to test UI:

```swift
#Preview {
    WritingAssistantView()
}
```

## Future Enhancements

Consider adding:
- [ ] Writing style presets (academic, creative, business)
- [ ] Multi-language support
- [ ] Grammar-only corrections
- [ ] Plagiarism checking integration
- [ ] Custom writing personas
- [ ] Batch processing for multiple drafts
- [ ] Writing analytics and insights

## Resources

- [Foundation Models Documentation](https://developer.apple.com/documentation/FoundationModels)
- [WWDC Session: Generating content with Foundation Models](https://developer.apple.com/videos/)
- [Human Interface Guidelines: Generative AI](https://developer.apple.com/design/human-interface-guidelines/technologies/generative-ai)

## Support

For issues or questions:
1. Check model availability first
2. Verify device meets requirements
3. Ensure Apple Intelligence is enabled
4. Check system requirements (iOS 18.2+)

---

**Note**: Foundation Models is available in iOS 18.2, iPadOS 18.2, and macOS 15.2 or later. Users must have Apple Intelligence enabled in their system settings.
