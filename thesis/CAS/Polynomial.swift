// Polynomial.swift
// CAS support — viewing an expression as a univariate polynomial.
//
// `polynomialCoefficients(in:)` rewrites an expression as a coefficient list
// [c₀, c₁, c₂, …] in ascending powers of one variable, where every coefficient
// is itself an Expr free of that variable. It returns nil when the expression
// is not a polynomial in that variable (e.g. it appears inside a transcendental
// function or under a non-integer / negative power). Solving and integration
// both build on this.

import Foundation

extension Expr {

    /// Coefficients [c₀, c₁, …, cₙ] such that self = Σ cᵢ·variableⁱ, with each
    /// cᵢ free of `variable`; nil if self is not a polynomial in `variable`.
    /// Trailing zero coefficients are not trimmed here — see `Expr.trimmedPolynomial`.
    public func polynomialCoefficients(in variable: String) -> [Expr]? {
        switch self {
        case .num, .con:
            return [self]

        case .sym(let name):
            return name == variable ? [.zero, .one] : [self]

        case .add(let terms):
            var acc: [Expr] = [.zero]
            for term in terms {
                guard let c = term.polynomialCoefficients(in: variable) else { return nil }
                acc = Expr.addPolynomials(acc, c)
            }
            return acc

        case .mul(let factors):
            var acc: [Expr] = [.one]
            for factor in factors {
                guard let c = factor.polynomialCoefficients(in: variable) else { return nil }
                acc = Expr.multiplyPolynomials(acc, c)
            }
            return acc

        case .pow(let base, let exp):
            // Only non-negative integer powers of a polynomial stay polynomial.
            guard case .num(let e) = exp, e.isInteger,
                  let ei = e.integerValue, let n = Int(exactly: ei), n >= 0 else {
                return base.contains(variable: variable) ? nil : [self]
            }
            guard let bc = base.polynomialCoefficients(in: variable) else { return nil }
            var acc: [Expr] = [.one]
            for _ in 0..<n { acc = Expr.multiplyPolynomials(acc, bc) }
            return acc

        case .fn:
            // A function application is polynomial only if it doesn't involve
            // the variable at all (then it's a constant coefficient).
            return contains(variable: variable) ? nil : [self]
        }
    }

    /// The polynomial degree in `variable`, or nil if not a polynomial.
    public func polynomialDegree(in variable: String) -> Int? {
        guard let coeffs = polynomialCoefficients(in: variable) else { return nil }
        let trimmed = Expr.trimmedPolynomial(coeffs)
        return trimmed.isEmpty ? 0 : trimmed.count - 1
    }

    // MARK: - Coefficient-list arithmetic

    /// Adds two ascending-power coefficient lists.
    static func addPolynomials(_ a: [Expr], _ b: [Expr]) -> [Expr] {
        let n = Swift.max(a.count, b.count)
        var result: [Expr] = []
        result.reserveCapacity(n)
        for i in 0..<n {
            let ai = i < a.count ? a[i] : .zero
            let bi = i < b.count ? b[i] : .zero
            result.append(.sum([ai, bi]))
        }
        return result
    }

    /// Multiplies two ascending-power coefficient lists (convolution).
    static func multiplyPolynomials(_ a: [Expr], _ b: [Expr]) -> [Expr] {
        guard !a.isEmpty, !b.isEmpty else { return [.zero] }
        var result = Array(repeating: Expr.zero, count: a.count + b.count - 1)
        for i in a.indices {
            for j in b.indices {
                result[i + j] = .sum([result[i + j], .product([a[i], b[j]])])
            }
        }
        return result
    }

    /// Drops trailing zero coefficients so the highest entry is the true leading term.
    static func trimmedPolynomial(_ coeffs: [Expr]) -> [Expr] {
        var c = coeffs
        while let last = c.last, last == .zero { c.removeLast() }
        return c
    }
}
