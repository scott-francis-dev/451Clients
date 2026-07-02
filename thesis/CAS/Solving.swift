// Solving.swift
// CAS Milestone 5 — solving polynomial equations over the canonical Expr.
//
// `solved(for:)` finds the roots of `self == 0` in one variable. It views the
// expression as a univariate polynomial (via polynomialCoefficients) and solves
// the linear and quadratic cases exactly, using the quadratic formula with exact
// rational arithmetic. Perfect-square discriminants collapse to rationals;
// negative discriminants produce complex roots in terms of the imaginary unit i.
//
// Returns:
//   • [roots]  — the solution set (possibly empty for "no solution")
//   • nil      — outside the supported class (degree ≥ 3, or non-polynomial,
//                or an identity that holds for all values).

import Foundation
import BigInt

extension Expr {

    /// Solves `self == 0` for `variable`. See file header for the return contract.
    public func solved(for variable: String) -> [Expr]? {
        guard let raw = polynomialCoefficients(in: variable) else { return nil }
        let c = Expr.trimmedPolynomial(raw)

        switch c.count {
        case 0:
            // self ≡ 0 — true for every value; not a finite solution set.
            return nil
        case 1:
            // A nonzero constant = 0 ⇒ no solution.
            return c[0] == .zero ? nil : []
        case 2:
            // c₁·x + c₀ = 0  ⇒  x = −c₀/c₁
            let root = Expr.product([.num(.minusOne), c[0], .power(c[1], .num(.minusOne))])
            return [root]
        case 3:
            return Expr.solveQuadratic(a: c[2], b: c[1], c: c[0])
        default:
            return nil   // degree ≥ 3 not yet supported
        }
    }

    // MARK: - Factoring

    /// Factors a univariate polynomial with rational coefficients over the
    /// rationals: linear `a·x + b → a·(x + b/a)` and quadratics that split into
    /// rational linear factors `a·(x − r₁)·(x − r₂)` (a repeated root collapses
    /// to `a·(x − r)²` automatically via the product constructor). Returns nil
    /// when there is nothing to factor (degree 0) or it doesn't factor over ℚ
    /// (irrational/complex roots, or non-polynomial input). Verify with
    /// `factored(in:)?.expanded()`, which must equal the original.
    public func factored(in variable: String) -> Expr? {
        guard let raw = polynomialCoefficients(in: variable) else { return nil }
        let trimmed = Expr.trimmedPolynomial(raw)

        // All coefficients must be concrete rationals.
        var coeffs: [Rational] = []
        for term in trimmed {
            guard case .num(let r) = term else { return nil }
            coeffs.append(r)
        }
        guard coeffs.count >= 2 else { return nil }   // degree ≥ 1

        let x = Expr.sym(variable)
        switch coeffs.count - 1 {
        case 1:
            let a = coeffs[1], b = coeffs[0]
            let root = -(b / a)
            return Expr.product([.num(a), Expr.sum([x, .num(-root)])])
        case 2:
            let a = coeffs[2], b = coeffs[1], c = coeffs[0]
            let disc = b * b - Rational(4) * a * c
            guard !disc.isNegative, let s = Expr.perfectRationalSqrt(disc) else { return nil }
            let twoA = Rational(2) * a
            let r1 = (-b + s) / twoA
            let r2 = (-b - s) / twoA
            return Expr.product([.num(a),
                                 Expr.sum([x, .num(-r1)]),
                                 Expr.sum([x, .num(-r2)])])
        default:
            return nil   // degree ≥ 3 not supported
        }
    }

    /// √r as an exact rational when r is a non-negative perfect-square rational.
    private static func perfectRationalSqrt(_ r: Rational) -> Rational? {
        guard !r.isNegative,
              let p = integerSquareRoot(r.numerator),
              let q = integerSquareRoot(r.denominator) else { return nil }
        return Rational(p, q)
    }

    // MARK: - Quadratic formula

    /// Roots of a·x² + b·x + c = 0 (a ≠ 0) via x = (−b ± √(b²−4ac)) / 2a.
    private static func solveQuadratic(a: Expr, b: Expr, c: Expr) -> [Expr] {
        let disc = Expr.sum([.power(b, .num(Rational(2))),
                             .product([.num(Rational(-4)), a, c])])
        let twoA = Expr.product([.num(Rational(2)), a])
        let negB = Expr.product([.num(.minusOne), b])

        // Repeated root when the discriminant is exactly zero.
        if case .num(let d) = disc, d.isZero {
            return [.product([negB, .power(twoA, .num(.minusOne))])]
        }

        let sqrtDisc = squareRoot(of: disc)
        let plus  = Expr.product([Expr.sum([negB, sqrtDisc]), .power(twoA, .num(.minusOne))])
        let minus = Expr.product([Expr.sum([negB, -sqrtDisc]), .power(twoA, .num(.minusOne))])
        return [plus, minus]
    }

    // MARK: - Symbolic square root

    /// √e, kept exact when possible: perfect-square rationals collapse to a
    /// rational, negative rationals come back as i·√|e|, and anything else stays
    /// as a symbolic sqrt(...).
    private static func squareRoot(of e: Expr) -> Expr {
        guard case .num(let r) = e else { return .function("sqrt", e) }

        if r.isNegative {
            let magnitude = Expr.exactSqrt(-r) ?? .function("sqrt", .num(-r))
            return .product([.con(.i), magnitude])
        }
        return Expr.exactSqrt(r) ?? .function("sqrt", e)
    }

    /// Returns √r as an exact `.num` when r is a perfect-square rational, else nil.
    private static func exactSqrt(_ r: Rational) -> Expr? {
        guard !r.isNegative,
              let p = Expr.integerSquareRoot(r.numerator),
              let q = Expr.integerSquareRoot(r.denominator) else { return nil }
        return .num(Rational(p, q))
    }

    /// Exact integer square root of a non-negative BigInt, or nil if `n` is not
    /// a perfect square. Uses Newton's method (floor sqrt) then verifies.
    private static func integerSquareRoot(_ n: BigInt) -> BigInt? {
        if n < 0 { return nil }
        if n == 0 || n == 1 { return n }
        var x = n
        var y = (x + 1) / 2
        while y < x {
            x = y
            y = (x + n / x) / 2
        }
        return x * x == n ? x : nil
    }
}
