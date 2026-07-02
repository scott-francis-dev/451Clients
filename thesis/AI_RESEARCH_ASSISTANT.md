# AI-Powered Research Assistant Feature

## Overview
This feature creates an intelligent two-panel research assistant for the macOS editor view:
- **Left Sidebar (Area 1)**: AI-generated conversational summary of search results
- **Right Sidebar (Area 2)**: Detailed list of 10 search results with metadata

## How It Works

### User Flow
1. User types a search query in the **Research** sidebar (Area 2)
2. System generates 10 fake search results instantly
3. **Foundation Models** analyzes all 10 results and creates a conversational summary
4. Summary appears in the **AI Assistant** sidebar (Area 1)
5. All 10 detailed results appear in the **Research** sidebar (Area 2)

### Example Output

#### Area 1 - AI Summary (Left Sidebar):
```
10 results found for 'AI in Education'. Most of these results focus on 
practical applications and implementation strategies for using AI in 
educational settings. Results 4 and 7 offer alternative perspectives, 
with #4 exploring historical context of educational technology and #7 
examining critical analysis of potential limitations and challenges.
```

#### Area 2 - Search Results (Right Sidebar):
```
#1: Introduction to AI in Education
    A comprehensive overview covering the fundamentals...
    Source: Academic Journal
    [Open] [Cite] [Copy]

#2: Advanced AI in Education Techniques
    Exploring cutting-edge methods and recent developments...
    Source: Research Paper
    [Open] [Cite] [Copy]

... (8 more results)
```

## Key Features

### SearchResult Structure
```swift
struct SearchResult: Identifiable {
    let id: Int                  // Result number (1-10)
    let title: String            // Result title
    let snippet: String          // Brief description
    let source: String           // Source attribution
    let relevance: Relevance     // High/Medium/Low with color coding
}
```

### AI Summary Generation
- **Automatic**: Triggers whenever user enters a search query
- **Conversational**: Friendly, succinct analysis (under 150 words)
- **Insightful**: Identifies:
  - Total number of results
  - Main themes across results
  - Outliers or unique perspectives (with specific result numbers)
- **Fallback**: Provides default summary if Foundation Models unavailable

### Visual Features
- **Relevance Indicators**: Color-coded dots (green/orange/gray) show result quality
- **Result Numbers**: Each result numbered #1-#10 for easy reference
- **Source Attribution**: Shows where each result comes from
- **Interactive Actions**: Open, Cite, and Copy buttons for each result

## Foundation Models Integration

### Summary Generation Prompt
```
You are a research assistant analyzing search results.
Provide a conversational, succinct summary that:
1. States how many results were found
2. Identifies the main themes across most results
3. Points out any outliers or unique perspectives (mention specific result numbers)
4. Keeps the tone friendly and helpful
Keep the summary under 150 words.
```

### Graceful Degradation
- If Foundation Models unavailable (iOS < 26.0 or Apple Intelligence disabled)
- Falls back to a sensible default summary
- All 10 search results still displayed normally

## UI/UX Details

### Left Sidebar (AI Assistant)
- Purple-tinted card for search summaries
- Progress indicator while generating
- Separate section from writing suggestions
- Divider between search and writing content

### Right Sidebar (Research)
- Result count badge in header
- Detailed cards with:
  - Result number and relevance badge
  - Title (bold)
  - Snippet (3-line limit)
  - Source with icon
  - Action buttons

## Benefits

1. **Contextual Understanding**: AI helps users quickly understand what they're looking at
2. **Outlier Detection**: Highlights unique or different perspectives
3. **Efficient Research**: Users can quickly assess 10 results without reading all details
4. **Reference Guidance**: AI points to specific results worth deeper investigation
5. **Natural Language**: Conversational tone makes research feel approachable

## Future Enhancements

Potential improvements:
- Real search API integration (replacing fake results)
- Click to highlight referenced results (e.g., clicking "results 4 and 7" in summary)
- Save summaries to notes
- Export citations
- Filter by relevance level
- Search history
