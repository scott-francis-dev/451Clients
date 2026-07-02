// Expr+MathNode.swift
// Bridge between the display AST (MathNode) and the canonical CAS term (Expr).
//
//   • `Expr(_:)`     lifts a MathNode into canonical form for computation.
//   • `Expr.mathNode` lowers a canonical term back to MathNode for layout,
//                     reconstructing fractions, square roots and subtractions.
//
// Algebraic notation (numbers, variables, +, −, ×, ÷, ^, functions, roots) maps
// faithfully. Non-algebraic MathNode kinds the engine doesn't model yet
// (matrices, cases, big operators, accents, subscripts, brackets, text) are
// carried through a reserved "$"-tagged function so the bridge is total and
// round-trips structurally; giving them real algebraic meaning is future work.

import Foundation
import BigInt

// MARK: - MathNode → Expr (lift)

extension Expr {

    public init(_ node: MathNode) {
        switch node {
        case .number(let d):
            self = .num(Expr.rational(approximating: d))

        case .variable(let name):
            self = .sym(name)

        case .symbol(let symbol):
            switch symbol {
            case .pi:        self = .con(.pi)
            case .infinity:  self = .con(.infinity)
            default:         self = .sym(symbol.rawValue)
            }

        case .text(let s):
            self = .fn(Expr.tagText, [.sym(s)])

        case .placeholder:
            self = .fn(Expr.tagPlaceholder, [])

        case .add(let a, let b):
            self = .sum([Expr(a), Expr(b)])

        case .subtract(let a, let b):
            self = .sum([Expr(a), -Expr(b)])

        case .multiply(let a, let b):
            self = .product([Expr(a), Expr(b)])

        case .divide(let a, let b):
            self = .product([Expr(a), .power(Expr(b), .num(.minusOne))])

        case .negate(let a):
            self = -Expr(a)

        case .apply(let name, let arg):
            self = .function(name, Expr.flattenArguments(arg))

        case .fraction(let n, let d):
            self = .product([Expr(n), .power(Expr(d), .num(.minusOne))])

        case .power(let base, let exp):
            self = .power(Expr(base), Expr(exp))

        case .sub(let base, let index):
            self = .fn(Expr.tagSub, [Expr(base), Expr(index)])

        case .subsup(let base, let sub, let sup):
            self = .fn(Expr.tagSubsup, [Expr(base), Expr(sub), Expr(sup)])

        case .radical(let degree, let radicand):
            if let degree {
                // nth root = radicand ^ (1/degree)
                self = .power(Expr(radicand), .power(Expr(degree), .num(.minusOne)))
            } else {
                self = .power(Expr(radicand), .num(Rational(1, 2)))
            }

        case .bigop(let op, let lower, let upper, let body):
            self = .fn(Expr.tagBigOp, [.sym(op.rawValue), Expr(lower), Expr(upper), Expr(body)])

        case .accent(let accent, let inner):
            self = .fn(Expr.tagAccent, [.sym(accent.rawValue), Expr(inner)])

        case .group(let nodes):
            // Juxtaposition is implicit multiplication.
            self = .product(nodes.map(Expr.init))

        case .matrix(let rows):
            var args: [Expr] = [.num(Rational(rows.count)),
                                .num(Rational(rows.first?.count ?? 0))]
            for row in rows { args.append(contentsOf: row.map(Expr.init)) }
            self = .fn(Expr.tagMatrix, args)

        case .cases(let pairs):
            var args: [Expr] = []
            for (value, condition) in pairs {
                args.append(Expr(value))
                args.append(Expr(condition))
            }
            self = .fn(Expr.tagCases, args)

        case .bracketed(let kind, let inner):
            self = .fn(Expr.tagBracket, [.sym(kind.rawValue), Expr(inner)])
        }
    }

    /// `apply` carries a single MathNode; a `.group` means several arguments.
    private static func flattenArguments(_ node: MathNode) -> [Expr] {
        if case .group(let nodes) = node { return nodes.map(Expr.init) }
        return [Expr(node)]
    }
}

// MARK: - Expr → MathNode (lower)

extension Expr {

    public var mathNode: MathNode {
        switch self {
        case .num(let r):
            return Expr.lowerNumber(r)

        case .con(let c):
            switch c {
            case .pi:       return .symbol(.pi)
            case .infinity: return .symbol(.infinity)
            case .e:        return .variable("e")
            case .i:        return .variable("i")
            }

        case .sym(let name):
            return .variable(name)

        case .add(let terms):
            return Expr.lowerSum(terms)

        case .mul(let factors):
            return Expr.lowerProduct(factors)

        case .pow(let base, let exp):
            return Expr.lowerPower(base, exp)

        case .fn(let name, let args):
            return Expr.lowerFunction(name, args)
        }
    }

    // MARK: number

    private static func lowerNumber(_ r: Rational) -> MathNode {
        if r.isInteger { return .number(r.doubleValue) }
        let sign: Rational = r.isNegative ? .minusOne : .one
        let magnitude = r * sign            // |r|
        let frac = MathNode.fraction(.number(Double(magnitude.numerator)),
                                     .number(Double(magnitude.denominator)))
        return r.isNegative ? .negate(frac) : frac
    }

    // MARK: sum

    private static func lowerSum(_ terms: [Expr]) -> MathNode {
        guard !terms.isEmpty else { return .number(0) }

        // Render positive terms first, then fold the negative ones in as
        // subtractions, so a canonical "[-3, x]" displays as "x − 3" rather
        // than "−3 + x". Within each group the canonical order is preserved.
        let positives = terms.filter { !$0.isNegativeTerm }
        let negatives = terms.filter { $0.isNegativeTerm }

        var acc: MathNode
        let trailingNegatives: ArraySlice<Expr>
        if let firstPositive = positives.first {
            acc = firstPositive.mathNode
            for term in positives.dropFirst() {
                acc = .add(acc, term.mathNode)
            }
            trailingNegatives = negatives[...]
        } else {
            // All terms negative: the first keeps its own sign.
            acc = negatives[0].mathNode
            trailingNegatives = negatives.dropFirst()
        }

        for term in trailingNegatives {
            acc = .subtract(acc, (-term).mathNode)
        }
        return acc
    }

    /// True when a term carries an overall negative sign (so a sum can render it
    /// as a subtraction).
    private var isNegativeTerm: Bool {
        switch self {
        case .num(let r): return r.isNegative
        case .mul(let factors):
            if case .num(let r) = factors.first { return r.isNegative }
            return false
        default: return false
        }
    }

    // MARK: product

    private static func lowerProduct(_ factors: [Expr]) -> MathNode {
        var coeff = Rational.one
        var numerator: [MathNode] = []
        var denominator: [MathNode] = []

        for factor in factors {
            if case .num(let r) = factor { coeff = coeff * r; continue }
            let (base, exp) = factor.baseAndExponentForLowering
            if case .num(let e) = exp, e.isNegative {
                denominator.append(Expr.power(base, .num(-e)).mathNode)
            } else {
                numerator.append(factor.mathNode)
            }
        }

        let negative = coeff.isNegative
        let magnitude = negative ? -coeff : coeff

        // Distribute the rational coefficient across numerator / denominator.
        if magnitude.numerator != 1 || numerator.isEmpty {
            numerator.insert(.number(Double(magnitude.numerator)), at: 0)
        }
        if magnitude.denominator != 1 {
            denominator.insert(.number(Double(magnitude.denominator)), at: 0)
        }

        var numNode = chainMultiply(numerator)
        if negative { numNode = .negate(numNode) }

        if denominator.isEmpty { return numNode }
        return .fraction(numNode, chainMultiply(denominator))
    }

    private static func chainMultiply(_ nodes: [MathNode]) -> MathNode {
        guard let first = nodes.first else { return .number(1) }
        return nodes.dropFirst().reduce(first) { .multiply($0, $1) }
    }

    private var baseAndExponentForLowering: (Expr, Expr) {
        if case .pow(let b, let e) = self { return (b, e) }
        return (self, .one)
    }

    // MARK: power

    private static func lowerPower(_ base: Expr, _ exp: Expr) -> MathNode {
        if case .num(let e) = exp {
            // Square root and nth roots.
            if e == Rational(1, 2) {
                return .radical(degree: nil, base.mathNode)
            }
            if e.numerator == 1, e.denominator > 1 {
                return .radical(degree: .number(Double(e.denominator)), base.mathNode)
            }
            // Negative exponent → reciprocal as a fraction.
            if e.isNegative {
                return .fraction(.number(1), Expr.power(base, .num(-e)).mathNode)
            }
        }
        return .power(base: base.mathNode, exp: exp.mathNode)
    }

    // MARK: function

    private static func lowerFunction(_ name: String, _ args: [Expr]) -> MathNode {
        switch name {
        case tagText:
            if case .sym(let s) = args.first { return .text(s) }
            return .text("")

        case tagPlaceholder:
            return .placeholder

        case tagSub where args.count == 2:
            return .sub(base: args[0].mathNode, index: args[1].mathNode)

        case tagSubsup where args.count == 3:
            return .subsup(base: args[0].mathNode, sub: args[1].mathNode, sup: args[2].mathNode)

        case tagBigOp where args.count == 4:
            if case .sym(let raw) = args[0], let op = MathBigOp(rawValue: raw) {
                return .bigop(op, lower: args[1].mathNode, upper: args[2].mathNode, body: args[3].mathNode)
            }

        case tagAccent where args.count == 2:
            if case .sym(let raw) = args[0], let accent = MathAccent(rawValue: raw) {
                return .accent(accent, args[1].mathNode)
            }

        case tagBracket where args.count == 2:
            if case .sym(let raw) = args[0], let kind = MathBracketKind(rawValue: raw) {
                return .bracketed(kind, args[1].mathNode)
            }

        case tagMatrix where args.count >= 2:
            if case .num(let rr) = args[0], case .num(let cc) = args[1],
               let rowCount = rr.integerValue.flatMap({ Int(exactly: $0) }),
               let colCount = cc.integerValue.flatMap({ Int(exactly: $0) }),
               args.count == 2 + rowCount * colCount {
                let entries = args[2...].map(\.mathNode)
                var rows: [[MathNode]] = []
                for r in 0..<rowCount {
                    rows.append(Array(entries[(r * colCount)..<((r + 1) * colCount)]))
                }
                return .matrix(rows)
            }

        case tagCases where args.count % 2 == 0:
            var pairs: [(MathNode, MathNode)] = []
            var i = 0
            while i < args.count {
                pairs.append((args[i].mathNode, args[i + 1].mathNode))
                i += 2
            }
            return .cases(pairs)

        default:
            break
        }
        // Ordinary function: one arg directly, several wrapped in a group.
        if args.count == 1 { return .apply(name, args[0].mathNode) }
        return .apply(name, .group(args.map(\.mathNode)))
    }
}

// MARK: - Reserved tags for non-algebraic MathNode kinds

extension Expr {
    fileprivate static let tagText        = "$text"
    fileprivate static let tagPlaceholder = "$placeholder"
    fileprivate static let tagSub         = "$sub"
    fileprivate static let tagSubsup      = "$subsup"
    fileprivate static let tagBigOp       = "$bigop"
    fileprivate static let tagAccent      = "$accent"
    fileprivate static let tagBracket     = "$bracket"
    fileprivate static let tagMatrix      = "$matrix"
    fileprivate static let tagCases       = "$cases"
}

// MARK: - Double → exact Rational

extension Expr {

    /// Converts a Double to an exact Rational via its shortest round-tripping
    /// decimal, so user input like 0.5 / 0.1 becomes 1/2 / 1/10 rather than a
    /// power-of-two fraction.
    static func rational(approximating value: Double) -> Rational {
        guard value.isFinite else { return .zero }
        return parseDecimal(String(value)) ?? .zero
    }

    private static func parseDecimal(_ text: String) -> Rational? {
        var s = Substring(text)
        var negative = false
        if s.first == "-" { negative = true; s = s.dropFirst() }
        else if s.first == "+" { s = s.dropFirst() }

        // Split off a decimal exponent (e/E).
        var exponent = 0
        if let eIndex = s.firstIndex(where: { $0 == "e" || $0 == "E" }) {
            guard let exp = Int(s[s.index(after: eIndex)...]) else { return nil }
            exponent = exp
            s = s[..<eIndex]
        }

        // Split mantissa into integer and fractional digits.
        let parts = s.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let intDigits = String(parts.first ?? "")
        let fracDigits = parts.count > 1 ? String(parts[1]) : ""

        let digits = intDigits + fracDigits
        guard let n = BigInt(digits.isEmpty ? "0" : digits) else { return nil }

        var numerator = n
        var denominator = BigInt(1)

        // Account for the fractional digits, then the explicit exponent.
        let scale = -fracDigits.count + exponent
        if scale >= 0 {
            numerator *= tenToThe(scale)
        } else {
            denominator *= tenToThe(-scale)
        }

        if negative { numerator = -numerator }
        return Rational(numerator, denominator)
    }

    private static func tenToThe(_ k: Int) -> BigInt {
        var result = BigInt(1)
        let ten = BigInt(10)
        for _ in 0..<k { result *= ten }
        return result
    }
}
