// CASCalculusTests.swift
// CAS Milestones 3–5 — substitution, integration, and equation solving.
//
// Integration is checked against differentiation (the trusted inverse): for an
// antiderivative F of f, d/dx F must return f in canonical form. Solving is
// checked structurally and by substituting roots back into the equation, using
// rational/complex roots so no √-simplification (which the engine does not yet
// perform) is required.

import Testing
import Foundation
@testable import thesis

@Suite("Substitution")
struct SubstitutionTests {

    let x = Expr.sym("x")
    let y = Expr.sym("y")

    @Test("substituting a number evaluates a polynomial")
    func numericSubstitution() {
        let p = Expr.power(x, 2) + 1            // x² + 1
        #expect(p.substituting("x", with: .num(Rational(3))) == 10)
    }

    @Test("substituting an expression and re-simplifying")
    func expressionSubstitution() {
        // (x²) with x → y+1 becomes (y+1)², which stays factored as a power.
        let result = Expr.power(x, 2).substituting("x", with: y + 1)
        #expect(result == Expr.power(y + 1, 2))
    }

    @Test("only the named variable is replaced")
    func leavesOthers() {
        let expr = x + y
        #expect(expr.substituting("x", with: .num(Rational(2))) == y + 2)
    }

    @Test("multi-substitution is simultaneous")
    func multiSubstitution() {
        let expr = x * y
        #expect(expr.substituting(["x": .num(Rational(2)), "y": .num(Rational(3))]) == 6)
    }

    @Test("free variables and containment")
    func queries() {
        let expr = x * y + .function("sin", x)
        #expect(expr.freeVariables == ["x", "y"])
        #expect(expr.contains(variable: "x"))
        #expect(!expr.contains(variable: "z"))
    }
}

@Suite("Numeric evaluation")
struct EvaluationTests {

    let x = Expr.sym("x")

    @Test("polynomial evaluates numerically")
    func polynomial() {
        // (x² + 2x − 1) at x = 3  ⇒  14
        let p = Expr.power(x, 2) + 2 * x - 1
        #expect(p.evaluate(["x": 3]) == 14)
    }

    @Test("a derivative can be evaluated at a point (tangent slope)")
    func derivativeAtPoint() {
        // d/dx x² = 2x; slope at x = 3 is 6.
        let slope = Expr.power(x, 2).differentiated(withRespectTo: "x").evaluate(["x": 3])
        #expect(slope == 6)
    }

    @Test("transcendental functions and constants")
    func transcendental() {
        #expect(Expr.function("sin", .con(.pi)).evaluate([:]) == Foundation.sin(Double.pi))
        #expect(Expr.con(.e).evaluate([:]) == M_E)
    }

    @Test("unbound symbols yield NaN")
    func unbound() {
        #expect(x.evaluate([:]).isNaN)
    }
}

@Suite("Integration")
struct IntegrationTests {

    let x = Expr.sym("x")

    /// Asserts that d/dx (∫ f dx) == f.
    private func roundTrips(_ f: Expr, sourceLocation: SourceLocation = #_sourceLocation) {
        let integral = f.integrated(withRespectTo: "x")
        #expect(integral != nil, "expected a closed-form integral", sourceLocation: sourceLocation)
        if let integral {
            #expect(integral.differentiated(withRespectTo: "x") == f, sourceLocation: sourceLocation)
        }
    }

    @Test("power rule")
    func powerRule() {
        // ∫ x² dx = x³/3
        #expect(Expr.power(x, 2).integrated(withRespectTo: "x")
                == Expr.num(Rational(1, 3)) * Expr.power(x, 3))
        roundTrips(Expr.power(x, 2))
        roundTrips(Expr.power(x, 5))
    }

    @Test("∫ 1/x dx = ln x")
    func reciprocal() {
        #expect(Expr.power(x, .num(.minusOne)).integrated(withRespectTo: "x")
                == Expr.function("ln", x))
    }

    @Test("constants and linearity")
    func linearity() {
        // ∫ 5 dx = 5x
        #expect(Expr.num(Rational(5)).integrated(withRespectTo: "x") == 5 * x)
        // ∫ (x² + 3x + 5) dx, verified by differentiation
        roundTrips(Expr.power(x, 2) + 3 * x + 5)
        // ∫ 5x dx = 5x²/2
        roundTrips(5 * x)
    }

    @Test("linear u-substitution for elementary functions")
    func linearSubstitution() {
        roundTrips(.function("sin", 2 * x))      // ∫ sin(2x) dx = −cos(2x)/2
        roundTrips(.function("cos", 3 * x + 1))
        roundTrips(.function("exp", x))
    }

    @Test("powers of a linear argument")
    func linearPower() {
        roundTrips(Expr.power(2 * x + 1, 3))     // ∫ (2x+1)³ dx
        roundTrips(Expr.power(3 * x - 2, .num(.minusOne)))  // ∫ 1/(3x−2) dx = ln(3x−2)/3
    }

    @Test("products needing integration by parts return nil")
    func notIntegrable() {
        #expect((x * .function("sin", x)).integrated(withRespectTo: "x") == nil)
    }
}

@Suite("Expansion")
struct ExpansionTests {

    let x = Expr.sym("x")
    let y = Expr.sym("y")

    @Test("distributing a product over a sum")
    func distribute() {
        // x·(x + 2) = x² + 2x
        #expect((x * (x + 2)).expanded() == Expr.power(x, 2) + 2 * x)
    }

    @Test("product of two binomials")
    func binomials() {
        // (x + 1)(x − 1) = x² − 1
        #expect(((x + 1) * (x - 1)).expanded() == Expr.power(x, 2) - 1)
    }

    @Test("integer power of a sum")
    func powerOfSum() {
        // (x + 1)² = x² + 2x + 1
        #expect(Expr.power(x + 1, 2).expanded() == Expr.power(x, 2) + 2 * x + 1)
        // (x + y)² = x² + 2xy + y²
        #expect(Expr.power(x + y, 2).expanded()
                == Expr.power(x, 2) + 2 * x * y + Expr.power(y, 2))
    }
}

@Suite("Factoring")
struct FactoringTests {

    let x = Expr.sym("x")

    /// Factoring is verified by expanding the result back to the original.
    private func factorsBackTo(_ p: Expr, sourceLocation: SourceLocation = #_sourceLocation) {
        let factored = p.factored(in: "x")
        #expect(factored != nil, "expected a rational factorization", sourceLocation: sourceLocation)
        if let factored {
            #expect(factored.expanded() == p, sourceLocation: sourceLocation)
        }
    }

    @Test("quadratic with distinct rational roots")
    func distinctRoots() {
        // x² − 5x + 6 = (x − 2)(x − 3)
        let p = Expr.power(x, 2) - 5 * x + 6
        #expect(p.factored(in: "x") == (x - 2) * (x - 3))
        factorsBackTo(p)
    }

    @Test("perfect square trinomial")
    func repeatedRoot() {
        // x² − 2x + 1 = (x − 1)²
        let p = Expr.power(x, 2) - 2 * x + 1
        #expect(p.factored(in: "x") == Expr.power(x - 1, 2))
        factorsBackTo(p)
    }

    @Test("leading coefficient and content")
    func leadingCoefficient() {
        // 2x² − 2 = 2(x − 1)(x + 1)
        factorsBackTo(2 * Expr.power(x, 2) - 2)
    }

    @Test("irreducible over the rationals returns nil")
    func irreducible() {
        // x² − 2 has irrational roots; x² + 1 has complex roots.
        #expect((Expr.power(x, 2) - 2).factored(in: "x") == nil)
        #expect((Expr.power(x, 2) + 1).factored(in: "x") == nil)
    }
}

@Suite("Solving")
struct SolvingTests {

    let x = Expr.sym("x")

    @Test("linear equation")
    func linear() {
        // 2x − 4 = 0  ⇒  x = 2
        let roots = (2 * x - 4).solved(for: "x")
        #expect(roots == [Expr.num(Rational(2))])
    }

    @Test("quadratic with rational roots")
    func rationalQuadratic() {
        // x² − 5x + 6 = 0  ⇒  {2, 3}
        let eq = Expr.power(x, 2) - 5 * x + 6
        let roots = eq.solved(for: "x")
        #expect(Set(roots ?? []) == [Expr.num(Rational(2)), Expr.num(Rational(3))])
        // Each root satisfies the equation exactly.
        for r in roots ?? [] {
            #expect(eq.substituting("x", with: r) == 0)
        }
    }

    @Test("repeated root")
    func repeatedRoot() {
        // x² − 2x + 1 = 0  ⇒  x = 1 (once)
        let roots = (Expr.power(x, 2) - 2 * x + 1).solved(for: "x")
        #expect(roots == [Expr.num(Rational(1))])
    }

    @Test("complex roots use the imaginary unit")
    func complexRoots() {
        // x² + 1 = 0  ⇒  ±i
        let roots = (Expr.power(x, 2) + 1).solved(for: "x")
        #expect(Set(roots ?? []) == [.con(.i), -Expr.con(.i)])
    }

    @Test("degree ≥ 3 is unsupported")
    func cubicUnsupported() {
        #expect((Expr.power(x, 3) - x).solved(for: "x") == nil)
    }

    @Test("nonzero constant has no solution")
    func noSolution() {
        #expect(Expr.num(Rational(5)).solved(for: "x") == [])
    }
}
