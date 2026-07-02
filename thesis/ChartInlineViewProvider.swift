import Foundation
import SwiftUI
import Combine
import Charts

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class ChartViewModel: ObservableObject {
    @Published var chartData: ChartData
    weak var attachment: ChartTextAttachment?

    init(attachment: ChartTextAttachment) {
        self.chartData = attachment.chartData
        self.attachment = attachment
    }

    func commit() {
        attachment?.chartData = chartData
    }
}

@available(iOS 15.0, macOS 12.0, *)
final class ChartInlineViewProvider: NSTextAttachmentViewProvider {
    private var viewModel: ChartViewModel?

    // Keep in sync with ChartTextAttachment's static bounds height so the line
    // reserves the same space whether the static image or this live view shows.
    static let attachmentSize = CGSize(width: 420, height: ChartTextAttachment.displayHeight)

    #if canImport(UIKit)
    override func loadView() {
        guard let chart = textAttachment as? ChartTextAttachment else { return }
        ChartPerf.event("ChartInlineViewProvider.loadView", "objectId=\(chart.objectId)")
        let model = ChartViewModel(attachment: chart)
        viewModel = model
        let host = UIHostingController(rootView: InlineChartView(model: model))
        host.view.backgroundColor = .clear
        host.view.frame = CGRect(origin: .zero, size: Self.attachmentSize)
        self.view = host.view
    }
    #elseif canImport(AppKit)
    override func loadView() {
        guard let chart = textAttachment as? ChartTextAttachment else { return }
        ChartPerf.event("ChartInlineViewProvider.loadView", "objectId=\(chart.objectId)")
        let model = ChartViewModel(attachment: chart)
        viewModel = model
        let host = NSHostingView(rootView: InlineChartView(model: model))
        host.frame = CGRect(origin: .zero, size: Self.attachmentSize)
        self.view = host
    }
    #endif

    // Reserve exactly the view's height in the text line (no extra slack).
    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        CGRect(origin: .zero, size: Self.attachmentSize)
    }
}

struct InlineChartView: View {
    @ObservedObject var model: ChartViewModel
    @State private var showEditor = false

    var body: some View {
        Button {
            showEditor = true
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.chartData.visualizationType.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "pencil.circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 4)

                miniChart
                    .frame(height: 120)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                    .allowsHitTesting(false)
            }
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showEditor) {
            ChartAttachmentView(
                chartData: model.chartData,
                onRemove: { showEditor = false },
                isSelected: true
            )
            .frame(width: 500, height: 500)
            .padding(4)
        }
    }

    @ViewBuilder
    private var miniChart: some View {
        let series = model.chartData.series
        if series.isEmpty {
            Text("No data")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart {
                ForEach(series) { s in
                    ForEach(s.dataPoints) { p in
                        LineMark(
                            x: .value("x", p.label),
                            y: .value("y", p.value)
                        )
                        .foregroundStyle(by: .value("Series", s.name))
                    }
                }
            }
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
    }
}
