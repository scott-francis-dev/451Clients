//
//  DiscoveryView.swift
//  wordsmatter
//
//  Created by User451 on 9/8/25.
//

import SwiftUI
import RichTextKit
import Charts
import Core451

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct DiscoveryView: View {
    // MARK: - Feed Filter
    enum FeedFilter: String, CaseIterable {
        case forYou = "For You"
        case trending = "Trending"
        case popular = "Popular"
    }
    
    // Temporary demo data — replace with your real models later
    let feedItems = [
        FeedItem(title: "Deep Residual Learning for Image Recognition",
                 subtitle: "Proceedings of CVPR 2016",
                 author: "John Siam",
                 date: "Sep 9, 2025",
                 score: 54, citations: 49, likes: 20648,
                 tags: ["Neural Networks", "Machine Learning", "Residual Learning Frameworks"],
                 description: "Deeper neural networks are notoriously hard to train, and accuracy often degrades once depth passes a certain point. We present a residual learning framework that reformulates layers as learning residual functions with reference to the layer inputs. These networks are easier to optimize and gain accuracy from considerably increased depth. On ImageNet we evaluate residual nets up to 152 layers, eight times deeper than VGG while still having lower complexity. An ensemble of these networks achieves a 3.57% top-5 error on the test set, winning first place at ILSVRC 2015. The same representations transfer remarkably well to detection and segmentation tasks, suggesting the approach is broadly useful.",
                 chart: reelDemoChart(.line, title: "Top-1 accuracy vs. network depth")),
        FeedItem(title: "Before & After",
                 subtitle: "Stories of Orphans Who Survived",
                 author: "Josie Siam",
                 date: "Aug 28, 2025",
                 score: 23, citations: 16, likes: 3638,
                 tags: ["Orphan", "Loss", "Grief", "Rediscovery"],
                 description: "Before & After follows a dozen children across two decades, from the night each lost their family to the lives they built afterward. Drawn from years of interviews, it refuses easy narratives of rescue and instead listens for the smaller turning points. We meet a girl who learns to trust again through a borrowed library card and a boy who finds a brother in a crowded shelter. The book traces how grief settles into the body and how, slowly, it makes room for something else. Cohort outcomes are charted not as statistics but as the texture of ordinary mornings. By the final pages, survival has quietly become a kind of authorship over one's own story.",
                 chart: reelDemoChart(.bar, title: "Outcomes by cohort")),
        FeedItem(title: "A Brief Discussion of Time and its Limitations",
                 subtitle: "Proceedings of CVPR 2016",
                 author: "Lucy Longly",
                 date: "Sep 9, 2025",
                 score: 54, citations: 49, likes: 20648,
                 tags: ["Physics", "Time-Space Continuum", "Relativity"],
                 description: "Time feels absolute, yet every measurement we make of it is stubbornly local. This paper revisits the limitations of clocks, from atomic oscillators to the relativistic frames that bend them. We derive a dilation factor and show how it compounds across nested reference frames. A worked example traces a signal through three observers, none of whom agree on its duration. The implications reach beyond physics into how we model causality in distributed systems. We close by arguing that time's limitations are not a flaw to be corrected but a feature that defines measurement itself.",
                 chart: reelDemoChart(.equation, title: "Dilation factor f(x) = 4x³ − 3")),
        FeedItem(title: "Before & After",
                 subtitle: "My Dog Sam",
                 author: "Josie Siam",
                 date: "Aug 28, 2025",
                 score: 23, citations: 16, likes: 3638,
                 tags: ["Dogs", "Friendship", "Loyalty"],
                 description: "My Dog Sam began as a stray who refused to leave the porch and ended as the center of a household. This is a small memoir about the years in between, told one walk at a time. Sam had a talent for arriving exactly when the day had gone wrong, leaning his full weight against whoever needed it. The book charts our walks per week as the seasons turned, a quiet ledger of an ordinary devotion. There are no grand adventures here, only the steady accumulation of trust. When Sam was gone, the routes remained, and walking them became its own kind of remembering.",
                 chart: reelDemoChart(.area, title: "Walks per week")),

    ]
    
    // State for search and create functionality
    @State private var searchText = ""
    @State private var showingTemplateChooser = false
    @State private var showingQuickCreate = false
    @State private var selectedTemplate: DraftTemplate?
    @State private var quickCreateTitle = ""
    @FocusState private var titleFieldFocused: Bool
    @State private var selectedFilter: FeedFilter = .forYou
    @State private var showingAdvancedFilters = false
    @State private var showingWritingAssistant = false

    // Drives the auto-hiding filter bar: visible at the top and when scrolling
    // up, hidden while scrolling down into the feed.
    @State private var filterVisible = true
    
    // Filtered items based on search
    private var filteredItems: [FeedItem] {
        let base: [FeedItem]
        if searchText.isEmpty {
            base = feedItems
        } else {
            base = feedItems.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.subtitle.localizedCaseInsensitiveContains(searchText) ||
                item.author.localizedCaseInsensitiveContains(searchText) ||
                item.description.localizedCaseInsensitiveContains(searchText) ||
                item.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
        }
        switch selectedFilter {
        case .forYou:
            // Heuristic: prioritize score, then likes
            return base.sorted { ($0.score, $0.likes) > ($1.score, $1.likes) }
        case .trending:
            // Use citations as a proxy for trending
            return base.sorted { $0.citations > $1.citations }
        case .popular:
            // Sort by likes descending
            return base.sorted { $0.likes > $1.likes }
        }
    }

    // Segmented feed filter.
    private var filterPicker: some View {
        Picker("Feed Filter", selection: $selectedFilter) {
            Text("For You").tag(FeedFilter.forYou)
            Text("Trending").tag(FeedFilter.trending)
            Text("Popular").tag(FeedFilter.popular)
        }
        .pickerStyle(.segmented)
    }

    // Floating, frosted filter bar that slides in/out as the feed is scrolled.
    private var filterBar: some View {
        filterPicker
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    if filteredItems.isEmpty {
                        FeedEmptyPage(isSearching: !searchText.isEmpty)
                            .containerRelativeFrame([.horizontal, .vertical])
                    } else {
                        ForEach(filteredItems) { item in
                            FeedReelPage(item: item)
                                .containerRelativeFrame([.horizontal, .vertical])
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .modifier(ScrollDirectionHide(visible: $filterVisible))
            .overlay(alignment: .top) {
                if filterVisible {
                    filterBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle("Discover")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .searchable(text: $searchText, prompt: "Search articles, stories...")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Advanced sort & filter options.
                    Button {
                        showingAdvancedFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("More filters")

                    // AI Writing Assistant button
                    Button {
                        showingWritingAssistant = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "sparkles")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.purple)
                        }
                    }
                    .accessibilityLabel("Writing Assistant")
                    .accessibilityHint("Get AI-powered writing help")
                    
                    // Quick create menu button
                    Menu {
                        // Quick create option
                        Button {
                            showingQuickCreate = true
                        } label: {
                            Label("Quick Draft", systemImage: "bolt.fill")
                        }
                        
                        Divider()
                        
                        // Template options
                        Button {
                            selectedTemplate = .article
                            createFromTemplate()
                        } label: {
                            Label("Article", systemImage: "newspaper.fill")
                        }
                        
                        Button {
                            selectedTemplate = .story
                            createFromTemplate()
                        } label: {
                            Label("Story", systemImage: "book.fill")
                        }
                        
                        Button {
                            selectedTemplate = .journal
                            createFromTemplate()
                        } label: {
                            Label("Journal Entry", systemImage: "journal.badge.plus")
                        }
                        
                        Button {
                            selectedTemplate = .letter
                            createFromTemplate()
                        } label: {
                            Label("Letter", systemImage: "envelope.fill")
                        }
                        
                        Divider()
                        
                        Button {
                            showingTemplateChooser = true
                        } label: {
                            Label("Browse Templates", systemImage: "list.bullet.rectangle.portrait.fill")
                        }
                        
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .accessibilityLabel("Create New Draft")
                    .accessibilityHint("Quickly create drafts from Discover tab")
                }
            }
            .sheet(isPresented: $showingTemplateChooser) {
                templateChooserView
            }
            .sheet(isPresented: $showingQuickCreate) {
                quickCreateView
            }
            .sheet(isPresented: $showingAdvancedFilters) {
                advancedFiltersView
            }
            .sheet(isPresented: $showingWritingAssistant) {
                if #available(iOS 26.0, macOS 15.0, *) {
                    WritingAssistantView()
                } else {
                    Text("Writing Assistant requires iOS 26.0 or later")
                        .padding()
                }
            }
        }
    }
    
    // MARK: - Template Chooser View
    
    private var templateChooserView: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 160), spacing: 16)
                ], spacing: 16) {
                    ForEach(DraftTemplate.allCases, id: \.self) { template in
                        DiscoveryTemplateCard(template: template) {
                            selectedTemplate = template
                            showingTemplateChooser = false
                            createFromTemplate()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Templates")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingTemplateChooser = false
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Create View
    
    private var quickCreateView: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                    
                    Text("Quick Draft")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Give your draft a title to get started")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Title input with glass effect
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.headline)
                    
                    TextField("Enter title...", text: $quickCreateTitle)
                        .textFieldStyle(.roundedBorder)
                        .focused($titleFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            createQuickDraft()
                        }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        showingQuickCreate = false
                        quickCreateTitle = ""
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Create") {
                        createQuickDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(quickCreateTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("Quick Create")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                titleFieldFocused = true
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Advanced Filters (placeholder)
    private var advancedFiltersView: some View {
        NavigationStack {
            Form {
                Section(header: Text("Sort")) {
                    Picker("Default Sort", selection: $selectedFilter) {
                        Text("For You").tag(FeedFilter.forYou)
                        Text("Trending").tag(FeedFilter.trending)
                        Text("Popular").tag(FeedFilter.popular)
                    }
                    .pickerStyle(.inline)
                }

                Section(footer: Text("More precise filtering coming soon.")) {
                    Toggle("Include only high score (50+)", isOn: .constant(false))
                    Toggle("Include only highly cited (25+)", isOn: .constant(false))
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showingAdvancedFilters = false
                    }
                }
            }
        }
    }
    
    // MARK: - Create Actions
    
    private func createQuickDraft() async {
        guard !quickCreateTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if var book = try? await DraftsStore.shared.createNewDraft() {
            book.title = quickCreateTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            try? await DraftsStore.shared.save(book)
            
            await MainActor.run {
                showingQuickCreate = false
                quickCreateTitle = ""
            }
        }
    }
    
    private func createQuickDraft() {
        Task {
            await createQuickDraft()
        }
    }
    
    private func createFromTemplate() {
        guard let template = selectedTemplate else { return }
        
        Task {
            if var book = try? await DraftsStore.shared.createNewDraft() {
                // Apply template
                book.title = template.defaultTitle
                
                // Set template content
                if let templateContent = template.content {
                    if let firstPage = book.pages.first {
                        var updatedPage = firstPage
                        updatedPage.title = template.defaultTitle
                        let doc = RichDoc(version: 1, blocks: [
                            Block(type: .paragraph, inlines: [.text(TextRun(text: templateContent))])
                        ])
                        if let data = try? RichTextCodec.encodeJSON(doc) {
                            updatedPage.richTextJSON = data
                        }
                        book.pages = [updatedPage]
                    }
                }
                
                try? await DraftsStore.shared.save(book)
            }
        }
    }
}


struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.title2).bold()
            .padding(.horizontal)
    }
}

struct CardView: View {
    let title: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
        }
        .frame(width: 140, height: 100)
        .background(color)
        .cornerRadius(12)
        .shadow(radius: 3)
    }
}

struct FeedItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let author: String
    let date: String      // short-format date string for display
    let score: Int
    let citations: Int
    let likes: Int
    let tags: [String]
    let description: String
    /// The seminal chart/graph for this work — the actual "content" of the reel.
    let chart: ChartData

    /// Stable identity for persistence (UUID is regenerated each launch).
    var interestKey: String { "\(title)|\(author)" }

    /// A compact snapshot used by the interest memory.
    func makeInterestRecord(savedAt: Date) -> InterestRecord {
        InterestRecord(
            id: interestKey,
            title: title,
            subtitle: subtitle,
            author: author,
            tags: tags,
            summary: description,
            savedAt: savedAt
        )
    }
}

/// Builds a demo chart for the feed. Real models will supply their own `ChartData`.
func reelDemoChart(_ type: ChartVisualizationType, title: String) -> ChartData {
    let data: ChartData = (type == .equation) ? .sampleEquation() : .sample()
    if type != .equation { data.visualizationType = type }
    data.chartTitle = title
    return data
}

// MARK: - Utilities

private var systemBackgroundColor: Color {
    #if canImport(UIKit)
    return Color(.systemBackground)
    #else
    return Color(.controlBackgroundColor)
    #endif
}

struct FeedCard: View {
    let item: FeedItem
    
    // Target card height so the book can fill it
    private let cardContentHeight: CGFloat = 210
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Left: text block + bubbles below it
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // Author
                        Text(item.author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // More spacing between bubbles to push the rightmost one toward the book
                    HStack(spacing: 40) {
                        StatBubble(title: "Score", value: item.score.description, diameter: 40) {
                            print("Score tapped for \(item.title)")
                        }
                        StatBubble(title: "Citations", value: item.citations.description, diameter: 40) {
                            print("Citations tapped for \(item.title)")
                        }
                        StatBubble(title: "Likes", value: item.likes.description, diameter: 40) {
                            print("Likes tapped for \(item.title)")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right: book that almost fills the card height
                BookThumbnail(
                    colorSeed: item.title,
                    size: .fill(height: cardContentHeight - 8),
                    title: item.title,
                    subtitle: item.subtitle,
                    author: item.author,
                    date: item.date
                )
                .alignmentGuide(.top) { d in d[.top] }
            }
            .frame(height: cardContentHeight, alignment: .top)
            
            // Full-width tags and description below, flowing under the book
            VStack(alignment: .leading, spacing: 8) {
                if !item.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(item.tags, id: \.self) { tag in
                                TagChip(label: tag)
                            }
                        }
                    }
                }
                
                Text(item.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
        .padding()
        .background(systemBackgroundColor)
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

// MARK: - Full-Screen Feed Reel

/// One full-screen, snap-paged reel page. The seminal chart + its text are the
/// content; engagement actions sit on a right rail like a short-video app.
private struct FeedReelPage: View {
    let item: FeedItem

    // Observation tracks reads of `records` through this reference, so the
    // Save button restyles when the saved set changes.
    private let interests = InterestStore.shared

    private var isSaved: Bool { interests.isSaved(id: item.interestKey) }

    private var shareText: String {
        "\(item.title) — \(item.author)\n\(item.description)"
    }

    // Flat page background. Today this is a pastel seeded from the title; a
    // future publisher tool will choose a deliberate flat color (often white,
    // black, or a pastel) per work.
    private var backgroundColor: Color {
        let idx = abs(item.title.hashValue) % PastelPalette.colors.count
        return PastelPalette.colors[idx]
    }

    // Foreground that stays legible whether the flat background is light or dark.
    private var textColor: Color {
        backgroundColor.luminance > 0.6 ? .black : .white
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Flat backdrop — no gradient.
            backgroundColor
                .ignoresSafeArea()

            // The chart/graph — the actual content — floating near the top.
            VStack {
                Spacer(minLength: 0)
                ReelChartCard(chart: item.chart, caption: item.chart.chartTitle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 200)

            // Text + actions.
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.title2.bold())
                        .foregroundStyle(textColor)
                        .lineLimit(3)
                    Text(item.author)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(textColor.opacity(0.9))
                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(textColor.opacity(0.8))
                            .lineLimit(2)
                    }
                    if !item.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(item.tags, id: \.self) { TagChip(label: $0) }
                            }
                        }
                    }
                    Text(item.description)
                        .font(.footnote)
                        .foregroundStyle(textColor.opacity(0.75))
                        .lineLimit(6)
                }

                Spacer(minLength: 0)

                VStack(spacing: 22) {
                    // Relevance score for this reader.
                    ReelStat(icon: "star.fill", value: item.score, label: "Score", tint: .yellow)

                    // Academic social signal: how many works cite this one.
                    ReelStat(icon: "quote.bubble.fill", value: item.citations, label: "Cited", tint: textColor)

                    // Save into the interest memory used as future AI context.
                    ReelActionButton(
                        icon: isSaved ? "bookmark.fill" : "bookmark",
                        label: isSaved ? "Saved" : "Save",
                        tint: isSaved ? .yellow : textColor
                    ) {
                        interests.toggle(item.makeInterestRecord(savedAt: Date()))
                    }

                    // Share the work out of the app.
                    ShareLink(item: shareText) {
                        ReelActionLabel(icon: "square.and.arrow.up", label: "Share", tint: textColor)
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(textColor)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }
}

/// A clean, frosted card that renders the work's chart with its caption.
private struct ReelChartCard: View {
    @ObservedObject var chart: ChartData
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            chartContent
                .frame(maxWidth: .infinity)
                .frame(height: 240)
            if !caption.isEmpty {
                Text(caption)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(systemBackgroundColor)
        )
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 14)
    }

    @ViewBuilder
    private var chartContent: some View {
        switch chart.visualizationType {
        case .bar, .histogram, .horizontalBar:
            Chart {
                ForEach(chart.series) { s in
                    ForEach(s.dataPoints) { p in
                        BarMark(x: .value("Category", p.label), y: .value("Value", p.value))
                            .foregroundStyle(by: .value("Series", s.name))
                    }
                }
            }
            .chartForegroundStyleScale(domain: chart.series.map(\.name), range: chart.series.map(\.color))
            .chartLegend(.hidden)
        case .area:
            Chart {
                ForEach(chart.series) { s in
                    ForEach(s.dataPoints) { p in
                        AreaMark(x: .value("Category", p.label), y: .value("Value", p.value))
                            .foregroundStyle(by: .value("Series", s.name))
                            .interpolationMethod(.catmullRom)
                            .opacity(0.4)
                    }
                }
            }
            .chartForegroundStyleScale(domain: chart.series.map(\.name), range: chart.series.map(\.color))
            .chartLegend(.hidden)
        case .point, .bubble, .scatter3D:
            Chart {
                ForEach(chart.series) { s in
                    ForEach(s.dataPoints) { p in
                        PointMark(x: .value("Category", p.label), y: .value("Value", p.value))
                            .foregroundStyle(by: .value("Series", s.name))
                    }
                }
            }
            .chartForegroundStyleScale(domain: chart.series.map(\.name), range: chart.series.map(\.color))
            .chartLegend(.hidden)
        case .pie:
            if let first = chart.series.first {
                Chart(first.dataPoints) { p in
                    SectorMark(angle: .value("Value", p.value), innerRadius: .ratio(0.5), angularInset: 1.5)
                        .foregroundStyle(by: .value("Category", p.label))
                        .cornerRadius(4)
                }
            }
        case .equation:
            if let fn = ExpressionParser.parse(chart.equationString) {
                Chart {
                    LinePlot(x: "x", y: "y", domain: chart.equationXMin...chart.equationXMax, function: fn)
                        .foregroundStyle(Color.accentColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                .chartXScale(domain: chart.equationXMin...chart.equationXMax)
            } else {
                placeholder
            }
        default:
            Chart {
                ForEach(chart.series) { s in
                    ForEach(s.dataPoints) { p in
                        LineMark(x: .value("Category", p.label), y: .value("Value", p.value))
                            .foregroundStyle(by: .value("Series", s.name))
                            .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartForegroundStyleScale(domain: chart.series.map(\.name), range: chart.series.map(\.color))
            .chartLegend(.hidden)
        }
    }

    private var placeholder: some View {
        Image(systemName: "chart.xyaxis.line")
            .font(.largeTitle)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A read-only stat on the reel's right rail: icon, numeric value, and caption.
private struct ReelStat: View {
    let icon: String
    let value: Int
    let label: String
    var tint: Color = .white

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value.formatted(.number.notation(.compactName)))
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .opacity(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }
}

/// The visual content of a reel action: a frosted icon bubble with a caption.
/// Used standalone inside containers like `ShareLink` that supply their own tap.
private struct ReelActionLabel: View {
    let icon: String
    let label: String
    var tint: Color = .white

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
            }
            Text(label)
                .font(.caption.weight(.semibold))
        }
    }
}

/// A TikTok-style vertical action button (frosted icon bubble + caption).
private struct ReelActionButton: View {
    let icon: String
    let label: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ReelActionLabel(icon: icon, label: label, tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Full-screen placeholder shown when the feed is empty or a search misses.
private struct FeedEmptyPage: View {
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isSearching ? "magnifyingglass" : "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(isSearching ? "No results found" : "Nothing to show yet")
                .font(.title2)
                .fontWeight(.medium)
            Text(isSearching ? "Try different search terms" : "Published work will appear here")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Translucent Stat Bubble

private struct StatBubble: View {
    let title: String
    let value: String
    var diameter: CGFloat
    var action: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            Button(action: action) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(width: diameter, height: diameter)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) \(value)")
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: max(44, diameter)) // keep label width reasonable
        }
    }
}

// MARK: - Tag Chip

private struct TagChip: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
            )
    }
}

// MARK: - Book Thumbnail

private struct BookThumbnail: View {
    enum Size {
        case small
        case large
        case fill(height: CGFloat) // fill to a target height keeping aspect
    }
    
    // Use a seed to choose a stable color per item (e.g., title)
    let colorSeed: String
    let size: Size
    
    // Real text to print on the cover face
    let title: String
    let subtitle: String
    let author: String
    let date: String
    
    private var baseColor: Color {
        let idx = abs(colorSeed.hashValue) % PastelPalette.colors.count
        return PastelPalette.colors[idx]
    }
    
    // Derived colors for accents
    private var spineColor: Color { baseColor.opacity(0.85) }
    private var dimensions: (width: CGFloat, height: CGFloat) {
        switch size {
        case .small:
            let w: CGFloat = 36
            return (w, w * (11.0 / 8.5))
        case .large:
            let w: CGFloat = 84
            return (w, w * (11.0 / 8.5))
        case .fill(let targetHeight):
            let h = targetHeight
            let w = h * (8.5 / 11.0)
            return (w, h)
        }
    }
    
    var body: some View {
        let (width, height) = dimensions
        let corner: CGFloat = 6
        let spineWidth = max(4, width * 0.16)
        let contentLeftPadding = width * 0.08
        let verticalInset = height * 0.08
        
        ZStack(alignment: .leading) {
            // Cover
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(baseColor)
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
            
            // Spine
            RoundedRectangle(cornerRadius: corner * 0.5, style: .continuous)
                .fill(spineColor)
                .frame(width: spineWidth, height: height * 0.96)
                .padding(.leading, 3)
            
            // Printed content on cover face (text only)
            Group {
                switch size {
                case .small:
                    // Keep it simple and readable: title only
                    VStack(alignment: .leading, spacing: height * 0.02) {
                        Text(title)
                            .font(.system(size: max(7, height * 0.12), weight: .semibold, design: .default))
                            .foregroundColor(.primary.opacity(0.95))
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                        Spacer(minLength: 0)
                    }
                case .large, .fill:
                    VStack(alignment: .leading, spacing: height * 0.025) {
                        // Title
                        Text(title)
                            .font(.system(size: max(9, height * 0.11), weight: .semibold, design: .default))
                            .foregroundColor(.primary.opacity(0.98))
                            .lineLimit(3)
                            .minimumScaleFactor(0.6)
                        
                        // Subtitle
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: max(7, height * 0.07), weight: .regular, design: .default))
                                .foregroundColor(.primary.opacity(0.9))
                                .lineLimit(2)
                                .minimumScaleFactor(0.6)
                        }
                        
                        Spacer(minLength: 0)
                        
                        // Author + Date row at the bottom area
                        HStack(spacing: 6) {
                            if !author.isEmpty {
                                Text(author)
                                    .font(.system(size: max(6.5, height * 0.065), weight: .medium, design: .default))
                                    .foregroundColor(.primary.opacity(0.9))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            if !author.isEmpty && !date.isEmpty {
                                Text("•")
                                    .font(.system(size: max(6, height * 0.06), weight: .regular))
                                    .foregroundColor(.primary.opacity(0.7))
                            }
                            if !date.isEmpty {
                                Text(date)
                                    .font(.system(size: max(6.5, height * 0.065), weight: .regular, design: .default))
                                    .foregroundColor(.primary.opacity(0.8))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                        }
                    }
                }
            }
            .padding(.leading, contentLeftPadding) // leave room after spine
            .padding(.top, verticalInset)
            .padding(.bottom, verticalInset)
            .frame(width: width, height: height, alignment: .topLeading)
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle.isEmpty ? "" : "\(subtitle), ")by \(author)\(date.isEmpty ? "" : ", \(date)")")
    }
}

/// Shows/hides a bound flag based on vertical scroll direction: visible at the
/// top and when scrolling up, hidden when scrolling down. No-op before the
/// scroll-geometry API is available.
private struct ScrollDirectionHide: ViewModifier {
    @Binding var visible: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { oldValue, newValue in
                // Always reveal at (or above) the top of the feed.
                if newValue <= 0 {
                    if !visible { withAnimation(.easeInOut(duration: 0.2)) { visible = true } }
                    return
                }
                let delta = newValue - oldValue
                // Ignore tiny jitters so the bar doesn't flicker.
                guard abs(delta) > 8 else { return }
                let shouldShow = delta < 0
                if shouldShow != visible {
                    withAnimation(.easeInOut(duration: 0.2)) { visible = shouldShow }
                }
            }
        } else {
            content
        }
    }
}

private enum PastelPalette {
    // Eight soft pastel colors
    static let colors: [Color] = [
        Color(red: 0.95, green: 0.78, blue: 0.78), // pastel red
        Color(red: 0.98, green: 0.89, blue: 0.75), // pastel orange
        Color(red: 0.99, green: 0.97, blue: 0.79), // pastel yellow
        Color(red: 0.80, green: 0.92, blue: 0.80), // pastel green
        Color(red: 0.77, green: 0.89, blue: 0.96), // pastel blue
        Color(red: 0.85, green: 0.80, blue: 0.94), // pastel purple
        Color(red: 0.95, green: 0.80, blue: 0.88), // pastel pink
        Color(red: 0.82, green: 0.90, blue: 0.88)  // pastel teal
    ]
}

private extension Color {
    // Simple blend: amount in [0,1], 0 returns self, 1 returns other
    func mix(with other: Color, amount: CGFloat) -> Color {
        // Convert to sRGB components via UIColor/NSColor
        #if canImport(UIKit)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(self).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(other).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(red: Double(r1 + (r2 - r1) * amount),
                     green: Double(g1 + (g2 - g1) * amount),
                     blue: Double(b1 + (b2 - b1) * amount),
                     opacity: Double(a1 + (a2 - a1) * amount))
        #else
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        NSColor(self).usingColorSpace(.sRGB)?.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        NSColor(other).usingColorSpace(.sRGB)?.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(red: Double(r1 + (r2 - r1) * amount),
                     green: Double(g1 + (g2 - g1) * amount),
                     blue: Double(b1 + (b2 - b1) * amount),
                     opacity: Double(a1 + (a2 - a1) * amount))
        #endif
    }

    /// Perceived brightness in [0,1] using the Rec. 601 luma weighting.
    /// Used to pick a legible foreground over a flat background.
    var luminance: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        NSColor(self).usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
}



// MARK: - Discovery Template Card View

struct DiscoveryTemplateCard: View {
    let template: DraftTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(template.color.opacity(0.2))
                        .frame(height: 80)
                    
                    Image(systemName: template.icon)
                        .font(.system(size: 32))
                        .foregroundStyle(template.color)
                }
                
                VStack(spacing: 4) {
                    Text(template.title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text(template.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

