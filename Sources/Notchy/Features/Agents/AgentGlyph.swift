import SwiftUI

struct AgentGlyph: View {
    let id: String
    var size: CGFloat = 20

    var body: some View {
        Canvas { context, canvas in
            AgentGlyphArt.draw(id, in: &context, unit: canvas.width / 24)
        }
        .frame(width: size, height: size)
    }
}

private enum AgentGlyphArt {
    static let claude = Color(red: 0.85, green: 0.47, blue: 0.34)

    static func draw(_ id: String, in context: inout GraphicsContext, unit u: CGFloat) {
        switch id {
        case "claude": drawClaude(&context, u)
        case "codex": drawCodex(&context, u)
        case "cursor": drawCursor(&context, u)
        case "antigravity": drawAntigravity(&context, u)
        case "gemini": drawGemini(&context, u)
        case "grok": drawGrok(&context, u)
        case "droid": drawDroid(&context, u)
        case "opencode": drawOpenCode(&context, u)
        case "pi": drawPi(&context, u)
        case "devin": drawDevin(&context, u)
        default: break
        }
    }

    private static func point(_ x: CGFloat, _ y: CGFloat, _ u: CGFloat) -> CGPoint { CGPoint(x: x * u, y: y * u) }

    private static func rotated(_ path: Path, by degrees: Double, _ u: CGFloat) -> Path {
        let center = point(12, 12, u)
        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: degrees * .pi / 180)
            .translatedBy(x: -center.x, y: -center.y)
        return path.applying(transform)
    }

    private static func drawClaude(_ c: inout GraphicsContext, _ u: CGFloat) {
        for i in 0..<12 {
            let angle = Double(i) * .pi / 6
            let outer: CGFloat = i % 2 == 0 ? 11 : 8.4
            var ray = Path()
            ray.move(to: point(12 + 3 * cos(angle), 12 + 3 * sin(angle), u))
            ray.addLine(to: point(12 + outer * cos(angle), 12 + outer * sin(angle), u))
            c.stroke(ray, with: .color(claude), style: StrokeStyle(lineWidth: 1.7 * u, lineCap: .round))
        }
    }

    private static func drawCodex(_ c: inout GraphicsContext, _ u: CGFloat) {
        let petal = Path(roundedRect: CGRect(x: 8.6 * u, y: 1.8 * u, width: 6.8 * u, height: 13.4 * u), cornerRadius: 3.4 * u)
        for i in 0..<6 {
            c.stroke(rotated(petal, by: Double(i) * 60, u), with: .color(.white), style: StrokeStyle(lineWidth: 1.5 * u, lineJoin: .round))
        }
    }

    private static func drawCursor(_ c: inout GraphicsContext, _ u: CGFloat) {
        let vertices = (0..<6).map { i -> CGPoint in
            let angle = (Double(i) * 60 - 90) * .pi / 180
            return point(12 + 10 * cos(angle), 12 + 10 * sin(angle), u)
        }
        var hex = Path()
        hex.addLines(vertices)
        hex.closeSubpath()
        c.fill(hex, with: .color(.white))
        var edges = Path()
        for i in [1, 3, 5] {
            edges.move(to: point(12, 12, u))
            edges.addLine(to: vertices[i])
        }
        c.stroke(edges, with: .color(.black.opacity(0.55)), style: StrokeStyle(lineWidth: 1.3 * u, lineCap: .round))
    }

    private static func drawAntigravity(_ c: inout GraphicsContext, _ u: CGFloat) {
        let k = u * 24 / 512
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: (x - 30) * k * 1.12, y: (y - 27) * k * 1.12) }
        var shape = Path()
        shape.move(to: p(97, 375))
        shape.addCurve(to: p(175, 220), control1: p(105, 360), control2: p(150, 330))
        shape.addCurve(to: p(255, 95), control1: p(190, 150), control2: p(215, 95))
        shape.addCurve(to: p(345, 230), control1: p(300, 95), control2: p(325, 150))
        shape.addCurve(to: p(418, 378), control1: p(360, 290), control2: p(395, 340))
        shape.addCurve(to: p(398, 398), control1: p(425, 392), control2: p(410, 400))
        shape.addCurve(to: p(320, 320), control1: p(360, 392), control2: p(335, 360))
        shape.addCurve(to: p(255, 258), control1: p(305, 280), control2: p(285, 258))
        shape.addCurve(to: p(190, 320), control1: p(225, 258), control2: p(205, 280))
        shape.addCurve(to: p(120, 396), control1: p(175, 360), control2: p(150, 392))
        shape.addCurve(to: p(97, 375), control1: p(105, 398), control2: p(90, 390))
        shape.closeSubpath()
        let bounds = CGRect(x: 0, y: 0, width: 24 * u, height: 24 * u)
        c.drawLayer { layer in
            layer.clip(to: shape)
            layer.fill(Path(bounds), with: .linearGradient(
                Gradient(colors: [Color(red: 1, green: 0.35, blue: 0.3), Color(red: 0.25, green: 0.52, blue: 1), Color(red: 0.25, green: 0.52, blue: 1)]),
                startPoint: p(300, 95), endPoint: p(255, 300)))
            layer.fill(Path(bounds), with: .radialGradient(
                Gradient(colors: [Color(red: 0.3, green: 0.82, blue: 0.35), Color(red: 0.3, green: 0.82, blue: 0.35).opacity(0)]),
                center: p(185, 190), startRadius: 0, endRadius: 7 * u))
            layer.fill(Path(bounds), with: .radialGradient(
                Gradient(colors: [Color(red: 1, green: 0.8, blue: 0.2), Color(red: 1, green: 0.8, blue: 0.2).opacity(0)]),
                center: p(215, 120), startRadius: 0, endRadius: 4.5 * u))
        }
    }

    private static func drawGemini(_ c: inout GraphicsContext, _ u: CGFloat) {
        var star = Path()
        star.move(to: point(12, 1.5, u))
        star.addQuadCurve(to: point(22.5, 12, u), control: point(12, 12, u))
        star.addQuadCurve(to: point(12, 22.5, u), control: point(12, 12, u))
        star.addQuadCurve(to: point(1.5, 12, u), control: point(12, 12, u))
        star.addQuadCurve(to: point(12, 1.5, u), control: point(12, 12, u))
        let gradient = Gradient(colors: [Color(red: 0.3, green: 0.55, blue: 1), Color(red: 0.7, green: 0.5, blue: 0.95)])
        c.fill(star, with: .linearGradient(gradient, startPoint: point(2, 2, u), endPoint: point(22, 22, u)))
    }

    private static func drawGrok(_ c: inout GraphicsContext, _ u: CGFloat) {
        c.stroke(Path(ellipseIn: CGRect(x: 3.5 * u, y: 3.5 * u, width: 17 * u, height: 17 * u)), with: .color(.white), lineWidth: 1.8 * u)
        var slash = Path()
        slash.move(to: point(19.5, 4.5, u))
        slash.addLine(to: point(4.5, 19.5, u))
        c.stroke(slash, with: .color(.white), style: StrokeStyle(lineWidth: 1.8 * u, lineCap: .round))
    }

    private static func drawDroid(_ c: inout GraphicsContext, _ u: CGFloat) {
        let petal = Path(ellipseIn: CGRect(x: 9.4 * u, y: 2 * u, width: 5.2 * u, height: 10 * u))
        for i in 0..<8 {
            c.stroke(rotated(petal, by: Double(i) * 45, u), with: .color(.white), lineWidth: 1.3 * u)
        }
    }

    private static func drawOpenCode(_ c: inout GraphicsContext, _ u: CGFloat) {
        let body = Path(roundedRect: CGRect(x: 5 * u, y: 3 * u, width: 14 * u, height: 18 * u), cornerRadius: 1.5 * u)
        c.fill(body, with: .color(Color(white: 0.8)))
        c.fill(Path(CGRect(x: 8.5 * u, y: 8 * u, width: 7 * u, height: 8 * u)), with: .color(Color(white: 0.2)))
    }

    private static func drawPi(_ c: inout GraphicsContext, _ u: CGFloat) {
        let blocks = [CGRect(x: 4, y: 5, width: 16, height: 4), CGRect(x: 4, y: 9, width: 4, height: 10), CGRect(x: 12, y: 9, width: 4, height: 6)]
        for block in blocks {
            c.fill(Path(CGRect(x: block.minX * u, y: block.minY * u, width: block.width * u, height: block.height * u)), with: .color(.white))
        }
    }

    private static func drawDevin(_ c: inout GraphicsContext, _ u: CGFloat) {
        var centers = [point(12, 12, u)]
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3
            centers.append(point(12 + 6.6 * cos(angle), 12 + 6.6 * sin(angle), u))
        }
        for center in centers {
            let r = 2.5 * u
            c.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(.white))
        }
    }
}
