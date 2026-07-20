import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif

public protocol TextMonitoringDelegate: AnyObject {
    func textMonitor(_ monitor: TextMonitoringService, didCompleteSentenceWith lastFourSentences: [String], fullText: String)
}

public final class TextMonitoringService {
    public weak var delegate: TextMonitoringDelegate?
    private var latestText: String = ""
    private let queue = DispatchQueue(label: "TextMonitoringService.queue")
    private var pendingWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.25

    public init(delegate: TextMonitoringDelegate? = nil) {
        self.delegate = delegate
    }

    public func update(text: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.latestText = text
            self.pendingWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.process(text: text)
            }
            self.pendingWorkItem = work
            self.queue.asyncAfter(deadline: .now() + self.debounceInterval, execute: work)
        }
    }

    private func process(text: String) {
        // Check if the last non-whitespace character is a period
        guard let lastChar = text.trimmingCharacters(in: .whitespacesAndNewlines).last, lastChar == "." else {
            return
        }
        let sentences = Self.lastFourSentences(from: text)
        delegate?.textMonitor(self, didCompleteSentenceWith: sentences, fullText: text)
    }

    public static func lastFourSentences(from text: String) -> [String] {
        #if canImport(NaturalLanguage)
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var ranges: [Range<String.Index>] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            ranges.append(range)
            return true
        }
        let sentences = ranges.map { String(text[$0]).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return Array(sentences.suffix(4))
        #else
        // Fallback: split on ., ?, ! and collapse whitespace
        let parts = text.components(separatedBy: CharacterSet(charactersIn: ".?!"))
        let sentences = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return Array(sentences.suffix(4))
        #endif
    }
}

#if canImport(SwiftUI)
final class TextMonitoringPreview: View, TextMonitoringDelegate {
    @State private var text: String = ""
    @State private var lastFour: [String] = []
    private let monitor = TextMonitoringService()

    init() {
        monitor.delegate = self
    }

    func textMonitor(_ monitor: TextMonitoringService, didCompleteSentenceWith lastFourSentences: [String], fullText: String) {
        DispatchQueue.main.async {
            self.lastFour = lastFourSentences
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            TextEditor(text: $text)
                .frame(height: 160)
                .border(Color.secondary)
                .onChange(of: text) { [weak self] _, newValue in
                    self?.monitor.update(text: newValue)
                }
            Text("Last four sentences:")
                .font(.headline)
            ForEach(lastFour, id: \.self) { s in
                Text("• \(s)").font(.caption)
            }
            Spacer()
        }.padding()
    }
}

#Preview("Text Monitor") {
    TextMonitoringPreview()
}
#endif

