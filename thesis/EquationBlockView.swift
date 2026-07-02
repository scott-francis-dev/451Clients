import SwiftUI

/// How an equation block appears in the document itself — "the paper."
///
/// A reader should see the typeset equation and nothing else, with a quiet
/// invitation to engage. All the machinery (editing, and the CAS operations:
/// simplify, differentiate, integrate, solve, plot) lives in an exploration
/// panel that opens on tap, so it never clutters the page.
struct EquationBlockView: View {
    let objectId: String
    var onExpressionChanged: ((String) -> Void)?

    @State private var expression: String
    @State private var showExplorer = false

    init(objectId: String, expression: String, onExpressionChanged: ((String) -> Void)? = nil) {
        self.objectId = objectId
        self.onExpressionChanged = onExpressionChanged
        self._expression = State(initialValue: expression)
    }

    private var parsed: ParsedExpression? {
        ExpressionParser.parseExpression(expression)
    }

    var body: some View {
        Button {
            showExplorer = true
        } label: {
            VStack(spacing: 10) {
                equationDisplay
                callToAction
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .sheet(isPresented: $showExplorer) {
            explorer.presentationDetents([.medium, .large])
        }
        #else
        .popover(isPresented: $showExplorer) {
            explorer.frame(width: 360, height: 540).padding(4)
        }
        #endif
    }

    // The equation itself, typeset through the layout engine.
    @ViewBuilder
    private var equationDisplay: some View {
        if let parsed {
            MathView(node: parsed.mathNode, fontSize: 28, style: .display)
        } else if expression.isEmpty {
            Text("Empty equation")
                .font(.system(size: 20, design: .serif))
                .foregroundStyle(.tertiary)
        } else {
            Text(expression)
                .font(.system(size: 20, design: .serif))
                .foregroundStyle(.secondary)
        }
    }

    // A quiet, single-line invitation to interact — not a toolbar.
    private var callToAction: some View {
        HStack(spacing: 5) {
            Image(systemName: "hand.tap")
                .font(.caption2)
            Text("Tap to explore — edit, differentiate, integrate, solve")
                .font(.caption2)
        }
        .foregroundStyle(.tertiary)
    }

    private var explorer: some View {
        EquationAttachmentView(
            objectId: objectId,
            expression: expression,
            onExpressionChanged: { newExpr in
                expression = newExpr
                onExpressionChanged?(newExpr)
            }
        )
    }
}

#Preview("Equation block in a document") {
    VStack(alignment: .leading, spacing: 20) {
        Text("As a reader, the page shows only the equation:")
            .font(.callout)
            .foregroundStyle(.secondary)
        EquationBlockView(objectId: "eq1", expression: "x^2 + 2x - 1")
        EquationBlockView(objectId: "eq2", expression: "sin(2x) + 1/x")
    }
    .padding(32)
    .frame(width: 520)
}
