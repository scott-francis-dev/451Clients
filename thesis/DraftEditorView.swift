import SwiftUI
import SwiftUI
import Combine
import RichTextKit
#if canImport(UIKit)
import CoreHaptics
import UIKit
typealias FontDescriptorSymbolicTraits = UIFontDescriptor.SymbolicTraits
#else
import AppKit
typealias FontDescriptorSymbolicTraits = NSFontDescriptor.SymbolicTraits
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

struct DraftEditorView: View {
    // Injected book to edit (no longer created internally)
    @State var book: Book
    @State private var selectedPageIndex: Int = 0

    @StateObject private var keyboard = KeyboardObserver.shared
    @StateObject private var richTextContext = RichTextContext()
    
    // Editor state for RichTextEditor
    @State private var selectedTextRange: NSRange = NSRange(location: 0, length: 0)
    @State private var scrollProgress: CGFloat = 0.0
    @State private var caretProgress: CGFloat = 0.0

    // Block-based document editor state
    @State private var documentBlocks: [DocumentBlock] = []
    @State private var activeBlockId: UUID?
    @State private var activeBlockContext: RichTextContext?

    // Autosave debounce
    @State private var pendingSave = false
    @State private var lastSaveDate = Date()
    private let autosaveDelay: TimeInterval = 1.0   // seconds

    // Track the page we scheduled an autosave for (by id) to avoid index races.
    @State private var scheduledPageID: UUID? = nil
    
    // Debug flags
    private let verboseAutoSaveLogs = false  // Set to true to see detailed autosave logs
    
    // Better typing state tracking
    @State private var isUserTyping: Bool = false
    @State private var typingTimer: Timer?

    /// The chart currently being edited in the right sidebar (macOS only).
    @State private var selectedChart: ChartData? = nil

    // Metadata
    @State private var showMetadata = false
    @State private var showRename = false
    @State private var tempTitle: String = ""

    // Publish gate: publishing requires an active persona. If none exists,
    // the shared soft-gate presents PersonaCreationView first.
    @EnvironmentObject private var personaManager: PersonaManager
    @State private var publishRequested = false
    @State private var showPublishing = false

    // Controls tab bar visibility while this view is visible
    @State private var hideTabBar: Bool = true

    // A virtual extra tab at the end that creates a page when selected.
    private var addPageTabIndex: Int { book.pages.count }

    // Platform-specific toolbar placement
    private var toolbarTrailingPlacement: ToolbarItemPlacement {
        #if canImport(UIKit)
        return .topBarTrailing
        #else
        return .primaryAction
        #endif
    }

    // HUD state for "Page N" badge
    @State private var pageHUDVisible: Bool = false
    @State private var pageHUDText: String = ""

    // Transient hint for creating a new page
    @State private var showAddHint: Bool = false

    // Inline title editing in the navigation bar
    @State private var isEditingNavTitle: Bool = false
    @State private var navTitleDraft: String = ""
    @FocusState private var navTitleFocused: Bool

    // MARK: - macOS sidebars state (moved here from CreateView)
    #if os(macOS)
    @State private var showSidebars: Bool = true

    // Lightweight per-editor search query and derived results
    @State private var _currentSearchQuery: String = ""
    @State private var searchResultsSummary: String = ""
    @State private var isGeneratingSummary: Bool = false
    
    private var searchQueryBinding: Binding<String> {
        Binding<String>(
            get: { 
                _currentSearchQuery 
            },
            set: { newQuery in
                print("🔍 Search query changed: '\(newQuery)'")
                _currentSearchQuery = newQuery
                // Trigger summary generation when search changes
                if !newQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    generateSearchSummary()
                } else {
                    searchResultsSummary = ""
                }
            }
        )
    }
    
    // Real search results for the current query. Populated asynchronously by
    // generateSearchSummary() (search is a network call), rendered by the sidebar.
    @State private var derivedSearchResults: [SearchSnippet] = []

    // Real full-text search against the S451 FTS5 index (replaces FakeSearchResults).
    private let searchService = SearchService()

    // Current page plain text for suggestions
    private var currentPagePlainText: String {
        guard book.pages.indices.contains(selectedPageIndex) else { return "" }
        return book.pages[selectedPageIndex].doc.attributed.string
    }
    
    // Generate AI summary of search results using Foundation Models
    private func generateSearchSummary() {
        guard !_currentSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResultsSummary = ""
            return
        }
        
        isGeneratingSummary = true
        
        Task { @MainActor in
            let q = _currentSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let snippets: [SearchSnippet]
            do {
                snippets = try await searchService.search(query: q, limit: 5).snippets
            } catch {
                derivedSearchResults = []
                searchResultsSummary = "Search failed: \(error.localizedDescription)"
                isGeneratingSummary = false
                return
            }
            derivedSearchResults = snippets

            guard !snippets.isEmpty else {
                searchResultsSummary = "No documents found for \"\(q)\"."
                isGeneratingSummary = false
                return
            }
            
            // Build a description of the search results for the AI
            let resultsDescription = snippets.map { snippet in
                "[\(snippet.index)] \(snippet.title) - \(snippet.snippet) [Source: \(snippet.url)]"
            }.joined(separator: "\n\n")
            
            let instructions = """
            You are a research assistant analyzing search results.
            Provide a conversational, succinct summary that:
            1. States how many results were found
            2. Identifies the main themes across most results
            3. Points out any outliers or unique perspectives (mention specific result numbers like [1], [2], etc.)
            4. Keeps the tone friendly and helpful
            Keep the summary under 150 words.
            """
            
            let prompt = """
            Search query: "\(_currentSearchQuery)"
            
            Results:
            \(resultsDescription)
            
            Provide a conversational summary of these search results.
            """
            
            do {
                // Try to use Apple Foundation Models with streaming
                // Note: The streaming function updates searchResultsSummary directly as it generates
                _ = try await generateSummaryWithFoundationModels(
                    prompt: prompt,
                    instructions: instructions,
                    snippetCount: snippets.count
                )
            } catch {
                print("⚠️ Foundation Models failed: \(error.localizedDescription)")
                // Fallback to static summary
                searchResultsSummary = """
                Found \(snippets.count) results for '\(_currentSearchQuery)'. The search results provide comprehensive coverage including \
                research studies, practical applications, and critical analyses. Key themes include evidence-based approaches, \
                real-world case studies, and diverse perspectives on implementation challenges and opportunities.
                """
            }
            
            isGeneratingSummary = false
        }
    }
    
    // Helper function to call Foundation Models with STREAMING support
    private func generateSummaryWithFoundationModels(prompt: String, instructions: String, snippetCount: Int) async throws -> String {
        // Import FoundationModels and check availability
        // Note: This requires FoundationModels framework to be imported at the top of the file
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        
        // Check if the model is available
        guard case .available = model.availability else {
            // Fall back to generic summary if not available
            throw NSError(domain: "FoundationModels", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Foundation Models not available on this device"
            ])
        }
        
        print("✨ Using Foundation Models to generate summary (streaming)...")
        
        // Create a session with instructions
        let session = LanguageModelSession(instructions: instructions)
        
        // Use STREAMING to update UI in real-time
        let stream = session.streamResponse(to: prompt)
        
        var fullContent = ""
        
        do {
            for try await partial in stream {
                // Update the UI on each chunk
                await MainActor.run {
                    searchResultsSummary = partial.content
                    fullContent = partial.content
                }
            }
            
            print("✅ Foundation Models summary generated (\(fullContent.count) chars)")
            
            return fullContent
        } catch {
            print("❌ Streaming error: \(error.localizedDescription)")
            throw error
        }
        
        #else
        // Foundation Models not available - use fallback
        throw NSError(domain: "FoundationModels", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "FoundationModels framework not imported"
        ])
        #endif
    }
    
    // Check if typed text contains search trigger phrases
    private func checkForSearchTriggers(in text: String) {
        // Auto-surfacing results while typing previously relied on FakeSearchResults' local
        // keyword→scenario table — cheap enough to run per keystroke. Real FTS has no local
        // topic table, and this fires on every text change over the whole page, so auto-search
        // here would mean a network call per keystroke against a poor (full-page) query.
        //
        // TODO(auto-search): reintroduce as a *debounced* trigger that derives a focused query
        // (current sentence or selection), not the entire page, and only fires after typing
        // pauses. Until then the explicit search field drives search; this is intentionally inert.
    }
    #endif

    var body: some View {
        Group {
            #if os(macOS)
            // Three-column editor layout with sidebars on macOS
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    if showSidebars {
                        CreateLLMSuggestionsSidebar(
                            pageText: currentPagePlainText,
                            searchSummary: searchResultsSummary,
                            isGeneratingSummary: isGeneratingSummary
                        )
                            .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
                            .background(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                Rectangle()
                                    .fill(Color(NSColor.separatorColor))
                                    .frame(width: 1),
                                alignment: .trailing
                            )
                    }

                    // Center "paper" area with gray background
                    ZStack {
                        Color(NSColor.controlBackgroundColor)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 0) {
                            pager
                        }
                        .frame(maxWidth: 1100) // Wider for comfortable full-screen editing
                        .background(Color(NSColor.textBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if showSidebars {
                        Group {
                            if let chart = selectedChart {
                                ChartEditorSidebarPanel(
                                    chartData: chart,
                                    onRemove: {
                                        withAnimation { selectedChart = nil }
                                    },
                                    onDismiss: { withAnimation(.easeInOut(duration: 0.2)) { selectedChart = nil } }
                                )
                            } else {
                                CreateSearchResultsSidebar(query: searchQueryBinding, results: derivedSearchResults)
                            }
                        }
                        .frame(minWidth: 220, idealWidth: 280, maxWidth: 360)
                        .background(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            Rectangle()
                                .fill(Color(NSColor.separatorColor))
                                .frame(width: 1),
                            alignment: .leading
                        )
                    }
                }
            }
            // Principal title view (tappable -> inline TextField)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    navTitleView
                }
            }
            // Trailing overflow menu "…"
            .toolbar {
                ToolbarItem(placement: toolbarTrailingPlacement) {
                    overflowMenu
                }
            }
            // macOS toolbar button to toggle sidebars
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSidebars.toggle()
                    } label: {
                        Label(showSidebars ? "Hide Sidebars" : "Show Sidebars",
                              systemImage: showSidebars ? "sidebar.squares.leading" : "sidebar.left")
                    }
                    .help(showSidebars ? "Hide sidebars" : "Show sidebars")
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                }
            }
            #else
            // iOS/iPadOS: keep existing pager/editor without sidebars
            pager
                // Principal title view (tappable -> inline TextField)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        navTitleView
                    }
                }
                // Trailing overflow menu "…"
                .toolbar {
                    ToolbarItem(placement: toolbarTrailingPlacement) {
                        overflowMenu
                    }
                }
                #if canImport(UIKit)
                .toolbar(hideTabBar ? .hidden : .visible, for: .tabBar)
                #endif
            #endif
        }
        .onAppear {
            hideTabBar = true
            ensureInitialPage()
            loadBlocksFromPage()
            showPageHUD()
            showAddHintOverlay()
        }
        .onDisappear {
            if verboseAutoSaveLogs {
                print("🧵 DraftEditorView.onDisappear -> flushAndSaveCurrentPage()")
            }
            cancelPendingAutosave()
            flushAndSaveCurrentPage()
            hideTabBar = false
            
            typingTimer?.invalidate()
            typingTimer = nil
            
            #if canImport(UIKit)
            setTabBarHidden(false)
            #endif
        }
        .sheet(isPresented: $showMetadata) {
            if selectedPageIndex < book.pages.count {
                MetadataView(book: book, page: book.pages[selectedPageIndex])
            }
        }
        // Publish is gated on having a persona (Thesis soft gate). If the user
        // has none, PersonaCreationView is presented; publishing continues once
        // a persona exists.
        .requiresPersona(personaManager, isActive: $publishRequested, onSatisfied: performPublish) {
            NavigationStack {
                PersonaCreationView()
                    .environmentObject(personaManager)
            }
        }
        // Isolated on a background EmptyView so it doesn't collide with the
        // metadata / persona-creation sheets attached above.
        .background(
            EmptyView()
                .sheet(isPresented: $showPublishing) {
                    NavigationStack {
                        PublishingCardsStreamView(autoSimulate: true)
                            .navigationTitle("Publishing")
                            #if canImport(UIKit)
                            .navigationBarTitleDisplayMode(.inline)
                            #endif
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { showPublishing = false }
                                }
                            }
                    }
                }
        )
        .alert("Rename Draft", isPresented: $showRename) {
            TextField("Title", text: $tempTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                book.title = tempTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                Task { try? await DraftsStore.shared.save(book) }
            }
        } message: {
            Text("Set a title for this draft.")
        }
        #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: selectedPageIndex) { newValue in
            if verboseAutoSaveLogs {
                print("📄 Page change -> selectedPageIndex = \(newValue)")
            }
            cancelPendingAutosave()
            showPageHUD()
        }
    }

    // MARK: - Navigation Title View

    @ViewBuilder
    private var navTitleView: some View {
        if isEditingNavTitle {
            TextField("Title", text: $navTitleDraft, onCommit: commitNavTitle)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)
                .submitLabel(.done)
                .focused($navTitleFocused)
                .onAppear {
                    navTitleDraft = (book.title.isEmpty ? "Untitled Draft" : book.title)
                    DispatchQueue.main.async {
                        navTitleFocused = true
                    }
                }
                .onChange(of: navTitleFocused) { focused in
                    if !focused {
                        commitNavTitle()
                    }
                }
        } else {
            Button {
                navTitleDraft = (book.title.isEmpty ? "Untitled Draft" : book.title)
                withAnimation(.easeInOut(duration: 0.15)) {
                    isEditingNavTitle = true
                }
            } label: {
                Text(book.title.isEmpty ? "Untitled Draft" : book.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .accessibilityLabel("Edit Title")
        }
    }

    private func commitNavTitle() {
        let newTitle = navTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if newTitle != book.title {
            book.title = newTitle
            Task { try? await DraftsStore.shared.save(book) }
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            isEditingNavTitle = false
        }
    }

    // MARK: - Overflow menu (ellipsis)

    private var overflowMenu: some View {
        Menu {
            Button("Rename Draft") {
                tempTitle = book.title
                showRename = true
            }
            Button("View Metadata") { showMetadata = true }
            Divider()
            Button("Publish") { publishRequested = true }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .help("More")
    }

    // MARK: - Publish

    /// Called only once a persona is guaranteed to exist (see `.requiresPersona`).
    private func performPublish() {
        flushAndSaveCurrentPage()
        // Present the publishing progress UI. Dispatched so any persona-creation
        // sheet has finished dismissing before this sheet is presented.
        DispatchQueue.main.async { showPublishing = true }
    }

    // MARK: - RichTextEditor attributed text binding
    private var currentPageAttributedText: Binding<NSMutableAttributedString> {
        Binding<NSMutableAttributedString>(
            get: {
                guard book.pages.indices.contains(selectedPageIndex) else { 
                    return NSMutableAttributedString(string: "")
                }
                return NSMutableAttributedString(attributedString: book.pages[selectedPageIndex].doc.attributed)
            },
            set: { newValue in
                guard book.pages.indices.contains(selectedPageIndex) else { return }
                book.pages[selectedPageIndex].doc.attributed = NSMutableAttributedString(attributedString: newValue)
                scheduleAutosave()
            }
        )
    }
    
    private var currentToolbarContext: RichTextContext {
        activeBlockContext ?? richTextContext
    }

    // MARK: - Block ↔ Page sync

    private func loadBlocksFromPage() {
        guard book.pages.indices.contains(selectedPageIndex) else { return }
        let page = book.pages[selectedPageIndex]

        if let decoded = DocumentBlock.decodeBlocks(from: page.documentBlocksJSON) {
            documentBlocks = decoded
            activeBlockId = decoded.first?.id
        } else {
            let content = page.doc.attributed
            let initialId = UUID()
            documentBlocks = [.text(id: initialId, content: NSMutableAttributedString(attributedString: content))]
            activeBlockId = initialId
        }
        activeBlockContext = nil
    }

    private func syncBlocksToPage() {
        guard book.pages.indices.contains(selectedPageIndex) else { return }
        book.pages[selectedPageIndex].documentBlocksJSON = DocumentBlock.encodeBlocks(documentBlocks)

        let combined = NSMutableAttributedString()
        for block in documentBlocks {
            switch block {
            case .text(_, let content):
                combined.append(content)
            case .equation(_, let objectId, let expression):
                let attachment = EquationTextAttachment(objectId: objectId, expressionSource: expression)
                combined.append(NSAttributedString(attachment: attachment))
            case .chart(_, let data):
                let attachment = ChartTextAttachment(objectId: UUID().uuidString, chartData: data)
                combined.append(NSAttributedString(attachment: attachment))
            case .molecule:
                break  // Molecule blocks are rendered by the block editor, not the attributed string
            case .sketch:
                break  // Sketch blocks are rendered by the block editor, not the attributed string
            }
        }
        book.pages[selectedPageIndex].doc.attributed = combined
    }

    private func insertBlockObject(_ object: DocumentBlock) {
        guard let activeId = activeBlockId,
              let ctx = activeBlockContext,
              let index = documentBlocks.firstIndex(where: { $0.id == activeId }),
              case .text(_, let content) = documentBlocks[index] else {
            documentBlocks.append(object)
            let afterId = UUID()
            documentBlocks.append(.text(id: afterId, content: NSMutableAttributedString(string: "")))
            activeBlockId = afterId
            syncBlocksToPage()
            scheduleAutosave()
            return
        }

        let cursor = min(ctx.selectedRange.location, content.length)
        let before = content.attributedSubstring(from: NSRange(location: 0, length: cursor))
        let after = content.attributedSubstring(from: NSRange(location: cursor, length: content.length - cursor))

        let beforeBlock = DocumentBlock.text(id: UUID(), content: NSMutableAttributedString(attributedString: before))
        let afterBlock = DocumentBlock.text(id: UUID(), content: NSMutableAttributedString(attributedString: after))

        documentBlocks.replaceSubrange(index...index, with: [beforeBlock, object, afterBlock])
        activeBlockId = afterBlock.id
        syncBlocksToPage()
        scheduleAutosave()
    }

    // MARK: - Pager with Block Document Editor
    private var pager: some View {
        BlockDocumentEditor(
            blocks: $documentBlocks,
            activeContext: $activeBlockContext,
            activeBlockId: $activeBlockId,
            onChartSelected: { chart in
                #if os(macOS)
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSidebars = true
                    selectedChart = chart
                }
                #endif
            },
            selectedChartData: selectedChart,
            onTextChanged: {
                syncBlocksToPage()

                let text = book.pages[selectedPageIndex].doc.attributed.string
                ActivityManager.triggerIfNeeded(forPlainText: text)

                #if os(macOS)
                checkForSearchTriggers(in: text)
                #endif

                isUserTyping = true
                typingTimer?.invalidate()
                typingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isUserTyping = false
                    }
                }

                scheduleAutosave()
            }
        )
        .onChange(of: selectedPageIndex) { _ in
            cancelPendingAutosave()
            flushAndSaveCurrentPage()
            loadBlocksFromPage()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            editorBottomBar
        }
    }

    @ViewBuilder
    private var editorBottomBar: some View {
        if isUserTyping {
            recommendationPill
                .transition(.opacity.combined(with: .scale(0.9)))
                .animation(.easeInOut(duration: 0.25), value: isUserTyping)
        } else {
            RichTextKit.RichTextKeyboardToolbar(
                context: currentToolbarContext,
                leadingButtons: { _ in
                    HStack(spacing: 8) {
                        Button {
                            currentToolbarContext.toggleStyle(.bold)
                        } label: {
                            Image(systemName: "bold")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(currentToolbarContext.hasStyle(.bold) ? .primary : .secondary)
                        }
                        .accessibilityLabel("Bold")

                        Button {
                            currentToolbarContext.toggleStyle(.italic)
                        } label: {
                            Image(systemName: "italic")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(currentToolbarContext.hasStyle(.italic) ? .primary : .secondary)
                        }
                        .accessibilityLabel("Italic")

                        Button {
                            currentToolbarContext.toggleStyle(.underlined)
                        } label: {
                            Image(systemName: "underline")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(currentToolbarContext.hasStyle(.underlined) ? .primary : .secondary)
                        }
                        .accessibilityLabel("Underline")

                        Button {
                            currentToolbarContext.toggleStyle(.strikethrough)
                        } label: {
                            Image(systemName: "strikethrough")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(currentToolbarContext.hasStyle(.strikethrough) ? .primary : .secondary)
                        }
                        .accessibilityLabel("Strikethrough")
                    }
                },
                trailingButtons: { _ in
                    Button {
                        insertInlineChart()
                    } label: {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Insert Chart")

                    Button {
                        insertInlineEquation()
                    } label: {
                        Image(systemName: "function")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Insert Equation")

                    Button {
                        insertInlineMolecule()
                    } label: {
                        Image(systemName: "atom")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Insert Molecule")

                    Button {
                        insertInlineSketch()
                    } label: {
                        Image(systemName: "scribble.variable")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Insert Sketch")
                },
                formatSheet: { $0 }
            )
            .background(.thinMaterial)
        }
    }

    // MARK: - Recommendation Pill
    private var recommendationPill: some View {
        HStack(spacing: 12) {
            Text("✨ Keep writing...")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                #if canImport(UIKit)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                #endif
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    // MARK: - Per-page editor (unused)
    private func pageEditor(at index: Int) -> some View {
        EmptyView()
    }
           
    // MARK: - Trailing "Add New Page" card
    private var addNewPageCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.secondary)
            Text("New Page")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Swipe left to create new page")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            print("➕ Tapped add-new page card")
            cancelPendingAutosave()
            createNewPageAndSelect()
            showAddHintOverlay()
        }
        .padding()
    }

    // MARK: - Block insertion

    private func insertInlineEquation() {
        insertBlockObject(.equation(id: UUID(), objectId: UUID().uuidString, expression: "x^2 + 2x - 1"))
    }

    private func insertInlineChart() {
        insertBlockObject(.chart(id: UUID(), data: ChartData.sampleTimeSeries()))
    }

    private func insertInlineMolecule() {
        insertBlockObject(.molecule(id: UUID(), objectId: UUID().uuidString, moleculeName: "Caffeine"))
    }

    private func insertInlineSketch() {
        insertBlockObject(.sketch(id: UUID(), objectId: UUID().uuidString, drawingData: Data()))
    }

    // MARK: - Page management
    private func ensureInitialPage() {
        if book.pages.isEmpty {
            let emptyDoc = RichDoc(version: 1, blocks: [
                Block(type: .paragraph, inlines: [.text(TextRun(text: ""))])
            ])
            let data = (try? RichTextCodec.encodeJSON(emptyDoc)) ?? Data()
            let page = Page(title: "Page 1", richTextJSON: data)
            book.pages = [page]
            selectedPageIndex = 0
            Task { try? await DraftsStore.shared.save(book) }
        }
    }

    private func createNewPageAndSelect() {
        autosaveForCurrentSelectionIfValid()
        let emptyDoc = RichDoc(version: 1, blocks: [
            Block(type: .paragraph, inlines: [.text(TextRun(text: ""))])
        ])
        let data = (try? RichTextCodec.encodeJSON(emptyDoc)) ?? Data()
        let new = Page(title: "Page \(book.pages.count + 1)", richTextJSON: data)
        let insertIndex = min(book.pages.count, selectedPageIndex + 1)
        book.pages.insert(new, at: insertIndex)
        selectedPageIndex = insertIndex
        showPageHUD()
        Task { try? await DraftsStore.shared.save(book) }
    }

    private func goToPreviousPage() {
        guard selectedPageIndex > 0 else { return }
        autosaveForCurrentSelectionIfValid()
        selectedPageIndex -= 1
        showPageHUD()
    }

    private func goToNextPage() {
        guard selectedPageIndex + 1 < book.pages.count else { return }
        autosaveForCurrentSelectionIfValid()
        selectedPageIndex += 1
        showPageHUD()
    }
    
    private func goToNextPageOrCreate() {
        if selectedPageIndex + 1 < book.pages.count {
            goToNextPage()
        } else {
            createNewPageAndSelect()
        }
    }

    // MARK: - Autosave
    private func cancelPendingAutosave() {
        pendingSave = false
        scheduledPageID = nil
    }

    private func scheduleAutosave() {
        guard book.pages.indices.contains(selectedPageIndex) else { return }
        pendingSave = true
        let scheduledAt = Date()
        let targetID = book.pages[selectedPageIndex].id
        scheduledPageID = targetID
        if verboseAutoSaveLogs {
            print("⏱️ scheduleAutosave at \(scheduledAt)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + autosaveDelay) {
            let idMatches = (self.scheduledPageID == targetID)
            if self.pendingSave, scheduledAt >= self.lastSaveDate, idMatches {
                if self.verboseAutoSaveLogs {
                    print("⏱️ scheduleAutosave firing -> autosave()")
                }
                self.autosave(targetPageID: targetID)
            } else {
                if self.verboseAutoSaveLogs {
                    print("⏱️ scheduleAutosave skipped (pendingSave=\(self.pendingSave), scheduledAt \(scheduledAt) < lastSaveDate \(self.lastSaveDate), idMatches=\(idMatches))")
                }
            }
        }
    }

    private func autosaveForCurrentSelectionIfValid() {
        guard book.pages.indices.contains(selectedPageIndex) else { return }
        autosave(targetPageID: book.pages[selectedPageIndex].id)
    }

    private func autosave(targetPageID: UUID) {
        guard let idx = book.pages.firstIndex(where: { $0.id == targetPageID }) else {
            if verboseAutoSaveLogs {
                print("⚠️ autosave: target page id not found")
            }
            pendingSave = false
            scheduledPageID = nil
            return
        }
        let attrLen = book.pages[idx].doc.attributed.length
        let beforeBytes = book.pages[idx].richTextJSON.count
        if verboseAutoSaveLogs {
            print("📝 autosave: idx=\(idx), attrLen=\(attrLen), jsonBytes(before)=\(beforeBytes)")
        }

        book.pages[idx].flush(verbose: verboseAutoSaveLogs)

        let afterBytes = book.pages[idx].richTextJSON.count
        if verboseAutoSaveLogs {
            print("✅ autosave: flushed jsonBytes(after)=\(afterBytes) -> saving book...")
        }
        pendingSave = false
        scheduledPageID = nil
        lastSaveDate = Date()
        Task {
            do {
                try await DraftsStore.shared.save(book)
                if verboseAutoSaveLogs {
                    print("💾 autosave: save complete")
                }
            } catch {
                print("❌ autosave: save failed \(error)")
            }
        }
    }

    private func flushAndSaveCurrentPage() {
        guard book.pages.indices.contains(selectedPageIndex) else {
            if verboseAutoSaveLogs {
                print("⚠️ flushAndSave: selectedPageIndex out of bounds")
            }
            return
        }
        syncBlocksToPage()
        let attrLen = book.pages[selectedPageIndex].doc.attributed.length
        let beforeBytes = book.pages[selectedPageIndex].richTextJSON.count
        if verboseAutoSaveLogs {
            print("🧼 flushAndSave: idx=\(selectedPageIndex), attrLen=\(attrLen), jsonBytes(before)=\(beforeBytes))")
        }

        book.pages[selectedPageIndex].flush(verbose: verboseAutoSaveLogs)
        let afterBytes = book.pages[selectedPageIndex].richTextJSON.count
        if verboseAutoSaveLogs {
            print("🧼 flushAndSave: flushed jsonBytes(after)=\(afterBytes) -> saving book...")
        }

        Task {
            do {
                try await DraftsStore.shared.save(book)
                if verboseAutoSaveLogs {
                    print("💾 flushAndSave: save complete")
                }
            } catch {
                print("❌ flushAndSave: save failed \(error)")
            }
        }
    }

    // MARK: - HUD helpers
    private func showPageHUD() {
        guard book.pages.indices.contains(selectedPageIndex) else { return }
        let n = selectedPageIndex + 1
        pageHUDText = "Page \(n)"
        withAnimation(.easeOut(duration: 0.15)) {
            pageHUDVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.25)) {
                pageHUDVisible = false
            }
        }
    }

    private func showAddHintOverlay() {
        withAnimation(.easeOut(duration: 0.15)) {
            showAddHint = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.25)) {
                showAddHint = false
            }
        }
    }
}

#if canImport(UIKit)
// UIKit fallback to ensure tab bar visibility is restored
private func setTabBarHidden(_ hidden: Bool) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first,
          let root = window.rootViewController else { return }
    func toggle(in vc: UIViewController) -> Bool {
        if let tab = vc as? UITabBarController {
            tab.tabBar.isHidden = hidden
            return true
        }
        for child in vc.children {
            if toggle(in: child) { return true }
        }
        if let presented = vc.presentedViewController {
            if toggle(in: presented) { return true }
        }
        return false
    }
    _ = toggle(in: root)
}
#endif

// MARK: - Sidebars moved from CreateView
#if os(macOS)

private struct CreateLLMSuggestionsSidebar: View {
    let pageText: String
    let searchSummary: String
    let isGeneratingSummary: Bool
    
    @State private var suggestions: [String] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header with visual separation
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    Text("AI Assistant")
                        .font(.headline)
                    Spacer()
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh suggestions")
                }
                
                Text("Suggestions appear here as you write")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .fill(Color(NSColor.separatorColor))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // Chat-like scrollable content area
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Show search summary if available
                    if !searchSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "magnifyingglass.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.purple)
                                Text("Search Summary")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                            }
                            
                            if isGeneratingSummary {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Analyzing results...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text(searchSummary)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                        
                        Divider()
                            .padding(.vertical, 4)
                    }
                    
                    // Writing suggestions section
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Thinking…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if suggestions.isEmpty && searchSummary.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "lightbulb")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No suggestions yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Start typing to see AI suggestions")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else if !suggestions.isEmpty {
                        ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                            // Chat bubble-like suggestion card
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                        .padding(.top, 2)
                                    
                                    Text(suggestion)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                }
                                
                                HStack(spacing: 8) {
                                    Button(action: { insertSuggestion(suggestion) }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "doc.on.clipboard")
                                                .font(.caption2)
                                            Text("Copy")
                                                .font(.caption2)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.blue.opacity(0.1), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: { /* Future: apply directly */ }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.right.circle")
                                                .font(.caption2)
                                            Text("Apply")
                                                .font(.caption2)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.green.opacity(0.1), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(NSColor.textBackgroundColor))
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
                            )
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        isLoading = true
        Task { @MainActor in
            let base = String(pageText.prefix(400))
            
            // Skip if the text is empty or too short
            guard !base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                suggestions = []
                isLoading = false
                return
            }
            
            // Provide helpful writing suggestions
            // TODO: Integrate with Apple Intelligence when available
            suggestions = [
                "Consider adding a concrete example to illustrate your point.",
                "This paragraph could be split into two for better readability.",
                "Try varying your sentence structure to improve flow."
            ]
            
            isLoading = false
        }
    }

    private func insertSuggestion(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

private struct CreateSearchResultsSidebar: View {
    @Binding var query: String
    let results: [SearchSnippet]

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header with visual separation
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.purple)
                    Text("Research")
                        .font(.headline)
                    Spacer()
                    if !results.isEmpty {
                        Text("\(results.count) results")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                TextField("Search for references…", text: $query)
                    .textFieldStyle(.roundedBorder)
                
                Text("Find sources and references")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .fill(Color(NSColor.separatorColor))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // Chat-like scrollable results
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if results.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No results")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Search for references to see results here")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ForEach(results) { snippet in
                            // Enhanced result card with more detail
                            VStack(alignment: .leading, spacing: 8) {
                                // Result number and tags
                                HStack {
                                    Text("[\(snippet.index)]")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    // Show first tag if available
                                    if let firstTag = snippet.tags.first {
                                        Text(firstTag)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.purple.opacity(0.1), in: Capsule())
                                            .foregroundStyle(.purple)
                                    }
                                }
                                
                                // Title
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "doc.text")
                                        .font(.caption)
                                        .foregroundStyle(.purple)
                                        .padding(.top, 2)
                                    
                                    Text(snippet.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                }
                                
                                // Snippet
                                Text(snippet.snippet)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .lineLimit(3)
                                
                                // Source URL
                                HStack(spacing: 4) {
                                    Image(systemName: "link")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(snippet.url)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                
                                // Action buttons
                                HStack(spacing: 8) {
                                    Button(action: { 
                                        // Open URL if valid
                                        if let url = URL(string: snippet.url) {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.up.right.square")
                                                .font(.caption2)
                                            Text("Open")
                                                .font(.caption2)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.purple.opacity(0.1), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: { /* Future: insert citation */ }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "text.insert")
                                                .font(.caption2)
                                            Text("Cite")
                                                .font(.caption2)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.blue.opacity(0.1), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: { 
                                        // Copy title to clipboard
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(snippet.title, forType: .string)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "doc.on.clipboard")
                                                .font(.caption2)
                                            Text("Copy")
                                                .font(.caption2)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.gray.opacity(0.1), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(NSColor.textBackgroundColor))
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
                            )
                        }
                    }
                }
                .padding()
            }
        }
    }
}
#endif

