//
//  AIConfiguration.swift
//  wordsmatter
//
//  Created by User451 on 1/1/26.
//

import Foundation
import SwiftUI
import Core451

/// Unified AI manager for Apple Foundation Models (Apple Intelligence)
@MainActor
@Observable
class UnifiedAIManager {
    static let shared = UnifiedAIManager()
    
    // Backend managers
    @available(iOS 26.0, *)
    private var foundationManager: LanguageModelManager { LanguageModelManager.shared }
    
    private init() {
        // Initialization happens lazily for foundationManager via computed property
    }
    
    var isAvailable: Bool {
        if #available(iOS 26.0, *) {
            return foundationManager.isAvailable
        }
        return false
    }

    var statusMessage: String {
        if isAvailable {
            return "Apple Intelligence ready"
        } else {
            return "Apple Intelligence not available (requires iPhone 15 Pro+)"
        }
    }
    
    // MARK: - Text Operations
    
    func improveWriting(_ text: String) async throws -> String {
        if #available(iOS 26.0, *) {
            guard foundationManager.isAvailable else { throw AIError.noProviderAvailable }
            return try await foundationManager.improveWriting(text)
        } else {
            throw AIError.providerNotSupported
        }
    }
    
    func makeConcise(_ text: String) async throws -> String {
        if #available(iOS 26.0, *) {
            guard foundationManager.isAvailable else { throw AIError.noProviderAvailable }
            return try await foundationManager.makeConcise(text)
        } else {
            throw AIError.providerNotSupported
        }
    }
    
    func expandText(_ text: String) async throws -> String {
        if #available(iOS 26.0, *) {
            guard foundationManager.isAvailable else { throw AIError.noProviderAvailable }
            return try await foundationManager.expandText(text)
        } else {
            throw AIError.providerNotSupported
        }
    }
    
    func summarize(_ text: String) async throws -> String {
        if #available(iOS 26.0, *) {
            guard foundationManager.isAvailable else { throw AIError.noProviderAvailable }
            return try await foundationManager.summarize(text)
        } else {
            throw AIError.providerNotSupported
        }
    }
    
    func generateTags(_ text: String, maxTags: Int = 5) async throws -> [String] {
        if #available(iOS 26.0, *) {
            guard foundationManager.isAvailable else { throw AIError.noProviderAvailable }
            return try await foundationManager.generateTags(text, maxTags: maxTags)
        } else {
            throw AIError.providerNotSupported
        }
    }
    
    func continueWriting(from text: String) async throws -> String {
        if #available(iOS 26.0, *) {
            guard foundationManager.isAvailable else { throw AIError.noProviderAvailable }
            return try await foundationManager.continueWriting(from: text)
        } else {
            throw AIError.providerNotSupported
        }
    }
}

// MARK: - Error Types

enum AIError: LocalizedError {
    case noProviderAvailable
    case providerNotSupported
    
    var errorDescription: String? {
        switch self {
        case .noProviderAvailable:
            return "No AI provider is currently available. Enable Apple Intelligence on a supported device."
        case .providerNotSupported:
            return "The selected AI provider is not supported on this device."
        }
    }
}

// MARK: - Settings View

struct AISettingsView: View {
    @State private var aiManager = UnifiedAIManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Current Status") {
                    HStack {
                        Label("Provider", systemImage: "cpu")
                        Spacer()
                        Text(aiManager.isAvailable ? "Apple Intelligence" : "None")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label("Status", systemImage: aiManager.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(aiManager.isAvailable ? .green : .red)
                        Spacer()
                        Text(aiManager.statusMessage)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Capabilities") {
                    if aiManager.isAvailable {
                        Label("Premium Quality", systemImage: "star.fill")
                        Label("Fast Inference", systemImage: "bolt.fill")
                        Label("Requires iPhone 15 Pro+", systemImage: "iphone")
                    } else {
                        Label("No AI Available", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                
                if !aiManager.isAvailable {
                    Section("How to Enable") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("To use Apple Intelligence:")
                                .font(.headline)
                            Text("1. Use iPhone 15 Pro or later")
                            Text("2. Update to iOS 18.2 or later")
                            Text("3. Enable: Settings → Apple Intelligence & Siri")
                        }
                        .font(.caption)
                    }
                }
            }
            .navigationTitle("AI Settings")
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
        }
    }
}

// MARK: - Preview

#Preview {
    AISettingsView()
}

