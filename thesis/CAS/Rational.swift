// Rational.swift
// CAS Layer 0 — exact arbitrary-precision rational numbers.
//
// Every value is stored in lowest terms with a positive denominator, so two
// equal rationals are bit-for-bit identical (Hashable/Equatable mean true
// mathematical equality). All exact arithmetic in the CAS flows through here.
//
// Built on attaswift/BigInt (a pure-Swift package) — no bridging to C/C++.

import Foundation
import BigInt

/// An exact rational number p/q held in canonical form: gcd(|p|, q) == 1 and q > 0.
/// A `denominator` of 1 represents an integer.
public struct Rational: Hashable, Sendable {

    public let numerator: BigInt
    public let denominator: BigInt   // invariant: > 0

    // MARK: Construction

    /// Builds n/d, reduced to lowest terms with a positive denominator.
    public init(_ n: BigInt, _ d: BigInt) {
        precondition(d != 0, "Rational: denominator must be non-zero")
        var num = n
        var den = d
        if den < 0 { num = -num; den = -den }
        let g = Rational.gcd(num, den)
        if g > 1 {
            num /= g
            den /= g
        }
        self.numerator = num
        self.denominator = den
    }

    public init(_ n: BigInt) {
        self.numerator = n
        self.denominator = 1
    }

    public init(_ n: Int) {
        self.init(BigInt(n))
    }

    public init(_ n: Int, _ d: Int) {
        self.init(BigInt(n), BigInt(d))
    }

    // MARK: Constants

    public static let zero = Rational(0)
    public static let one = Rational(1)
    public static let minusOne = Rational(-1)

    // MARK: Predicates

    public var isInteger: Bool { denominator == 1 }
    public var isZero: Bool { numerator == 0 }
    public var isOne: Bool { numerator == 1 && denominator == 1 }
    public var isNegative: Bool { numerator < 0 }

    /// The integer value if this is a whole number, else nil.
    public var integerValue: BigInt? { isInteger ? numerator : nil }

    /// Nearest Double (for numeric fallback / plotting). Lossy by nature.
    public var doubleValue: Double { Double(numerator) / Double(denominator) }

    // MARK: Arithmetic

    public static prefix func - (r: Rational) -> Rational {
        Rational(-r.numerator, r.denominator)
    }

    public static func + (a: Rational, b: Rational) -> Rational {
        Rational(a.numerator * b.denominator + b.numerator * a.denominator,
                 a.denominator * b.denominator)
    }

    public static func - (a: Rational, b: Rational) -> Rational {
        Rational(a.numerator * b.denominator - b.numerator * a.denominator,
                 a.denominator * b.denominator)
    }

    public static func * (a: Rational, b: Rational) -> Rational {
        Rational(a.numerator * b.numerator, a.denominator * b.denominator)
    }

    public static func / (a: Rational, b: Rational) -> Rational {
        precondition(!b.isZero, "Rational: division by zero")
        return Rational(a.numerator * b.denominator, a.denominator * b.numerator)
    }

    /// Multiplicative inverse q/p. Traps on zero.
    public var reciprocal: Rational {
        precondition(!isZero, "Rational: reciprocal of zero")
        return Rational(denominator, numerator)
    }

    /// Exact integer power (negative exponents allowed; traps on 0 ** negative).
    public func raised(to exponent: Int) -> Rational {
        if exponent == 0 { return .one }
        if exponent < 0 { return reciprocal.raised(to: -exponent) }
        let p = Rational.ipow(numerator, exponent)
        let q = Rational.ipow(denominator, exponent)
        return Rational(p, q)
    }

    // MARK: Helpers

    /// Greatest common divisor of the magnitudes (result is non-negative).
    static func gcd(_ a: BigInt, _ b: BigInt) -> BigInt {
        var x = a < 0 ? -a : a
        var y = b < 0 ? -b : b
        while y != 0 {
            let t = x % y
            x = y
            y = t
        }
        return x
    }

    /// Exact integer exponentiation by squaring (exponent >= 0).
    private static func ipow(_ base: BigInt, _ exponent: Int) -> BigInt {
        var result: BigInt = 1
        var b = base
        var e = exponent
        while e > 0 {
            if e & 1 == 1 { result *= b }
            e >>= 1
            if e > 0 { b *= b }
        }
        return result
    }
}

// MARK: - Comparable

extension Rational: Comparable {
    public static func < (a: Rational, b: Rational) -> Bool {
        // Denominators are positive, so cross-multiplication preserves order.
        a.numerator * b.denominator < b.numerator * a.denominator
    }
}

// MARK: - Literals & Description

extension Rational: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension Rational: CustomStringConvertible {
    public var description: String {
        isInteger ? "\(numerator)" : "\(numerator)/\(denominator)"
    }
}
