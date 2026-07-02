import SwiftUI
import Core451

struct PagerScrollView<Content: View>: View {
    let pageCount: Int
    @Binding var selectedIndex: Int
    let pageWidth: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        #if canImport(UIKit)
        PagerScrollViewUIKit(pageCount: pageCount, selectedIndex: $selectedIndex, pageWidth: pageWidth, content: content)
        #elseif canImport(AppKit)
        PagerScrollViewAppKit(pageCount: pageCount, selectedIndex: $selectedIndex, pageWidth: pageWidth, content: content)
        #else
        ScrollView(.horizontal, showsIndicators: false) {
            content()
        }
        #endif
    }
}

#if canImport(UIKit)
import UIKit

private struct PagerScrollViewUIKit<Content: View>: UIViewRepresentable {
    let pageCount: Int
    @Binding var selectedIndex: Int
    let pageWidth: CGFloat
    let content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.isPagingEnabled = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = false
        scroll.delegate = context.coordinator

        // Host SwiftUI content (type-erased)
        let root = AnyView(HStack(spacing: 0) { content() })
        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false

        scroll.addSubview(host.view)
        context.coordinator.hostingController = host

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            host.view.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])

        return scroll
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.hostingController?.rootView = AnyView(HStack(spacing: 0) { content() })

        // Update content size based on page count and width
        let totalWidth = CGFloat(pageCount) * max(1, pageWidth)
        let size = CGSize(width: totalWidth, height: scrollView.bounds.height)
        scrollView.contentSize = size

        // Ensure current page is visible
        let x = CGFloat(selectedIndex) * max(1, pageWidth)
        if abs(scrollView.contentOffset.x - x) > 1 {
            scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: false)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: PagerScrollViewUIKit
        weak var hostingController: UIHostingController<AnyView>?

        init(_ parent: PagerScrollViewUIKit) {
            self.parent = parent
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            snapAndUpdateIndex(scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate { snapAndUpdateIndex(scrollView) }
        }

        private func snapAndUpdateIndex(_ scrollView: UIScrollView) {
            let width = max(1, parent.pageWidth)
            let page = Int(round(scrollView.contentOffset.x / width))
            let clamped = max(0, min(parent.pageCount - 1, page))
            if clamped != parent.selectedIndex {
                parent.selectedIndex = clamped
            }
            let x = CGFloat(clamped) * width
            if abs(scrollView.contentOffset.x - x) > 1 {
                scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: true)
            }
        }
    }
}
#endif

#if canImport(AppKit)
import AppKit

private struct PagerScrollViewAppKit<Content: View>: NSViewRepresentable {
    let pageCount: Int
    @Binding var selectedIndex: Int
    let pageWidth: CGFloat
    let content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = false
        scroll.horizontalScrollElasticity = .none

        let root = AnyView(HStack(spacing: 0) { content() })
        let host = NSHostingController(rootView: root)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = NSColor.clear.cgColor

        let doc = NSView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(host.view)

        scroll.documentView = doc

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: doc.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            host.view.heightAnchor.constraint(equalTo: scroll.contentView.heightAnchor)
        ])

        context.coordinator.hostingController = host
        context.coordinator.documentView = doc
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.hostingController?.rootView = AnyView(HStack(spacing: 0) { content() })

        let totalWidth = CGFloat(pageCount) * max(1, pageWidth)
        context.coordinator.documentView?.setFrameSize(CGSize(width: totalWidth, height: scrollView.contentSize.height))

        let x = CGFloat(selectedIndex) * max(1, pageWidth)
        if abs(scrollView.contentView.bounds.origin.x - x) > 1 {
            scrollView.contentView.scroll(to: NSPoint(x: x, y: 0))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    final class Coordinator: NSObject {
        var parent: PagerScrollViewAppKit
        weak var hostingController: NSHostingController<AnyView>?
        weak var documentView: NSView?

        init(_ parent: PagerScrollViewAppKit) {
            self.parent = parent
        }
    }
}
#endif
