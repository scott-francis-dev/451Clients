// Differentiation.swift
// CAS Milestone 2 — symbolic differentiation over the canonical Expr term.
//
// d/dx is a structural recursion: each rule builds its result through the
// smart constructors in Expr.swift, so the answer comes back already in
// canonical, automatically-simplified form (no separate simplify pass needed).
//
// Symbols other than the differentiation variable are treated as constants
// (their derivative is 0) — the usual partial-derivative convention.

import Foundation

extension Expr {

    /// The derivative of this expression with respect to `variable`.
    public func differentiated(withRespectTo variable: String) -> Expr {
        switch self {
        case .num, .con:
            return .zero

        case .sym(let name):
            return name == variable ? .one : .zero

        case .add(let terms):
            // (f + g + …)' = f' + g' + …
            return .sum(terms.map { $0.differentiated(withRespectTo: variable) })

        case .mul(let factors):
            return Expr.differentiateProduct(factors, variable)

        case .pow(let base, let exponent):
            return Expr.differentiatePower(base, exponent, variable)

        case .fn(let name, let args):
            return Expr.differentiateFunction(name, args, variable)
        }
    }

    // MARK: - Product rule

    /// (f₁·f₂·…·fₙ)' = Σᵢ fᵢ' · ∏_{j≠i} fⱼ
    private static func differentiateProduct(_ factors: [Expr], _ v: String) -> Expr {
        var terms: [Expr] = []
        for i in factors.indices {
            let dfi = factors[i].differentiated(withRespectTo: v)
            if dfi == .zero { continue }
            var product = [dfi]
            for j in factors.indices where j != i { product.append(factors[j]) }
            terms.append(.product(product))
        }
        return .sum(terms)
    }

    // MARK: - Power rule

    private static func differentiatePower(_ base: Expr, _ exponent: Expr, _ v: String) -> Expr {
        let dBase = base.differentiated(withRespectTo: v)
        let dExp = exponent.differentiated(withRespectTo: v)

        // Constant exponent:  (uⁿ)' = n·uⁿ⁻¹·u'
        if dExp == .zero {
            if dBase == .zero { return .zero }
            return .product([exponent, .power(base, exponent - 1), dBase])
        }

        // Constant base:  (aᵛ)' = aᵛ·ln(a)·v'
        if dBase == .zero {
            return .product([.power(base, exponent), .function("ln", base), dExp])
        }

        // General case:  (uᵛ)' = uᵛ·(v'·ln(u) + v·u'/u)
        let logTerm = Expr.product([dExp, .function("ln", base)])
        let powerTerm = Expr.product([exponent, dBase, .power(base, .num(.minusOne))])
        return .product([.power(base, exponent), .sum([logTerm, powerTerm])])
    }

    // MARK: - Chain rule for functions

    private static func differentiateFunction(_ name: String, _ args: [Expr], _ v: String) -> Expr {
        // Only single-argument elementary functions are handled analytically;
        // everything else becomes an unevaluated formal derivative.
        guard args.count == 1, let arg = args.first else {
            return formalDerivative(name, args, v)
        }

        let dArg = arg.differentiated(withRespectTo: v)
        if dArg == .zero { return .zero }

        guard let outer = outerDerivative(name, arg) else {
            return formalDerivative(name, args, v)
        }
        // d/dx f(u) = f'(u) · u'
        return .product([outer, dArg])
    }

    /// f'(u) for a known elementary function f, or nil if unknown.
    private static func outerDerivative(_ name: String, _ u: Expr) -> Expr? {
        switch name {
        case "sin":  return .function("cos", u)
        case "cos":  return -Expr.function("sin", u)
        case "tan":  return .power(.function("cos", u), .num(Rational(-2)))   // sec²u
        case "cot":  return -Expr.power(.function("sin", u), .num(Rational(-2)))
        case "exp":  return .function("exp", u)
        case "ln":   return .power(u, .num(.minusOne))                        // 1/u
        case "log":  return .power(.product([u, .function("ln", .num(Rational(10)))]), .num(.minusOne))
        case "sqrt": return .product([.num(Rational(1, 2)), .power(u, .num(Rational(-1, 2)))])
        case "asin": return .power(.one - .power(u, 2), .num(Rational(-1, 2)))
        case "acos": return -Expr.power(.one - .power(u, 2), .num(Rational(-1, 2)))
        case "atan": return .power(.one + .power(u, 2), .num(.minusOne))
        case "sinh": return .function("cosh", u)
        case "cosh": return .function("sinh", u)
        case "tanh": return .power(.function("cosh", u), .num(Rational(-2)))  // sech²u
        default:     return nil
        }
    }

    /// An unevaluated total derivative d(f(args))/dv, used when no analytic rule
    /// applies. Kept total so differentiation never fails.
    private static func formalDerivative(_ name: String, _ args: [Expr], _ v: String) -> Expr {
        .function("$deriv", [.function(name, args), .sym(v)])
    }
}
