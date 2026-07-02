// CASDifferentiationTests.swift
// CAS Milestone 2 — symbolic differentiation. Results are checked against
// canonical Expr values built with the operators, so structural ordering is
// handled by the engine's normalization.

import Testing
@testable import thesis

@Suite("Differentiation")
struct DifferentiationTests {

    let x = Expr.sym("x")
    let y = Expr.sym("y")

    private func sin(_ u: Expr) -> Expr { .function("sin", u) }
    private func cos(_ u: Expr) -> Expr { .function("cos", u) }

    // MARK: Atoms

    @Test("constants and independent variables differentiate to zero")
    func zeros() {
        #expect(Expr.num(5).differentiated(withRespectTo: "x") == 0)
        #expect(Expr.con(.pi).differentiated(withRespectTo: "x") == 0)
        #expect(y.differentiated(withRespectTo: "x") == 0)
    }

    @Test("d/dx x = 1")
    func variable() {
        #expect(x.differentiated(withRespectTo: "x") == 1)
    }

    // MARK: Power rule

    @Test("power rule")
    func powerRule() {
        #expect(Expr.power(x, 2).differentiated(withRespectTo: "x") == 2 * x)
        #expect(Expr.power(x, 3).differentiated(withRespectTo: "x") == 3 * Expr.power(x, 2))
        // d/dx (1/x) = -1/x²
        #expect(Expr.power(x, .num(.minusOne)).differentiated(withRespectTo: "x")
                == -Expr.power(x, .num(Rational(-2))))
    }

    @Test("polynomial, by the sum rule")
    func polynomial() {
        let p = Expr.power(x, 2) + 3 * x + 5
        #expect(p.differentiated(withRespectTo: "x") == 2 * x + 3)
    }

    @Test("second derivative")
    func secondDerivative() {
        let d2 = Expr.power(x, 3)
            .differentiated(withRespectTo: "x")
            .differentiated(withRespectTo: "x")
        #expect(d2 == 6 * x)
    }

    // MARK: Product & chain rules

    @Test("product rule")
    func productRule() {
        let expr = x * sin(x)
        #expect(expr.differentiated(withRespectTo: "x") == sin(x) + x * cos(x))
    }

    @Test("chain rule")
    func chainRule() {
        // d/dx sin(x²) = 2x·cos(x²)
        #expect(sin(Expr.power(x, 2)).differentiated(withRespectTo: "x")
                == 2 * x * cos(Expr.power(x, 2)))
        // d/dx sin(3x) = 3·cos(3x)
        #expect(sin(3 * x).differentiated(withRespectTo: "x") == 3 * cos(3 * x))
    }

    // MARK: Transcendental table

    @Test("exp and ln")
    func expAndLog() {
        #expect(Expr.function("exp", x).differentiated(withRespectTo: "x") == Expr.function("exp", x))
        #expect(Expr.function("ln", x).differentiated(withRespectTo: "x") == Expr.power(x, .num(.minusOne)))
    }

    @Test("trig derivatives")
    func trig() {
        #expect(sin(x).differentiated(withRespectTo: "x") == cos(x))
        #expect(cos(x).differentiated(withRespectTo: "x") == -sin(x))
    }

    @Test("sqrt and atan")
    func rootsAndInverse() {
        #expect(Expr.function("sqrt", x).differentiated(withRespectTo: "x")
                == Expr.num(Rational(1, 2)) * Expr.power(x, .num(Rational(-1, 2))))
        #expect(Expr.function("atan", x).differentiated(withRespectTo: "x")
                == Expr.power(.one + Expr.power(x, 2), .num(.minusOne)))
    }

    // MARK: Fallback

    @Test("unknown functions yield a formal derivative")
    func formalFallback() {
        let foo = Expr.function("foo", x)
        #expect(foo.differentiated(withRespectTo: "x")
                == Expr.function("$deriv", [foo, .sym("x")]))
    }
}
