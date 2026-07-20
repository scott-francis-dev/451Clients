//
//  WritingAssistantView.swift
//  wordsmatter
//
//  Created by User451 on 1/1/26.
//

import SwiftUI

/// A view that provides AI-powered writing assistance
@available(iOS 26.0, macOS 15.0, *)
struct WritingAssistantView: View {
    @State private var inputText = ""
    @State private var outputText = ""
    @State private var isProcessing = false
    @State private var selectedAction: AssistantAction = .improve
    @State private var selectedTone: WritingTone = .professional
    @State private var errorMessage: String?
    @State private var showingError = false
    
    @Environment(\.dismiss) private var dismiss
    
    let languageModel = LanguageModelManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                // Model availability status
                Section {
                    HStack {
                        Image(systemName: languageModel.isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(languageModel.isAvailable ? .green : .orange)
                        
                        Text(languageModel.availabilityMessage)
                            .font(.subheadline)
                    }
                }
                
                // Input section
                Section("Your Text") {
                    TextEditor(text: $inputText)
                        .frame(minHeight: 120)
                        .font(.body)
                }
                
                // Action selection
                Section("What would you like to do?") {
                    Picker("Action", selection: $selectedAction) {
                        ForEach(AssistantAction.allCases) { action in
                            Label(action.title, systemImage: action.icon)
                                .tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    // Show tone picker for tone changes
                    if selectedAction == .changeTone {
                        Picker("Tone", selection: $selectedTone) {
                            ForEach(WritingTone.allCases, id: \.self) { tone in
                                Text(tone.rawValue.capitalized)
                                    .tag(tone)
                            }
                        }
                    }
                }
                
                // Generate button
                Section {
                    Button {
                        performAction()
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text(isProcessing ? "Processing..." : "Generate")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing || !languageModel.isAvailable)
                }
                
                // Output section
                if !outputText.isEmpty {
                    Section("Result") {
                        Text(outputText)
                            .textSelection(.enabled)
                        
                        Button {
                            copyToClipboard()
                        } label: {
                            Label("Copy Result", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
            .navigationTitle("Writing Assistant")
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
    
    private func performAction() {
        Task {
            await performActionAsync()
        }
    }
    
    @MainActor
    private func performActionAsync() async {
        isProcessing = true
        outputText = ""
        errorMessage = nil
        
        defer {
            isProcessing = false
        }
        
        do {
            let result: String
            
            switch selectedAction {
            case .improve:
                result = try await languageModel.improveWriting(inputText)
            case .makeConcise:
                result = try await languageModel.makeConcise(inputText)
            case .expand:
                result = try await languageModel.expandText(inputText)
            case .changeTone:
                result = try await languageModel.changeTone(inputText, to: selectedTone)
            case .summarize:
                result = try await languageModel.summarize(inputText)
            case .continueWriting:
                result = try await languageModel.continueWriting(from: inputText)
            }
            
            outputText = result
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func copyToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = outputText
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        #endif
    }
}

// MARK: - Assistant Actions

enum AssistantAction: String, CaseIterable, Identifiable {
    case improve
    case makeConcise
    case expand
    case changeTone
    case summarize
    case continueWriting
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .improve: return "Improve Writing"
        case .makeConcise: return "Make Concise"
        case .expand: return "Expand"
        case .changeTone: return "Change Tone"
        case .summarize: return "Summarize"
        case .continueWriting: return "Continue Writing"
        }
    }
    
    var icon: String {
        switch self {
        case .improve: return "wand.and.stars"
        case .makeConcise: return "arrow.down.right.and.arrow.up.left"
        case .expand: return "arrow.up.left.and.arrow.down.right"
        case .changeTone: return "slider.horizontal.3"
        case .summarize: return "text.alignleft"
        case .continueWriting: return "pencil.and.outline"
        }
    }
}

// MARK: - Preview

@available(iOS 26.0, macOS 15.0, *)
#Preview {
    WritingAssistantView()
}
