# Foundation Models Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Your App (wordsmatter)                   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────────┐     ┌──────────────────┐                │
│  │ DiscoveryView  │────>│ Writing          │                │
│  │                │     │ AssistantView    │                │
│  │  [✨ Button]   │     └──────────────────┘                │
│  └────────────────┘              │                           │
│                                   │                           │
│  ┌────────────────┐              │                           │
│  │ Draft Editor   │              │                           │
│  │ Views          │──────────────┘                           │
│  │                │              │                           │
│  └────────────────┘              │                           │
│         │                        │                           │
│         │                        │                           │
│         v                        v                           │
│  ┌─────────────────────────────────────────┐                │
│  │      LanguageModelManager.shared        │                │
│  ├─────────────────────────────────────────┤                │
│  │  ┌──────────────────────────────────┐   │                │
│  │  │  • improveWriting()              │   │                │
│  │  │  • makeConcise()                 │   │                │
│  │  │  • expandText()                  │   │                │
│  │  │  • changeTone()                  │   │                │
│  │  │  • summarize()                   │   │                │
│  │  │  • generateTags()                │   │                │
│  │  │  • continueWriting()             │   │                │
│  │  │  • generateOutline()             │   │                │
│  │  │  • streamWritingImprovement()    │   │                │
│  │  └──────────────────────────────────┘   │                │
│  └─────────────────────────────────────────┘                │
│                        │                                     │
│                        │                                     │
│                        v                                     │
│  ┌─────────────────────────────────────────┐                │
│  │         SystemLanguageModel             │                │
│  │         (FoundationModels)              │                │
│  └─────────────────────────────────────────┘                │
│                        │                                     │
└────────────────────────┼─────────────────────────────────────┘
                         │
                         v
         ┌───────────────────────────────┐
         │   Apple Intelligence          │
         │   (On-Device LLM)             │
         └───────────────────────────────┘
```

## Data Flow

### 1. User Interaction Flow

```
User writes text
     │
     v
┌─────────────┐
│ Text Editor │
└─────────────┘
     │
     v
Taps AI button (✨)
     │
     v
┌──────────────────────┐
│ WritingAssistantView │
└──────────────────────┘
     │
     v
Selects action (improve, summarize, etc.)
     │
     v
┌───────────────────────┐
│ LanguageModelManager  │
└───────────────────────┘
     │
     v
Checks availability
     │
     ├─> Available ──────> Process request
     │                          │
     └─> Unavailable ──> Show error message
                                │
                                v
                     ┌──────────────────┐
                     │ Apple Intelligence│
                     └──────────────────┘
                                │
                                v
                         Process on-device
                                │
                                v
                       Return improved text
                                │
                                v
                       Update UI with result
                                │
                                v
                       User copies or saves
```

### 2. Streaming Flow

```
User requests improvement
     │
     v
┌─────────────────────────────┐
│ streamWritingImprovement()  │
└─────────────────────────────┘
     │
     v
Start async stream
     │
     v
┌─────────────────────┐
│ for await snapshot  │◄──┐
└─────────────────────┘   │
     │                    │
     v                    │
Update UI (real-time) ────┘
     │
     v
Stream completes
     │
     v
Final text displayed
```

## Component Hierarchy

```
App Root
│
├── DiscoveryView
│   ├── Toolbar
│   │   ├── AI Button (✨) ────> WritingAssistantView
│   │   └── Create Button (+)
│   │
│   └── Feed Items
│       └── FeedCard
│           └── (Can generate tags with AI)
│
├── Draft Editor Views
│   ├── TextEditor
│   ├── AIWritingToolbar
│   │   ├── Quick Actions Menu
│   │   │   ├── Improve
│   │   │   ├── Make Concise
│   │   │   ├── Expand
│   │   │   └── Summarize
│   │   │
│   │   └── Full Assistant Button
│   │
│   └── Character Count
│
└── Writing Assistant Views
    ├── WritingAssistantView (Full featured)
    ├── StreamingWritingAssistantView (Real-time)
    └── SmartTagGeneratorView (Tag generation)
```

## Data Model Integration

```
┌─────────────────┐
│      Book       │
│                 │
│  • title        │
│  • description  │
│  • author       │
│  • subject      │ ◄──── AI can generate
│  • pages[]      │
└─────────────────┘
        │
        ├──> generateAITags() ────────┐
        ├──> generateAIDescription()  │
        │                             │
        v                             │
┌─────────────────┐                  │
│      Page       │                  │
│                 │                  │
│  • title        │                  │
│  • richTextJSON │                  v
│  • doc          │         ┌────────────────────┐
└─────────────────┘         │ LanguageModelManager│
        │                   └────────────────────┘
        ├──> plainTextContent()
        ├──> improveWriting()
        └──> summarize()
```

## Extension Architecture

```
Book Extensions (DraftExtensions+AI.swift)
│
├── generateAITags() async throws -> [String]
│   └── Extracts content from all pages
│       └── Generates contextual tags
│
├── generateAIDescription() async throws -> String
│   └── Samples first 3 pages
│       └── Creates concise description
│
Page Extensions
│
├── plainTextContent() -> String
│   └── Converts RichDoc to plain text
│
├── improveWriting() async throws
│   └── Improves text and updates richTextJSON
│
└── summarize() async throws -> String
    └── Creates summary of page content

DraftsStore Extensions
│
└── createDraftWithAIOutline() async throws -> Book
    ├── Generates AI outline
    ├── Creates pages from sections
    └── Saves to storage
```

## State Management

```
┌─────────────────────────────────────┐
│     LanguageModelManager             │
│                                      │
│  @MainActor                          │
│  @Observable                         │
│                                      │
│  Properties:                         │
│  • model: SystemLanguageModel       │
│  • availability: Availability        │
│  • isAvailable: Bool                │
│  • availabilityMessage: String      │
│                                      │
│  Shared Instance:                   │
│  static let shared = ...            │
└─────────────────────────────────────┘
           │
           │ Observable by
           v
┌─────────────────────────────────────┐
│         UI Views                     │
│                                      │
│  Access via:                         │
│  let manager =                       │
│      LanguageModelManager.shared    │
│                                      │
│  React to:                           │
│  • availability changes              │
│  • processing state                  │
│  • result updates                    │
└─────────────────────────────────────┘
```

## Error Handling Flow

```
User action
    │
    v
Check availability ─────> Unavailable ──> Show error
    │                                     (Enable AI)
    │
    v Available
    │
Perform AI operation
    │
    ├─> Success ──────> Display result
    │
    └─> Error ────────> Catch error
                             │
                             ├─> modelUnavailable
                             ├─> generationFailed
                             └─> invalidResponse
                                      │
                                      v
                              Show user-friendly
                                  message
```

## Performance Considerations

```
┌─────────────────────────────────┐
│     Token Limit: 4096           │
│  (Instructions + Prompt +       │
│   Previous context)             │
└─────────────────────────────────┘
           │
           v
┌─────────────────────────────────┐
│  Chunking Strategy              │
│                                 │
│  For large documents:           │
│  • Split into pages             │
│  • Process incrementally        │
│  • Show progress updates        │
│  • Combine results              │
└─────────────────────────────────┘
           │
           v
┌─────────────────────────────────┐
│  User Experience                │
│                                 │
│  • Use streaming for real-time  │
│  • Show progress indicators     │
│  • Allow cancellation           │
│  • Cache when appropriate       │
└─────────────────────────────────┘
```

## Testing Strategy

```
Unit Tests
├── Manager Initialization
├── Availability Checking
├── Error Handling
└── Mock Testing

Integration Tests
├── Book Extensions
├── Page Extensions
├── DraftsStore AI Methods
└── UI Component Integration

UI Tests
├── Writing Assistant Flow
├── Toolbar Interactions
├── Tag Generation
└── Error State Display

Device Tests (Required)
└── Real Apple Intelligence
    ├── iPhone 15 Pro+
    ├── iPad M1+
    └── Mac Apple Silicon
```

## Future Enhancements

```
Current Implementation
    │
    ├─> Writing assistance
    ├─> Tag generation
    ├─> Summarization
    └─> Outline creation
         │
         v
    Future Ideas
    │
    ├─> Multi-language support
    ├─> Style presets
    ├─> Grammar-only mode
    ├─> Plagiarism detection
    ├─> Writing analytics
    ├─> Collaboration features
    ├─> Voice integration
    └─> Custom training data
```

---

This architecture provides:
- ✅ Clean separation of concerns
- ✅ Reusable components
- ✅ Extensible design
- ✅ Testable structure
- ✅ User-friendly error handling
- ✅ Performance optimization
