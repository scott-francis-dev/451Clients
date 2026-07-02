import Foundation
import Core451
#if canImport(SwiftUI)
import SwiftUI
#endif

public struct QueryPlan {
    public let topics: [String]
    public let queries: [String]

    public init(topics: [String], queries: [String]) {
        self.topics = topics
        self.queries = queries
    }
}

public final class AIOrchestrator: TextMonitoringDelegate {
    public let monitor: TextMonitoringService

    public private(set) var latestSentences: [String] = []
    public private(set) var latestResponse: SearchResponse?

    public init() {
        self.monitor = TextMonitoringService()
        self.monitor.delegate = self
    }

    public func attach() {
        // Placeholder for wiring into a RichTextView / editor
    }

    public func update(text: String) {
        monitor.update(text: text)
    }

    public func buildPlan(from lastFour: [String]) -> QueryPlan {
        let context = lastFour.joined(separator: " ")
        let topics = [
            "Biology & gene regulation",
            "Astronomy & observational question",
            "Dairy production & protein feeding",
            "Nutrition & GLP-1 inhibitors"
        ]
        let queries = [
            "Biology gene regulation result, context: \(context)",
            "Astronomy question, context: \(context)",
            "Feeding protein in dairy production, context: \(context)",
            "Nutrition and GLP-1 inhibitors, context: \(context)"
        ]
        return QueryPlan(topics: topics, queries: queries)
    }

    public func performSearch(plan: QueryPlan) -> SearchResponse {
        // TODO: Select scenarios based on plan (stub returns all)
        return FakeSearchResults.makeResponse()
    }

    public func summarizeIfPossible() async {
        // Placeholder for future summarization using UnifiedAIManager.shared
        // Example:
        // let combined = latestResponse?.results.flatMap { $0.snippets }.map { $0.snippet }.joined(separator: "\n\n") ?? ""
        // let summary = try? await UnifiedAIManager.shared.summarize(combined)
        // store or publish summary
    }

    // MARK: - TextMonitoringDelegate
    public func textMonitor(_ monitor: TextMonitoringService, didCompleteSentenceWith lastFourSentences: [String], fullText: String) {
        latestSentences = lastFourSentences
        let plan = buildPlan(from: lastFourSentences)
        let response = performSearch(plan: plan)
        latestResponse = response
        // In a real app, you might publish changes here
    }
}

#if canImport(SwiftUI)
struct AIOrchestratorPreview: View {
    @State private var text: String = "Typing a sentence. Another one follows. And a third ends here."
    private let orchestrator = AIOrchestrator()

    var body: some View {
        VStack(alignment: .leading) {
            TextEditor(text: $text)
                .frame(height: 160)
                .border(Color.secondary)
                .onChange(of: text) { _, newValue in
                    orchestrator.update(text: newValue)
                }
            if let resp = orchestrator.latestResponse {
                Text("Scenarios: \(resp.results.count)")
                Text("Total snippets: \(resp.results.map { $0.snippets.count }.reduce(0, +))")
            } else {
                Text("Type until a period to trigger search...")
            }
            Spacer()
        }
        .padding()
    }
}

#Preview("Orchestrator") {
    AIOrchestratorPreview()
}
#endif
