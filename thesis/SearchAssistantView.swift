import SwiftUI
import Core451

/// Example SwiftUI view demonstrating the SearchAssistantService
struct SearchAssistantView: View {
    @State private var service = SearchAssistantService()
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Input Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type a question and end with a period (.)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        TextField("Ask about climate, education, nutrition, or transit...", 
                                text: $service.currentText,
                                axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                            .focused($isTextFieldFocused)
                            .onChange(of: service.currentText) { oldValue, newValue in
                                service.handleTextInput(newValue)
                            }
                    }
                    .padding()
                    .background(.background)
                    
                    // Matched Scenario
                    if let scenario = service.currentScenario {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Matched Topic", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text(scenario.title)
                                .font(.headline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Processing Indicator
                    if service.isProcessing {
                        HStack {
                            ProgressView()
                            Text("Analyzing search results...")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                    
                    // Error Message
                    if let error = service.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    // AI Response
                    if !service.aiResponse.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("AI Analysis", systemImage: "sparkles")
                                .font(.headline)
                            
                            Text(service.aiResponse)
                                .font(.body)
                            
                            Text("Based on \(service.currentSearchResults.count) search results")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.secondary.opacity(0.15))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Search Results
                    if !service.currentSearchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Search Results (\(service.currentSearchResults.count))")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(service.currentSearchResults.prefix(3)) { snippet in
                                SearchResultCard(snippet: snippet)
                            }
                            
                            if service.currentSearchResults.count > 3 {
                                Text("+ \(service.currentSearchResults.count - 3) more results")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Search Assistant")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear", action: service.reset)
                        .disabled(service.currentText.isEmpty && service.aiResponse.isEmpty)
                }
            }
        }
    }
}

struct SearchResultCard: View {
    let snippet: SearchSnippet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snippet.title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(snippet.snippet)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            HStack {
                ForEach(snippet.tags.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(.tertiary)
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    SearchAssistantView()
}

#Preview("With Sample Data") {
    SearchAssistantViewWithService(service: createSampleService())
}

// Helper function to create a pre-populated service for preview
private func createSampleService() -> SearchAssistantService {
    var service = SearchAssistantService()
    service.currentText = "How does climate change affect coastal cities."
    service.currentScenario = FakeScenario.climateChangePolicy
    service.aiResponse = "Based on the search results, climate change significantly impacts coastal cities through rising sea levels, increased storm intensity, and economic challenges..."
    service.currentSearchResults = Array(FakeSearchResults.allSnippets.prefix(5))
    return service
}
// Helper view for preview with injected service
private struct SearchAssistantViewWithService: View {
    @State var service: SearchAssistantService
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Input Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type a question and end with a period (.)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        TextField("Ask about climate, education, nutrition, or transit...", 
                                text: $service.currentText,
                                axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                            .focused($isTextFieldFocused)
                            .onChange(of: service.currentText) { oldValue, newValue in
                                service.handleTextInput(newValue)
                            }
                    }
                    .padding()
                    .background(.background)
                    
                    // Matched Scenario
                    if let scenario = service.currentScenario {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Matched Topic", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text(scenario.title)
                                .font(.headline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Processing Indicator
                    if service.isProcessing {
                        HStack {
                            ProgressView()
                            Text("Analyzing search results...")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                    
                    // Error Message
                    if let error = service.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    // AI Response
                    if !service.aiResponse.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("AI Analysis", systemImage: "sparkles")
                                .font(.headline)
                            
                            Text(service.aiResponse)
                                .font(.body)
                            
                            Text("Based on \(service.currentSearchResults.count) search results")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.secondary.opacity(0.15))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Search Results
                    if !service.currentSearchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Search Results (\(service.currentSearchResults.count))")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(service.currentSearchResults.prefix(3)) { snippet in
                                SearchResultCard(snippet: snippet)
                            }
                            
                            if service.currentSearchResults.count > 3 {
                                Text("+ \(service.currentSearchResults.count - 3) more results")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Search Assistant")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear", action: service.reset)
                        .disabled(service.currentText.isEmpty && service.aiResponse.isEmpty)
                }
            }
        }
    }
}

