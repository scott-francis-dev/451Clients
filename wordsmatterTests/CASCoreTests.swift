// CASCoreTests.swift
// Milestone 1 of the CAS: exact rationals, the canonical Expr term with
// automatic simplification, and the MathNode ⇄ Expr bridge.
//
// Note: these tests deliberately use only thesis-module types (Rational, Expr,
// MathNode) and integer literals, so the test target needs no direct BigInt
// dependency — BigInt is an implementation detail of Rational.

import Testing
@testable import thesis

// MARK: - Rational (Layer 0)

@Suite("Rational")
struct RationalTests {

    @Test("reduces to lowest terms")
    func reduces() {
        #expect(Rational(2, 4) == Rational(1, 2))
        #expect(Rational(10, 5) == Rational(2))
        #expect(Rational(6, 3).isInteger)
    }

    @Test("normalizes sign onto the numerator")
    func signNormalization() {
        #expect(Rational(1, -2) == Rational(-1, 2))
        #expect(Rational(-3, -6) == Rational(1, 2))
    }

    @Test("exact arithmetic")
    func arithmetic() {
        #expect(Rational(1, 2) + Rational(1, 3) == Rational(5, 6))
        #expect(Rational(2, 3) - Rational(1, 6) == Rational(1, 2))
        #expect(Rational(2, 3) * Rational(3, 4) == Rational(1, 2))
        #expect(Rational(1, 2) / Rational(1, 4) == Rational(2))
    }

    @Test("integer powers, including negative exponents")
    func powers() {
        #expect(Rational(2, 3).raised(to: 3) == Rational(8, 27))
        #expect(Rational(2, 3).raised(to: -1) == Rational(3, 2))
        #expect(Rational(5).raised(to: 0) == Rational(1))
    }

    @Test("ordering")
    func ordering() {
        #expect(Rational(1, 3) < Rational(1, 2))
        #expect(Rational(-1, 2) < Rational(0))
        #expect(!(Rational(2, 4) < Rational(1, 2)))
    }

    @Test("stays exact well beyond Double's integer range")
    func bigExactArithmetic() {
        let big = Rational(10).raised(to: 30)       // 10^30, far past 2^53
        #expect(big.isInteger)
        #expect(big * Rational(1, 10) == Rational(10).raised(to: 29))
        #expect(big - big == Rational(0))
    }
}

// MARK: - Expr automatic simplification (Layer 1)

@Suite("Expr simplification")
struct ExprSimplificationTests {

    let x = Expr.sym("x")
    let y = Expr.sym("y")
    let z = Expr.sym("z")

    @Test("numeric folding")
    func numericFolding() {
        #expect(Expr.sum([2, 3]) == 5)
        #expect(Expr.product([2, 3, 4]) == 24)
        #expect(Expr.power(2, 3) == 8)
        #expect(Expr.power(Expr.num(Rational(2, 3)), 2) == Expr.num(Rational(4, 9)))
    }

    @Test("additive identities")
    func additiveIdentities() {
        #expect(x + 0 == x)
        #expect(0 + x == x)
        #expect(x - x == 0)
    }

    @Test("multiplicative identities and absorbing zero")
    func multiplicativeIdentities() {
        #expect(1 * x == x)
        #expect(x * 1 == x)
        #expect(0 * x == 0)
        #expect(x * 0 == 0)
    }

    @Test("like terms collect")
    func likeTerms() {
        #expect(x + x == 2 * x)
        #expect(2 * x + 3 * x == 5 * x)
        #expect(x + y - x == y)
    }

    @Test("like factors combine exponents")
    func likeFactors() {
        #expect(x * x == Expr.power(x, 2))
        #expect(Expr.power(x, 2) * Expr.power(x, 3) == Expr.power(x, 5))
        #expect(x / x == 1)
    }

    @Test("commutativity normalizes to one representation")
    func commutativity() {
        #expect(x + y == y + x)
        #expect(x * y == y * x)
        #expect((x + y) + z == x + (y + z))
        #expect((x * y) * z == x * (y * z))
    }

    @Test("power rules")
    func powerRules() {
        #expect(Expr.power(x, 0) == 1)
        #expect(Expr.power(x, 1) == x)
        #expect(Expr.power(1, x) == 1)
        // (x·y)^2 = x^2·y^2
        #expect(Expr.power(x * y, 2) == Expr.power(x, 2) * Expr.power(y, 2))
        // (x^2)^3 = x^6
        #expect(Expr.power(Expr.power(x, 2), 3) == Expr.power(x, 6))
    }

    @Test("negation")
    func negation() {
        #expect(-(-x) == x)
        #expect(x + (-x) == 0)
        // Automatic simplification does NOT distribute: -(x + y) stays factored
        // as -1·(x + y). Expanding to -x - y is the job of a separate `expand`
        // operation (a later milestone), so the two forms are intentionally
        // distinct here.
        #expect(-(x + y) == Expr.product([.num(.minusOne), x + y]))
        #expect(-(x + y) != (-x) + (-y))
    }
}

// MARK: - MathNode ⇄ Expr bridge

@Suite("Expr/MathNode bridge")
struct ExprBridgeTests {

    let x = Expr.sym("x")
    let y = Expr.sym("y")

    @Test("decimals lift to exact rationals")
    func decimalsAreExact() {
        #expect(Expr(MathNode.number(0.5)) == Expr.num(Rational(1, 2)))
        #expect(Expr(MathNode.number(0.1)) == Expr.num(Rational(1, 10)))
        #expect(Expr(MathNode.number(3)) == 3)
        #expect(Expr(MathNode.number(-2.25)) == Expr.num(Rational(-9, 4)))
    }

    @Test("division lowers to a stacked fraction")
    func divisionLowersToFraction() {
        if case .fraction(let n, let d) = (x / y).mathNode {
            #expect(n == .variable("x"))
            #expect(d == .variable("y"))
        } else {
            Issue.record("expected a fraction MathNode")
        }
    }

    @Test("half-power lowers to a square root")
    func halfPowerIsRadical() {
        if case .radical(let degree, let radicand) = Expr.power(x, Expr.num(Rational(1, 2))).mathNode {
            #expect(degree == nil)
            #expect(radicand == .variable("x"))
        } else {
            Issue.record("expected a radical MathNode")
        }
    }

    @Test("subtraction is reconstructed when lowering a sum")
    func subtractionReconstructed() {
        // x + (-3)  →  should render as a subtraction, not "x + -3".
        if case .subtract = (x - 3).mathNode {
            // ok
        } else {
            Issue.record("expected a subtract MathNode")
        }
    }

    @Test("canonical round-trip is stable through MathNode")
    func roundTripStable() {
        let sources = ["x^2 - 3*x + 1/2", "(x + 1)/(x - 1)", "2*x*y + y*x", "sqrt(x) + x^2"]
        for source in sources {
            guard let parsed = ExpressionParser.parseExpression(source) else {
                Issue.record("could not parse \(source)")
                continue
            }
            let e0 = Expr(parsed.mathNode)
            let e1 = Expr(e0.mathNode)        // lower then lift again
            #expect(e0 == e1, "round-trip changed canonical form for \(source)")
        }
    }
}
