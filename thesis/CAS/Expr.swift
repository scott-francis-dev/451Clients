// Expr.swift
// CAS Layer 1 — the canonical algebraic term.
//
// This is what the computer-algebra engine computes on. It is deliberately
// SEPARATE from MathNode (the display AST in MathNode.swift): MathNode is
// optimized for 2D layout, whereas Expr is a normalized algebraic form where
//
//   • addition and multiplication are flat, n-ary, commutatively sorted,
//   • integers/rationals are exact (Rational over BigInt),
//   • structurally-equal expressions are bitwise-equal (so == and hashing are
//     genuine mathematical equality up to automatic simplification).
//
// The raw enum cases hold the normal form. Build values only through the smart
// constructors (`sum`, `product`, `power`, `number`, …) or the operators — they
// are the automatic simplifier and they establish the invariants the rest of
// the engine relies on.

import Foundation
import BigInt

// MARK: - Constants

/// Exact mathematical constants kept symbolic (never folded to Double).
public enum MathConstant: String, Hashable, Sendable, CaseIterable {
    case pi
    case e
    case i          // imaginary unit
    case infinity
}

// MARK: - Core term

public indirect enum Expr: Hashable, Sendable {

    /// Exact numeric literal (integer when its denominator is 1).
    case num(Rational)

    /// A named exact constant: π, e, i, ∞.
    case con(MathConstant)

    /// A free variable: x, y, t, …
    case sym(String)

    /// Flat n-ary sum. Invariants: ≥ 2 terms, canonically sorted, no nested
    /// `.add`, at most one `.num` (placed first), no `.num(0)`.
    case add([Expr])

    /// Flat n-ary product. Invariants: ≥ 2 factors, canonically sorted, no
    /// nested `.mul`, at most one `.num` (placed first, ≠ 0, ≠ 1).
    case mul([Expr])

    /// Power base^exponent.
    case pow(Expr, Expr)

    /// Function application: sin, cos, ln, exp, …
    case fn(String, [Expr])
}

// MARK: - Leaf conveniences

extension Expr {
    public static func number(_ r: Rational) -> Expr { .num(r) }
    public static func number(_ n: Int) -> Expr { .num(Rational(n)) }
    public static func number(_ n: BigInt) -> Expr { .num(Rational(n)) }

    public static let zero = Expr.num(.zero)
    public static let one = Expr.num(.one)

    /// The numeric value if this term is a pure rational, else nil.
    public var rationalValue: Rational? {
        if case .num(let r) = self { return r }
        return nil
    }
}

// MARK: - Smart constructor: power

extension Expr {

    public static func power(_ base: Expr, _ exponent: Expr) -> Expr {
        // x^0 = 1, x^1 = x
        if case .num(let e) = exponent {
            if e.isZero { return .one }
            if e.isOne { return base }
        }
        // 1^x = 1
        if case .num(let b) = base, b.isOne { return .one }

        // Numeric base & integer exponent → fold exactly.
        if case .num(let b) = base, case .num(let e) = exponent, let ei = e.integerValue {
            if let small = Int(exactly: ei) {
                if b.isZero {
                    if small > 0 { return .zero }
                    // 0 ^ (negative) is undefined — leave symbolic.
                } else {
                    return .num(b.raised(to: small))
                }
            }
        }

        // 0 ^ (positive) = 0 for non-integer positive exponents too.
        if case .num(let b) = base, b.isZero,
           case .num(let e) = exponent, e > .zero {
            return .zero
        }

        // (a^b)^c with integer c  →  a^(b·c)
        if case .pow(let innerBase, let innerExp) = base,
           case .num(let e) = exponent, e.isInteger {
            return power(innerBase, product([innerExp, exponent]))
        }

        // (a·b·c)^n with integer n  →  a^n · b^n · c^n
        if case .mul(let factors) = base,
           case .num(let e) = exponent, e.isInteger {
            return product(factors.map { power($0, exponent) })
        }

        return .pow(base, exponent)
    }
}

// MARK: - Smart constructor: product

extension Expr {

    public static func product(_ factors: [Expr]) -> Expr {
        // 1. Flatten nested products.
        var flat: [Expr] = []
        for f in factors {
            if case .mul(let inner) = f { flat.append(contentsOf: inner) }
            else { flat.append(f) }
        }

        // 2. Fold numeric coefficient; short-circuit on zero.
        var coeff = Rational.one
        var rest: [Expr] = []
        for f in flat {
            if case .num(let r) = f {
                if r.isZero { return .zero }
                coeff = coeff * r
            } else {
                rest.append(f)
            }
        }

        // 3. Collect like bases, summing exponents:  x · x^3 → x^4.
        var bases: [Expr] = []                 // preserves first-seen order
        var exponents: [Expr: Expr] = [:]
        for f in rest {
            let (base, exp) = f.baseAndExponent
            if let existing = exponents[base] {
                exponents[base] = sum([existing, exp])
            } else {
                bases.append(base)
                exponents[base] = exp
            }
        }

        // 4. Rebuild non-numeric factors.
        var result: [Expr] = []
        for base in bases {
            let e = exponents[base]!
            if case .num(let r) = e, r.isZero { continue }      // x^0 = 1
            result.append(power(base, e))
        }

        // 5. Reattach the numeric coefficient.
        if coeff.isZero { return .zero }
        if result.isEmpty { return .num(coeff) }
        result.sort(by: Expr.canonicalOrder)
        if !coeff.isOne { result.insert(.num(coeff), at: 0) }

        if result.count == 1 { return result[0] }
        return .mul(result)
    }

    /// Splits a factor into (base, exponent) for like-factor collection.
    fileprivate var baseAndExponent: (Expr, Expr) {
        if case .pow(let b, let e) = self { return (b, e) }
        return (self, .one)
    }
}

// MARK: - Smart constructor: sum

extension Expr {

    public static func sum(_ terms: [Expr]) -> Expr {
        // 1. Flatten nested sums.
        var flat: [Expr] = []
        for t in terms {
            if case .add(let inner) = t { flat.append(contentsOf: inner) }
            else { flat.append(t) }
        }

        // 2. Fold numeric constant; collect like terms by their non-numeric part.
        var constant = Rational.zero
        var keys: [Expr] = []                  // preserves first-seen order
        var coeffs: [Expr: Rational] = [:]
        for t in flat {
            let (coeff, key) = t.coefficientAndRest
            if let key {
                if let existing = coeffs[key] {
                    coeffs[key] = existing + coeff
                } else {
                    keys.append(key)
                    coeffs[key] = coeff
                }
            } else {
                constant = constant + coeff    // purely numeric term
            }
        }

        // 3. Rebuild terms.
        var result: [Expr] = []
        for key in keys {
            let c = coeffs[key]!
            if c.isZero { continue }
            if c.isOne { result.append(key) }
            else { result.append(product([.num(c), key])) }
        }
        result.sort(by: Expr.canonicalOrder)
        if !constant.isZero { result.insert(.num(constant), at: 0) }

        if result.isEmpty { return .zero }
        if result.count == 1 { return result[0] }
        return .add(result)
    }

    /// Splits a term into (coefficient, non-numeric part). A `nil` part means the
    /// whole term is numeric and `coefficient` is its value.
    fileprivate var coefficientAndRest: (Rational, Expr?) {
        switch self {
        case .num(let r):
            return (r, nil)
        case .mul(let factors):
            var coeff = Rational.one
            var rest: [Expr] = []
            for f in factors {
                if case .num(let r) = f { coeff = coeff * r }
                else { rest.append(f) }
            }
            if rest.isEmpty { return (coeff, nil) }
            if rest.count == 1 { return (coeff, rest[0]) }
            return (coeff, .mul(rest))
        default:
            return (.one, self)
        }
    }
}

// MARK: - Smart constructor: function

extension Expr {
    public static func function(_ name: String, _ args: [Expr]) -> Expr {
        .fn(name, args)
    }

    public static func function(_ name: String, _ arg: Expr) -> Expr {
        .fn(name, [arg])
    }
}

// MARK: - Operators

extension Expr {
    public static func + (l: Expr, r: Expr) -> Expr { sum([l, r]) }
    public static func - (l: Expr, r: Expr) -> Expr { sum([l, product([.num(.minusOne), r])]) }
    public static prefix func - (e: Expr) -> Expr { product([.num(.minusOne), e]) }
    public static func * (l: Expr, r: Expr) -> Expr { product([l, r]) }
    public static func / (l: Expr, r: Expr) -> Expr { product([l, power(r, .num(.minusOne))]) }
}

extension Expr: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .num(Rational(value)) }
}

// MARK: - Canonical ordering

extension Expr {

    /// Strict total order used to sort the children of sums and products so that
    /// commutatively-equal expressions normalize to the same representation.
    public static func canonicalOrder(_ a: Expr, _ b: Expr) -> Bool {
        compare(a, b) < 0
    }

    /// Rank of each case; lower sorts first. Numbers lead, functions trail.
    private var rank: Int {
        switch self {
        case .num: return 0
        case .con: return 1
        case .sym: return 2
        case .pow: return 3
        case .mul: return 4
        case .add: return 5
        case .fn:  return 6
        }
    }

    /// Three-way comparison: <0, 0, >0.
    private static func compare(_ a: Expr, _ b: Expr) -> Int {
        if a.rank != b.rank { return a.rank < b.rank ? -1 : 1 }
        switch (a, b) {
        case (.num(let x), .num(let y)):
            if x == y { return 0 }
            return x < y ? -1 : 1
        case (.con(let x), .con(let y)):
            return compareStrings(x.rawValue, y.rawValue)
        case (.sym(let x), .sym(let y)):
            return compareStrings(x, y)
        case (.pow(let xb, let xe), .pow(let yb, let ye)):
            let c = compare(xb, yb)
            return c != 0 ? c : compare(xe, ye)
        case (.mul(let xs), .mul(let ys)):
            return compareLists(xs, ys)
        case (.add(let xs), .add(let ys)):
            return compareLists(xs, ys)
        case (.fn(let xn, let xa), .fn(let yn, let ya)):
            let c = compareStrings(xn, yn)
            return c != 0 ? c : compareLists(xa, ya)
        default:
            return 0
        }
    }

    private static func compareStrings(_ x: String, _ y: String) -> Int {
        if x == y { return 0 }
        return x < y ? -1 : 1
    }

    private static func compareLists(_ xs: [Expr], _ ys: [Expr]) -> Int {
        for (x, y) in zip(xs, ys) {
            let c = compare(x, y)
            if c != 0 { return c }
        }
        if xs.count == ys.count { return 0 }
        return xs.count < ys.count ? -1 : 1
    }
}

// MARK: - Description (linear debug form, distinct from MathNode rendering)

extension Expr: CustomStringConvertible {
    public var description: String {
        switch self {
        case .num(let r): return r.description
        case .con(let c): return c.rawValue
        case .sym(let s): return s
        case .add(let terms):
            return terms.map(\.description).joined(separator: " + ")
        case .mul(let factors):
            return factors.map { factor in
                switch factor {
                case .add: return "(\(factor.description))"
                default: return factor.description
                }
            }.joined(separator: "·")
        case .pow(let b, let e):
            return "\(parenthesized(b))^\(parenthesized(e))"
        case .fn(let name, let args):
            return "\(name)(\(args.map(\.description).joined(separator: ", ")))"
        }
    }

    private func parenthesized(_ e: Expr) -> String {
        switch e {
        case .num, .con, .sym, .fn: return e.description
        default: return "(\(e.description))"
        }
    }
}
