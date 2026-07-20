//
//  StreamingWritingAssistantView.swift
//  wordsmatter
//
//  Created by User451 on 1/1/26.
//

import SwiftUI

/// A writing assistant view with real-time streaming responses
@available(iOS 26.0, *)
struct StreamingWritingAssistantView: View {
    @State private var inputText = ""
    @State private var streamingOutput = ""
    @State private var isStreaming = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    @Environment(\.dismiss) private var dismiss
    
    let languageModel = LanguageModelManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Model status
                HStack {
                    Image(systemName: languageModel.isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(languageModel.isAvailable ? .green : .orange)
                    
                    Text(languageModel.availabilityMessage)
                        .font(.subheadline)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Input section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Text")
                        .font(.headline)
                    
                    TextEditor(text: $inputText)
                        .frame(minHeight: 120)
                        .font(.body)
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal)
                
                // Action button
                Button {
                    streamImprovement()
                } label: {
                    HStack {
                        if isStreaming {
                            ProgressView()
                                .padding(.trailing, 4)
                        }
                        Text(isStreaming ? "Improving..." : "Improve Writing")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStreaming || !languageModel.isAvailable)
                .padding(.horizontal)
                
                // Streaming output
                if !streamingOutput.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Improved Version")
                                .font(.headline)
                            
                            Spacer()
                            
                            if !isStreaming {
                                Button {
                                    copyToClipboard()
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        ScrollView {
                            Text(streamingOutput)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(minHeight: 120, maxHeight: 300)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.vertical)
            .navigationTitle("Streaming Assistant")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }
    
    private func streamImprovement() {
        Task {
            await streamImprovementAsync()
        }
    }
    
    @MainActor
    private func streamImprovementAsync() async {
        isStreaming = true
        streamingOutput = ""
        errorMessage = nil
        
        defer {
            isStreaming = false
        }
        
        do {
            let stream = languageModel.streamWritingImprovement(inputText)
            
            for try await snapshot in stream {
                // Update UI with each snapshot
                streamingOutput = snapshot
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func copyToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = streamingOutput
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(streamingOutput, forType: .string)
        #endif
    }
}

// MARK: - Preview

#Preview {
    if #available(iOS 26.0, *) {
        StreamingWritingAssistantView()
    } else {
        Text("Requires iOS 26.0 or later")
    }
}
