// MathLayout.swift
// 2D math typesetting engine for Thesis.
//
// Architecture:
//   MathNode  →  layout()  →  MathBox  →  MathView (SwiftUI Canvas)
//
// Each MathBox knows its width, ascent (above baseline), and descent (below
// baseline), plus a DrawCommand tree that records everything to draw.
// Coordinates in DrawCommand are absolute Canvas coords: origin top-left, y↓.
//
// Text is measured using UIFont/NSFont for exact platform metrics.
// Drawing uses SwiftUI Canvas so the renderer is pure Swift with no WebView.

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Style

/// Math typesetting style — mirrors TeX's \displaystyle / \textstyle / \scriptstyle.
public enum MathStyle: Sendable {
    case display      // standalone block equation, large operators
    case text         // inline within prose
    case script       // superscripts / subscripts
    case scriptscript // scripts of scripts

    var scriptScale: CGFloat {
        switch self {
        case .display, .text:   return 0.72
        case .script:           return 0.72
        case .scriptscript:     return 0.72  // don't go smaller than script
        }
    }

    var childStyle: MathStyle {
        switch self {
        case .display, .text: return .script
        case .script, .scriptscript: return .scriptscript
        }
    }

    var isDisplay: Bool { self == .display }
}

// MARK: - Layout Environment

struct MathEnv {
    let fontSize: CGFloat
    let style: MathStyle

    /// Environment for scripts / sub- and superscripts.
    var script: MathEnv {
        MathEnv(fontSize: fontSize * style.scriptScale, style: style.childStyle)
    }

    // TeX-derived constants (in points relative to fontSize)
    var axisHeight:      CGFloat { fontSize * 0.22 }
    var ruleThickness:   CGFloat { max(0.5, fontSize * 0.05) }
    var numGap:          CGFloat { fontSize * 0.10 }
    var denGap:          CGFloat { fontSize * 0.10 }
    var radicalClearance:CGFloat { fontSize * 0.08 }
    var supShift:        CGFloat { fontSize * 0.42 }   // baseline of sup above base baseline
    var subShift:        CGFloat { fontSize * 0.18 }   // baseline of sub below base baseline
    var bigopSize:       CGFloat { style.isDisplay ? fontSize * 1.8 : fontSize }
    var scriptHorizGap:  CGFloat { fontSize * 0.02 }
}

// MARK: - Platform Font Metrics

/// Returns (ascent, descent) above and below the baseline for the given font size.
private func fontMetrics(size: CGFloat, italic: Bool = false) -> (ascent: CGFloat, descent: CGFloat) {
#if canImport(UIKit)
    let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
    let serif = base.withDesign(.serif) ?? base
    var traits = serif.symbolicTraits
    if italic { traits.insert(.traitItalic) }
    let desc = serif.withSymbolicTraits(traits) ?? serif
    let font = UIFont(descriptor: desc, size: size)
    return (font.ascender, abs(font.descender))
#elseif canImport(AppKit)
    let font = NSFont.systemFont(ofSize: size)
    return (font.ascender, abs(font.descender))
#endif
}

/// Returns the bounding CGSize for a string at a given font size.
private func measureString(_ s: String, size: CGFloat, italic: Bool = false, bold: Bool = false) -> CGSize {
#if canImport(UIKit)
    let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
    let serif = base.withDesign(.serif) ?? base
    var traits = serif.symbolicTraits
    if italic { traits.insert(.traitItalic) }
    if bold   { traits.insert(.traitBold)   }
    let desc = serif.withSymbolicTraits(traits) ?? serif
    let font = UIFont(descriptor: desc, size: size)
    return (s as NSString).size(withAttributes: [.font: font])
#elseif canImport(AppKit)
    var font = NSFont.systemFont(ofSize: size)
    let traits: NSFontDescriptor.SymbolicTraits = bold ? .bold : []
    let desc = font.fontDescriptor.withSymbolicTraits(traits)
    font = NSFont(descriptor: desc, size: size) ?? font
    return (s as NSString).size(withAttributes: [.font: font])
#endif
}

// MARK: - Draw Commands

/// Value-type draw list. All positions are in Canvas coordinates (y↓).
/// Baseline of a box sits at y = box.ascent from the top of its allocated rect.
indirect enum DrawCommand: Sendable {
    /// String drawn with its baseline-left at `pt`.
    case text(String, CGFloat, Bool, Bool, CGPoint)      // str, fontSize, italic, bold, pt

    /// Single Unicode character at `pt`, typically for symbols/operators.
    case symbol(String, CGFloat, CGPoint)                // char, fontSize, pt

    /// Horizontal rule: from (x1,y) to (x2,y) at given thickness.
    case hline(x1: CGFloat, x2: CGFloat, y: CGFloat, thickness: CGFloat)

    /// Arbitrary SwiftUI Path at given stroke width.
    case path(Path, CGFloat)

    /// Grouped commands (no transform).
    case group([DrawCommand])
}

private func translate(_ cmd: DrawCommand, dx: CGFloat, dy: CGFloat) -> DrawCommand {
    guard dx != 0 || dy != 0 else { return cmd }
    switch cmd {
    case .text(let s, let sz, let it, let b, let pt):
        return .text(s, sz, it, b, CGPoint(x: pt.x + dx, y: pt.y + dy))
    case .symbol(let s, let sz, let pt):
        return .symbol(s, sz, CGPoint(x: pt.x + dx, y: pt.y + dy))
    case .hline(let x1, let x2, let y, let t):
        return .hline(x1: x1 + dx, x2: x2 + dx, y: y + dy, thickness: t)
    case .path(let p, let sw):
        return .path(p.applying(CGAffineTransform(translationX: dx, y: dy)), sw)
    case .group(let cmds):
        return .group(cmds.map { translate($0, dx: dx, dy: dy) })
    }
}

// MARK: - Math Box

/// A fully laid-out math expression: dimensions + draw tree.
struct MathBox {
    let width:   CGFloat   // total width
    let ascent:  CGFloat   // height above baseline
    let descent: CGFloat   // depth below baseline
    let cmd:     DrawCommand

    var height: CGFloat { ascent + descent }

    /// Returns a copy of this box translated by (dx, dy) in Canvas coords.
    func moved(dx: CGFloat, dy: CGFloat) -> MathBox {
        MathBox(width: width, ascent: ascent, descent: descent,
                cmd: translate(cmd, dx: dx, dy: dy))
    }
}

// MARK: - Rendering DrawCommand → Canvas

func renderDrawCommand(_ cmd: DrawCommand, context: inout GraphicsContext) {
    switch cmd {

    case .text(let s, let sz, let italic, let bold, let pt):
        var t = Text(s).font(.system(size: sz, design: .serif))
        if italic { t = t.italic() }
        if bold   { t = t.bold()   }
        // .bottomLeading ≈ baseline-left for ascender-only glyphs
        context.draw(t, at: pt, anchor: .bottomLeading)

    case .symbol(let s, let sz, let pt):
        let t = Text(s).font(.system(size: sz))
        context.draw(t, at: pt, anchor: .bottomLeading)

    case .hline(let x1, let x2, let y, let t):
        var p = Path()
        p.move(to: CGPoint(x: x1, y: y))
        p.addLine(to: CGPoint(x: x2, y: y))
        context.stroke(p, with: .foreground, lineWidth: t)

    case .path(let p, let sw):
        context.stroke(p, with: .foreground, lineWidth: sw)

    case .group(let cmds):
        for c in cmds { renderDrawCommand(c, context: &context) }
    }
}

// MARK: - Layout Functions

/// Entry point: lay out a MathNode in the given environment.
func layoutMathNode(_ node: MathNode, env: MathEnv) -> MathBox {
    switch node {

    // ── Atoms ────────────────────────────────────────────────────────────────

    case .number(let v):
        let s = formatNumber(v)
        let sz = measureString(s, size: env.fontSize)
        let (asc, des) = fontMetrics(size: env.fontSize)
        return MathBox(width: sz.width, ascent: asc, descent: des,
                       cmd: .text(s, env.fontSize, false, false,
                                  CGPoint(x: 0, y: asc)))

    case .variable(let name):
        let sz = measureString(name, size: env.fontSize, italic: true)
        let (asc, des) = fontMetrics(size: env.fontSize, italic: true)
        return MathBox(width: sz.width, ascent: asc, descent: des,
                       cmd: .text(name, env.fontSize, true, false,
                                  CGPoint(x: 0, y: asc)))

    case .symbol(let sym):
        return layoutAtom(sym.rawValue, env: env)

    case .text(let s):
        let sz = measureString(s, size: env.fontSize)
        let (asc, des) = fontMetrics(size: env.fontSize)
        return MathBox(width: sz.width, ascent: asc, descent: des,
                       cmd: .text(s, env.fontSize, false, false,
                                  CGPoint(x: 0, y: asc)))

    case .placeholder:
        let side = env.fontSize * 0.8
        let (asc, _) = fontMetrics(size: env.fontSize)
        var p = Path(roundedRect: CGRect(x: 1, y: asc - side, width: side - 2, height: side),
                     cornerRadius: 3)
        return MathBox(width: side, ascent: asc, descent: 0,
                       cmd: .path(p, 1))

    // ── Arithmetic ───────────────────────────────────────────────────────────

    case .add(let l, let r):
        return layoutInfix(l, "+", r, env: env)

    case .subtract(let l, let r):
        return layoutInfix(l, "−", r, env: env)

    case .multiply(let l, let r):
        // Implicit multiplication: juxtapose without symbol
        return layoutHStack([layoutMathNode(l, env: env),
                              layoutMathNode(r, env: env)], spacing: 0)

    case .divide(let l, let r):
        return layoutInfix(l, "/", r, env: env)

    case .negate(let n):
        let inner = layoutMathNode(n, env: env)
        let minus = layoutAtom("−", env: env)
        return layoutHStack([minus, inner], spacing: 0)

    case .apply(let name, let arg):
        let nameSz = measureString(name, size: env.fontSize)
        let (asc, des) = fontMetrics(size: env.fontSize)
        let nameBox = MathBox(width: nameSz.width, ascent: asc, descent: des,
                              cmd: .text(name, env.fontSize, false, false,
                                         CGPoint(x: 0, y: asc)))
        let argBox = layoutMathNode(arg, env: env)
        // Wrap arg in parens
        let wrapped = layoutBracketed(.paren, argBox, env: env)
        return layoutHStack([nameBox, wrapped], spacing: 1)

    // ── 2D Structure ─────────────────────────────────────────────────────────

    case .fraction(let num, let den):
        return layoutFraction(layoutMathNode(num, env: env),
                              layoutMathNode(den, env: env),
                              env: env)

    case .power(let base, let exp):
        let baseBox = layoutMathNode(base, env: env)
        let expBox  = layoutMathNode(exp, env: env.script)
        return layoutSuper(base: baseBox, sup: expBox, env: env)

    case .sub(let base, let idx):
        let baseBox = layoutMathNode(base, env: env)
        let idxBox  = layoutMathNode(idx, env: env.script)
        return layoutSub(base: baseBox, sub: idxBox, env: env)

    case .subsup(let base, let s, let p):
        let baseBox = layoutMathNode(base, env: env)
        let subBox  = layoutMathNode(s, env: env.script)
        let supBox  = layoutMathNode(p, env: env.script)
        return layoutSubSup(base: baseBox, sub: subBox, sup: supBox, env: env)

    case .radical(let degree, let body):
        let bodyBox   = layoutMathNode(body, env: env)
        let degreeBox = degree.map { layoutMathNode($0, env: env.script) }
        return layoutRadical(degree: degreeBox, body: bodyBox, env: env)

    // ── Big Operators ────────────────────────────────────────────────────────

    case .bigop(let op, let lower, let upper, let body):
        let opBox    = layoutAtom(op.character, env: MathEnv(fontSize: env.bigopSize, style: env.style))
        let lowerBox = layoutMathNode(lower, env: env.script)
        let upperBox = layoutMathNode(upper, env: env.script)
        let bodyBox  = layoutMathNode(body, env: env)
        return layoutBigOp(op: opBox, lower: lowerBox, upper: upperBox,
                           body: bodyBox, env: env)

    // ── Accents ──────────────────────────────────────────────────────────────

    case .accent(let acc, let inner):
        let innerBox = layoutMathNode(inner, env: env)
        return layoutAccent(acc, over: innerBox, env: env)

    // ── Containers ───────────────────────────────────────────────────────────

    case .group(let nodes):
        let boxes = nodes.map { layoutMathNode($0, env: env) }
        return layoutHStack(boxes, spacing: env.fontSize * 0.05)

    case .matrix(let rows):
        return layoutMatrix(rows, env: env)

    case .cases(let pairs):
        return layoutCases(pairs, env: env)

    case .bracketed(let kind, let inner):
        let innerBox = layoutMathNode(inner, env: env)
        return layoutBracketed(kind, innerBox, env: env)
    }
}

// MARK: - Atom

private func layoutAtom(_ char: String, env: MathEnv) -> MathBox {
    let sz = measureString(char, size: env.fontSize)
    let (asc, des) = fontMetrics(size: env.fontSize)
    return MathBox(width: sz.width, ascent: asc, descent: des,
                   cmd: .symbol(char, env.fontSize,
                                CGPoint(x: 0, y: asc)))
}

// MARK: - HStack

private func layoutHStack(_ boxes: [MathBox], spacing: CGFloat) -> MathBox {
    guard !boxes.isEmpty else {
        return MathBox(width: 0, ascent: 0, descent: 0, cmd: .group([]))
    }
    var cmds: [DrawCommand] = []
    var x: CGFloat = 0
    var maxAscent:  CGFloat = 0
    var maxDescent: CGFloat = 0
    for box in boxes {
        maxAscent  = max(maxAscent,  box.ascent)
        maxDescent = max(maxDescent, box.descent)
    }
    // Re-translate each box so baselines align
    for box in boxes {
        let dy = maxAscent - box.ascent   // shift box down so its baseline matches
        cmds.append(translate(box.cmd, dx: x, dy: dy))
        x += box.width + spacing
    }
    let totalWidth = x - (boxes.isEmpty ? 0 : spacing)
    return MathBox(width: totalWidth, ascent: maxAscent, descent: maxDescent,
                   cmd: .group(cmds))
}

// MARK: - Infix operator

private func layoutInfix(_ l: MathNode, _ op: String, _ r: MathNode, env: MathEnv) -> MathBox {
    let lBox  = layoutMathNode(l, env: env)
    let opSz  = measureString(op, size: env.fontSize)
    let (asc, des) = fontMetrics(size: env.fontSize)
    let pad: CGFloat = env.fontSize * 0.18
    let opBox = MathBox(width: opSz.width + pad * 2, ascent: asc, descent: des,
                        cmd: .text(op, env.fontSize, false, false,
                                   CGPoint(x: pad, y: asc)))
    let rBox  = layoutMathNode(r, env: env)
    return layoutHStack([lBox, opBox, rBox], spacing: 0)
}

// MARK: - Fraction

private func layoutFraction(_ num: MathBox, _ den: MathBox, env: MathEnv) -> MathBox {
    let pad     = env.fontSize * 0.1
    let width   = max(num.width, den.width) + pad * 2
    let rule    = env.ruleThickness
    let numGap  = env.numGap
    let denGap  = env.denGap

    // The fraction's baseline IS the math axis.
    // ascent  = rule/2 + numGap + num.height
    // descent = rule/2 + denGap + den.height
    let ascent  = rule / 2 + numGap + num.height
    let descent = rule / 2 + denGap + den.height

    // Canvas y of baseline (= math axis) = ascent
    let axisY = ascent

    // Numerator: its bottom (baseline + descent) sits at axisY - rule/2 - numGap
    let numBaseY = axisY - rule / 2 - numGap - num.descent
    let numX = (width - num.width) / 2

    // Denominator: its top sits at axisY + rule/2 + denGap
    let denBaseY = axisY + rule / 2 + denGap + den.ascent
    let denX = (width - den.width) / 2

    let cmd = DrawCommand.group([
        translate(num.cmd, dx: numX, dy: numBaseY - num.ascent),
        .hline(x1: 0, x2: width, y: axisY, thickness: rule),
        translate(den.cmd, dx: denX, dy: denBaseY - den.ascent)
    ])

    return MathBox(width: width, ascent: ascent, descent: descent, cmd: cmd)
}

// MARK: - Superscript / Subscript

private func layoutSuper(base: MathBox, sup: MathBox, env: MathEnv) -> MathBox {
    let supRaise = max(env.supShift, base.ascent * 0.6)
    let gap = env.scriptHorizGap

    // sup baseline canvas y = (combined baseline) - supRaise
    // Combined baseline canvas y = ascent
    let ascent  = max(base.ascent, supRaise + sup.ascent)
    let descent = base.descent
    let width   = base.width + gap + sup.width

    let baseShift = ascent - base.ascent
    let supBaseY  = ascent - supRaise

    let cmd = DrawCommand.group([
        translate(base.cmd, dx: 0,             dy: baseShift),
        translate(sup.cmd,  dx: base.width + gap, dy: supBaseY - sup.ascent)
    ])
    return MathBox(width: width, ascent: ascent, descent: descent, cmd: cmd)
}

private func layoutSub(base: MathBox, sub: MathBox, env: MathEnv) -> MathBox {
    let subDrop = max(env.subShift, base.descent * 0.8 + sub.ascent * 0.3)
    let gap = env.scriptHorizGap

    let ascent  = base.ascent
    let descent = max(base.descent, subDrop + sub.descent)
    let width   = base.width + gap + sub.width

    // base draws with its baseline at y = ascent
    // sub baseline at y = ascent + subDrop
    let cmd = DrawCommand.group([
        base.cmd,
        translate(sub.cmd, dx: base.width + gap,
                  dy: (ascent + subDrop) - sub.ascent)
    ])
    return MathBox(width: width, ascent: ascent, descent: descent, cmd: cmd)
}

private func layoutSubSup(base: MathBox, sub: MathBox, sup: MathBox, env: MathEnv) -> MathBox {
    let supRaise = max(env.supShift, base.ascent * 0.6)
    let subDrop  = max(env.subShift, base.descent * 0.8)
    let gap = env.scriptHorizGap

    let scriptWidth = max(sub.width, sup.width)
    let ascent  = max(base.ascent,  supRaise + sup.ascent)
    let descent = max(base.descent, subDrop  + sub.descent)
    let width   = base.width + gap + scriptWidth

    let baseShift = ascent - base.ascent
    let supBaseY  = ascent - supRaise
    let subBaseY  = ascent + subDrop

    let cmd = DrawCommand.group([
        translate(base.cmd, dx: 0,             dy: baseShift),
        translate(sup.cmd,  dx: base.width + gap, dy: supBaseY - sup.ascent),
        translate(sub.cmd,  dx: base.width + gap, dy: subBaseY - sub.ascent)
    ])
    return MathBox(width: width, ascent: ascent, descent: descent, cmd: cmd)
}

// MARK: - Radical

private func layoutRadical(degree: MathBox?, body: MathBox, env: MathEnv) -> MathBox {
    let clearance = env.radicalClearance
    let rule      = env.ruleThickness

    // Total inner height (body + clearance above + rule)
    let innerH = body.height + clearance + rule

    // The surd is drawn as a Path scaled to innerH.
    // Geometry:
    //   surdW  = width of the left curved part
    //   tick   = small downward notch at the bottom
    let surdW: CGFloat = innerH * 0.45
    let tick:  CGFloat = innerH * 0.2

    // Build the radical path.
    // (0, ascent)              is the baseline of the whole box.
    // The bar sits at canvas y = rule/2 (top of box).
    // Body top at canvas y = rule.
    // Body baseline at canvas y = rule + clearance + body.ascent.

    let boxAscent  = body.ascent + clearance + rule
    let boxDescent = body.descent

    // Path points (in box-local coordinates, y↓):
    //  A: bottom-left of surd tick         (0,           boxAscent + tick * 0.4)
    //  B: bottom of surd notch             (surdW * 0.35, boxAscent + tick)
    //  C: top of surd stroke               (surdW,        rule * 0.5)
    //  D: end of overline                  (surdW + body.width + 2, rule * 0.5)

    let bodyOffsetX = surdW + 2
    let totalWidth  = bodyOffsetX + body.width + 2

    var surdPath = Path()
    surdPath.move(to:    CGPoint(x: 0,           y: boxAscent + tick * 0.3))
    surdPath.addLine(to: CGPoint(x: surdW * 0.3, y: boxAscent + tick))
    surdPath.addLine(to: CGPoint(x: surdW,       y: rule * 0.5))
    surdPath.addLine(to: CGPoint(x: totalWidth,  y: rule * 0.5))

    // Body sits with its top at canvas y = rule + clearance, baseline at boxAscent
    let bodyDY = (rule + clearance + body.ascent) - body.ascent   // = rule + clearance
    let bodyCmd = translate(body.cmd, dx: bodyOffsetX, dy: bodyDY)

    var cmds: [DrawCommand] = [.path(surdPath, rule), bodyCmd]

    // Degree (small index above surd, e.g. "3" for cube root)
    if let deg = degree {
        let degX = max(0, surdW * 0.2 - deg.width)
        let degY = rule - deg.descent - env.fontSize * 0.05
        cmds.append(translate(deg.cmd, dx: degX, dy: degY - deg.ascent))
    }

    return MathBox(width: totalWidth, ascent: boxAscent, descent: boxDescent,
                   cmd: .group(cmds))
}

// MARK: - Big Operator (∑, ∫, ∏, …)

private func layoutBigOp(op: MathBox, lower: MathBox, upper: MathBox,
                         body: MathBox, env: MathEnv) -> MathBox {
    if env.style.isDisplay {
        // Display: limits stacked above/below operator
        let gap: CGFloat = env.fontSize * 0.04
        let colWidth = max(op.width, lower.width, upper.width)

        let upperX = (colWidth - upper.width) / 2
        let opX    = (colWidth - op.width)    / 2
        let lowerX = (colWidth - lower.width) / 2

        // Stack: upper, gap, op, gap, lower
        let ascent  = upper.height + gap + op.ascent
        let descent = op.descent + gap + lower.height

        let upperBaseY = upper.ascent                        // at canvas top
        let opBaseY    = upper.height + gap + op.ascent      // = ascent
        let lowerBaseY = ascent + op.descent + gap + lower.ascent

        // Body to the right of the column, baseline-aligned with op
        let bodyX = colWidth + env.fontSize * 0.12
        let bodyBaseY = ascent   // same baseline as op

        let combined = MathBox(
            width: colWidth + env.fontSize * 0.12 + body.width,
            ascent: max(ascent, bodyBaseY - body.ascent + body.ascent),
            descent: max(descent, body.descent),
            cmd: .group([
                translate(upper.cmd, dx: upperX, dy: upperBaseY - upper.ascent),
                translate(op.cmd,    dx: opX,    dy: opBaseY    - op.ascent),
                translate(lower.cmd, dx: lowerX, dy: lowerBaseY - lower.ascent),
                translate(body.cmd,  dx: bodyX,  dy: bodyBaseY  - body.ascent)
            ])
        )
        return combined

    } else {
        // Inline: limits as sub/superscript on the operator
        return layoutSubSup(base: op, sub: lower, sup: upper, env: env)
            .then { opWithScripts in
                layoutHStack([opWithScripts, body], spacing: env.fontSize * 0.1)
            }
    }
}

// MARK: - Accents

private func layoutAccent(_ accent: MathAccent, over inner: MathBox, env: MathEnv) -> MathBox {
    let clearance: CGFloat = env.fontSize * 0.04
    let rule = env.ruleThickness

    // Most accents sit slightly above the inner box
    let accentY = -(clearance)   // above inner's ascent
    let accentH = env.fontSize * 0.15

    var accentCmd: DrawCommand
    switch accent {
    case .bar, .widehat:
        // Overline: a horizontal rule
        accentCmd = .hline(x1: 0, x2: inner.width, y: -clearance, thickness: rule)
    case .vec:
        // Arrow: a rightward arrow over the expression
        let arrowChar = "→"
        let sz = measureString(arrowChar, size: env.fontSize * 0.7)
        let arrowX = (inner.width - sz.width) / 2
        accentCmd = .symbol(arrowChar, env.fontSize * 0.7,
                            CGPoint(x: arrowX, y: -clearance))
    case .hat, .check:
        let char: String
        switch accent {
        case .hat:   char = "^"
        case .check: char = "ˇ"
        default:     char = "˘"
        }
        let sz = measureString(char, size: env.fontSize * 0.8)
        accentCmd = .symbol(char, env.fontSize * 0.8,
                            CGPoint(x: (inner.width - sz.width) / 2, y: -clearance))
    case .tilde, .widetilde:
        let sz = measureString("~", size: env.fontSize * 0.8)
        accentCmd = .symbol("~", env.fontSize * 0.8,
                            CGPoint(x: (inner.width - sz.width) / 2, y: -clearance))
    case .dot:
        let r: CGFloat = rule * 1.5
        var p = Path()
        p.addEllipse(in: CGRect(x: inner.width / 2 - r, y: -clearance - r * 2,
                                width: r * 2, height: r * 2))
        accentCmd = .path(p, 0)    // fill via stroke with 0 width: use filled path
    case .ddot:
        let r: CGFloat = rule * 1.5
        let spacing = inner.width * 0.25
        var p = Path()
        p.addEllipse(in: CGRect(x: inner.width / 2 - spacing - r, y: -clearance - r * 2,
                                width: r * 2, height: r * 2))
        p.addEllipse(in: CGRect(x: inner.width / 2 + spacing - r, y: -clearance - r * 2,
                                width: r * 2, height: r * 2))
        accentCmd = .path(p, 0)
    }

    let extraAscent = accentH + clearance
    // Translate inner box down slightly and add accent above it
    let cmd = DrawCommand.group([
        translate(accentCmd, dx: 0, dy: inner.ascent),  // accent above inner
        inner.cmd                                         // inner at its natural position
    ])
    return MathBox(width: inner.width,
                   ascent: inner.ascent + extraAscent,
                   descent: inner.descent,
                   cmd: cmd)
}

// MARK: - Brackets (auto-sizing)

private func layoutBracketed(_ kind: MathBracketKind, _ inner: MathBox,
                              env: MathEnv) -> MathBox {
    // Scale bracket characters to match inner height
    let targetH = inner.height * 1.1
    let bracketFontSize = max(env.fontSize, targetH * 0.9)
    let (bAsc, bDes) = fontMetrics(size: bracketFontSize)

    func makeBracket(_ char: String) -> MathBox {
        let sz = measureString(char, size: bracketFontSize)
        return MathBox(width: sz.width, ascent: bAsc, descent: bDes,
                       cmd: .symbol(char, bracketFontSize,
                                    CGPoint(x: 0, y: bAsc)))
    }

    let open  = makeBracket(kind.open)
    let close = makeBracket(kind.close)
    // Baseline: align brackets and inner to a common baseline
    let ascent  = max(open.ascent,  inner.ascent,  close.ascent)
    let descent = max(open.descent, inner.descent, close.descent)

    let openCmd  = translate(open.cmd,  dx: 0,                             dy: ascent - open.ascent)
    let innerCmd = translate(inner.cmd, dx: open.width,                    dy: ascent - inner.ascent)
    let closeCmd = translate(close.cmd, dx: open.width + inner.width,      dy: ascent - close.ascent)

    return MathBox(width: open.width + inner.width + close.width,
                   ascent: ascent, descent: descent,
                   cmd: .group([openCmd, innerCmd, closeCmd]))
}

// MARK: - Matrix

private func layoutMatrix(_ rows: [[MathNode]], env: MathEnv) -> MathBox {
    guard !rows.isEmpty else { return MathBox(width: 0, ascent: 0, descent: 0, cmd: .group([])) }
    let colGap: CGFloat = env.fontSize * 0.5
    let rowGap: CGFloat = env.fontSize * 0.4

    let grid = rows.map { row in row.map { layoutMathNode($0, env: env) } }
    let nCols = grid.map(\.count).max() ?? 0

    // Column widths
    var colWidths = Array(repeating: CGFloat(0), count: nCols)
    for row in grid {
        for (j, box) in row.enumerated() {
            colWidths[j] = max(colWidths[j], box.width)
        }
    }
    // Row heights (ascent + descent per row)
    let rowAscents  = grid.map { row in row.map(\.ascent).max()  ?? 0 }
    let rowDescents = grid.map { row in row.map(\.descent).max() ?? 0 }

    var cmds: [DrawCommand] = []
    var y: CGFloat = 0
    for (i, row) in grid.enumerated() {
        let rowA = rowAscents[i]
        var x: CGFloat = 0
        for (j, box) in row.enumerated() {
            let dx = x + (colWidths[j] - box.width) / 2  // center in column
            let dy = y + rowA - box.ascent
            cmds.append(translate(box.cmd, dx: dx, dy: dy))
            x += colWidths[j] + colGap
        }
        y += rowAscents[i] + rowDescents[i] + rowGap
    }

    let totalWidth  = colWidths.reduce(0, +) + CGFloat(max(0, nCols - 1)) * colGap
    let totalHeight = zip(rowAscents, rowDescents).reduce(0) { $0 + $1.0 + $1.1 }
                      + CGFloat(max(0, rows.count - 1)) * rowGap
    let midAscent = totalHeight / 2 + env.axisHeight

    // Wrap in brackets { } for matrix, [ ] for array — caller chooses; here just return raw
    return MathBox(width: totalWidth, ascent: midAscent,
                   descent: totalHeight - midAscent,
                   cmd: .group(cmds))
}

// MARK: - Piecewise (cases)

private func layoutCases(_ pairs: [(MathNode, MathNode)], env: MathEnv) -> MathBox {
    let rowGap: CGFloat = env.fontSize * 0.3
    let colGap: CGFloat = env.fontSize * 0.5

    var rows: [(MathBox, MathBox)] = []
    for (val, cond) in pairs {
        rows.append((layoutMathNode(val, env: env), layoutMathNode(cond, env: env)))
    }

    let valWidth  = rows.map { $0.0.width }.max() ?? 0
    let condWidth = rows.map { $0.1.width }.max() ?? 0

    var cmds: [DrawCommand] = []
    var y: CGFloat = 0
    for (valBox, condBox) in rows {
        let rowA = max(valBox.ascent, condBox.ascent)
        cmds.append(translate(valBox.cmd,  dx: 0,                 dy: y + rowA - valBox.ascent))
        cmds.append(translate(condBox.cmd, dx: valWidth + colGap, dy: y + rowA - condBox.ascent))
        y += rowA + max(valBox.descent, condBox.descent) + rowGap
    }

    let totalH = y - rowGap
    let contentBox = MathBox(width: valWidth + colGap + condWidth,
                             ascent: totalH / 2, descent: totalH / 2,
                             cmd: .group(cmds))

    // Large left brace
    let braceBox = makeBigBrace(height: totalH, env: env)

    let combined = DrawCommand.group([
        braceBox.cmd,
        translate(contentBox.cmd, dx: braceBox.width + env.fontSize * 0.1,
                  dy: totalH / 2 - contentBox.ascent)
    ])
    return MathBox(width: braceBox.width + env.fontSize * 0.1 + contentBox.width,
                   ascent: totalH / 2, descent: totalH / 2,
                   cmd: combined)
}

private func makeBigBrace(height: CGFloat, env: MathEnv) -> MathBox {
    let w = env.fontSize * 0.35
    let t = env.ruleThickness
    let mid = height / 2

    var p = Path()
    // Left brace shape: two curved arcs meeting at a center point
    // Simplified as straight segments for v1
    p.move(to:    CGPoint(x: w,       y: 0))
    p.addLine(to: CGPoint(x: w * 0.4, y: 0))
    p.addLine(to: CGPoint(x: w * 0.4, y: mid - w * 0.3))
    p.addLine(to: CGPoint(x: 0,       y: mid))
    p.addLine(to: CGPoint(x: w * 0.4, y: mid + w * 0.3))
    p.addLine(to: CGPoint(x: w * 0.4, y: height))
    p.addLine(to: CGPoint(x: w,       y: height))

    return MathBox(width: w, ascent: height / 2, descent: height / 2,
                   cmd: .path(p, t))
}

// MARK: - Helpers

private func formatNumber(_ v: Double) -> String {
    if v == v.rounded(.towardZero) && abs(v) < 1e12 {
        return "\(Int(v))"
    }
    return String(format: "%g", v)
}

private extension MathBox {
    /// Lets us chain a transform immediately after construction.
    func then<T>(_ f: (MathBox) -> T) -> T { f(self) }
}

// MARK: - Public SwiftUI View

/// Renders a MathNode as a native SwiftUI view.
///
/// Usage:
///   MathView(node: .fraction(.variable("x"), .number(2)))
///   MathView(node: expr.mathNode, fontSize: 22, style: .display)
public struct MathView: View {
    public let node: MathNode
    public let fontSize: CGFloat
    public let style: MathStyle

    public init(node: MathNode,
                fontSize: CGFloat = 20,
                style: MathStyle = .text) {
        self.node = node
        self.fontSize = fontSize
        self.style = style
    }

    private var box: MathBox {
        layoutMathNode(node, env: MathEnv(fontSize: fontSize, style: style))
    }

    public var body: some View {
        let b = box
        Canvas { context, _ in
            renderDrawCommand(b.cmd, context: &context)
        }
        .frame(width: b.width, height: b.height)
        .accessibilityLabel(mathAccessibilityLabel(node))
    }
}

// MARK: - Accessibility

private func mathAccessibilityLabel(_ node: MathNode) -> String {
    switch node {
    case .number(let v):         return formatNumber(v)
    case .variable(let s):       return s
    case .symbol(let s):         return s.rawValue
    case .text(let s):           return s
    case .placeholder:           return "empty"
    case .add(let l, let r):     return "\(mathAccessibilityLabel(l)) plus \(mathAccessibilityLabel(r))"
    case .subtract(let l, let r):return "\(mathAccessibilityLabel(l)) minus \(mathAccessibilityLabel(r))"
    case .multiply(let l, let r):return "\(mathAccessibilityLabel(l)) times \(mathAccessibilityLabel(r))"
    case .divide(let l, let r):  return "\(mathAccessibilityLabel(l)) over \(mathAccessibilityLabel(r))"
    case .negate(let n):         return "negative \(mathAccessibilityLabel(n))"
    case .apply(let f, let a):   return "\(f) of \(mathAccessibilityLabel(a))"
    case .fraction(let n, let d):return "\(mathAccessibilityLabel(n)) over \(mathAccessibilityLabel(d))"
    case .power(let b, let e):   return "\(mathAccessibilityLabel(b)) to the power \(mathAccessibilityLabel(e))"
    case .sub(let b, let i):     return "\(mathAccessibilityLabel(b)) subscript \(mathAccessibilityLabel(i))"
    case .radical(_, let b):     return "square root of \(mathAccessibilityLabel(b))"
    case .bigop(let op, _, _, let body): return "\(op.rawValue) of \(mathAccessibilityLabel(body))"
    default:                     return "expression"
    }
}
