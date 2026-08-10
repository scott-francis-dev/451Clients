import Foundation
import FoundationModels
import Core451

/// Service that handles search queries and AI-powered analysis using Apple Foundation Models
@Observable
public class SearchAssistantService {
    
    // MARK: - Properties
    
    /// The current sentence being typed by the user
    public var currentText: String = ""
    
    /// The last processed query
    public var lastQuery: String = ""
    
    /// The AI-generated response
    public var aiResponse: String = ""
    
    /// Loading state
    public var isProcessing: Bool = false
    
    /// Error message if something goes wrong
    public var errorMessage: String?
    
    /// The search results that were used for the current response
    public var currentSearchResults: [SearchSnippet] = []
    
    /// The matched scenario for the current query.
    /// Legacy: only the mock path set this. The real search path leaves it nil.
    public var currentScenario: FakeScenario?

    /// Real full-text search against the S451 FTS5 index. Replaces the FakeSearchResults path.
    private let searchService = SearchService()

    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// Call this method when text changes to detect sentence completion
    public func handleTextInput(_ text: String) {
        currentText = text
        
        // Check if sentence is complete (ends with period)
        if text.hasSuffix(".") && text.count > 1 {
            let sentence = text.trimmingCharacters(in: .whitespaces)
            if !sentence.isEmpty && sentence != lastQuery {
                Task {
                    await processSentence(sentence)
                }
            }
        }
    }
    
    /// Manually trigger search and analysis for a specific query
    public func search(query: String) async {
        await processSentence(query)
    }
    
    /// Clear the current response and reset state
    public func reset() {
        currentText = ""
        lastQuery = ""
        aiResponse = ""
        errorMessage = nil
        currentSearchResults = []
        currentScenario = nil
        isProcessing = false
    }
    
    // MARK: - Private Methods
    
    private func processSentence(_ sentence: String) async {
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
            lastQuery = sentence
        }
        
        // 1. Run a real full-text search against the S451 FTS5 index.
        //    limit: 5 + .citations realizes the "five most-cited documents" flow.
        let searchResult: SearchResult
        do {
            // Default weights = citation-dominant "most cited" blend; tune RankingWeights later.
            searchResult = try await searchService.search(query: sentence, limit: 5)
        } catch {
            await MainActor.run {
                isProcessing = false
                errorMessage = "Search failed: \(error.localizedDescription)"
            }
            return
        }

        guard !searchResult.snippets.isEmpty else {
            await MainActor.run {
                isProcessing = false
                errorMessage = "No documents found for \"\(sentence)\"."
            }
            return
        }

        await MainActor.run {
            currentSearchResults = searchResult.snippets
        }

        // 2. Send to Foundation Models for analysis.
        //    TODO(content-hop): snippets carry titles only — search returns no body. Fetch each
        //    hit's content before this step so the model reasons over documents, not just titles.
        do {
            let response = try await analyzeWithFoundationModels(
                query: sentence,
                snippets: searchResult.snippets
            )
            
            await MainActor.run {
                aiResponse = response
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                isProcessing = false
                errorMessage = "Error analyzing results: \(error.localizedDescription)"
            }
        }
    }
    
    /// Sends the query and search results to Apple Foundation Models for analysis
    private func analyzeWithFoundationModels(query: String, snippets: [SearchSnippet]) async throws -> String {
        // Build context from search results with proper formatting
        let context = snippets.enumerated().map { index, snippet in
            """
            [\(index + 1)] \(snippet.title)
            \(snippet.snippet)
            Source: \(snippet.url)
            Tags: \(snippet.tags.joined(separator: ", "))
            """
        }.joined(separator: "\n\n---\n\n")
        
        // Create the prompt for the Foundation Model
        let prompt = """
        You are a helpful research assistant. Based on the following search results, provide a comprehensive and accurate answer to the user's question.
        
        User Question: \(query)
        
        Search Results:
        \(context)
        
        Instructions:
        - Provide a clear, well-structured answer
        - Cite specific sources using their numbers [1], [2], etc.
        - If there are conflicting viewpoints in the sources, acknowledge them
        - Be concise but thorough
        - If the search results don't contain enough information to fully answer the question, acknowledge this
        
        Answer:
        """
        
        // TODO: Call Foundation Models API here
        // For now, we'll use a placeholder implementation
        // Replace this with actual Foundation Models API call:
        
        /*
        let model = LanguageModel()
        let response = try await model.generate(
            prompt: prompt,
            maxTokens: 500,
            temperature: 0.7
        )
        return response.text
        */
        
        // Placeholder response for testing
        return await generatePlaceholderResponse(query: query, snippetCount: snippets.count)
    }
    
    /// Placeholder function that simulates an AI response
    /// Replace this when Foundation Models API is ready
    private func generatePlaceholderResponse(query: String, snippetCount: Int) async -> String {
        // Simulate network delay
        try? await Task.sleep(for: .seconds(1.5))
        
        return """
        Based on the \(snippetCount) search results found for your query "\(query)", here's a comprehensive answer:
        
        [This is a placeholder response. When the Foundation Models API is integrated, this will be replaced with an AI-generated answer that synthesizes information from all the search results, cites specific sources, and provides nuanced insights based on the content.]
        
        The search results cover multiple perspectives on this topic, including:
        • Research findings and statistical data
        • Real-world case studies and examples
        • Expert opinions and analysis
        • Policy implications and recommendations
        
        To get the full AI-powered analysis, integrate the Foundation Models API in the `analyzeWithFoundationModels` method.
        """
    }
}

// MARK: - Foundation Models Integration Helper

/// Extension with helper methods for Foundation Models integration
extension SearchAssistantService {
    
    /// Creates a structured prompt optimized for summarization
    public func createSummarizationPrompt(snippets: [SearchSnippet]) -> String {
        let context = snippets.map { snippet in
            "Title: \(snippet.title)\n\(snippet.snippet)"
        }.joined(separator: "\n\n")
        
        return """
        Summarize the key points from these articles:
        
        \(context)
        
        Provide a concise summary highlighting the main themes and findings.
        """
    }
    
    /// Creates a structured prompt optimized for question answering
    public func createQAPrompt(question: String, snippets: [SearchSnippet]) -> String {
        let context = snippets.enumerated().map { index, snippet in
            "[\(index + 1)] \(snippet.title)\n\(snippet.snippet)\nSource: \(snippet.url)"
        }.joined(separator: "\n\n")
        
        return """
        Answer the following question using only information from the provided sources. Cite sources using their numbers.
        
        Question: \(question)
        
        Sources:
        \(context)
        
        Answer:
        """
    }
    
    /// Creates a structured prompt for extracting specific information
    public func createExtractionPrompt(topic: String, snippets: [SearchSnippet]) -> String {
        let context = snippets.map { snippet in
            "Title: \(snippet.title)\n\(snippet.snippet)"
        }.joined(separator: "\n\n")
        
        return """
        Extract all information related to "\(topic)" from the following articles:
        
        \(context)
        
        List the key facts, statistics, and findings related to this topic.
        """
    }
}
