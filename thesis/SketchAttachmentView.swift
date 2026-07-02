import SwiftUI
#if canImport(PencilKit)
import PencilKit
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct SketchAttachmentView: View {
    let objectId: String
    let drawingData: Data
    var onDrawingChanged: ((Data) -> Void)?
    var onRemove: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            canvasBody
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "pencil.tip.crop.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Sketch")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            #if canImport(PencilKit) && canImport(UIKit)
            Button {
                onDrawingChanged?(Data())
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear Sketch")
            #endif
            if let onRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove Sketch")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var canvasBody: some View {
        #if canImport(PencilKit) && canImport(UIKit)
        SketchCanvas(drawingData: drawingData, onDrawingChanged: onDrawingChanged)
            .frame(height: 320)
        #else
        Text("Sketching is available on iPadOS, iOS, and visionOS.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding()
        #endif
    }

    private var cardBackground: Color {
        #if os(macOS)
        Color(NSColor.textBackgroundColor)
        #else
        Color(UIColor.systemBackground)
        #endif
    }
}

#if canImport(PencilKit) && canImport(UIKit)
struct SketchCanvas: UIViewRepresentable {
    let drawingData: Data
    var onDrawingChanged: ((Data) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .label, width: 4)
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.alwaysBounceVertical = false
        if !drawingData.isEmpty, let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }

        let toolPicker = PKToolPicker()
        toolPicker.addObserver(canvas)
        toolPicker.setVisible(true, forFirstResponder: canvas)
        context.coordinator.toolPicker = toolPicker
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.onDrawingChanged = onDrawingChanged
        let currentData = canvas.drawing.dataRepresentation()
        guard currentData != drawingData else { return }
        if drawingData.isEmpty {
            canvas.drawing = PKDrawing()
        } else if let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onDrawingChanged: ((Data) -> Void)?
        var toolPicker: PKToolPicker?

        init(onDrawingChanged: ((Data) -> Void)?) {
            self.onDrawingChanged = onDrawingChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged?(canvasView.drawing.dataRepresentation())
        }
    }
}
#endif
