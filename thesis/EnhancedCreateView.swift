//
//  EnhancedCreateView.swift
//  thesis
//
//  Created for improved Create tab experience
//

import SwiftUI
import RichTextKit

/// Enhanced Create tab view with improved + button functionality
struct EnhancedCreateView: View {
    @State private var drafts: [Book] = []
    @State private var isLoading = false
    @State private var showingCreateOptions = false
    @State private var showingTemplateChooser = false
    @State private var selectedTemplate: DraftTemplate?
    
    // Quick create options
    @State private var quickCreateTitle = ""
    @State private var showingQuickCreate = false
    @FocusState private var titleFieldFocused: Bool
    
    // Animation states
    @State private var animateEmptyState = false
    @Namespace private var createNamespace


    
    var body: some View {
        #if os(macOS)
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Group {
                    if isLoading { loadingView }
                    else if drafts.isEmpty { enhancedEmptyStateView }
                    else { draftsListView }
                }
            }
            .navigationTitle("Create")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { Task { await reload() } } label: {
                        Image(systemName: "arrow.clockwise").font(.body.weight(.medium))
                    }
                    .disabled(isLoading)
                    enhancedCreateButton
                }
            }
            .task { await reload() }
            .sheet(isPresented: $showingTemplateChooser) { templateChooserView }
            .sheet(isPresented: $showingQuickCreate) { quickCreateView }
        }
        #else
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Group {
                    if isLoading { loadingView }
                    else if drafts.isEmpty { enhancedEmptyStateView }
                    else { draftsListView }
                }
            }
            .navigationTitle("Create")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { Task { await reload() } } label: {
                        Image(systemName: "arrow.clockwise").font(.body.weight(.medium))
                    }
                    .disabled(isLoading)
                    enhancedCreateButton
                }
            }
            .task { await reload() }
            .sheet(isPresented: $showingTemplateChooser) { templateChooserView }
            .sheet(isPresented: $showingQuickCreate) { quickCreateView }
        }
        #endif
    }
    
    // MARK: - Enhanced Create Button
    
    private var enhancedCreateButton: some View {
        Menu {
            // Quick create option
            Button {
                showingQuickCreate = true
            } label: {
                Label("Quick Draft", systemImage: "doc.text.fill")
            }
            
            Divider()
            
            // Template options
            Button {
                selectedTemplate = .article
                createFromTemplate()
            } label: {
                Label("Article", systemImage: "newspaper.fill")
            }
            
            Button {
                selectedTemplate = .story
                createFromTemplate()
            } label: {
                Label("Story", systemImage: "book.fill")
            }
            
            Button {
                selectedTemplate = .journal
                createFromTemplate()
            } label: {
                Label("Journal Entry", systemImage: "journal.badge.plus")
            }
            
            Button {
                selectedTemplate = .letter
                createFromTemplate()
            } label: {
                Label("Letter", systemImage: "envelope.fill")
            }
            
            Divider()
            
            Button {
                showingTemplateChooser = true
            } label: {
                Label(
                    "Browse Templates",
                    systemImage: "list.bullet.rectangle.portrait.fill"
                )
            }
            
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 32, height: 32)
                
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityLabel("Create New Draft")
        .accessibilityHint("Choose from quick create options or templates")
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading drafts...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Enhanced Empty State
    
    private var enhancedEmptyStateView: some View {
        VStack(spacing: 32) {
            // Animated illustration
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateEmptyState ? 1.05 : 1.0)
                
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
                    .scaleEffect(animateEmptyState ? 1.1 : 1.0)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    animateEmptyState = true
                }
            }
            
            VStack(spacing: 12) {
                Text("Ready to Create")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choose from templates or start with a quick draft")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Create action buttons with glass effects
            VStack(spacing: 16) {
                Button {
                    showingQuickCreate = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.fill")
                        Text("Quick Draft")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: 200)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    showingTemplateChooser = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                        Text("Browse Templates")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: 200)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Drafts List View
    
    private var draftsListView: some View {
        List {
            ForEach(drafts, id: \.id) { book in
                DraftCard(book: book) {
                    Task { await deleteDraft(book) }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Quick Create View
    
    private var quickCreateView: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                    
                    Text("Quick Draft")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Give your draft a title to get started")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Title input with glass effect
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.headline)
                    
                    TextField("Enter title...", text: $quickCreateTitle)
                        .textFieldStyle(.roundedBorder)
                        .focused($titleFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            createQuickDraft()
                        }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        showingQuickCreate = false
                        quickCreateTitle = ""
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Create") {
                        createQuickDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(quickCreateTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("Quick Create")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                titleFieldFocused = true
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Template Chooser View
    
    private var templateChooserView: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 160), spacing: 16)
                ], spacing: 16) {
                    ForEach(DraftTemplate.allCases, id: \.self) { template in
                        TemplateCard(template: template) {
                            selectedTemplate = template
                            showingTemplateChooser = false
                            createFromTemplate()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Templates")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingTemplateChooser = false
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        if let list = try? await DraftsStore.shared.loadAllDrafts() {
            await MainActor.run { 
                withAnimation(.easeInOut) {
                    drafts = list
                }
            }
        }
    }
    
    private func createQuickDraft() async {
        guard !quickCreateTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if var book = try? await DraftsStore.shared.createNewDraft() {
            book.title = quickCreateTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            try? await DraftsStore.shared.save(book)
            
            await reload()
            
            await MainActor.run {
                showingQuickCreate = false
                quickCreateTitle = ""
            }
        }
    }
    
    private func createQuickDraft() {
        Task {
            await createQuickDraft()
        }
    }
    
    private func createFromTemplate() {
        guard let template = selectedTemplate else { return }
        
        Task {
            if var book = try? await DraftsStore.shared.createNewDraft() {
                // Apply template
                book.title = template.defaultTitle
                
                // Set template content
                if let templateContent = template.content {
                    if let firstPage = book.pages.first {
                        var updatedPage = firstPage
                        updatedPage.title = template.defaultTitle
                        let doc = RichDoc(version: 1, blocks: [
                            Block(type: .paragraph, inlines: [.text(TextRun(text: templateContent))])
                        ])
                        if let data = try? RichTextCodec.encodeJSON(doc) {
                            updatedPage.richTextJSON = data
                        }
                        book.pages = [updatedPage]
                    }
                }
                
                try? await DraftsStore.shared.save(book)
                await reload()
            }
        }
    }
    
    private func deleteDraft(_ book: Book) async {
        isLoading = true
        defer { isLoading = false }
        try? await DraftsStore.shared.delete(id: book.id)
        await reload()
    }
    
    private func deleteItems(offsets: IndexSet) {
        Task {
            for index in offsets {
                let book = drafts[index]
                await deleteDraft(book)
            }
        }
    }
}

// MARK: - Draft Template Enum

enum DraftTemplate: CaseIterable {
    case article
    case story
    case journal
    case letter
    case blank
    
    var title: String {
        switch self {
        case .article: return "Article"
        case .story: return "Story"
        case .journal: return "Journal Entry"
        case .letter: return "Letter"
        case .blank: return "Blank"
        }
    }
    
    var icon: String {
        switch self {
        case .article: return "newspaper.fill"
        case .story: return "book.fill"
        case .journal: return "journal.badge.plus"
        case .letter: return "envelope.fill"
        case .blank: return "doc.text.fill"
        }
    }
    
    var description: String {
        switch self {
        case .article: return "Perfect for news, blog posts, or reports"
        case .story: return "Creative writing and storytelling"
        case .journal: return "Personal thoughts and daily entries"
        case .letter: return "Formal or informal correspondence"
        case .blank: return "Start from scratch"
        }
    }
    
    var defaultTitle: String {
        switch self {
        case .article: return "Untitled Article"
        case .story: return "Untitled Story"
        case .journal: return "Journal Entry - \(DateFormatter.shortDate.string(from: Date()))"
        case .letter: return "Untitled Letter"
        case .blank: return "Untitled Draft"
        }
    }
    
    var content: String? {
        switch self {
        case .article:
            return "# Article Title\n\nWrite your article here..."
        case .story:
            return "# Story Title\n\nOnce upon a time..."
        case .journal:
            return "# \(DateFormatter.longDate.string(from: Date()))\n\nToday I..."
        case .letter:
            return "Dear [Name],\n\n\n\nSincerely,\n[Your name]"
        case .blank:
            return nil
        }
    }
    
    var color: Color {
        switch self {
        case .article: return .blue
        case .story: return .purple
        case .journal: return .green
        case .letter: return .orange
        case .blank: return .gray
        }
    }
}

// MARK: - Supporting Views

struct DraftCard: View {
    let book: Book
    let onDelete: () -> Void
    
    var body: some View {
        NavigationLink(destination: DraftEditorView(book: book)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(book.title.isEmpty ? "Untitled Draft" : book.title)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let firstPage = book.pages.first {
                    let preview = firstPage.doc.attributed.string.prefix(100)
                    if !preview.isEmpty {
                        Text(String(preview))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text("Empty draft")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                }
                
                HStack {
                    Text(book.did)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                    
                    Text("\(book.pages.count) page\(book.pages.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    // Add a subtle delete button for additional discoverability
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                // Could add duplicate functionality here later
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct TemplateCard: View {
    let template: DraftTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(template.color.opacity(0.2))
                        .frame(height: 80)
                    
                    Image(systemName: template.icon)
                        .font(.system(size: 32))
                        .foregroundStyle(template.color)
                }
                
                VStack(spacing: 4) {
                    Text(template.title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text(template.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Date Formatter Extensions

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    static let longDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
}

#Preview {
    EnhancedCreateView()
}


