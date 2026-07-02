//
//  SimpleEnhancedCreateView.swift
//  thesis
//
//  Simple version that immediately creates and opens a new draft
//

import SwiftUI
import RichTextKit
import Core451

/// Simple enhanced Create tab view that immediately opens new drafts
struct SimpleEnhancedCreateView: View {
    @State private var drafts: [Book] = []
    @State private var isLoading = false
    @State private var navigateToNewDraft: Book?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if drafts.isEmpty {
                    VStack(spacing: 16) {
                        Text("No Drafts Yet")
                            .font(.title2).bold()
                        Text("Tap the + button to create your first draft.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(drafts, id: \.id) { book in
                            NavigationLink(destination: DraftEditorView(book: book)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title.isEmpty ? "Untitled Draft" : book.title)
                                        .font(.headline)
                                    Text(book.did)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await deleteDraft(book) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { idxSet in
                            Task {
                                for idx in idxSet {
                                    let book = drafts[idx]
                                    await deleteDraft(book)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await createAndOpenNewDraft() }
                    } label: {
                        Label("New Draft", systemImage: "plus")
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    .help("Reload")
                }
            }
            .task { await reload() }
            .navigationDestination(item: $navigateToNewDraft) { book in
                DraftEditorView(book: book)
            }
        }
    }
    
    // MARK: - Actions
    
    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        if let list = try? await DraftsStore.shared.loadAllDrafts() {
            await MainActor.run { drafts = list }
        }
    }
    
    /// Creates a new draft and immediately opens it for editing
    private func createAndOpenNewDraft() async {
        isLoading = true
        defer { isLoading = false }
        
        if let book = try? await DraftsStore.shared.createNewDraft() {
            await reload()
            await MainActor.run {
                navigateToNewDraft = book
            }
        }
    }
    
    private func deleteDraft(_ book: Book) async {
        isLoading = true
        defer { isLoading = false }
        try? await DraftsStore.shared.delete(id: book.id)
        await reload()
    }
}

#Preview {
    SimpleEnhancedCreateView()
}
