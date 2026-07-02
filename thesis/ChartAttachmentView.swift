import SwiftUI
import Combine
import Charts
import UniformTypeIdentifiers

// MARK: - Data Model

enum ChartVisualizationType: String, CaseIterable, Identifiable {
    case line = "Line"
    case bar = "Bar"
    case area = "Area"
    case point = "Scatter"
    case pie = "Pie"
    case equation = "Equation"
    case histogram = "Histogram"
    case horizontalBar = "H. Bar"
    case heatmap = "Heatmap"
    case bubble = "Bubble"
    case surface3D = "Surface 3D"
    case scatter3D = "Scatter 3D"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .bar: return "chart.bar.fill"
        case .pie: return "chart.pie.fill"
        case .line: return "chart.xyaxis.line"
        case .area: return "chart.line.uptrend.xyaxis"
        case .point: return "chart.dots.scatter"
        case .equation: return "function"
        case .histogram: return "chart.bar.doc.horizontal"
        case .horizontalBar: return "chart.bar.horizontal.fill"
        case .heatmap: return "square.grid.3x3.fill"
        case .bubble: return "circle.grid.3x3.fill"
        case .surface3D: return "cube.transparent"
        case .scatter3D: return "cube"
        }
    }

    var is3D: Bool {
        self == .surface3D || self == .scatter3D
    }
}

// MARK: - Reference Lines

enum ReferenceAxis: String, CaseIterable {
    case x = "X", y = "Y"
}

struct ReferenceLineData: Identifiable {
    let id = UUID()
    var value: Double
    var axis: ReferenceAxis
    var color: Color
    var label: String
}

// MARK: - Heatmap

enum HeatmapColormap: String, CaseIterable, Identifiable {
    case viridis = "Viridis"
    case plasma = "Plasma"
    case heat = "Heat"
    case cool = "Cool"
    case grayscale = "Grayscale"

    var id: String { rawValue }

    /// Map a normalized value 0–1 to a Color.
    func color(for t: Double) -> Color {
        let v = max(0, min(1, t))
        switch self {
        case .viridis:
            // Purple → blue → green → yellow
            let r = v < 0.5 ? 0.267 + v * 0.1 : 0.317 + (v - 0.5) * 1.366
            let g = v < 0.5 ? v * 1.0 : 0.5 + (v - 0.5) * 1.0
            let b = v < 0.5 ? 0.329 + v * 0.342 : 0.5 - (v - 0.5) * 1.0
            return Color(red: min(r,1), green: min(g,1), blue: max(b,0))
        case .plasma:
            let r = 0.05 + v * 0.95
            let g = v * v * 0.7
            let b = 0.6 - v * 0.6
            return Color(red: min(r,1), green: min(g,1), blue: max(b,0))
        case .heat:
            if v < 0.333 { return Color(red: v * 3, green: 0, blue: 0) }
            else if v < 0.667 { return Color(red: 1, green: (v - 0.333) * 3, blue: 0) }
            else { return Color(red: 1, green: 1, blue: (v - 0.667) * 3) }
        case .cool:
            return Color(red: v, green: 1.0 - v, blue: 1.0)
        case .grayscale:
            return Color(white: v)
        }
    }
}

// MARK: - 3D Data

struct ThreeDDataPoint: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var z: Double
    var label: String = ""
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    var label: String
    var value: Double
    /// Numeric x value used for windowing. For categorical data this is the
    /// point index; for imported time-series it is the parsed time value.
    var xNumeric: Double = 0
}

struct ChartSeries: Identifiable {
    let id = UUID()
    var name: String
    var color: Color
    var dataPoints: [ChartDataPoint]
}

final class ChartData: ObservableObject, Identifiable {
    let id = UUID()
    @Published var visualizationType: ChartVisualizationType = .line
    @Published var series: [ChartSeries] = []

    @Published var equationString: String = "x^2"
    @Published var equationXMin: Double = -10
    @Published var equationXMax: Double = 10

    // MARK: - Annotations / axes
    @Published var chartTitle: String = ""
    @Published var xLabel: String = ""
    @Published var yLabel: String = ""
    @Published var logScaleY: Bool = false
    @Published var showValueLabels: Bool = false
    @Published var referenceLines: [ReferenceLineData] = []

    // MARK: - Histogram
    @Published var histogramBins: Int = 10

    // MARK: - Heatmap
    @Published var heatmapValues: [[Double]] = []
    @Published var heatmapRowLabels: [String] = []
    @Published var heatmapColLabels: [String] = []
    @Published var heatmapColormap: HeatmapColormap = .viridis

    // MARK: - 3D scatter / surface
    @Published var scatter3DPoints: [ThreeDDataPoint] = []
    @Published var surface3DGrid: [[Double]] = []
    @Published var surface3DColormap: HeatmapColormap = .viridis

    // MARK: - Windowing / playback
    @Published var windowStart: Double = 0
    @Published var windowEnd: Double   = 1
    @Published var dataStart: Double   = 0
    @Published var dataEnd: Double     = 1
    @Published var isPlaying: Bool     = false
    /// True when series were loaded from a file with a parseable numeric x axis.
    @Published var hasNumericAxis: Bool = false

    private var playTimer: AnyCancellable?

    // MARK: - Chunked streaming (large files)
    /// Non-nil when the file is large enough to use byte-range streaming.
    private var chunkLoader: ChunkLoader? = nil
    /// The currently visible series fed by the chunk loader (replaces windowedSeries for large files).
    @Published var displaySeries: [ChartSeries] = []
    private var chunkCancellable: AnyCancellable? = nil
    private var chunkTask: Task<Void, Never>? = nil

    func startPlayback() {
        ChartPerf.event("playback.start")
        isPlaying = true
        let step = (dataEnd - dataStart) * 0.01   // 1 % of total range per tick
        let size = windowEnd - windowStart          // preserve window size
        playTimer = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                var newEnd = self.windowEnd + step
                var newStart = newEnd - size
                if newEnd >= self.dataEnd {
                    newEnd   = self.dataEnd
                    newStart = max(self.dataStart, newEnd - size)
                    self.stopPlayback()
                }
                self.windowEnd   = newEnd
                self.windowStart = newStart
            }
    }

    func stopPlayback() {
        isPlaying = false
        playTimer?.cancel()
        playTimer = nil
    }

    func resetPlayback() {
        stopPlayback()
        let size     = windowEnd - windowStart
        windowStart  = dataStart
        windowEnd    = min(dataStart + size, dataEnd)
    }

    /// Series for the current window.
    /// - Chunked mode (large file): returns `displaySeries` kept fresh by async reads.
    /// - In-memory mode (small file): filters and downsamples `series` synchronously.
    var windowedSeries: [ChartSeries] {
        if chunkLoader != nil { return displaySeries }
        guard hasNumericAxis else { return series }
        let totalIn = series.reduce(0) { $0 + $1.dataPoints.count }
        return ChartPerf.measure("windowedSeries", detail: "in=\(totalIn) window=\(windowStart)...\(windowEnd)") {
            series.map { s in
                var copy = s   // struct copy — id (let) is preserved, preventing chart flicker
                copy.dataPoints = s.dataPoints.filter {
                    $0.xNumeric >= windowStart && $0.xNumeric <= windowEnd
                }
                if copy.dataPoints.count > 200 {
                    let step = copy.dataPoints.count / 200
                    copy.dataPoints = copy.dataPoints.enumerated()
                        .filter { $0.offset % step == 0 }
                        .map(\.element)
                }
                return copy
            }
        }
    }

    // MARK: - File import
    // Last imported filename, shown in the editor.
    @Published var importedFileName: String? = nil
    @Published var importError: String? = nil
    @Published var isImporting: Bool = false

    /// Replace series data from a CSV/TSV file.
    /// Files ≥ 10 MB use byte-range streaming via ChunkLoader (index built once,
    /// cached as a .ridx file).  Smaller files are parsed entirely into memory.
    @MainActor
    func loadFromFile(url: URL) async {
        isImporting = true
        importError = nil
        // Tear down any previous chunk subscription.
        chunkCancellable = nil
        chunkTask?.cancel()
        chunkTask   = nil
        chunkLoader = nil

        do {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let dest     = try ChartAssets.importFile(from: url)
            importedFileName = url.lastPathComponent
            visualizationType = .line

            let attrs    = try FileManager.default.attributesOfItem(atPath: dest.path)
            let fileSize = (attrs[.size] as? Int) ?? 0
            let threshold = 10 * 1024 * 1024   // 10 MB

            if fileSize >= threshold {
                // ── Chunked path ────────────────────────────────────────────
                // Build (or load) the sparse row index.  For a 200 MB file
                // this typically takes < 2 s the first time, then is instant.
                let loader = try await ChunkLoader.prepare(url: dest)

                hasNumericAxis = loader.index.hasNumericFirstColumn
                dataStart  = loader.index.entries.first?.time ?? 0
                dataEnd    = loader.index.entries.last?.time  ?? 1
                windowStart = dataStart
                windowEnd   = min(dataStart + 5.0, dataEnd)

                // Placeholder series (empty dataPoints) so the legend and
                // colour scale are correct before the first chunk arrives.
                let palette: [Color] = [.blue, .orange, .green, .red,
                                        .purple, .cyan, .yellow, .pink]
                series = Array(loader.index.columnNames.dropFirst())
                    .enumerated()
                    .map { i, name in
                        ChartSeries(name: name,
                                    color: palette[i % palette.count],
                                    dataPoints: [])
                    }

                // Load the first chunk synchronously (still inside isImporting)
                // so there's no empty-chart flash when the view appears.
                if let initial = try? await loader.load(windowStart: windowStart,
                                                         windowEnd:   windowEnd) {
                    displaySeries = initial
                }
                activateChunking(loader)

            } else {
                // ── In-memory path ─────────────────────────────────────────
                let parsed = try ChartFileParser.parse(url: dest)
                series = parsed

                // Detect numeric axis from first data point's label.
                let firstLabel = parsed.first?.dataPoints.first?.label ?? ""
                hasNumericAxis = Double(firstLabel) != nil

                let allX = parsed.flatMap { $0.dataPoints.map(\.xNumeric) }
                dataStart   = allX.min() ?? 0
                dataEnd     = allX.max() ?? 1
                windowStart = dataStart
                windowEnd   = min(dataStart + 5.0, dataEnd)
            }
        } catch {
            importError = error.localizedDescription
        }
        isImporting = false
    }

    // MARK: - Chunk streaming internals

    /// Wire up the Combine subscription that re-reads the file on every
    /// window change (debounced to avoid read storms during scrubber drags).
    private func activateChunking(_ loader: ChunkLoader) {
        chunkLoader = loader
        chunkCancellable = Publishers.CombineLatest($windowStart, $windowEnd)
            .debounce(for: .milliseconds(30), scheduler: RunLoop.main)
            .dropFirst()   // initial load already done by loadFromFile
            .sink { [weak self] _, _ in self?.triggerChunkLoad() }
    }

    private func triggerChunkLoad() {
        guard let loader = chunkLoader else { return }
        let start = windowStart
        let end   = windowEnd
        chunkTask?.cancel()
        chunkTask = Task { [weak self] in
            guard let self else { return }
            do {
                let loaded = try await loader.load(windowStart: start, windowEnd: end)
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    self?.displaySeries = loaded
                }
            } catch {}
        }
    }

    static func sampleEquation() -> ChartData {
        let data = ChartData()
        data.visualizationType = .equation
        data.equationString = "4x^3 - 3"
        data.equationXMin = -2
        data.equationXMax = 2
        return data
    }

    static func sample() -> ChartData {
        let data = ChartData()
        let labels = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN"]
        func pts(_ values: [Double]) -> [ChartDataPoint] {
            values.enumerated().map { i, v in
                ChartDataPoint(label: labels[i], value: v, xNumeric: Double(i))
            }
        }
        data.series = [
            ChartSeries(name: "Stock 1", color: .blue,   dataPoints: pts([20,25,30,28,65,95])),
            ChartSeries(name: "Stock 2", color: .orange, dataPoints: pts([30,32,35,33,30,28])),
            ChartSeries(name: "Stock 3", color: .green,  dataPoints: pts([40,45,38,35,32,30])),
        ]
        data.dataStart = 0; data.dataEnd = 5
        data.windowStart = 0; data.windowEnd = 5
        return data
    }

    /// Load the bundled sample_timeseries.csv (20s, 4 channels, 100 Hz).
    /// Falls back to categorical sample() if the file isn't in the bundle.
    static func sampleTimeSeries() -> ChartData {
        let data = ChartData()
        // Look in the bundle first, then next to the executable (debug builds).
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "sample_timeseries", withExtension: "csv"),
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("sample_timeseries.csv"),
        ]
        guard let url = candidates.compactMap({ $0 }).first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) else {
            return sample()   // graceful fallback
        }
        guard let parsed = try? ChartFileParser.parse(url: url), !parsed.isEmpty else {
            return sample()
        }
        data.series           = parsed
        data.visualizationType = .line
        data.hasNumericAxis   = true
        let allX = parsed.flatMap { $0.dataPoints.map(\.xNumeric) }
        data.dataStart   = allX.min() ?? 0
        data.dataEnd     = allX.max() ?? 20
        // Start with a 5-second window so the scrubber is obviously usable.
        data.windowStart = data.dataStart
        data.windowEnd   = data.dataStart + 5.0
        return data
    }
}

// MARK: - Chart Attachment View

struct ChartAttachmentView: View {
    @ObservedObject var chartData: ChartData
    var onRemove: (() -> Void)?
    /// On macOS: called when the chart is tapped so the parent can show
    /// the editor in the right pane. If nil, falls back to the popover.
    var onSelect: (() -> Void)? = nil
    /// Whether this chart is currently selected / being edited in the sidebar.
    var isSelected: Bool = false

    @State private var showEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            chartBody
                .frame(height: 220)
                .padding()

            if chartData.visualizationType == .equation {
                Text("f(x) = \(chartData.equationString)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
            } else if ![.pie, .heatmap, .surface3D, .scatter3D].contains(chartData.visualizationType) {
                legendRow
                    .padding(.horizontal)
                    .padding(.bottom, 6)
            }

            // Scrubber — shown for windowed chart types with numeric x axis
            if chartData.hasNumericAxis,
               [.line, .area, .point].contains(chartData.visualizationType) {
                RangeScrubber(chartData: chartData)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        // Explicit edit affordance: opens the data / visualization-type editor.
        // macOS routes to the right sidebar; other platforms use a popover.
        .overlay(alignment: .topTrailing) {
            Button(action: activateEditor) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(.thinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(10)
            .help("Edit chart data & type")
            .accessibilityLabel("Edit chart data and type")
        }
        .onTapGesture(perform: activateEditor)
        .popover(isPresented: $showEditor) {
            ChartEditorPopover(chartData: chartData, onRemove: onRemove)
                .frame(minWidth: 360, minHeight: 420)
        }
    }

    /// Opens the chart editor. On macOS this hands off to the parent so the
    /// editor can replace the Research pane in the right sidebar (more
    /// performant than a popover that re-renders the chart); elsewhere it
    /// falls back to an inline popover.
    private func activateEditor() {
        #if os(macOS)
        if let onSelect {
            onSelect()
            return
        }
        #endif
        showEditor = true
    }

    private var cardBackground: Color {
        #if os(macOS)
        Color(NSColor.textBackgroundColor)
        #else
        Color(UIColor.systemBackground)
        #endif
    }

    // MARK: - Chart Body

    @ViewBuilder
    private var chartBody: some View {
        switch chartData.visualizationType {
        case .line: lineChart
        case .bar: barChart
        case .area: areaChart
        case .point: pointChart
        case .pie: pieChart
        case .equation: equationChart
        case .histogram: histogramChart
        case .horizontalBar: horizontalBarChart
        case .heatmap: HeatmapChartView(chartData: chartData)
        case .bubble: bubbleChart
        case .surface3D: Chart3DView(chartData: chartData, mode: .surface)
        case .scatter3D: Chart3DView(chartData: chartData, mode: .scatter)
        }
    }

    @ViewBuilder
    private var lineChart: some View {
        let src = chartData.windowedSeries
        if chartData.hasNumericAxis {
            Chart {
                ForEach(src) { s in
                    ForEach(s.dataPoints) { p in
                        LineMark(x: .value("x", p.xNumeric), y: .value("Value", p.value))
                            .foregroundStyle(by: .value("Series", s.name))
                            .interpolationMethod(.linear)
                    }
                }
                ForEach(chartData.referenceLines.filter { $0.axis == .y }) { ref in
                    RuleMark(y: .value(ref.label, ref.value))
                        .foregroundStyle(ref.color)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                }
                ForEach(chartData.referenceLines.filter { $0.axis != .y }) { ref in
                    RuleMark(x: .value(ref.label, ref.value))
                        .foregroundStyle(ref.color)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                }
            }
            .chartForegroundStyleScale(domain: chartData.series.map(\.name), range: chartData.series.map(\.color))
            .chartLegend(.hidden)
            .chartXScale(domain: chartData.windowStart...max(chartData.windowEnd, chartData.windowStart + 0.001))
            .chartYScale(type: chartData.logScaleY ? .log : .linear)
            .applyChartLabels(chartData)
            .transaction { $0.animation = nil }
        } else {
            Chart {
                ForEach(src) { s in
                    ForEach(s.dataPoints) { p in
                        LineMark(x: .value("Category", p.label), y: .value("Value", p.value))
                            .foregroundStyle(by: .value("Series", s.name))
                            .interpolationMethod(.catmullRom)
                    }
                }
                ForEach(chartData.referenceLines) { ref in
                    if ref.axis == .y {
                        RuleMark(y: .value(ref.label, ref.value))
                            .foregroundStyle(ref.color)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                    }
                }
            }
            .chartForegroundStyleScale(domain: chartData.series.map(\.name), range: chartData.series.map(\.color))
            .chartLegend(.hidden)
            .chartYScale(type: chartData.logScaleY ? .log : .linear)
            .applyChartLabels(chartData)
        }
    }

    private var barChart: some View {
        Chart {
            ForEach(chartData.series) { s in
                ForEach(s.dataPoints) { p in
                    BarMark(
                        x: .value("Category", p.label),
                        y: .value("Value", p.value)
                    )
                    .foregroundStyle(by: .value("Series", s.name))
                    .annotation(position: .top) {
                        if chartData.showValueLabels {
                            Text(String(format: "%.1f", p.value))
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            ForEach(chartData.referenceLines) { ref in
                if ref.axis == .y {
                    RuleMark(y: .value(ref.label, ref.value))
                        .foregroundStyle(ref.color)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                }
            }
        }
        .chartForegroundStyleScale(
            domain: chartData.series.map(\.name),
            range: chartData.series.map(\.color)
        )
        .chartYScale(type: chartData.logScaleY ? .log : .linear)
        .applyChartLabels(chartData)
        .chartLegend(.hidden)
    }

    @ViewBuilder
    private var areaChart: some View {
        let src = chartData.windowedSeries
        if chartData.hasNumericAxis {
            Chart {
                ForEach(src) { s in
                    ForEach(s.dataPoints) { p in
                        AreaMark(x: .value("x", p.xNumeric), y: .value("Value", p.value))
                            .foregroundStyle(by: .value("Series", s.name))
                            .interpolationMethod(.linear)
                            .opacity(0.4)
                    }
                }
            }
            .chartForegroundStyleScale(domain: chartData.series.map(\.name), range: chartData.series.map(\.color))
            .chartLegend(.hidden)
            .chartXScale(domain: chartData.windowStart...max(chartData.windowEnd, chartData.windowStart + 0.001))
            .transaction { $0.animation = nil }
        } else {
            Chart {
                ForEach(src) { s in
                    ForEach(s.dataPoints) { p in
                        AreaMark(x: .value("Category", p.label), y: .value("Value", p.value))
                            .foregroundStyle(by: .value("Series", s.name))
                            .interpolationMethod(.catmullRom)
                            .opacity(0.4)
                    }
                }
            }
            .chartForegroundStyleScale(domain: chartData.series.map(\.name), range: chartData.series.map(\.color))
            .chartLegend(.hidden)
        }
    }

    @ViewBuilder
    private var pointChart: some View {
        let src = chartData.windowedSeries
        if chartData.hasNumericAxis {
            Chart {
                ForEach(src) { s in
                    ForEach(s.dataPoints) { p in
                        PointMark(x: .value("x", p.xNumeric), y: .value("Value", p.value))
                            .foregroundStyle(by: .value("Series", s.name))
                            .symbolSize(30)
                    }
                }
            }
            .chartForegroundStyleScale(domain: chartData.series.map(\.name), range: chartData.series.map(\.color))
            .chartLegend(.hidden)
            .chartXScale(domain: chartData.windowStart...max(chartData.windowEnd, chartData.windowStart + 0.001))
            .transaction { $0.animation = nil }
        } else {
            Chart {
                ForEach(src) { s in
                    ForEach(s.dataPoints) { p in
                        PointMark(x: .value("Category", p.label), y: .value("Value", p.value))
                            .foregroundStyle(by: .value("Series", s.name))
                            .symbolSize(60)
                    }
                }
            }
            .chartForegroundStyleScale(domain: chartData.series.map(\.name), range: chartData.series.map(\.color))
            .chartLegend(.hidden)
        }
    }

    @ViewBuilder
    private var pieChart: some View {
        if let first = chartData.series.first {
            Chart(first.dataPoints) { p in
                SectorMark(
                    angle: .value("Value", p.value),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Category", p.label))
                .cornerRadius(4)
            }
        } else {
            Text("No data")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Equation

    @ViewBuilder
    private var equationChart: some View {
        if let fn = ExpressionParser.parse(chartData.equationString) {
            Chart {
                LinePlot(x: "x", y: "y", domain: chartData.equationXMin...chartData.equationXMax, function: fn)
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            .chartXScale(domain: chartData.equationXMin...chartData.equationXMax)
            .chartXAxisLabel("x")
            .chartYAxisLabel("y")
        } else {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Invalid expression")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Histogram

    private static func histogramCounts(values: [Double], bins: Int, lo: Double, binSize: Double) -> [Int] {
        var counts = [Int](repeating: 0, count: bins)
        for v in values {
            let idx = min(bins - 1, Int((v - lo) / binSize))
            counts[idx] += 1
        }
        return counts
    }

    @ViewBuilder
    private var histogramChart: some View {
        let allValues = chartData.series.flatMap { $0.dataPoints.map(\.value) }
        if allValues.isEmpty {
            Text("No data").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let bins = max(2, chartData.histogramBins)
            let lo = allValues.min()!
            let hi = allValues.max()!
            let span = hi - lo > 0 ? hi - lo : 1
            let binSize = span / Double(bins)
            let counts = Self.histogramCounts(values: allValues, bins: bins, lo: lo, binSize: binSize)
            Chart {
                ForEach(0..<bins, id: \.self) { i in
                    let label = String(format: "%.1f", lo + Double(i) * binSize)
                    BarMark(x: .value("Bin", label), y: .value("Count", counts[i]))
                        .foregroundStyle(Color.accentColor.opacity(0.8))
                }
                ForEach(chartData.referenceLines) { ref in
                    if ref.axis == .y {
                        RuleMark(y: .value(ref.label, ref.value))
                            .foregroundStyle(ref.color)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text(ref.label).font(.caption2).foregroundStyle(ref.color)
                            }
                    }
                }
            }
            .applyChartLabels(chartData)
            .chartLegend(.hidden)
        }
    }

    // MARK: - Horizontal Bar

    @ViewBuilder
    private var horizontalBarChart: some View {
        Chart {
            ForEach(chartData.series) { s in
                ForEach(s.dataPoints) { p in
                    BarMark(
                        x: .value("Value", p.value),
                        y: .value("Category", p.label)
                    )
                    .foregroundStyle(by: .value("Series", s.name))
                    .annotation(position: .trailing) {
                        if chartData.showValueLabels {
                            Text(String(format: "%.1f", p.value))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            ForEach(chartData.referenceLines) { ref in
                if ref.axis == .x {
                    RuleMark(x: .value(ref.label, ref.value))
                        .foregroundStyle(ref.color)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                }
            }
        }
        .chartForegroundStyleScale(domain: chartData.series.map(\.name), range: chartData.series.map(\.color))
        .applyChartLabels(chartData)
        .chartLegend(.hidden)
    }

    // MARK: - Bubble

    @ViewBuilder
    private var bubbleChart: some View {
        let src = chartData.windowedSeries
        if src.isEmpty {
            Text("No data").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let allValues = src.flatMap { $0.dataPoints.map(\.value) }
            let maxVal = allValues.max() ?? 1
            Chart {
                ForEach(src) { s in
                    ForEach(s.dataPoints) { p in
                        let size = maxVal > 0 ? max(10, (p.value / maxVal) * 1200) : 50
                        if chartData.hasNumericAxis {
                            PointMark(x: .value("x", p.xNumeric), y: .value("Value", p.value))
                                .foregroundStyle(by: .value("Series", s.name))
                                .symbolSize(size)
                                .opacity(0.7)
                        } else {
                            PointMark(x: .value("Category", p.label), y: .value("Value", p.value))
                                .foregroundStyle(by: .value("Series", s.name))
                                .symbolSize(size)
                                .opacity(0.7)
                        }
                    }
                }
                ForEach(chartData.referenceLines) { ref in
                    if ref.axis == .y {
                        RuleMark(y: .value(ref.label, ref.value))
                            .foregroundStyle(ref.color)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                    } else {
                        RuleMark(x: .value(ref.label, ref.value))
                            .foregroundStyle(ref.color)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                    }
                }
            }
            .chartForegroundStyleScale(domain: chartData.series.map(\.name), range: chartData.series.map(\.color))
            .applyChartLabels(chartData)
            .chartLegend(.hidden)
        }
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 16) {
            ForEach(chartData.series) { s in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(s.color)
                        .frame(width: 16, height: 3)
                    Text(s.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Chart Editor Sidebar Panel (macOS right pane)

#if os(macOS)
/// Full-height sidebar version of the chart editor — shown in the Research
/// pane when the user taps a chart card on macOS.
struct ChartEditorSidebarPanel: View {
    @ObservedObject var chartData: ChartData
    var onRemove: (() -> Void)?
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                Text("Chart Editor")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(Rectangle().fill(Color(NSColor.separatorColor)).frame(height: 1), alignment: .bottom)

            ChartEditorPopover(chartData: chartData, onRemove: onRemove)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
}
#endif

// MARK: - Chart Editor Popover

struct ChartEditorPopover: View {
    @ObservedObject var chartData: ChartData
    var onRemove: (() -> Void)?
    @State private var selectedTab = 0
    @State private var selectedSeriesIndex = 0
    @State private var showingFilePicker = false

    private static let allowedTypes: [UTType] = [
        .commaSeparatedText, .tabSeparatedText, .plainText, .data
    ]

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Data").tag(0)
                Text("Type").tag(1)
                Text("Style").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            if selectedTab == 0 {
                dataTab
            } else if selectedTab == 1 {
                visualizationTab
            } else {
                styleTab
            }

            Divider()

            HStack {
                if let onRemove {
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove Chart", systemImage: "trash")
                            .font(.caption)
                    }
                }
                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Data Tab

    @ViewBuilder
    private var dataTab: some View {
        if chartData.visualizationType == .equation {
            equationDataTab
        } else if chartData.visualizationType.is3D || chartData.visualizationType == .heatmap {
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: chartData.visualizationType.systemImage)
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("Use the \(Text("Type").bold()) tab to configure data for this chart type.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            }
        } else {
            seriesDataTab
        }
    }

    private var equationDataTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("f(x) =")
                    .font(.headline)

                TextField("e.g. 4x^3 - 3", text: $chartData.equationString)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                if ExpressionParser.parse(chartData.equationString) != nil {
                    Label("Valid expression", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if !chartData.equationString.isEmpty {
                    Label("Invalid expression", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Divider()

                Text("X Range")
                    .font(.subheadline.bold())

                HStack {
                    Text("Min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Min", value: $chartData.equationXMin, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 80)
                    Spacer()
                    Text("Max")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Max", value: $chartData.equationXMax, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 80)
                }

                Divider()

                Text("Examples")
                    .font(.subheadline.bold())

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], spacing: 6) {
                    ForEach([
                        "x^2", "4x^3 - 3", "sin(x)", "cos(x)",
                        "x^3 - 3x", "1/x", "sqrt(x)", "2^x"
                    ], id: \.self) { example in
                        Button {
                            chartData.equationString = example
                        } label: {
                            Text(example)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity)
                                .background(Capsule().fill(Color.secondary.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Supports: +, -, *, /, ^ (power), parentheses, and functions: sin, cos, tan, sqrt, abs, log, ln, exp")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
    }

    private var seriesDataTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: File import
                VStack(alignment: .leading, spacing: 6) {
                    if chartData.isImporting {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Importing…").font(.caption).foregroundStyle(.secondary)
                        }
                    } else if let err = chartData.importError {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.red)
                    } else if let name = chartData.importedFileName {
                        Label(name, systemImage: "doc.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button {
                        showingFilePicker = true
                    } label: {
                        Label("Import CSV / TSV…", systemImage: "square.and.arrow.down")
                            .font(.subheadline)
                    }
                    .disabled(chartData.isImporting)
                    Text("First column = labels, remaining columns = series")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .fileImporter(
                    isPresented: $showingFilePicker,
                    allowedContentTypes: Self.allowedTypes,
                    allowsMultipleSelection: false
                ) { result in
                    guard case .success(let urls) = result, let url = urls.first else { return }
                    Task { await chartData.loadFromFile(url: url) }
                }

                Divider()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(chartData.series.enumerated()), id: \.element.id) { idx, series in
                            Button {
                                selectedSeriesIndex = idx
                            } label: {
                                Text(series.name)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(
                                            selectedSeriesIndex == idx
                                            ? series.color.opacity(0.2)
                                            : Color.secondary.opacity(0.1)
                                        )
                                    )
                                    .overlay(
                                        Capsule().stroke(
                                            selectedSeriesIndex == idx ? series.color : .clear,
                                            lineWidth: 1.5
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: addSeries) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if chartData.series.indices.contains(selectedSeriesIndex) {
                    HStack {
                        TextField("Series Name", text: Binding(
                            get: { chartData.series[selectedSeriesIndex].name },
                            set: { chartData.series[selectedSeriesIndex].name = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)

                        ColorPicker("", selection: Binding(
                            get: { chartData.series[selectedSeriesIndex].color },
                            set: { chartData.series[selectedSeriesIndex].color = $0 }
                        ))
                        .labelsHidden()
                        .frame(width: 30)

                        if chartData.series.count > 1 {
                            Button {
                                chartData.series.remove(at: selectedSeriesIndex)
                                selectedSeriesIndex = max(0, selectedSeriesIndex - 1)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ForEach(
                        Array(chartData.series[selectedSeriesIndex].dataPoints.enumerated()),
                        id: \.element.id
                    ) { pIdx, _ in
                        HStack {
                            TextField("Label", text: Binding(
                                get: {
                                    guard chartData.series.indices.contains(selectedSeriesIndex),
                                          chartData.series[selectedSeriesIndex].dataPoints.indices.contains(pIdx)
                                    else { return "" }
                                    return chartData.series[selectedSeriesIndex].dataPoints[pIdx].label
                                },
                                set: {
                                    guard chartData.series.indices.contains(selectedSeriesIndex),
                                          chartData.series[selectedSeriesIndex].dataPoints.indices.contains(pIdx)
                                    else { return }
                                    chartData.series[selectedSeriesIndex].dataPoints[pIdx].label = $0
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 100)

                            TextField("Value", value: Binding(
                                get: {
                                    guard chartData.series.indices.contains(selectedSeriesIndex),
                                          chartData.series[selectedSeriesIndex].dataPoints.indices.contains(pIdx)
                                    else { return 0 }
                                    return chartData.series[selectedSeriesIndex].dataPoints[pIdx].value
                                },
                                set: {
                                    guard chartData.series.indices.contains(selectedSeriesIndex),
                                          chartData.series[selectedSeriesIndex].dataPoints.indices.contains(pIdx)
                                    else { return }
                                    chartData.series[selectedSeriesIndex].dataPoints[pIdx].value = $0
                                }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 100)

                            Button {
                                guard chartData.series[selectedSeriesIndex].dataPoints.indices.contains(pIdx)
                                else { return }
                                chartData.series[selectedSeriesIndex].dataPoints.remove(at: pIdx)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button(action: addDataPoint) {
                        Label("Add Data Point", systemImage: "plus")
                            .font(.caption)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Visualization Type Tab

    private var visualizationTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("2D Charts")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 72), spacing: 12)
                ], spacing: 12) {
                    ForEach(ChartVisualizationType.allCases.filter { !$0.is3D }) { type in
                        chartTypeButton(type)
                    }
                }

                Divider()

                Text("3D Charts")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 72), spacing: 12)
                ], spacing: 12) {
                    ForEach(ChartVisualizationType.allCases.filter(\.is3D)) { type in
                        chartTypeButton(type)
                    }
                }

                if chartData.visualizationType.is3D {
                    Divider()
                    threeDDataSection
                }

                if chartData.visualizationType == .heatmap {
                    Divider()
                    heatmapDataSection
                }
            }
            .padding()
        }
    }

    private func chartTypeButton(_ type: ChartVisualizationType) -> some View {
        Button {
            chartData.visualizationType = type
        } label: {
            VStack(spacing: 6) {
                Image(systemName: type.systemImage)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(chartData.visualizationType == type
                                  ? Color.accentColor.opacity(0.15)
                                  : Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(chartData.visualizationType == type ? Color.accentColor : .clear,
                                    lineWidth: 2)
                    )
                Text(type.rawValue)
                    .font(.caption2)
                    .foregroundStyle(chartData.visualizationType == type ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Heatmap data entry

    private var heatmapDataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Heatmap Data").font(.subheadline.bold())

            HStack {
                Text("Colormap").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $chartData.heatmapColormap) {
                    ForEach(HeatmapColormap.allCases) { c in
                        Text(c.rawValue).tag(c)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Text("Paste a grid as CSV rows (one row per line):")
                .font(.caption2).foregroundStyle(.tertiary)

            HeatmapPasteEditor(chartData: chartData)
        }
    }

    // MARK: - 3D data entry

    private var threeDDataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("3D Points").font(.subheadline.bold())
                Spacer()
                Button {
                    chartData.scatter3DPoints.append(
                        ThreeDDataPoint(x: Double.random(in: -1...1),
                                        y: Double.random(in: -1...1),
                                        z: Double.random(in: -1...1))
                    )
                } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if chartData.visualizationType == .surface3D {
                HStack {
                    Text("Colormap").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $chartData.surface3DColormap) {
                        ForEach(HeatmapColormap.allCases) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    .pickerStyle(.menu).labelsHidden()
                }

                Button("Generate Sample Surface") {
                    chartData.surface3DGrid = (0..<12).map { r in
                        (0..<12).map { c in
                            let x = Double(c) / 11.0 * 4 - 2
                            let y = Double(r) / 11.0 * 4 - 2
                            return sin(x) * cos(y)
                        }
                    }
                }
                .font(.caption)
            }

            if chartData.scatter3DPoints.isEmpty {
                Button("Generate Sample Scatter") {
                    chartData.scatter3DPoints = (0..<30).map { _ in
                        ThreeDDataPoint(x: Double.random(in: -1...1),
                                        y: Double.random(in: -1...1),
                                        z: Double.random(in: -1...1))
                    }
                }
                .font(.caption)
            } else {
                Text("\(chartData.scatter3DPoints.count) points")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Clear") { chartData.scatter3DPoints.removeAll() }
                    .font(.caption).foregroundStyle(.red)
            }
        }
    }

    // MARK: - Style Tab

    private var styleTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Title & Labels
                Group {
                    Text("Labels").font(.subheadline.bold())

                    LabeledContent("Title") {
                        TextField("Chart title", text: $chartData.chartTitle)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("X axis") {
                        TextField("X label", text: $chartData.xLabel)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Y axis") {
                        TextField("Y label", text: $chartData.yLabel)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Divider()

                // Scale options
                Group {
                    Text("Scale").font(.subheadline.bold())

                    Toggle("Log scale Y", isOn: $chartData.logScaleY)
                        .font(.callout)
                        .disabled([.pie, .equation, .heatmap, .surface3D, .scatter3D].contains(chartData.visualizationType))

                    Toggle("Show value labels", isOn: $chartData.showValueLabels)
                        .font(.callout)
                        .disabled([.pie, .equation, .heatmap, .surface3D, .scatter3D, .line, .area, .point, .bubble].contains(chartData.visualizationType))
                }

                if chartData.visualizationType == .histogram {
                    Divider()
                    Group {
                        Text("Histogram").font(.subheadline.bold())
                        Stepper("Bins: \(chartData.histogramBins)",
                                value: $chartData.histogramBins, in: 2...100)
                            .font(.callout)
                    }
                }

                Divider()

                // Reference lines
                referenceLineEditor
            }
            .padding()
        }
    }

    // MARK: - Reference line editor

    private var referenceLineEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reference Lines").font(.subheadline.bold())
                Spacer()
                Button {
                    chartData.referenceLines.append(
                        ReferenceLineData(value: 0, axis: .y, color: .red, label: "")
                    )
                } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            ForEach(Array(chartData.referenceLines.enumerated()), id: \.element.id) { idx, ref in
                HStack(spacing: 8) {
                    Picker("", selection: Binding(
                        get: { chartData.referenceLines[safe: idx]?.axis ?? .y },
                        set: { if chartData.referenceLines.indices.contains(idx) { chartData.referenceLines[idx].axis = $0 } }
                    )) {
                        Text("Y").tag(ReferenceAxis.y)
                        Text("X").tag(ReferenceAxis.x)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 70)

                    TextField("Value", value: Binding(
                        get: { chartData.referenceLines[safe: idx]?.value ?? 0 },
                        set: { if chartData.referenceLines.indices.contains(idx) { chartData.referenceLines[idx].value = $0 } }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 70)

                    TextField("Label", text: Binding(
                        get: { chartData.referenceLines[safe: idx]?.label ?? "" },
                        set: { if chartData.referenceLines.indices.contains(idx) { chartData.referenceLines[idx].label = $0 } }
                    ))
                    .textFieldStyle(.roundedBorder)

                    ColorPicker("", selection: Binding(
                        get: { chartData.referenceLines[safe: idx]?.color ?? .red },
                        set: { if chartData.referenceLines.indices.contains(idx) { chartData.referenceLines[idx].color = $0 } }
                    ))
                    .labelsHidden()
                    .frame(width: 28)

                    Button {
                        chartData.referenceLines.remove(at: idx)
                    } label: {
                        Image(systemName: "trash").foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            if chartData.referenceLines.isEmpty {
                Text("No reference lines. Tap + to add a threshold or guideline.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Actions

    private func addSeries() {
        let palette: [Color] = [.blue, .orange, .green, .red, .purple, .cyan, .yellow, .pink]
        let color = palette[chartData.series.count % palette.count]
        let labels = chartData.series.first?.dataPoints.map(\.label)
            ?? ["JAN", "FEB", "MAR", "APR", "MAY", "JUN"]
        chartData.series.append(
            ChartSeries(
                name: "Dimension \(chartData.series.count + 1)",
                color: color,
                dataPoints: labels.map { ChartDataPoint(label: $0, value: Double.random(in: 10...80)) }
            )
        )
        selectedSeriesIndex = chartData.series.count - 1
    }

    private func addDataPoint() {
        guard chartData.series.indices.contains(selectedSeriesIndex) else { return }
        chartData.series[selectedSeriesIndex].dataPoints.append(
            ChartDataPoint(label: "NEW", value: 0)
        )
    }
}

// MARK: - Range Scrubber

struct RangeScrubber: View {
    @ObservedObject var chartData: ChartData

    // Anchors captured on first frame of each drag; nil = not dragging.
    @State private var anchorStart:     Double? = nil
    @State private var anchorEnd:       Double? = nil
    @State private var anchorBandStart: Double? = nil
    @State private var anchorBandEnd:   Double? = nil

    private let trackHeight: CGFloat = 4
    private let thumbSize:   CGFloat = 18

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                // Play / Pause / Reset
                Button {
                    if chartData.windowEnd >= chartData.dataEnd && !chartData.isPlaying {
                        chartData.resetPlayback()
                        chartData.startPlayback()
                    } else if chartData.isPlaying {
                        chartData.stopPlayback()
                    } else {
                        chartData.startPlayback()
                    }
                } label: {
                    Image(systemName: playbackIcon)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                // Track
                GeometryReader { geo in
                    let w    = geo.size.width
                    let span = chartData.dataEnd - chartData.dataStart
                    let startFrac = span > 0 ? (chartData.windowStart - chartData.dataStart) / span : 0
                    let endFrac   = span > 0 ? (chartData.windowEnd   - chartData.dataStart) / span : 1
                    let startX = startFrac * w
                    let endX   = endFrac   * w

                    ZStack(alignment: .leading) {
                        // Full track
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: trackHeight)

                        // Selected range — pan gesture
                        Capsule()
                            .fill(Color.accentColor.opacity(0.5))
                            .frame(width: max(0, endX - startX), height: trackHeight)
                            .offset(x: startX)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { v in
                                        // Capture anchor on first frame.
                                        if anchorBandStart == nil {
                                            anchorBandStart = chartData.windowStart
                                            anchorBandEnd   = chartData.windowEnd
                                        }
                                        let delta = v.translation.width / w * span
                                        let size  = (anchorBandEnd ?? 0) - (anchorBandStart ?? 0)
                                        let newStart = (anchorBandStart! + delta)
                                            .clamped(to: chartData.dataStart...(chartData.dataEnd - size))
                                        chartData.windowStart = newStart
                                        chartData.windowEnd   = newStart + size
                                    }
                                    .onEnded { _ in
                                        anchorBandStart = nil
                                        anchorBandEnd   = nil
                                    }
                            )

                        // Start thumb
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: thumbSize, height: thumbSize)
                            .shadow(radius: 2)
                            .offset(x: startX - thumbSize / 2)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { v in
                                        if anchorStart == nil { anchorStart = chartData.windowStart }
                                        let newVal = anchorStart! + v.translation.width / w * span
                                        chartData.windowStart = newVal
                                            .clamped(to: chartData.dataStart...(chartData.windowEnd - 0.05))
                                    }
                                    .onEnded { _ in anchorStart = nil }
                            )

                        // End thumb
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: thumbSize, height: thumbSize)
                            .shadow(radius: 2)
                            .offset(x: endX - thumbSize / 2)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { v in
                                        if anchorEnd == nil { anchorEnd = chartData.windowEnd }
                                        let newVal = anchorEnd! + v.translation.width / w * span
                                        chartData.windowEnd = newVal
                                            .clamped(to: (chartData.windowStart + 0.05)...chartData.dataEnd)
                                    }
                                    .onEnded { _ in anchorEnd = nil }
                            )
                    }
                    .frame(height: thumbSize)
                }

                // Time readout
                Text(timeLabel)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .trailing)
            }
            .frame(height: thumbSize)
        }
    }

    private var playbackIcon: String {
        if chartData.windowEnd >= chartData.dataEnd && !chartData.isPlaying {
            return "arrow.counterclockwise"
        }
        return chartData.isPlaying ? "pause.fill" : "play.fill"
    }

    private var timeLabel: String {
        let fmt = { (v: Double) -> String in
            abs(v) < 100 ? String(format: "%.2f", v) : String(format: "%.0f", v)
        }
        return "\(fmt(chartData.windowStart))–\(fmt(chartData.windowEnd))"
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Heatmap Paste Editor

struct HeatmapPasteEditor: View {
    @ObservedObject var chartData: ChartData
    @State private var rawText: String = ""
    @State private var parseError: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextEditor(text: $rawText)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 80)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))

            if let err = parseError {
                Text(err).font(.caption2).foregroundStyle(.red)
            }

            Button("Apply") {
                parseError = nil
                let rows = rawText
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                let parsed: [[Double]] = rows.map { row in
                    row.components(separatedBy: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                }
                let colCounts = Set(parsed.map(\.count))
                if colCounts.count > 1 {
                    parseError = "All rows must have the same number of columns."
                } else if parsed.isEmpty {
                    parseError = "No valid data found."
                } else {
                    chartData.heatmapValues = parsed
                }
            }
            .font(.caption)
        }
    }
}

// MARK: - Chart Label Modifier

extension View {
    @ViewBuilder
    func applyChartLabels(_ data: ChartData) -> some View {
        if data.xLabel.isEmpty && data.yLabel.isEmpty {
            self
        } else if data.xLabel.isEmpty {
            self.chartYAxisLabel(data.yLabel)
        } else if data.yLabel.isEmpty {
            self.chartXAxisLabel(data.xLabel)
        } else {
            self
                .chartXAxisLabel(data.xLabel)
                .chartYAxisLabel(data.yLabel)
        }
    }
}

// MARK: - Heatmap Chart View

struct HeatmapChartView: View {
    @ObservedObject var chartData: ChartData

    var body: some View {
        let values = chartData.heatmapValues
        if values.isEmpty || (values.first?.isEmpty ?? true) {
            Text("No heatmap data.\nUse the Type tab to enter grid values.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HeatmapGridView(
                values: values,
                rowLabels: chartData.heatmapRowLabels,
                colLabels: chartData.heatmapColLabels,
                colormap: chartData.heatmapColormap
            )
        }
    }
}

struct HeatmapGridView: View {
    let values: [[Double]]
    let rowLabels: [String]
    let colLabels: [String]
    let colormap: HeatmapColormap

    private var allFlat: [Double] { values.flatMap { $0 } }
    private var lo: Double { allFlat.min() ?? 0 }
    private var hi: Double { allFlat.max() ?? 1 }
    private var span: Double { hi - lo > 0 ? hi - lo : 1 }

    var body: some View {
        GeometryReader { geo in
            let rows = values.count
            let cols = values[0].count
            let cellW = geo.size.width / CGFloat(cols)
            let cellH = geo.size.height / CGFloat(rows)
            let loVal = lo, hiVal = hi, spanVal = span, cmap = colormap

            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for r in 0..<rows {
                        for c in 0..<cols {
                            let t = (values[r][c] - loVal) / spanVal
                            let rect = CGRect(x: CGFloat(c) * cellW, y: CGFloat(r) * cellH,
                                             width: cellW, height: cellH)
                            ctx.fill(Path(rect), with: .color(cmap.color(for: t)))
                        }
                    }
                }

                // Colorbar (right edge)
                HStack(spacing: 2) {
                    LinearGradient(
                        colors: stride(from: 0.0, through: 1.0, by: 0.05).map { cmap.color(for: $0) },
                        startPoint: .bottom, endPoint: .top
                    )
                    .frame(width: 8)
                    .cornerRadius(2)
                    VStack {
                        Text(String(format: "%.1f", hiVal)).font(.system(size: 8)).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f", loVal)).font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                }
                .frame(height: geo.size.height * 0.8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 4)
            }
        }
    }
}

#Preview("Categorical") {
    ChartAttachmentView(chartData: .sample())
        .frame(width: 480)
        .padding()
}

#Preview("Time Series") {
    ChartAttachmentView(chartData: .sampleTimeSeries())
        .frame(width: 480)
        .padding()
}
