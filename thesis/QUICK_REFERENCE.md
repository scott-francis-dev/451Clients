# Foundation Models Quick Reference

## 🚀 Quick Start

### 1. Check Availability
```swift
let manager = LanguageModelManager.shared
if manager.isAvailable {
    // Ready to use!
} else {
    print(manager.availabilityMessage)
}
```

### 2. Basic Usage
```swift
// Improve writing
let improved = try await manager.improveWriting("Your text here")

// Generate tags
let tags = try await manager.generateTags("Content", maxTags: 5)

// Summarize
let summary = try await manager.summarize("Long text...")
```

### 3. Streaming (Real-time)
```swift
let stream = manager.streamWritingImprovement(text)
for try await snapshot in stream {
    updateUI(with: snapshot)
}
```

## 📁 Files Created

### Core Files
1. **LanguageModelManager.swift** - Main AI manager
2. **WritingAssistantView.swift** - Full UI for writing help
3. **StreamingWritingAssistantView.swift** - Real-time streaming UI
4. **SmartTagGeneratorView.swift** - Tag generation UI
5. **AIWritingToolbar.swift** - Quick toolbar component
6. **DraftExtensions+AI.swift** - Integration with Book/Page models

### Documentation
7. **FOUNDATION_MODELS_INTEGRATION.md** - Complete guide
8. **Info.plist.example** - Configuration example
9. **FoundationModelsTests.swift** - Test suite

## 🎯 Common Use Cases

### In DiscoveryView
```swift
// Already integrated! Look for the purple sparkles button (✨)
@State private var showingWritingAssistant = false

Button {
    showingWritingAssistant = true
} label: {
    Image(systemName: "sparkles")
}
.sheet(isPresented: $showingWritingAssistant) {
    WritingAssistantView()
}
```

### In Draft Editing
```swift
// Add AI toolbar to your editor
VStack {
    TextEditor(text: $draftText)
    AIWritingToolbar(text: $draftText) { newText in
        // Save updated text
    }
}
```

### Generate Tags for a Book
```swift
Button("Generate Tags") {
    Task {
        let tags = try await book.generateAITags()
        book.subject = tags.joined(separator: ", ")
        try await DraftsStore.shared.save(book)
    }
}
```

### Improve a Page
```swift
Button("Improve This Page") {
    Task {
        try await book.pages[index].improveWriting()
        try await DraftsStore.shared.save(book)
    }
}
```

### Create Draft with AI Outline
```swift
let book = try await DraftsStore.shared.createDraftWithAIOutline(
    title: "My Book",
    description: "About..."
)
```

## ⚡️ Available Actions

### Text Transformation
- `improveWriting()` - Enhance grammar, style, clarity
- `makeConcise()` - Reduce length, keep meaning
- `expandText()` - Add detail and examples
- `changeTone(to:)` - Adjust tone (professional, casual, etc.)

### Content Generation
- `summarize(length:)` - Short, medium, or detailed summaries
- `generateTags(maxTags:)` - Smart tag suggestions
- `continueWriting(from:style:)` - Continue the narrative
- `generateOutline(title:description:)` - Structured outlines

### Streaming
- `streamWritingImprovement()` - Real-time text improvement

## 🎨 UI Components

### Full Assistant
```swift
.sheet(isPresented: $showing) {
    WritingAssistantView()
}
```

### Streaming Assistant
```swift
.sheet(isPresented: $showing) {
    StreamingWritingAssistantView()
}
```

### Tag Generator
```swift
.sheet(isPresented: $showing) {
    SmartTagGeneratorView(text: content) { tags in
        // Use generated tags
    }
}
```

### Quick Toolbar
```swift
AIWritingToolbar(text: $text) { newText in
    // Handle changes
}
```

## 🔧 Customization

### Writing Tones
- `.professional`
- `.casual`
- `.friendly`
- `.formal`
- `.creative`

### Writing Styles
- `.general`
- `.narrative`
- `.descriptive`
- `.academic`
- `.conversational`

### Summary Lengths
- `.short`
- `.medium`
- `.detailed`

## ⚠️ Error Handling

```swift
do {
    let result = try await manager.improveWriting(text)
} catch LanguageModelError.modelUnavailable {
    // Show "Enable Apple Intelligence" message
} catch LanguageModelError.generationFailed {
    // Show "Generation failed" message
} catch {
    // Handle other errors
}
```

## 📱 Device Requirements

### Supported Devices
- iPhone 15 Pro and later (iOS 18.2+)
- iPad with M1 or later (iPadOS 18.2+)
- Mac with Apple silicon (macOS 15.2+)

### User Settings
Users must enable: Settings > Apple Intelligence & Siri

## 🧪 Testing

### Run Tests
```bash
# Run all Foundation Models tests
swift test --filter FoundationModelsTests
```

### Test Availability
```swift
@Test("Model availability check")
func testAvailability() {
    let manager = LanguageModelManager.shared
    #expect(manager.availability != nil)
}
```

### Mock Testing
When Apple Intelligence is unavailable:
```swift
let mock = MockLanguageModelManager()
let result = await mock.mockImproveWriting(text)
```

## 🎯 Integration Points

### Your App Structure
```
wordsmatter/
├── DiscoveryView.swift         ✅ AI button added
├── LanguageModelManager.swift  ✅ Core manager
├── WritingAssistantView.swift  ✅ Full UI
├── AIWritingToolbar.swift      ✅ Quick tools
├── DraftExtensions+AI.swift    ✅ Book/Page integration
└── SmartTagGeneratorView.swift ✅ Tag generation
```

### Next Steps
1. ✅ Import `FoundationModels` in your targets
2. ✅ Add usage description to Info.plist (optional)
3. ✅ Build and test on supported device
4. ✅ Enable Apple Intelligence in Settings
5. ✅ Try the purple sparkles button in DiscoveryView!

## 💡 Pro Tips

1. **Always check availability** before calling AI methods
2. **Use streaming** for long operations to show progress
3. **Handle errors gracefully** - not all devices support AI
4. **Break large text** into chunks (4096 token limit)
5. **Test on real devices** - Simulator may not have AI
6. **Cache results** when appropriate to save processing
7. **Provide feedback** - Users like to see AI working

## 📚 Resources

- [Foundation Models Docs](https://developer.apple.com/documentation/FoundationModels)
- [Generative AI HIG](https://developer.apple.com/design/human-interface-guidelines/technologies/generative-ai)
- Your detailed guide: `FOUNDATION_MODELS_INTEGRATION.md`

## 🎉 You're Ready!

The purple sparkles button (✨) is now in your DiscoveryView toolbar. Tap it to start using AI-powered writing assistance!

---

**Questions?** Check `FOUNDATION_MODELS_INTEGRATION.md` for detailed explanations.
