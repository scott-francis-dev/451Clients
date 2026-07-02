// Integration.swift
// CAS Milestone 4 — symbolic indefinite integration over the canonical Expr.
//
// Integration is harder than differentiation: there is no algorithm that
// integrates every elementary function in closed form, so this returns an
// optional — nil means "no closed form in the rules implemented here" rather
// than "undefined". The constant of integration is omitted.
//
// Implemented rules:
//   • constants and the variable itself          (∫c dx, ∫x dx)
//   • the power rule, including ∫x⁻¹ = ln x       (∫xⁿ dx)
//   • linearity                                   (∫(f+g) = ∫f + ∫g)
//   • pulling out constant factors               (∫c·f = c·∫f)
//   • linear u-substitution for elementary fns   (∫f(ax+b) dx = F(ax+b)/a)
//   • ∫(ax+b)ⁿ dx and ∫1/(ax+b) dx
//
// Everything else (notably products needing integration by parts) returns nil.

import Foundation

extension Expr {

    /// The indefinite integral with respect to `variable`, or nil when no rule
    /// here produces a closed form. The constant of integration is omitted.
    public func integrated(withRespectTo variable: String) -> Expr? {
        switch self {
        case .num, .con:
            // ∫ c dx = c·x
            return .product([self, .sym(variable)])

        case .sym(let name):
            if name == variable {
                // ∫ x dx = x²/2
                return .product([.num(Rational(1, 2)), .power(.sym(variable), .num(Rational(2)))])
            }
            // A different symbol is constant w.r.t. `variable`.
            return .product([self, .sym(variable)])

        case .add(let terms):
            var parts: [Expr] = []
            for term in terms {
                guard let part = term.integrated(withRespectTo: variable) else { return nil }
                parts.append(part)
            }
            return .sum(parts)

        case .mul(let factors):
            return Expr.integrateProduct(factors, variable)

        case .pow(let base, let exp):
            return Expr.integratePower(base, exp, variable)

        case .fn(let name, let args):
            return Expr.integrateFunction(name, args, variable)
        }
    }

    // MARK: - Products (constant-factor rule only)

    private static func integrateProduct(_ factors: [Expr], _ v: String) -> Expr? {
        let constants = factors.filter { !$0.contains(variable: v) }
        let dependent = factors.filter { $0.contains(variable: v) }

        // Nothing constant to pull out and more than one variable factor ⇒ would
        // need integration by parts, which we don't implement.
        guard !constants.isEmpty else { return nil }

        let constPart = Expr.product(constants)
        if dependent.isEmpty {
            // Whole product is constant ⇒ ∫ c dx = c·x.
            return .product([constPart, .sym(v)])
        }
        guard let restIntegral = Expr.product(dependent).integrated(withRespectTo: v) else {
            return nil
        }
        return .product([constPart, restIntegral])
    }

    // MARK: - Powers

    private static func integratePower(_ base: Expr, _ exp: Expr, _ v: String) -> Expr? {
        // ∫ xⁿ dx with the variable as the base and a constant exponent.
        if base == .sym(v), case .num(let n) = exp {
            if n == .minusOne { return .function("ln", .sym(v)) }
            let np1 = n + .one
            return .product([.num(np1.reciprocal), .power(.sym(v), .num(np1))])
        }

        // ∫ aˣ dx with a constant base and the variable as the exponent.
        if exp == .sym(v), !base.contains(variable: v) {
            if base == .con(.e) { return .power(.con(.e), .sym(v)) }       // ∫ eˣ = eˣ
            return .product([.power(base, .sym(v)),
                             .power(.function("ln", base), .num(.minusOne))])
        }

        // Both base and exponent constant ⇒ the whole power is a constant.
        if !base.contains(variable: v), !exp.contains(variable: v) {
            return .product([.pow(base, exp), .sym(v)])
        }

        // Linear u-substitution: base = a·v + b (a ≠ 0), constant exponent.
        if case .num(let n) = exp,
           let coeffs = base.polynomialCoefficients(in: v), coeffs.count == 2 {
            let slope = coeffs[1]                 // constant by construction
            if n == .minusOne {
                // ∫ 1/(a·v+b) dx = ln(a·v+b) / a
                return .product([.function("ln", base), .power(slope, .num(.minusOne))])
            }
            let np1 = n + .one
            return .product([.num(np1.reciprocal),
                             .power(base, .num(np1)),
                             .power(slope, .num(.minusOne))])
        }

        return nil
    }

    // MARK: - Elementary functions (linear argument only)

    private static func integrateFunction(_ name: String, _ args: [Expr], _ v: String) -> Expr? {
        guard args.count == 1, let arg = args.first else { return nil }

        // f(constant) is itself constant.
        if !arg.contains(variable: v) {
            return .product([.function(name, args), .sym(v)])
        }

        // Require the argument to be linear in v so ∫f(ax+b) dx = F(ax+b)/a.
        guard let coeffs = arg.polynomialCoefficients(in: v), coeffs.count <= 2 else {
            return nil
        }
        let slope: Expr = coeffs.count == 2 ? coeffs[1] : .zero
        guard let outer = outerAntiderivative(name, arg) else { return nil }
        return .product([outer, .power(slope, .num(.minusOne))])
    }

    /// F(u) for a known elementary function f (so that F' = f), or nil if unknown.
    private static func outerAntiderivative(_ name: String, _ u: Expr) -> Expr? {
        switch name {
        case "sin":  return -Expr.function("cos", u)
        case "cos":  return .function("sin", u)
        case "exp":  return .function("exp", u)
        case "sinh": return .function("cosh", u)
        case "cosh": return .function("sinh", u)
        case "tan":  return -Expr.function("ln", .function("cos", u))   // ∫tan = −ln(cos u)
        case "sqrt":                                                     // ∫√u = (2/3)u^{3/2}
            return .product([.num(Rational(2, 3)), .power(u, .num(Rational(3, 2)))])
        case "ln":   return .sum([.product([u, .function("ln", u)]), -u]) // ∫ln u = u·ln u − u
        default:     return nil
        }
    }
}
