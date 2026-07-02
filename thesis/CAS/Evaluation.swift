// Evaluation.swift
// CAS support — numeric (Double) evaluation of a canonical Expr.
//
// Exact rational results come from substitution + `rationalValue`; this is the
// lossy floating-point counterpart used for plotting and for evaluating
// derivatives at a point (e.g. a tangent line's slope). Unknown symbols or the
// imaginary unit yield NaN, matching ExpressionParser's numeric evaluator.

import Foundation

extension Expr {

    /// Evaluates the expression numerically with the given variable bindings.
    /// Returns NaN for unbound symbols, the imaginary unit, or unknown functions.
    public func evaluate(_ bindings: [String: Double]) -> Double {
        switch self {
        case .num(let r):
            return r.doubleValue

        case .con(let c):
            switch c {
            case .pi:       return .pi
            case .e:        return M_E
            case .infinity: return .infinity
            case .i:        return .nan
            }

        case .sym(let name):
            return bindings[name] ?? .nan

        case .add(let terms):
            return terms.reduce(0) { $0 + $1.evaluate(bindings) }

        case .mul(let factors):
            return factors.reduce(1) { $0 * $1.evaluate(bindings) }

        case .pow(let base, let exp):
            return Foundation.pow(base.evaluate(bindings), exp.evaluate(bindings))

        case .fn(let name, let args):
            let a = args.first?.evaluate(bindings) ?? .nan
            switch name {
            case "sin":  return Foundation.sin(a)
            case "cos":  return Foundation.cos(a)
            case "tan":  return Foundation.tan(a)
            case "cot":  return 1 / Foundation.tan(a)
            case "asin": return Foundation.asin(a)
            case "acos": return Foundation.acos(a)
            case "atan": return Foundation.atan(a)
            case "sinh": return Foundation.sinh(a)
            case "cosh": return Foundation.cosh(a)
            case "tanh": return Foundation.tanh(a)
            case "exp":  return Foundation.exp(a)
            case "ln":   return Foundation.log(a)
            case "log":  return Foundation.log10(a)
            case "sqrt": return Foundation.sqrt(a)
            case "abs":  return Swift.abs(a)
            default:     return .nan
            }
        }
    }
}
