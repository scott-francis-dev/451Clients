# Search Assistant with Foundation Models Integration

## Overview

This system provides an AI-powered search assistant that:
1. Detects when a user completes a sentence (types a period)
2. Matches the query to one of 4 topic scenarios
3. Retrieves relevant fake search results (10 snippets per topic)
4. Sends the query + search results to Apple Foundation Models
5. Returns an AI-generated analysis

## Architecture

```
User Types Sentence → Detect Period → Match Scenario → Get Search Results → Foundation Models → AI Response
```

## Files

### 1. `FakeSearchResults.swift`
- **SearchSnippet**: Model for individual search results
- **SearchResult**: Collection of snippets for a query
- **SearchResponse**: Complete response with timestamp
- **FakeScenario**: 4 topics (Climate, AI/Education, Nutrition, Transit)
- **FakeSearchResults**: 
  - `matchScenario(for:)` - Matches query to scenario
  - `search(query:)` - Returns search results for query
  - `makeResult(for:)` - Generates 10 snippets for a scenario

### 2. `SearchAssistantService.swift`
- **@Observable class** that manages the search flow
- **Properties**:
  - `currentText` - User's input text
  - `aiResponse` - AI-generated answer
  - `isProcessing` - Loading state
  - `currentSearchResults` - The 10 snippets found
  - `currentScenario` - Matched topic
- **Methods**:
  - `handleTextInput(_:)` - Call on every text change
  - `search(query:)` - Manual search trigger
  - `reset()` - Clear all state

### 3. `SearchAssistantView.swift`
- Example SwiftUI implementation
- Shows input field, matched scenario, AI response, and search results

## Usage

### Basic Integration

```swift
import SwiftUI

struct MyView: View {
    @State private var assistant = SearchAssistantService()
    
    var body: some View {
        VStack {
            // Text input
            TextField("Type a question...", text: $assistant.currentText)
                .onChange(of: assistant.currentText) { oldValue, newValue in
                    assistant.handleTextInput(newValue)
                }
            
            // Show loading
            if assistant.isProcessing {
                ProgressView("Analyzing...")
            }
            
            // Show AI response
            if !assistant.aiResponse.isEmpty {
                Text(assistant.aiResponse)
            }
        }
    }
}
```

### Manual Search

```swift
let service = SearchAssistantService()

Task {
    await service.search(query: "How does climate change affect coastal cities?")
    print(service.aiResponse)
    print("Found \(service.currentSearchResults.count) results")
}
```

### Direct Search Results Access

```swift
// Get results without AI analysis
if let result = FakeSearchResults.search(query: "What are the benefits of AI in education?") {
    for snippet in result.snippets {
        print(snippet.title)
        print(snippet.snippet)
    }
}
```

## Foundation Models Integration

### Current Implementation (Placeholder)

The `analyzeWithFoundationModels` method in `SearchAssistantService` currently returns a placeholder response. 

### To Integrate Real Foundation Models:

1. **Import the Framework**:
```swift
import FoundationModels
```

2. **Replace the placeholder in `SearchAssistantService.swift`**:

```swift
private func analyzeWithFoundationModels(query: String, snippets: [SearchSnippet]) async throws -> String {
    // Build context (already implemented)
    let context = snippets.enumerated().map { index, snippet in
        """
        [\(index + 1)] \(snippet.title)
        \(snippet.snippet)
        Source: \(snippet.url)
        """
    }.joined(separator: "\n\n---\n\n")
    
    let prompt = """
    Answer this question using the search results:
    
    Question: \(query)
    
    Results:
    \(context)
    
    Provide a comprehensive answer with source citations.
    """
    
    // REPLACE THIS SECTION with actual Foundation Models call:
    let model = LanguageModel() // Or however you initialize it
    let response = try await model.generate(
        prompt: prompt,
        maxTokens: 500,
        temperature: 0.7
    )
    return response.text
}
```

3. **Alternative: Use helper methods for different prompt types**:

```swift
// Summarization
let prompt = service.createSummarizationPrompt(snippets: snippets)

// Q&A
let prompt = service.createQAPrompt(question: query, snippets: snippets)

// Information extraction
let prompt = service.createExtractionPrompt(topic: "flood prevention", snippets: snippets)
```

## Example Queries

### Climate Change (10 results)
- "How does climate change affect coastal cities?"
- "What are the insurance implications of flooding?"
- "Tell me about wetland restoration."

### AI in Education (10 results)
- "What are the benefits of AI in education?"
- "How does AI tutoring compare to human tutors?"
- "What are the privacy concerns with AI in schools?"

### Nutrition & Longevity (10 results)
- "What do Blue Zones tell us about longevity?"
- "Should I take vitamin D supplements?"
- "How much protein do older adults need?"

### Urban Transit (10 results)
- "What are the benefits of protected bike lanes?"
- "How effective are electric buses?"
- "Should transit be fare-free?"

## Keyword Matching

The `matchScenario(for:)` function uses keyword matching. Current keywords:

**Climate**: climate, flood, sea level, coastal, hurricane, storm, wetland, insurance, adaptation, erosion

**Education**: ai, education, student, teacher, learning, school, tutor, classroom, homework, grade

**Nutrition**: nutrition, diet, food, health, vitamin, protein, longevity, aging, microbiome, supplement

**Transit**: transit, bus, bike, transport, subway, train, commute, fare, cycling, electric bus

### To add more keywords:

Edit the `matchScenario(for:)` function in `FakeSearchResults.swift`:

```swift
// Add new keywords to existing checks
if lowercased.contains("climate") || lowercased.contains("flood") ||
   lowercased.contains("YOUR_NEW_KEYWORD") {
    return .climateChangePolicy
}
```

## Data Structure

Each search returns **10 SearchSnippets** with:
- `id`: UUID (unique per snippet)
- `resultID`: UUID (shared by all 10 snippets in a result set)
- `index`: 1-10
- `title`: Descriptive article title
- `tags`: 4-6 relevant tags
- `url`: Unique URL
- `snippet`: 150-200 words of content (realistic, nuanced, with data/quotes)

Total: **40 snippets** (4 scenarios × 10 snippets each)

## Testing

Run the preview to test the interface:

```swift
#Preview {
    SearchAssistantView()
}
```

Or test programmatically:

```swift
let service = SearchAssistantService()
await service.search(query: "How does climate change affect coastal cities?")
assert(service.currentScenario == .climateChangePolicy)
assert(service.currentSearchResults.count == 10)
```

## Next Steps

1. ✅ Keyword matching is implemented (can be refined later)
2. ✅ Search result generation is complete (40 high-quality snippets)
3. ✅ Service layer is ready
4. ⏳ **Integrate actual Foundation Models API** (replace placeholder)
5. ⏳ Add streaming support for real-time responses (optional)
6. ⏳ Add conversation history (optional)
7. ⏳ Add citation formatting (optional)

## Questions?

The system is ready to integrate with Foundation Models. The placeholder will show you the structure, and you just need to replace the `generatePlaceholderResponse` call with the actual API call.
