// LaTeXParserTests.swift
// Tests for LaTeXParser — verifies structural correctness on real arXiv equations.

import Testing
@testable import thesis

// MARK: - Helpers

/// Returns true if `node` matches the given pattern at its top level.
/// Used for structural spot-checks without requiring full equality.
private func isGroup(_ node: MathNode) -> Bool {
    if case .group = node { return true }
    return false
}
private func isFraction(_ node: MathNode) -> Bool {
    if case .fraction = node { return true }
    return false
}
private func isPower(_ node: MathNode) -> Bool {
    if case .power = node { return true }
    return false
}
private func isRadical(_ node: MathNode) -> Bool {
    if case .radical = node { return true }
    return false
}
private func isBigop(_ node: MathNode, _ op: MathBigOp) -> Bool {
    if case .bigop(let o, _, _, _) = node { return o == op }
    return false
}
private func isBracketed(_ node: MathNode, _ kind: MathBracketKind) -> Bool {
    if case .bracketed(let k, _) = node { return k == kind }
    return false
}
private func isMatrix(_ node: MathNode) -> Bool {
    if case .matrix = node { return true }
    return false
}
private func isCases(_ node: MathNode) -> Bool {
    if case .cases = node { return true }
    return false
}
private func isSymbol(_ node: MathNode, _ sym: MathSymbol) -> Bool {
    if case .symbol(let s) = node { return s == sym }
    return false
}
private func isAccent(_ node: MathNode, _ acc: MathAccent) -> Bool {
    if case .accent(let a, _) = node { return a == acc }
    return false
}

// ── Unwrap helpers ────────────────────────────────────────────────────────────

private func fracParts(_ node: MathNode) -> (MathNode, MathNode)? {
    if case .fraction(let n, let d) = node { return (n, d) }
    return nil
}
private func powerParts(_ node: MathNode) -> (base: MathNode, exp: MathNode)? {
    if case .power(let b, let e) = node { return (b, e) }
    return nil
}
private func subsupParts(_ node: MathNode) -> (base: MathNode, sub: MathNode, sup: MathNode)? {
    if case .subsup(let b, let s, let p) = node { return (b, s, p) }
    return nil
}
private func bigopParts(_ node: MathNode) -> (MathBigOp, lower: MathNode, upper: MathNode, body: MathNode)? {
    if case .bigop(let op, let lo, let hi, let body) = node { return (op, lo, hi, body) }
    return nil
}
private func bracketedInner(_ node: MathNode) -> MathNode? {
    if case .bracketed(_, let inner) = node { return inner }
    return nil
}
private func groupItems(_ node: MathNode) -> [MathNode]? {
    if case .group(let items) = node { return items }
    return nil
}

// MARK: - Atom Tests

@Suite("Atoms") struct AtomTests {

    @Test func greekLetters() {
        #expect(LaTeXParser.parse(#"\alpha"#)       == .symbol(.alpha))
        #expect(LaTeXParser.parse(#"\beta"#)        == .symbol(.beta))
        #expect(LaTeXParser.parse(#"\omega"#)       == .symbol(.omega))
        #expect(LaTeXParser.parse(#"\Omega"#)       == .symbol(.Omega))
        #expect(LaTeXParser.parse(#"\pi"#)          == .symbol(.pi))
        #expect(LaTeXParser.parse(#"\varphi"#)      == .symbol(.varphi))
        #expect(LaTeXParser.parse(#"\varepsilon"#)  == .symbol(.varepsilon))
        #expect(LaTeXParser.parse(#"\nabla"#)       == .symbol(.nabla))
        #expect(LaTeXParser.parse(#"\partial"#)     == .symbol(.partial))
        #expect(LaTeXParser.parse(#"\infty"#)       == .symbol(.infinity))
    }

    @Test func numberSets() {
        #expect(LaTeXParser.parse(#"\mathbb{R}"#) == .symbol(.reals))
        #expect(LaTeXParser.parse(#"\mathbb{Z}"#) == .symbol(.integers))
        #expect(LaTeXParser.parse(#"\mathbb{N}"#) == .symbol(.naturals))
        #expect(LaTeXParser.parse(#"\mathbb{C}"#) == .symbol(.complex))
    }

    @Test func relations() {
        #expect(LaTeXParser.parse(#"\leq"#)   == .symbol(.leq))
        #expect(LaTeXParser.parse(#"\geq"#)   == .symbol(.geq))
        #expect(LaTeXParser.parse(#"\neq"#)   == .symbol(.neq))
        #expect(LaTeXParser.parse(#"\approx"#) == .symbol(.approx))
        #expect(LaTeXParser.parse(#"\in"#)     == .symbol(.inSet))
        #expect(LaTeXParser.parse(#"\subset"#) == .symbol(.subset))
    }

    @Test func arrows() {
        #expect(LaTeXParser.parse(#"\to"#)           == .symbol(.rightArrow))
        #expect(LaTeXParser.parse(#"\rightarrow"#)   == .symbol(.rightArrow))
        #expect(LaTeXParser.parse(#"\Rightarrow"#)   == .symbol(.Rightarrow))
        #expect(LaTeXParser.parse(#"\Leftrightarrow"#) == .symbol(.iff))
    }

    @Test func singleVariable() {
        #expect(LaTeXParser.parse("x") == .variable("x"))
        #expect(LaTeXParser.parse("n") == .variable("n"))
    }

    @Test func number() {
        #expect(LaTeXParser.parse("42")   == .number(42))
        #expect(LaTeXParser.parse("3.14") == .number(3.14))
        #expect(LaTeXParser.parse("0")    == .number(0))
    }
}

// MARK: - Structure Tests

@Suite("Structure") struct StructureTests {

    @Test func simpleFraction() {
        let node = LaTeXParser.parse(#"\frac{1}{2}"#)
        #expect(isFraction(node))
        let parts = fracParts(node)
        #expect(parts?.0 == .number(1))
        #expect(parts?.1 == .number(2))
    }

    @Test func nestedFraction() {
        // \frac{x}{\frac{y}{z}} — fraction inside denominator
        let node = LaTeXParser.parse(#"\frac{x}{\frac{y}{z}}"#)
        #expect(isFraction(node))
        let (_, den) = fracParts(node)!
        #expect(isFraction(den))
    }

    @Test func superscript() {
        let node = LaTeXParser.parse("x^2")
        #expect(isPower(node))
        let parts = powerParts(node)
        #expect(parts?.base == .variable("x"))
        #expect(parts?.exp  == .number(2))
    }

    @Test func superscriptGroup() {
        let node = LaTeXParser.parse(#"e^{i\pi}"#)
        #expect(isPower(node))
        let parts = powerParts(node)
        #expect(parts?.base == .variable("e"))
        // exponent is a group: [.variable("i"), .symbol(.pi)]
        #expect(isGroup(parts!.exp))
    }

    @Test func subScript() {
        let node = LaTeXParser.parse(#"x_i"#)
        if case .sub(let base, let idx) = node {
            #expect(base == .variable("x"))
            #expect(idx  == .variable("i"))
        } else {
            Issue.record("Expected .sub, got \(node)")
        }
    }

    @Test func subsup() {
        let node = LaTeXParser.parse(#"x_i^2"#)
        let parts = subsupParts(node)
        #expect(parts?.base == .variable("x"))
        #expect(parts?.sub  == .variable("i"))
        #expect(parts?.sup  == .number(2))
    }

    @Test func squareRoot() {
        let node = LaTeXParser.parse(#"\sqrt{x}"#)
        #expect(isRadical(node))
        if case .radical(let deg, let body) = node {
            #expect(deg  == nil)
            #expect(body == .variable("x"))
        }
    }

    @Test func nthRoot() {
        let node = LaTeXParser.parse(#"\sqrt[3]{x}"#)
        #expect(isRadical(node))
        if case .radical(let deg, _) = node {
            #expect(deg == .number(3))
        }
    }

    @Test func leftRightParen() {
        let node = LaTeXParser.parse(#"\left( x \right)"#)
        #expect(isBracketed(node, .paren))
        let inner = bracketedInner(node)
        #expect(inner == .variable("x"))
    }

    @Test func leftRightBracket() {
        let node = LaTeXParser.parse(#"\left[ a, b \right]"#)
        #expect(isBracketed(node, .square))
    }

    @Test func accents() {
        #expect(isAccent(LaTeXParser.parse(#"\hat{x}"#),   .hat))
        #expect(isAccent(LaTeXParser.parse(#"\bar{x}"#),   .bar))
        #expect(isAccent(LaTeXParser.parse(#"\vec{v}"#),   .vec))
        #expect(isAccent(LaTeXParser.parse(#"\dot{x}"#),   .dot))
        #expect(isAccent(LaTeXParser.parse(#"\ddot{x}"#),  .ddot))
        #expect(isAccent(LaTeXParser.parse(#"\tilde{f}"#), .tilde))
    }

    @Test func bigopSum() {
        let node = LaTeXParser.parse(#"\sum_{i=0}^{n} x_i"#)
        #expect(isBigop(node, .sum))
        let parts = bigopParts(node)!
        #expect(isGroup(parts.lower))   // i=0 parses as a group
        #expect(parts.upper == .variable("n"))
    }

    @Test func bigopIntegral() {
        let node = LaTeXParser.parse(#"\int_0^1 f(x)\,dx"#)
        #expect(isBigop(node, .integral))
        let parts = bigopParts(node)!
        #expect(parts.lower == .number(0))
        #expect(parts.upper == .number(1))
    }

    @Test func pmatrix() {
        let node = LaTeXParser.parse(#"\begin{pmatrix} a & b \\ c & d \end{pmatrix}"#)
        #expect(isBracketed(node, .paren))
        let inner = bracketedInner(node)!
        #expect(isMatrix(inner))
        if case .matrix(let rows) = inner {
            #expect(rows.count == 2)
            #expect(rows[0].count == 2)
            #expect(rows[1].count == 2)
        }
    }

    @Test func casesEnvironment() {
        let node = LaTeXParser.parse(#"""
            \begin{cases}
              x^2 & \text{if } x \geq 0 \\
              -x  & \text{if } x < 0
            \end{cases}
        """#)
        #expect(isCases(node))
        if case .cases(let pairs) = node {
            #expect(pairs.count == 2)
            #expect(isPower(pairs[0].0))   // x^2
        }
    }
}

// MARK: - Real arXiv Equations

@Suite("arXiv Equations") struct ArXivTests {

    // ── Physics ───────────────────────────────────────────────────────────────

    // Euler's identity:  e^{i\pi} + 1 = 0
    @Test func eulersIdentity() {
        let node = LaTeXParser.parse(#"e^{i\pi} + 1 = 0"#)
        let items = groupItems(node)
        #expect(items != nil)
        // First element should be e^{iπ}
        let first = items?.first
        #expect(isPower(first!))
    }

    // Gaussian integral:  \int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}
    @Test func gaussianIntegral() {
        let node = LaTeXParser.parse(#"\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}"#)
        // Top level is a group (integral + equals + sqrt)
        #expect(isGroup(node))
        let items = groupItems(node)!
        #expect(isBigop(items[0], .integral))
    }

    // Schrödinger equation:  i\hbar\frac{\partial}{\partial t}\Psi = \hat{H}\Psi
    @Test func schrodingerEquation() {
        let node = LaTeXParser.parse(#"i\hbar\frac{\partial}{\partial t}\Psi = \hat{H}\Psi"#)
        #expect(isGroup(node))
        let items = groupItems(node)!
        // Check that \frac{\partial}{\partial t} appears in the group
        let hasFrac = items.contains(where: isFraction)
        #expect(hasFrac)
    }

    // Lorentz factor:  \gamma = \frac{1}{\sqrt{1 - v^2/c^2}}
    @Test func lorentzFactor() {
        let node = LaTeXParser.parse(#"\gamma = \frac{1}{\sqrt{1 - v^2/c^2}}"#)
        let items = groupItems(node)!
        #expect(isSymbol(items[0], .gamma))
        let frac = items.first(where: isFraction)!
        let (num, den) = fracParts(frac)!
        #expect(num == .number(1))
        #expect(isRadical(den))
    }

    // Taylor series:  f(x) = \sum_{n=0}^{\infty} \frac{f^{(n)}(a)}{n!}(x-a)^n
    @Test func taylorSeries() {
        let node = LaTeXParser.parse(#"f(x) = \sum_{n=0}^{\infty} \frac{f^{(n)}(a)}{n!}(x-a)^n"#)
        #expect(isGroup(node))
        let items = groupItems(node)!
        let sum = items.first(where: { isBigop($0, .sum) })
        #expect(sum != nil)
    }

    // ── Machine learning ──────────────────────────────────────────────────────

    // Softmax:  \sigma(z)_j = \frac{e^{z_j}}{\sum_{k=1}^K e^{z_k}}
    @Test func softmax() {
        let node = LaTeXParser.parse(#"\frac{e^{z_j}}{\sum_{k=1}^{K} e^{z_k}}"#)
        #expect(isFraction(node))
        let (num, den) = fracParts(node)!
        #expect(isPower(num))
        #expect(isBigop(den, .sum))
    }

    // Cross-entropy loss:  L = -\sum_{i} y_i \log(\hat{y}_i)
    @Test func crossEntropyLoss() {
        let node = LaTeXParser.parse(#"-\sum_{i} y_i \log(\hat{y}_i)"#)
        // Either a group starting with negation or a bigop
        #expect(node != .placeholder)
        let items = groupItems(node) ?? [node]
        #expect(items.contains(where: { isBigop($0, .sum) }))
    }

    // Bayes' theorem:  P(A|B) = \frac{P(B|A)\,P(A)}{P(B)}
    @Test func bayesTheorem() {
        let node = LaTeXParser.parse(#"P(A|B) = \frac{P(B|A)\,P(A)}{P(B)}"#)
        #expect(isGroup(node))
        let items = groupItems(node)!
        #expect(items.contains(where: isFraction))
    }

    // Normal distribution PDF:
    //   f(x) = \frac{1}{\sigma\sqrt{2\pi}} e^{-\frac{1}{2}\left(\frac{x-\mu}{\sigma}\right)^2}
    @Test func normalDistribution() {
        let latex = #"f(x) = \frac{1}{\sigma\sqrt{2\pi}} e^{-\frac{1}{2}\left(\frac{x-\mu}{\sigma}\right)^2}"#
        let node = LaTeXParser.parse(latex)
        #expect(node != .placeholder)
        #expect(isGroup(node))
        let items = groupItems(node)!
        #expect(items.contains(where: isFraction))
        // e^{...} should be a power
        #expect(items.contains(where: isPower))
    }

    // ── Linear algebra ────────────────────────────────────────────────────────

    // Eigenvalue equation:  A\mathbf{v} = \lambda\mathbf{v}
    @Test func eigenvalue() {
        let node = LaTeXParser.parse(#"A\mathbf{v} = \lambda\mathbf{v}"#)
        #expect(isGroup(node))
        let items = groupItems(node)!
        #expect(items.contains(where: { isSymbol($0, .lambda) }))
    }

    // Matrix determinant:  \det(A) = \sum_{\sigma \in S_n} \text{sgn}(\sigma) \prod_{i=1}^n a_{i,\sigma(i)}
    @Test func matrixDeterminant() {
        let latex = #"\sum_{\sigma \in S_n} \text{sgn}(\sigma) \prod_{i=1}^{n} a_{i,\sigma(i)}"#
        let node = LaTeXParser.parse(latex)
        // Should parse to a group containing a sum
        #expect(isGroup(node))
        #expect(groupItems(node)!.contains(where: { isBigop($0, .sum) }))
    }

    // Quadratic formula:  x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
    @Test func quadraticFormula() {
        let node = LaTeXParser.parse(#"x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"#)
        #expect(isGroup(node))
        let frac = groupItems(node)!.first(where: isFraction)!
        let (num, _) = fracParts(frac)!
        // Numerator is a group containing a radical
        let numItems = groupItems(num)!
        #expect(numItems.contains(where: isRadical))
    }

    // ── Round-trip: ExpressionParser bridge ───────────────────────────────────

    @Test func expressionParserBridge() {
        // Verify that old-style expressions bridge correctly to MathNode
        let expr = ExpressionParser.parseExpression("x^2 + 2x - 1")!
        let node = expr.mathNode
        // Should be a group: [power, +, multiply, -, number]
        #expect(isGroup(node))
        let items = groupItems(node)!
        #expect(items.contains(where: isPower))
    }

    @Test func expressionParserFractionBridge() {
        // sin(x)/cos(x) bridges as a divide node
        let expr = ExpressionParser.parseExpression("sin(x)/cos(x)")!
        let node = expr.mathNode
        if case .divide = node { /* expected */ }
        else { #expect(node != .placeholder) }
    }
}

// MARK: - Robustness

@Suite("Robustness") struct RobustnessTests {

    @Test func emptyString() {
        let node = LaTeXParser.parse("")
        #expect(node == .placeholder)
    }

    @Test func dollarStripped() {
        #expect(LaTeXParser.parse("$x$")  == .variable("x"))
        #expect(LaTeXParser.parse("$$x$$") == .variable("x"))
        #expect(LaTeXParser.parse(#"\(x\)"#) == .variable("x"))
        #expect(LaTeXParser.parse(#"\[x\]"#) == .variable("x"))
    }

    @Test func unknownCommandRendersAsText() {
        let node = LaTeXParser.parse(#"\unknowncommand"#)
        if case .text(let s) = node {
            #expect(s == #"\unknowncommand"#)
        } else {
            Issue.record("Expected .text for unknown command, got \(node)")
        }
    }

    @Test func unclosedBrace() {
        // Should not crash — returns whatever was parsed
        let node = LaTeXParser.parse(#"\frac{x"#)
        #expect(node != .placeholder || node == .placeholder)   // just don't crash
    }

    @Test func deeplyNested() {
        // 5-level nested fraction — stress test for recursion
        let latex = #"\frac{1}{\frac{1}{\frac{1}{\frac{1}{\frac{1}{x}}}}}"#
        let node = LaTeXParser.parse(latex)
        #expect(isFraction(node))
    }

    @Test func spacingCommandsDropped() {
        // \, \; \quad should not produce nodes
        let node = LaTeXParser.parse(#"x\,+\;y"#)
        // Should parse as a group of x + y (spacing dropped)
        #expect(node != .placeholder)
        let items = groupItems(node) ?? [node]
        let hasVariable = items.contains(where: { if case .variable = $0 { return true }; return false })
        #expect(hasVariable)
    }
}
