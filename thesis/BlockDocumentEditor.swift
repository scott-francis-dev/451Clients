import SwiftUI
import RichTextKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Document Block Model

enum DocumentBlock: Identifiable {
    case text(id: UUID, content: NSMutableAttributedString)
    case equation(id: UUID, objectId: String, expression: String)
    case chart(id: UUID, data: ChartData)
    case molecule(id: UUID, objectId: String, moleculeName: String)
    case sketch(id: UUID, objectId: String, drawingData: Data)

    var id: UUID {
        switch self {
        case .text(let id, _): return id
        case .equation(let id, _, _): return id
        case .chart(let id, _): return id
        case .molecule(let id, _, _): return id
        case .sketch(let id, _, _): return id
        }
    }

    var isText: Bool {
        if case .text = self { return true }
        return false
    }

    /// Human-readable name used in the block deletion context menu.
    var typeName: String {
        switch self {
        case .text: return "Text"
        case .equation: return "Equation"
        case .chart: return "Chart"
        case .molecule: return "Molecule"
        case .sketch: return "Sketch"
        }
    }
}

// MARK: - Block Document Editor

struct BlockDocumentEditor: View {
    @Binding var blocks: [DocumentBlock]
    @Binding var activeContext: RichTextContext?
    @Binding var activeBlockId: UUID?
    /// macOS: invoked when a chart's edit affordance is tapped so the parent
    /// can show the chart editor in the right sidebar.
    var onChartSelected: ((ChartData) -> Void)? = nil
    /// The chart currently being edited, used to highlight it. macOS only.
    var selectedChartData: ChartData? = nil
    var onTextChanged: (() -> Void)?

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(blocks) { block in
                        if block.isText {
                            blockView(for: block, containerWidth: geo.size.width)
                        } else {
                            blockView(for: block, containerWidth: geo.size.width)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        removeBlock(block.id)
                                    } label: {
                                        Label("Delete \(block.typeName)", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .padding(EdgeInsets(top: 48, leading: 64, bottom: 48, trailing: 64))
            }
        }
    }

    @ViewBuilder
    private func blockView(for block: DocumentBlock, containerWidth: CGFloat) -> some View {
        switch block {
        case .text(let id, _):
            TextBlockEditorView(
                blocks: $blocks,
                blockId: id,
                isActive: activeBlockId == id,
                containerWidth: containerWidth,
                onActivate: {
                    activeBlockId = id
                },
                onContextReady: { ctx in
                    activeContext = ctx
                },
                onTextChanged: onTextChanged
            )

        case .equation(let id, let objectId, let expression):
            EquationBlockView(
                objectId: objectId,
                expression: expression,
                onExpressionChanged: { newExpr in
                    if let idx = blocks.firstIndex(where: { $0.id == id }) {
                        blocks[idx] = .equation(id: id, objectId: objectId, expression: newExpr)
                        onTextChanged?()
                    }
                }
            )
            .padding(.vertical, 8)

        case .chart(_, let data):
            ChartAttachmentView(
                chartData: data,
                onRemove: {
                    withAnimation { blocks.removeAll { $0.id == block.id } }
                    mergeAdjacentTextBlocks()
                    onTextChanged?()
                },
                onSelect: onChartSelected.map { cb in { cb(data) } },
                isSelected: selectedChartData === data
            )
            .padding(.vertical, 8)

        case .molecule(let id, let objectId, let moleculeName):
            MoleculeAttachmentView(
                objectId: objectId,
                moleculeName: moleculeName,
                onMoleculeChanged: { newName in
                    if let idx = blocks.firstIndex(where: { $0.id == id }) {
                        blocks[idx] = .molecule(id: id, objectId: objectId, moleculeName: newName)
                        onTextChanged?()
                    }
                },
                onRemove: {
                    withAnimation { blocks.removeAll { $0.id == id } }
                    mergeAdjacentTextBlocks()
                    onTextChanged?()
                }
            )
            .padding(.vertical, 8)

        case .sketch(let id, let objectId, let drawingData):
            SketchAttachmentView(
                objectId: objectId,
                drawingData: drawingData,
                onDrawingChanged: { newData in
                    if let idx = blocks.firstIndex(where: { $0.id == id }) {
                        blocks[idx] = .sketch(id: id, objectId: objectId, drawingData: newData)
                        onTextChanged?()
                    }
                },
                onRemove: {
                    withAnimation { blocks.removeAll { $0.id == id } }
                    mergeAdjacentTextBlocks()
                    onTextChanged?()
                }
            )
            .padding(.vertical, 8)
        }
    }

    /// Removes a block and merges any text blocks that become adjacent.
    /// Centralized so every non-text block (equations included) can be deleted
    /// consistently from the block-level context menu.
    private func removeBlock(_ id: UUID) {
        withAnimation { blocks.removeAll { $0.id == id } }
        mergeAdjacentTextBlocks()
        onTextChanged?()
    }

    func mergeAdjacentTextBlocks() {
        var merged: [DocumentBlock] = []
        for block in blocks {
            if case .text(let id, let content) = block,
               let last = merged.last,
               case .text(_, let prevContent) = last {
                let combined = NSMutableAttributedString(attributedString: prevContent)
                combined.append(content)
                merged[merged.count - 1] = .text(id: id, content: combined)
            } else {
                merged.append(block)
            }
        }
        if merged.count != blocks.count {
            blocks = merged
        }
    }
}

// MARK: - Individual Text Block

struct TextBlockEditorView: View {
    @Binding var blocks: [DocumentBlock]
    let blockId: UUID
    let isActive: Bool
    let containerWidth: CGFloat
    let onActivate: () -> Void
    let onContextReady: (RichTextContext) -> Void
    var onTextChanged: (() -> Void)?

    @StateObject private var context = RichTextContext()
    @State private var measuredContentHeight: CGFloat = 0

    private var textContent: NSAttributedString {
        guard let block = blocks.first(where: { $0.id == blockId }),
              case .text(_, let content) = block else {
            return NSAttributedString()
        }
        return content
    }

    private var textBinding: Binding<NSAttributedString> {
        Binding(
            get: { textContent },
            set: { newValue in
                guard let index = blocks.firstIndex(where: { $0.id == blockId }) else { return }
                blocks[index] = .text(id: blockId, content: NSMutableAttributedString(attributedString: newValue))
                measureContent()
                onTextChanged?()
            }
        )
    }

    private var editorHeight: CGFloat {
        // Hug the measured text height with a small margin for the editor's own
        // text-container inset and the caret. A large floor here (previously 200)
        // showed up as a big undeletable gap below short text the moment a block
        // became editable.
        max(44, measuredContentHeight + 24)
    }

    var body: some View {
        Group {
            if isActive {
                RichTextKit.RichTextEditor(text: textBinding, context: context)
                    .frame(height: editorHeight)
                    .onAppear {
                        onContextReady(context)
                        measureContent()
                    }
                    .onChange(of: context.selectedRange) { _ in
                        onContextReady(context)
                    }
            } else {
                readOnlyView
            }
        }
    }

    private func measureContent() {
        let content = textContent
        guard content.length > 0 else {
            measuredContentHeight = 0
            return
        }
        let textWidth = max(containerWidth - 128 - 20, 100)
        let rect = content.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        measuredContentHeight = ceil(rect.height)
    }

    private var readOnlyView: some View {
        Group {
            if let block = blocks.first(where: { $0.id == blockId }),
               case .text(_, let content) = block,
               content.length > 0 {
                Text(AttributedString(content))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Color.clear.frame(height: 8)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
    }
}

// MARK: - Block Serialization

struct SerializedBlock: Codable {
    enum Kind: String, Codable { case text, equation, chart, molecule, sketch }

    var id: String
    var kind: Kind
    var richTextJSON: Data?
    var objectId: String?
    var expression: String?
    var chartState: SerializedChartState?
    var moleculeName: String?
    var drawingData: Data?
}

struct SerializedChartState: Codable {
    var visualizationType: String
    var equationString: String
    var equationXMin: Double
    var equationXMax: Double
    var series: [SerializedSeries]
}

struct SerializedSeries: Codable {
    var name: String
    var colorHex: String
    var dataPoints: [SerializedDataPoint]
}

struct SerializedDataPoint: Codable {
    var label: String
    var value: Double
    var xNumeric: Double
}

extension DocumentBlock {

    static func encodeBlocks(_ blocks: [DocumentBlock]) -> Data {
        let serialized = blocks.map { block -> SerializedBlock in
            switch block {
            case .text(let id, let content):
                let doc = RichTextCodec.makeRichDoc(from: content)
                let json = try? RichTextCodec.encodeJSON(doc)
                return SerializedBlock(id: id.uuidString, kind: .text, richTextJSON: json)

            case .equation(let id, let objectId, let expression):
                return SerializedBlock(
                    id: id.uuidString, kind: .equation,
                    objectId: objectId, expression: expression
                )

            case .chart(let id, let data):
                return SerializedBlock(
                    id: id.uuidString, kind: .chart,
                    chartState: SerializedChartState.from(data)
                )

            case .molecule(let id, let objectId, let moleculeName):
                return SerializedBlock(
                    id: id.uuidString, kind: .molecule,
                    objectId: objectId, moleculeName: moleculeName
                )

            case .sketch(let id, let objectId, let drawingData):
                return SerializedBlock(
                    id: id.uuidString, kind: .sketch,
                    objectId: objectId, drawingData: drawingData
                )
            }
        }
        return (try? JSONEncoder().encode(serialized)) ?? Data()
    }

    static func decodeBlocks(from data: Data) -> [DocumentBlock]? {
        guard !data.isEmpty,
              let serialized = try? JSONDecoder().decode([SerializedBlock].self, from: data)
        else { return nil }

        return serialized.compactMap { block -> DocumentBlock? in
            guard let uuid = UUID(uuidString: block.id) else { return nil }
            switch block.kind {
            case .text:
                if let json = block.richTextJSON,
                   let doc = try? RichTextCodec.decodeJSON(json) {
                    return .text(id: uuid, content: RichTextCodec.makeAttributedString(from: doc))
                }
                return .text(id: uuid, content: NSMutableAttributedString())

            case .equation:
                return .equation(
                    id: uuid,
                    objectId: block.objectId ?? uuid.uuidString,
                    expression: block.expression ?? "x^2 + 2x - 1"
                )

            case .chart:
                let chartData = block.chartState?.toChartData() ?? ChartData.sampleTimeSeries()
                return .chart(id: uuid, data: chartData)

            case .molecule:
                return .molecule(
                    id: uuid,
                    objectId: block.objectId ?? uuid.uuidString,
                    moleculeName: block.moleculeName ?? "Caffeine"
                )

            case .sketch:
                return .sketch(
                    id: uuid,
                    objectId: block.objectId ?? uuid.uuidString,
                    drawingData: block.drawingData ?? Data()
                )
            }
        }
    }
}

// MARK: - Chart State Serialization

extension SerializedChartState {
    static func from(_ data: ChartData) -> SerializedChartState {
        SerializedChartState(
            visualizationType: data.visualizationType.rawValue,
            equationString: data.equationString,
            equationXMin: data.equationXMin,
            equationXMax: data.equationXMax,
            series: data.series.map { s in
                SerializedSeries(
                    name: s.name,
                    colorHex: colorToHex(s.color),
                    dataPoints: s.dataPoints.map { p in
                        SerializedDataPoint(label: p.label, value: p.value, xNumeric: p.xNumeric)
                    }
                )
            }
        )
    }

    func toChartData() -> ChartData {
        let data = ChartData()
        data.visualizationType = ChartVisualizationType(rawValue: visualizationType) ?? .line
        data.equationString = equationString
        data.equationXMin = equationXMin
        data.equationXMax = equationXMax
        data.series = series.map { s in
            ChartSeries(
                name: s.name,
                color: hexToColor(s.colorHex),
                dataPoints: s.dataPoints.map { p in
                    ChartDataPoint(label: p.label, value: p.value, xNumeric: p.xNumeric)
                }
            )
        }
        let allX = data.series.flatMap { $0.dataPoints.map(\.xNumeric) }
        data.dataStart = allX.min() ?? 0
        data.dataEnd = allX.max() ?? 1
        data.windowStart = data.dataStart
        data.windowEnd = data.dataEnd
        data.hasNumericAxis = data.series.first.flatMap {
            $0.dataPoints.first.map { Double($0.label) != nil }
        } ?? false
        return data
    }
}

private func colorToHex(_ color: Color) -> String {
    #if canImport(UIKit)
    let ui = UIColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    ui.getRed(&r, green: &g, blue: &b, alpha: &a)
    #elseif canImport(AppKit)
    let ns = NSColor(color)
    let rgb = ns.usingColorSpace(.deviceRGB) ?? ns
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
    #endif
    return String(format: "#%02X%02X%02X%02X",
                  Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
}

private func hexToColor(_ hex: String) -> Color {
    var s = hex
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 8, let v = UInt32(s, radix: 16) else { return .blue }
    let r = Double((v >> 24) & 0xFF) / 255.0
    let g = Double((v >> 16) & 0xFF) / 255.0
    let b = Double((v >> 8) & 0xFF) / 255.0
    let a = Double(v & 0xFF) / 255.0
    return Color(red: r, green: g, blue: b, opacity: a)
}
