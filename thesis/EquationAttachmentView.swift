import SwiftUI
import Charts
import Core451

struct EquationAttachmentView: View {
    let objectId: String
    var onExpressionChanged: ((String) -> Void)?

    @State private var input: String
    @State private var variableInputs: [String: String] = [:]
    @State private var showRange = false
    @State private var rangeVariable = ""
    @State private var rangeMin = "0"
    @State private var rangeMax = "10"
    @State private var showTangent = false
    @State private var tangentPointText = ""
    @State private var showSimplify = false
    @State private var showExpand = false
    @State private var showFactor = false
    @State private var showSubstitute = false
    @State private var showDerivative = false
    @State private var showIntegral = false
    @State private var showSolve = false
    @State private var derivativeOrder = 1
    @State private var operationVariable = ""
    @State private var substituteText = ""

    init(objectId: String, expression: String = "x^2 + 2x - 1", onExpressionChanged: ((String) -> Void)? = nil) {
        self.objectId = objectId
        self.onExpressionChanged = onExpressionChanged
        self._input = State(initialValue: expression)
    }

    private var parsed: ParsedExpression? {
        ExpressionParser.parseExpression(input)
    }

    private var sortedVariables: [String] {
        guard let expr = parsed else { return [] }
        return expr.variables.sorted()
    }

    private var bindings: [String: Double] {
        var result: [String: Double] = [:]
        for v in sortedVariables {
            if let text = variableInputs[v], let val = Double(text) {
                result[v] = val
            }
        }
        return result
    }

    private var allVariablesFilled: Bool {
        let b = bindings
        return sortedVariables.allSatisfy { b[$0] != nil }
    }

    /// The exact rational value when every variable is bound to a number and the
    /// expression reduces to a pure rational (no π, e, or transcendental calls).
    private var exactResult: Rational? {
        guard let expr = baseExpr, allVariablesFilled else { return nil }
        var exactBindings: [String: Expr] = [:]
        for v in sortedVariables {
            guard let text = variableInputs[v], let val = Double(text) else { return nil }
            exactBindings[v] = .num(Expr.rational(approximating: val))
        }
        return expr.substituting(exactBindings).rationalValue
    }

    private var evaluatedResult: Double? {
        guard let expr = parsed, allVariablesFilled else { return nil }
        let val = expr.evaluate(bindings)
        guard val.isFinite else { return nil }
        return val
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            equationDisplay
            Divider()
            expressionInput
            if !sortedVariables.isEmpty {
                Divider()
                variableSection
            }
            if let result = evaluatedResult {
                Divider()
                resultSection(result)
            }
            if parsed != nil {
                Divider()
                simplifySection
                Divider()
                expandSection
                Divider()
                factorSection
                Divider()
                substituteSection
                Divider()
                derivativeSection
                Divider()
                integralSection
                Divider()
                solveSection
            }
            if !sortedVariables.isEmpty {
                Divider()
                rangeSection
            }
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
        .onChange(of: input) {
            syncVariableInputs()
            onExpressionChanged?(input)
        }
        .onAppear {
            syncVariableInputs()
        }
    }

    private var cardBackground: Color {
        #if os(macOS)
        Color(NSColor.textBackgroundColor)
        #else
        Color(UIColor.systemBackground)
        #endif
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "function")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Equation")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Pretty Equation Display

    private var equationDisplay: some View {
        Group {
            if let expr = parsed {
                MathView(node: expr.mathNode, fontSize: 26, style: .display)
                    .foregroundStyle(.primary)
            } else if input.isEmpty {
                Text("Enter an expression")
                    .font(.system(size: 20, design: .serif))
                    .foregroundStyle(.tertiary)
            } else {
                Text(input)
                    .font(.system(size: 20, design: .serif))
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.horizontal, 16)
        .background(.quaternary.opacity(0.3))
    }

    // MARK: - Expression Input

    private var expressionInput: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("e.g. x^2 + 2x - 1", text: $input)
                .textFieldStyle(.plain)
                .font(.system(.subheadline, design: .monospaced))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Variable Inputs

    private var variableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Variables")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(sortedVariables, id: \.self) { name in
                HStack(spacing: 8) {
                    Text(name)
                        .font(.system(.subheadline, design: .serif).weight(.semibold))
                        .frame(width: 30, alignment: .trailing)

                    Text("=")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("value", text: bindingFor(name))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(maxWidth: 120)

                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif

                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Result

    private func resultSection(_ result: Double) -> some View {
        HStack(spacing: 8) {
            Text("=")
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundStyle(.secondary)

            if let exact = exactResult, !exact.isInteger {
                // Exact rational result, with the decimal as an approximation.
                MathView(node: Expr.num(exact).mathNode, fontSize: 22, style: .display)
                    .foregroundStyle(.primary)
                Text("≈ \(formatResult(result))")
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(.secondary)
            } else {
                Text(formatResult(result))
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.blue.opacity(0.06))
    }

    // MARK: - CAS operations

    /// The canonical CAS term for the current input, or nil if it doesn't parse.
    private var baseExpr: Expr? {
        guard let parsed else { return nil }
        return Expr(parsed.mathNode)
    }

    /// The variable calculus operations act on: the user's choice when set,
    /// otherwise the first variable (falling back to "x" for constants).
    private var effectiveOperationVariable: String {
        if !operationVariable.isEmpty { return operationVariable }
        return sortedVariables.first ?? "x"
    }

    private var operationVariableBinding: Binding<String> {
        Binding(
            get: { effectiveOperationVariable },
            set: { operationVariable = $0 }
        )
    }

    /// A collapsible row sharing the look of the existing sections.
    @ViewBuilder
    private func operationDisclosure(
        _ title: String,
        isExpanded: Binding<Bool>,
        tint: Color,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.wrappedValue.toggle() }
            } label: {
                HStack {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                    Text(title)
                        .font(.caption.weight(.medium))
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                VStack(alignment: .leading, spacing: 12, content: content)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .background(tint.opacity(0.05))
            }
        }
    }

    /// Variable picker shared by the calculus operations (only when ambiguous).
    @ViewBuilder
    private func operationVariablePicker(_ label: String) -> some View {
        if sortedVariables.count > 1 {
            HStack(spacing: 8) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: operationVariableBinding) {
                    ForEach(sortedVariables, id: \.self) { v in
                        Text(v).tag(v)
                    }
                }
                .labelsHidden()
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
                Spacer()
            }
        }
    }

    // MARK: Simplify

    private var simplifySection: some View {
        operationDisclosure("Simplify", isExpanded: $showSimplify, tint: .green) {
            if let node = baseExpr?.mathNode {
                MathView(node: node, fontSize: 24, style: .display)
            }
        }
    }

    // MARK: Expand

    private var expandSection: some View {
        operationDisclosure("Expand", isExpanded: $showExpand, tint: .teal) {
            if let node = baseExpr?.expanded().mathNode {
                MathView(node: node, fontSize: 24, style: .display)
            }
        }
    }

    // MARK: Factor

    private var factorSection: some View {
        operationDisclosure("Factor", isExpanded: $showFactor, tint: .pink) {
            operationVariablePicker("in")
            if let node = baseExpr?.factored(in: effectiveOperationVariable)?.mathNode {
                MathView(node: node, fontSize: 24, style: .display)
            } else {
                Text("Doesn't factor over the rationals (try Solve for the roots).")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: Substitute

    /// The expression entered in the substitution field, lifted to an Expr.
    private var substitutionReplacement: Expr? {
        ExpressionParser.parseExpression(substituteText).map { Expr($0.mathNode) }
    }

    private var substitutionResultNode: MathNode? {
        guard let expr = baseExpr, let replacement = substitutionReplacement else { return nil }
        return expr.substituting(effectiveOperationVariable, with: replacement).mathNode
    }

    private var substituteSection: some View {
        operationDisclosure("Substitute", isExpanded: $showSubstitute, tint: .indigo) {
            HStack(spacing: 8) {
                Text("let")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                operationVariablePickerInline
                Text("=")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("expression", text: $substituteText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(maxWidth: 160)
            }
            if let node = substitutionResultNode {
                MathView(node: node, fontSize: 24, style: .display)
            } else if !substituteText.isEmpty {
                Text("Enter a valid expression to substitute.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// A compact variable chip/picker for inline use in the substitute row.
    @ViewBuilder
    private var operationVariablePickerInline: some View {
        if sortedVariables.count > 1 {
            Picker("", selection: operationVariableBinding) {
                ForEach(sortedVariables, id: \.self) { v in
                    Text(v).tag(v)
                }
            }
            .labelsHidden()
            #if os(macOS)
            .pickerStyle(.menu)
            #endif
        } else {
            Text(effectiveOperationVariable)
                .font(.system(.subheadline, design: .serif).weight(.semibold))
        }
    }

    // MARK: Derivative

    /// The nth derivative (n = `derivativeOrder`) lowered to a MathNode.
    private var derivativeNode: MathNode? {
        guard var e = baseExpr else { return nil }
        for _ in 0..<max(1, derivativeOrder) {
            e = e.differentiated(withRespectTo: effectiveOperationVariable)
        }
        return e.mathNode
    }

    /// The Leibniz operator dⁿ/dxⁿ rendered as a stacked fraction.
    private var derivativeOperatorNode: MathNode {
        let v = effectiveOperationVariable
        if derivativeOrder <= 1 {
            return .fraction(.variable("d"), .group([.variable("d"), .variable(v)]))
        }
        let n = MathNode.number(Double(derivativeOrder))
        return .fraction(
            .power(base: .variable("d"), exp: n),
            .group([.variable("d"), .power(base: .variable(v), exp: n)])
        )
    }

    private var derivativeSection: some View {
        operationDisclosure("Derivative", isExpanded: $showDerivative, tint: .purple) {
            HStack(spacing: 8) {
                Text("Order")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper(value: $derivativeOrder, in: 1...4) {
                    Text("\(derivativeOrder)")
                        .font(.caption.monospacedDigit())
                }
                .labelsHidden()
                .fixedSize()
                Spacer()
            }
            operationVariablePicker("with respect to")
            if let node = derivativeNode {
                HStack(alignment: .center, spacing: 10) {
                    MathView(node: derivativeOperatorNode, fontSize: 20, style: .display)
                    Text("=")
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundStyle(.secondary)
                    MathView(node: node, fontSize: 24, style: .display)
                    Spacer()
                }
            }
        }
    }

    // MARK: Integral

    /// The indefinite integral lowered to a MathNode, or nil when the engine
    /// finds no closed form with its current rules.
    private var integralNode: MathNode? {
        baseExpr?.integrated(withRespectTo: effectiveOperationVariable)?.mathNode
    }

    private var integralSection: some View {
        operationDisclosure("Integral", isExpanded: $showIntegral, tint: .orange) {
            operationVariablePicker("with respect to")
            if let node = integralNode, let parsed {
                HStack(alignment: .center, spacing: 6) {
                    Text("∫")
                        .font(.system(size: 26, design: .serif))
                        .foregroundStyle(.secondary)
                    MathView(node: parsed.mathNode, fontSize: 20, style: .text)
                    Text("d\(effectiveOperationVariable)")
                        .font(.system(size: 18, design: .serif))
                        .foregroundStyle(.secondary)
                    Text("=")
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundStyle(.secondary)
                    MathView(node: node, fontSize: 22, style: .display)
                    Text("+ C")
                        .font(.system(size: 18, design: .serif))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                Text("No closed form with the current rules (e.g. needs integration by parts).")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: Solve

    private enum SolveOutcome {
        case roots([MathNode])
        case noSolution
        case unsupported
    }

    /// Solves `expression = 0` for the active variable.
    private var solveOutcome: SolveOutcome {
        guard let roots = baseExpr?.solved(for: effectiveOperationVariable) else {
            return .unsupported
        }
        return roots.isEmpty ? .noSolution : .roots(roots.map(\.mathNode))
    }

    private var solveSection: some View {
        operationDisclosure("Solve", isExpanded: $showSolve, tint: .blue) {
            Text("Setting the expression equal to 0:")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            operationVariablePicker("solve for")
            switch solveOutcome {
            case .roots(let nodes):
                ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                    HStack(alignment: .center, spacing: 8) {
                        Text("\(effectiveOperationVariable) =")
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundStyle(.secondary)
                        MathView(node: node, fontSize: 22, style: .display)
                        Spacer()
                    }
                }
            case .noSolution:
                Text("No solution.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .unsupported:
                Text("Can't solve symbolically yet — supports polynomials up to degree 2.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Range

    private var rangeSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showRange.toggle()
                    if showRange && rangeVariable.isEmpty,
                       let first = sortedVariables.first {
                        rangeVariable = first
                    }
                }
            } label: {
                HStack {
                    Image(systemName: showRange ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                    Text("Range Visualization")
                        .font(.caption.weight(.medium))
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if showRange {
                rangeControls
                if let points = rangeDataPoints, !points.isEmpty {
                    rangeChart(points)
                } else if parsed != nil {
                    Text("Fill in all other variables to see the chart")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private var rangeControls: some View {
        VStack(spacing: 8) {
            if sortedVariables.count > 1 {
                HStack(spacing: 8) {
                    Text("Variable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $rangeVariable) {
                        ForEach(sortedVariables, id: \.self) { v in
                            Text(v).tag(v)
                        }
                    }
                    .labelsHidden()
                    #if os(macOS)
                    .pickerStyle(.menu)
                    #endif
                    Spacer()
                }
            }

            HStack(spacing: 10) {
                Text("From")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("min", text: $rangeMin)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(width: 70)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif

                Text("To")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("max", text: $rangeMax)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(width: 70)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif

                Spacer()
            }

            HStack(spacing: 10) {
                Toggle(isOn: $showTangent) {
                    Text("Tangent line")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.switch)
                .fixedSize()

                if showTangent {
                    Text("at \(rangeVariable) =")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("point", text: $tangentPointText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(width: 70)
                    #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                    #endif
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // The point the tangent is taken at: the user's value, else the midpoint.
    private var tangentAnchorValue: Double? {
        guard showTangent else { return nil }
        if let v = Double(tangentPointText) { return v }
        if let lo = Double(rangeMin), let hi = Double(rangeMax), lo < hi {
            return (lo + hi) / 2
        }
        return nil
    }

    /// The tangent line y = f(a) + f′(a)·(x − a) over the plotted range, plus the
    /// point of tangency. f′ comes from the symbolic derivative, evaluated at a.
    /// nil when tangents are off or the inputs aren't ready.
    private var tangentData: (line: [RangePoint], anchor: RangePoint)? {
        guard let expr = parsed,
              !rangeVariable.isEmpty,
              let a = tangentAnchorValue,
              let lo = Double(rangeMin), let hi = Double(rangeMax), lo < hi,
              let derivative = baseExpr?.differentiated(withRespectTo: rangeVariable)
        else { return nil }

        var base = bindings
        for v in sortedVariables where v != rangeVariable {
            guard base[v] != nil else { return nil }
        }
        base[rangeVariable] = a

        let fa = expr.evaluate(base)
        let slope = derivative.evaluate(base)
        guard fa.isFinite, slope.isFinite else { return nil }

        let line = [
            RangePoint(x: lo, y: fa + slope * (lo - a)),
            RangePoint(x: hi, y: fa + slope * (hi - a))
        ]
        return (line, RangePoint(x: a, y: fa))
    }

    private var rangeDataPoints: [RangePoint]? {
        guard let expr = parsed,
              !rangeVariable.isEmpty,
              let lo = Double(rangeMin),
              let hi = Double(rangeMax),
              lo < hi else { return nil }

        let otherVars = sortedVariables.filter { $0 != rangeVariable }
        var base = bindings
        for v in otherVars {
            guard base[v] != nil else { return nil }
        }

        let count = 200
        let step = (hi - lo) / Double(count)
        var points: [RangePoint] = []
        for i in 0...count {
            let xVal = lo + step * Double(i)
            base[rangeVariable] = xVal
            let yVal = expr.evaluate(base)
            if yVal.isFinite {
                points.append(RangePoint(x: xVal, y: yVal))
            }
        }
        return points
    }

    private func rangeChart(_ points: [RangePoint]) -> some View {
        let tangent = tangentData
        return Chart {
            ForEach(points) { p in
                LineMark(
                    x: .value(rangeVariable, p.x),
                    y: .value("f(\(rangeVariable))", p.y),
                    series: .value("Series", "f")
                )
                .foregroundStyle(.blue.gradient)
                .interpolationMethod(.catmullRom)
            }

            if let tangent {
                ForEach(tangent.line) { p in
                    LineMark(
                        x: .value(rangeVariable, p.x),
                        y: .value("f(\(rangeVariable))", p.y),
                        series: .value("Series", "tangent")
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                }
                PointMark(
                    x: .value(rangeVariable, tangent.anchor.x),
                    y: .value("f(\(rangeVariable))", tangent.anchor.y)
                )
                .foregroundStyle(.orange)
                .symbolSize(60)
            }
        }
        .chartXAxisLabel(rangeVariable, alignment: .center)
        .frame(height: 180)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Helpers

    private func bindingFor(_ name: String) -> Binding<String> {
        Binding(
            get: { variableInputs[name] ?? "" },
            set: { variableInputs[name] = $0 }
        )
    }

    private func syncVariableInputs() {
        let current = Set(variableInputs.keys)
        let needed = Set(sortedVariables)
        for removed in current.subtracting(needed) {
            variableInputs.removeValue(forKey: removed)
        }
        for added in needed.subtracting(current) {
            variableInputs[added] = ""
        }
        if rangeVariable.isEmpty || !needed.contains(rangeVariable) {
            rangeVariable = sortedVariables.first ?? ""
        }
        if !operationVariable.isEmpty && !needed.contains(operationVariable) {
            operationVariable = sortedVariables.first ?? ""
        }
    }

    private func formatResult(_ value: Double) -> String {
        if value == value.rounded(.towardZero) && abs(value) < 1e15 {
            return "\(Int(value))"
        }
        return String(format: "%.6g", value)
    }
}

// MARK: - Range Data Point

private struct RangePoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
}
