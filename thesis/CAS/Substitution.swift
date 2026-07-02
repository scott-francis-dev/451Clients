// Substitution.swift
// CAS Milestone 3 — substitution and structural queries over the canonical Expr.
//
// Substitution replaces a free variable with an arbitrary expression, rebuilding
// the term through the smart constructors so the result comes back already in
// canonical, automatically-simplified form. It is the foundation many other
// operations (evaluation at a point, the chain rule for integration, solving)
// rely on.

import Foundation

extension Expr {

    // MARK: - Substitution

    /// Replaces every occurrence of `variable` with `replacement`, rebuilding
    /// through the smart constructors so the answer is automatically simplified.
    public func substituting(_ variable: String, with replacement: Expr) -> Expr {
        switch self {
        case .num, .con:
            return self

        case .sym(let name):
            return name == variable ? replacement : self

        case .add(let terms):
            return .sum(terms.map { $0.substituting(variable, with: replacement) })

        case .mul(let factors):
            return .product(factors.map { $0.substituting(variable, with: replacement) })

        case .pow(let base, let exp):
            return .power(base.substituting(variable, with: replacement),
                          exp.substituting(variable, with: replacement))

        case .fn(let name, let args):
            return .function(name, args.map { $0.substituting(variable, with: replacement) })
        }
    }

    /// Applies several substitutions at once. All replacements refer to the
    /// original variables (they are not re-substituted into each other).
    public func substituting(_ bindings: [String: Expr]) -> Expr {
        guard !bindings.isEmpty else { return self }
        switch self {
        case .num, .con:
            return self
        case .sym(let name):
            return bindings[name] ?? self
        case .add(let terms):
            return .sum(terms.map { $0.substituting(bindings) })
        case .mul(let factors):
            return .product(factors.map { $0.substituting(bindings) })
        case .pow(let base, let exp):
            return .power(base.substituting(bindings), exp.substituting(bindings))
        case .fn(let name, let args):
            return .function(name, args.map { $0.substituting(bindings) })
        }
    }

    // MARK: - Structural queries

    /// True when `variable` appears anywhere in this expression.
    public func contains(variable: String) -> Bool {
        switch self {
        case .num, .con:
            return false
        case .sym(let name):
            return name == variable
        case .add(let xs), .mul(let xs):
            return xs.contains { $0.contains(variable: variable) }
        case .pow(let base, let exp):
            return base.contains(variable: variable) || exp.contains(variable: variable)
        case .fn(_, let args):
            return args.contains { $0.contains(variable: variable) }
        }
    }

    /// Every free symbol appearing in the expression.
    public var freeVariables: Set<String> {
        switch self {
        case .num, .con:
            return []
        case .sym(let name):
            return [name]
        case .add(let xs), .mul(let xs):
            return xs.reduce(into: Set<String>()) { $0.formUnion($1.freeVariables) }
        case .pow(let base, let exp):
            return base.freeVariables.union(exp.freeVariables)
        case .fn(_, let args):
            return args.reduce(into: Set<String>()) { $0.formUnion($1.freeVariables) }
        }
    }
}
