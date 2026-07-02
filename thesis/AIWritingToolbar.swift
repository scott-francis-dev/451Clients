//
//  AIWritingToolbar.swift
//  wordsmatter
//
//  Created by User451 on 1/1/26.
//

import SwiftUI
import Core451

/// A toolbar view that provides quick AI-powered writing tools
/// Can be embedded in your text editor views
@available(iOS 26.0, *)
struct AIWritingToolbar: View {
    @Binding var text: String
    let onTextChanged: (String) -> Void
    
    @State private var isProcessing = false
    @State private var showingFullAssistant = false
    @State private var showingTagGenerator = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    let languageModel = LanguageModelManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Model availability indicator
            if languageModel.isAvailable {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                    .font(.caption)
            }
            
            // Quick actions
            Menu {
                Button {
                    performQuickAction(.improve)
                } label: {
                    Label("Improve", systemImage: "wand.and.stars")
                }
                
                Button {
                    performQuickAction(.makeConcise)
                } label: {
                    Label("Make Concise", systemImage: "arrow.down.right.and.arrow.up.left")
                }
                
                Button {
                    performQuickAction(.expand)
                } label: {
                    Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                
                Divider()
                
                Button {
                    performQuickAction(.summarize)
                } label: {
                    Label("Summarize", systemImage: "text.alignleft")
                }
                
                Button {
                    showingTagGenerator = true
                } label: {
                    Label("Generate Tags", systemImage: "tag.fill")
                }
                
                Divider()
                
                Button {
                    showingFullAssistant = true
                } label: {
                    Label("More Options...", systemImage: "ellipsis.circle")
                }
            } label: {
                HStack(spacing: 4) {
                    if isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isProcessing ? "Processing..." : "AI Tools")
                        .font(.subheadline)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing || !languageModel.isAvailable)
            
            Spacer()
            
            // Character count
            Text("\(text.count) characters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showingFullAssistant) {
            WritingAssistantView()
        }
        .sheet(isPresented: $showingTagGenerator) {
            SmartTagGeneratorView(text: text) { tags in
                print("Generated tags: \(tags)")
                // You can add tags to your draft metadata here
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }
    
    private enum QuickAction {
        case improve
        case makeConcise
        case expand
        case summarize
    }
    
    private func performQuickAction(_ action: QuickAction) {
        Task {
            await performQuickActionAsync(action)
        }
    }
    
    @MainActor
    private func performQuickActionAsync(_ action: QuickAction) async {
        isProcessing = true
        errorMessage = nil
        
        defer {
            isProcessing = false
        }
        
        do {
            let result: String
            
            switch action {
            case .improve:
                result = try await languageModel.improveWriting(text)
            case .makeConcise:
                result = try await languageModel.makeConcise(text)
            case .expand:
                result = try await languageModel.expandText(text)
            case .summarize:
                result = try await languageModel.summarize(text)
            }
            
            text = result
            onTextChanged(result)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Example Usage

@available(iOS 26.0, *)
struct ExampleEditorView: View {
    @State private var draftText = "This is an example of how to use the AI writing toolbar in your text editor."
    
    var body: some View {
        VStack(spacing: 0) {
            // Your text editor
            TextEditor(text: $draftText)
                .font(.body)
                .padding()
            
            Divider()
            
            // AI toolbar
            AIWritingToolbar(text: $draftText) { newText in
                // Handle text changes
                print("Text updated by AI: \(newText)")
                // Save to draft, etc.
            }
        }
        .navigationTitle("Draft Editor")
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview {
    NavigationStack {
        ExampleEditorView()
    }
}
