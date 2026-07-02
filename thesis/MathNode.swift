// MathNode.swift
// Extended math AST for Thesis.
//
// Handles the full range of mathematical notation — from simple algebra
// through research-paper-grade expressions (fractions, integrals, sums,
// matrices, Greek symbols, accents, piecewise functions …).
//
// The canonical serialization format is a source string stored in
// ObjectRun.state["mathSource"] (with state["mathFormat"] = "expr451" or "latex").
// The MathNode AST is purely in-memory — parse on load, serialize as source.
//
// Relationship to ExpressionParser:
//   ParsedExpression (from ExpressionParser) exposes a `.mathNode` property
//   that bridges the existing AST into MathNode. Old documents round-trip cleanly.

import Foundation

// MARK: - Core AST

public indirect enum MathNode: Sendable, Equatable {

    // ── Atoms ───────────────────────────────────────────────────────────────

    /// A numeric literal: 3, 2.718, …
    case number(Double)

    /// An italic math variable: x, y, t, n, …
    case variable(String)

    /// A named symbol — Greek letters, operators, relations, arrows. See MathSymbol.
    case symbol(MathSymbol)

    /// Upright roman text inside math: \text{where}, \text{s.t.}
    case text(String)

    /// An empty interactive slot (for equation editing UX).
    case placeholder

    // ── Arithmetic ──────────────────────────────────────────────────────────
    // These mirror ExpressionParser's _Node so old expressions bridge cleanly.

    case add(MathNode, MathNode)
    case subtract(MathNode, MathNode)

    /// Implicit or explicit multiplication.
    case multiply(MathNode, MathNode)

    /// Inline division (renders as a/b on one line). Use .fraction for stacked.
    case divide(MathNode, MathNode)

    case negate(MathNode)

    /// Function application: sin, cos, exp, log, det, max, …  Multiple args for
    /// things like max(a, b) stored as a .group of comma-separated nodes.
    case apply(String, MathNode)

    // ── 2D Structure ────────────────────────────────────────────────────────

    /// Stacked fraction: numerator over denominator with a rule.
    case fraction(MathNode, MathNode)

    /// Superscript: base^exponent  (2D raised rendering).
    case power(base: MathNode, exp: MathNode)

    /// Subscript: base_index.
    case sub(base: MathNode, index: MathNode)

    /// Simultaneous sub and superscript on the same base: a_i^n.
    case subsup(base: MathNode, sub: MathNode, sup: MathNode)

    /// Nth root. `degree` is nil for square root.
    case radical(degree: MathNode?, MathNode)

    // ── Large Operators ─────────────────────────────────────────────────────

    /// ∑, ∏, ∫, ⋃, ⋂, … with lower/upper bounds and a body to the right.
    case bigop(MathBigOp, lower: MathNode, upper: MathNode, body: MathNode)

    // ── Accents ─────────────────────────────────────────────────────────────

    /// Diacritical marks over a node: hat, bar, tilde, vec, dot, …
    case accent(MathAccent, MathNode)

    // ── Containers ──────────────────────────────────────────────────────────

    /// Horizontal sequence of nodes (implicit adjacency / juxtaposition).
    case group([MathNode])

    /// m × n matrix of nodes.
    case matrix([[MathNode]])

    /// Piecewise function: [(value, condition)] rendered with a big left brace.
    case cases([(MathNode, MathNode)])

    /// Auto-sizing brackets around an inner node.
    case bracketed(MathBracketKind, MathNode)
}

// MARK: - Supporting Enums

public enum MathBigOp: String, Sendable, Equatable, CaseIterable {
    case sum, product, coproduct
    case integral, doubleIntegral, tripleIntegral, oint
    case union, intersection
    case bigwedge, bigvee
    case bigoplus, bigotimes

    public var character: String {
        switch self {
        case .sum:             return "∑"
        case .product:         return "∏"
        case .coproduct:       return "∐"
        case .integral:        return "∫"
        case .doubleIntegral:  return "∬"
        case .tripleIntegral:  return "∭"
        case .oint:            return "∮"
        case .union:           return "⋃"
        case .intersection:    return "⋂"
        case .bigwedge:        return "⋀"
        case .bigvee:          return "⋁"
        case .bigoplus:        return "⊕"
        case .bigotimes:       return "⊗"
        }
    }
}

public enum MathAccent: String, Sendable, Equatable, CaseIterable {
    case hat       // â  — \hat
    case bar       // ā  — \bar / \overline
    case tilde     // ã  — \tilde
    case vec       // →  — \vec
    case dot       // ȧ  — \dot
    case ddot      // ä  — \ddot
    case check     // ǎ  — \check / \breve
    case widehat   // extended hat
    case widetilde // extended tilde
}

public enum MathBracketKind: String, Sendable, Equatable, CaseIterable {
    case paren          // ( )
    case square         // [ ]
    case curly          // { }
    case angle          // ⟨ ⟩
    case abs            // | |
    case norm           // ‖ ‖
    case ceil           // ⌈ ⌉
    case floor          // ⌊ ⌋
    case openInterval   // ( ]
    case closedInterval // [ )

    public var open: String {
        switch self {
        case .paren:          return "("
        case .square:         return "["
        case .curly:          return "{"
        case .angle:          return "⟨"
        case .abs:            return "|"
        case .norm:           return "‖"
        case .ceil:           return "⌈"
        case .floor:          return "⌊"
        case .openInterval:   return "("
        case .closedInterval: return "["
        }
    }

    public var close: String {
        switch self {
        case .paren:          return ")"
        case .square:         return "]"
        case .curly:          return "}"
        case .angle:          return "⟩"
        case .abs:            return "|"
        case .norm:           return "‖"
        case .ceil:           return "⌉"
        case .floor:          return "⌋"
        case .openInterval:   return "]"
        case .closedInterval: return ")"
        }
    }
}

// MARK: - Symbol Table

public enum MathSymbol: String, Sendable, Equatable, CaseIterable {

    // Greek lowercase
    case alpha = "α", beta = "β", gamma = "γ", delta = "δ"
    case epsilon = "ε", varepsilon = "ϵ"
    case zeta = "ζ", eta = "η"
    case theta = "θ", vartheta = "ϑ"
    case iota = "ι", kappa = "κ", lambda = "λ", mu = "μ"
    case nu = "ν", xi = "ξ"
    case pi = "π", varpi = "ϖ"
    case rho = "ρ", varrho = "ϱ"
    case sigma = "σ", varsigma = "ς"
    case tau = "τ", upsilon = "υ"
    case phi = "φ", varphi = "ϕ"
    case chi = "χ", psi = "ψ", omega = "ω"

    // Greek uppercase
    case Gamma = "Γ", Delta = "Δ", Theta = "Θ", Lambda = "Λ"
    case Xi = "Ξ", Pi = "Π", Sigma = "Σ", Upsilon = "Υ"
    case Phi = "Φ", Psi = "Ψ", Omega = "Ω"

    // Calculus / analysis
    case partial = "∂", nabla = "∇", infinity = "∞"
    case prime = "′", dprime = "″"

    // Set theory
    case inSet = "∈", notIn = "∉"
    case subset = "⊂", subseteq = "⊆", supset = "⊃", supseteq = "⊇"
    case union = "∪", intersection = "∩", emptyset = "∅", setminus = "∖"

    // Logic
    case forall = "∀", exists = "∃", nexists = "∄"
    case wedge = "∧", vee = "∨", lnot = "¬"
    case top = "⊤", perp = "⊥"

    // Relations
    case leq = "≤", geq = "≥", neq = "≠"
    case ll = "≪", gg = "≫"
    case approx = "≈", sim = "∼", simeq = "≃", cong = "≅"
    case equiv = "≡", propto = "∝"

    // Arrows
    case rightArrow = "→", leftArrow = "←", leftRightArrow = "↔"
    case Rightarrow = "⇒", Leftarrow = "⇐", iff = "⟺"
    case mapsto = "↦", uparrow = "↑", downarrow = "↓"

    // Binary operators
    case pm = "±", mp = "∓"
    case times = "×", div = "÷", cdot = "·"
    case circ = "∘", bullet = "•"
    case oplus = "⊕", otimes = "⊗", ominus = "⊖"

    // Miscellaneous
    case hbar = "ℏ", ell = "ℓ"
    case aleph = "ℵ"
    case reals = "ℝ", integers = "ℤ", naturals = "ℕ", rationals = "ℚ", complex = "ℂ"
    case ldots = "…", cdots = "⋯", vdots = "⋮", ddots = "⋱"
    case therefore = "∴", because = "∵"
    case dagger = "†", ddagger = "‡"
    case angle = "∠"
}

// MARK: - Equatable for cases

// Swift synthesizes Equatable for indirect enum when all associated values conform.
// For cases (array of tuples), we need a manual conformance.
extension MathNode {
    public static func == (lhs: MathNode, rhs: MathNode) -> Bool {
        switch (lhs, rhs) {
        case (.number(let a), .number(let b)): return a == b
        case (.variable(let a), .variable(let b)): return a == b
        case (.symbol(let a), .symbol(let b)): return a == b
        case (.text(let a), .text(let b)): return a == b
        case (.placeholder, .placeholder): return true
        case (.add(let a1, let a2), .add(let b1, let b2)): return a1 == b1 && a2 == b2
        case (.subtract(let a1, let a2), .subtract(let b1, let b2)): return a1 == b1 && a2 == b2
        case (.multiply(let a1, let a2), .multiply(let b1, let b2)): return a1 == b1 && a2 == b2
        case (.divide(let a1, let a2), .divide(let b1, let b2)): return a1 == b1 && a2 == b2
        case (.negate(let a), .negate(let b)): return a == b
        case (.apply(let n1, let a1), .apply(let n2, let a2)): return n1 == n2 && a1 == a2
        case (.fraction(let a1, let a2), .fraction(let b1, let b2)): return a1 == b1 && a2 == b2
        case (.power(let a1, let a2), .power(let b1, let b2)): return a1 == b1 && a2 == b2
        case (.sub(let a1, let a2), .sub(let b1, let b2)): return a1 == b1 && a2 == b2
        case (.subsup(let ab, let as_, let ap), .subsup(let bb, let bs, let bp)): return ab == bb && as_ == bs && ap == bp
        case (.radical(let d1, let b1), .radical(let d2, let b2)): return d1 == d2 && b1 == b2
        case (.bigop(let op1, let l1, let u1, let b1), .bigop(let op2, let l2, let u2, let b2)):
            return op1 == op2 && l1 == l2 && u1 == u2 && b1 == b2
        case (.accent(let a1, let n1), .accent(let a2, let n2)): return a1 == a2 && n1 == n2
        case (.group(let a), .group(let b)): return a == b
        case (.matrix(let a), .matrix(let b)): return a == b
        case (.cases(let a), .cases(let b)):
            guard a.count == b.count else { return false }
            return zip(a, b).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        case (.bracketed(let k1, let n1), .bracketed(let k2, let n2)): return k1 == k2 && n1 == n2
        default: return false
        }
    }
}
