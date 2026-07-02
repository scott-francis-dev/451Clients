// Expansion.swift
// CAS Milestone 6 — expanding products and integer powers over the canonical Expr.
//
// Automatic simplification deliberately does NOT distribute (so `a·(x+y)` stays
// factored). `expanded()` is the explicit opposite: it multiplies everything
// out, distributing products over sums and raising sums to non-negative integer
// powers, then lets the smart constructors recombine like terms. It is the
// inverse direction of `factored(in:)` and a natural verification oracle for it.

import Foundation

extension Expr {

    /// Fully distributes products over sums and expands non-negative integer
    /// powers of sums, returning the result in canonical (auto-simplified) form.
    public func expanded() -> Expr {
        switch self {
        case .num, .con, .sym:
            return self

        case .add(let terms):
            return .sum(terms.map { $0.expanded() })

        case .mul(let factors):
            // Expand each factor, then distribute them together one at a time.
            return factors
                .map { $0.expanded() }
                .reduce(Expr.one) { Expr.distribute($0, $1) }

        case .pow(let base, let exp):
            let b = base.expanded()
            if case .num(let e) = exp, e.isInteger,
               let ei = e.integerValue, let n = Int(exactly: ei), n >= 0, n <= 16 {
                if n == 0 { return .one }
                var result = b
                for _ in 1..<n { result = Expr.distribute(result, b) }
                return result
            }
            return .power(b, exp.expanded())

        case .fn(let name, let args):
            return .function(name, args.map { $0.expanded() })
        }
    }

    /// Distributes (Σ aᵢ)·(Σ bⱼ) into Σᵢⱼ aᵢ·bⱼ. Inputs are assumed already
    /// expanded, so each "term" is sum-free at the top level.
    private static func distribute(_ a: Expr, _ b: Expr) -> Expr {
        var products: [Expr] = []
        for x in terms(of: a) {
            for y in terms(of: b) {
                products.append(.product([x, y]))
            }
        }
        return .sum(products)
    }

    /// The top-level additive terms of an expression (itself if not a sum).
    private static func terms(of e: Expr) -> [Expr] {
        if case .add(let t) = e { return t }
        return [e]
    }
}
