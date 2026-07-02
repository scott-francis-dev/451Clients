//
//  SmartTagGenerator.swift
//  wordsmatter
//
//  Created by User451 on 1/1/26.
//

import SwiftUI
import Core451

/// A view for generating smart tags using AI
@available(iOS 26.0, *)
struct SmartTagGeneratorView: View {
    let text: String
    let onTagsGenerated: ([String]) -> Void
    
    @State private var generatedTags: [String] = []
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    @Environment(\.dismiss) private var dismiss
    
    let languageModel = LanguageModelManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: languageModel.isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(languageModel.isAvailable ? .green : .orange)
                        
                        Text(languageModel.availabilityMessage)
                            .font(.subheadline)
                    }
                }
                
                Section("Preview") {
                    Text(text)
                        .font(.body)
                        .lineLimit(5)
                        .foregroundStyle(.secondary)
                }
                
                if !generatedTags.isEmpty {
                    Section("Generated Tags") {
                        ForEach(generatedTags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                Image(systemName: "tag.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                
                Section {
                    if isGenerating {
                        HStack {
                            ProgressView()
                            Text("Generating tags...")
                        }
                    } else if generatedTags.isEmpty {
                        Button("Generate Tags") {
                            generateTags()
                        }
                        .disabled(!languageModel.isAvailable)
                    } else {
                        Button("Use These Tags") {
                            onTagsGenerated(generatedTags)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        
                        Button("Regenerate") {
                            generateTags()
                        }
                    }
                }
            }
            .navigationTitle("Smart Tags")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .onAppear {
                if languageModel.isAvailable && generatedTags.isEmpty {
                    generateTags()
                }
            }
        }
    }
    
    private func generateTags() {
        Task {
            await generateTagsAsync()
        }
    }
    
    @MainActor
    private func generateTagsAsync() async {
        isGenerating = true
        errorMessage = nil
        
        defer {
            isGenerating = false
        }
        
        do {
            generatedTags = try await languageModel.generateTags(text, maxTags: 6)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview {
    SmartTagGeneratorView(
        text: "This is a fascinating article about machine learning and artificial intelligence in modern applications.",
        onTagsGenerated: { tags in
            print("Generated tags: \(tags)")
        }
    )
}
