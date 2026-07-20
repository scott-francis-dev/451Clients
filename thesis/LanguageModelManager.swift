//
//  LanguageModelManager.swift
//  wordsmatter
//
//  Created by User451 on 1/1/26.
//

import Foundation
import FoundationModels
import Observation

/// Manager for interacting with Apple's on-device language model
@available(iOS 26.0, *)
@Observable
@MainActor
class LanguageModelManager {
    static let shared = LanguageModelManager()
    
    // Reference to the system language model
    private let model = SystemLanguageModel.default
    
    // Track model availability
    var availability: SystemLanguageModel.Availability {
        model.availability
    }
    
    var isAvailable: Bool {
        if case .available = availability {
            return true
        }
        return false
    }
    
    var availabilityMessage: String {
        switch availability {
        case .available:
            return "Apple Intelligence is ready"
        case .unavailable(.deviceNotEligible):
            return "Device not eligible for Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Please enable Apple Intelligence in Settings"
        case .unavailable(.modelNotReady):
            return "Model is downloading or not ready"
        case .unavailable:
            return "Model unavailable"
        }
    }
    
    private init() {}
    
    // MARK: - Writing Assistance
    
    /// Improve the writing style of the given text
    func improveWriting(_ text: String) async throws -> String {
        guard isAvailable else {
            throw LanguageModelError.modelUnavailable
        }
        
        let instructions = """
        You are a helpful writing assistant.
        Improve the writing style, grammar, and clarity of the text.
        Maintain the original meaning and tone.
        Keep the length similar to the original.
        Return only the improved text without explanations.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: "Improve this text: \(text)")
        
        return response.content
    }
    
    /// Make text more concise
    func makeConcise(_ text: String) async throws -> String {
        guard isAvailable else {
            throw LanguageModelError.modelUnavailable
        }
        
        let instructions = """
        You are a writing assistant that specializes in concise writing.
        Make the text shorter while preserving key information.
        Remove redundancy and unnecessary words.
        Return only the concise version without explanations.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: text)
        
        return response.content
    }
    
    /// Expand text with more detail
    func expandText(_ text: String) async throws -> String {
        guard isAvailable else {
            throw LanguageModelError.modelUnavailable
        }
        
        let instructions = """
        You are a writing assistant that helps elaborate on ideas.
        Expand the text with relevant details and examples.
        Maintain the original tone and style.
        Return only the expanded text without explanations.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: "Expand this text: \(text)")
        
        return response.content
    }
    
    /// Change the tone of the text
    func changeTone(_ text: String, to tone: WritingTone) async throws -> String {
        guard isAvailable else {
            throw LanguageModelError.modelUnavailable
        }
        
        let instructions = """
        You are a writing assistant that adjusts writing tone.
        Rewrite the text in a \(tone.description) tone.
        Maintain the core meaning and information.
        Return only the rewritten text without explanations.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: text)
        
        return response.content
    }
    
    // MARK: - Content Generation
    
    /// Generate a summary of the text
    func summarize(_ text: String, length: SummaryLength = .medium) async throws -> String {
        guard isAvailable else {
            throw LanguageModelError.modelUnavailable
        }
        
        let instructions = """
        You are a summarization assistant.
        Create a \(length.description) summary of the text.
        Focus on the main ideas and key points.
        Return only the summary without explanations.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: text)
        
        return response.content
    }
    
    /// Generate tags for content
    func generateTags(_ text: String, maxTags: Int = 5) async throws -> [String] {
        guard isAvailable else {
            throw LanguageModelError.modelUnavailable
        }
        
        let instructions = """
        You are a content tagging assistant.
        Generate up to \(maxTags) relevant tags for the text.
        Tags should be concise and descriptive.
        Return only the tags, separated by commas.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: text)
        
        // Parse comma-separated tags
        let tags: [String] = response.content
            .split(separator: ",")
            .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.isEmpty }

        return Array(tags.prefix(maxTags))
    }
    
    /// Continue writing from a prompt
    func continueWriting(from prompt: String, style: WritingStyle = .general) async throws -> String {
        guard isAvailable else {
            throw LanguageModelError.modelUnavailable
        }
        
        let instructions = """
        You are a creative writing assistant.
        Continue the writing in a \(style.description) style.
        Match the tone and style of the existing text.
        Write 2-3 sentences to continue the narrative.
        Return only the continuation without explanations.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: "Continue this: \(prompt)")
        
        return response.content
    }
    
    // MARK: - Structured Generation
    
    /// Generate a draft outline based on a title and description
    func generateOutline(title: String, description: String) async throws -> DraftOutline {
        guard isAvailable else {
            throw LanguageModelError.modelUnavailable
        }
        
        let instructions = """
        You are an outline generation assistant.
        Create a clear, logical outline for the given topic.
        Include 3-5 main sections with brief descriptions.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        let prompt = "Create an outline for: '\(title)'. Description: \(description)"
        
        let response = try await session.respond(
            to: prompt,
            generating: DraftOutline.self
        )
        
        return response.content
    }
    
    // MARK: - Streaming Support
    
    /// Stream writing improvements in real-time
    func streamWritingImprovement(_ text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard isAvailable else {
                        throw LanguageModelError.modelUnavailable
                    }
                    
                    let instructions = """
                    You are a helpful writing assistant.
                    Improve the writing style, grammar, and clarity of the text.
                    Maintain the original meaning and tone.
                    """
                    
                    let session = LanguageModelSession(instructions: instructions)
                    let stream = session.streamResponse(to: "Improve this text: \(text)")
                    
                    var accumulated = ""
                    for try await partial in stream {
                        // Yield progressive updates based on full snapshot content
                        let content = partial.content
                        // Skip if nothing new yet
                        if content.isEmpty { continue }
                        
                        // Compute incremental delta by removing the common prefix
                        let newText: String
                        if content.hasPrefix(accumulated) {
                            let startIndex = content.index(content.startIndex, offsetBy: accumulated.count)
                            newText = String(content[startIndex...])
                        } else {
                            // In case the model revises earlier text, yield the full content
                            newText = content
                        }
                        accumulated = content
                        continuation.yield(newText)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum LanguageModelError: LocalizedError {
    case modelUnavailable
    case generationFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Language model is not available"
        case .generationFailed:
            return "Failed to generate content"
        case .invalidResponse:
            return "Received invalid response from model"
        }
    }
}

enum WritingTone: String, CaseIterable {
    case professional
    case casual
    case friendly
    case formal
    case creative
    
    var description: String {
        rawValue
    }
}

enum WritingStyle: String, CaseIterable {
    case general
    case narrative
    case descriptive
    case academic
    case conversational
    
    var description: String {
        rawValue
    }
}

enum SummaryLength: String, CaseIterable {
    case short
    case medium
    case detailed
    
    var description: String {
        rawValue
    }
}

// MARK: - Generable Types

@available(iOS 26.0, *)
@Generable(description: "An outline for a writing draft")
struct DraftOutline {
    @Guide(description: "The main title of the outline")
    var title: String
    
    @Guide(description: "Main sections of the outline", .count(3...5))
    var sections: [OutlineSection]
}

@available(iOS 26.0, *)
@Generable(description: "A section in a draft outline")
struct OutlineSection {
    @Guide(description: "The section heading")
    var heading: String
    
    @Guide(description: "A brief description of what this section covers")
    var description: String
}

