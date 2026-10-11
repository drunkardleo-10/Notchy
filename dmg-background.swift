import AppKit

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: dmg-background <out.png>\n".utf8))
    exit(1)
}

let size = NSSize(width: 660, height: 420)
let scale: CGFloat = 2
let appCenter = CGPoint(x: 190, y: 215)
let folderCenter = CGPoint(x: 470, y: 215)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width * scale),
    pixelsHigh: Int(size.height * scale),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { exit(1) }
rep.size = size

guard let gfx = NSGraphicsContext(bitmapImageRep: rep) else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = gfx
let ctx = gfx.cgContext

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let bounds = CGRect(origin: .zero, size: size)
NSGradient(colors: [color(0xFBFAF7), color(0xF1EFEA)])?.draw(in: bounds, angle: -90)

let glow = NSGradient(colors: [color(0xFF9F0A, 0.18), color(0xFF9F0A, 0)])
glow?.draw(
    fromCenter: CGPoint(x: size.width / 2, y: size.height + 40),
    radius: 0,
    toCenter: CGPoint(x: size.width / 2, y: size.height + 40),
    radius: 300,
    options: []
)

enum Face { case happy, wink, surprised, love, cool, sleepy, cheer }

let spritePalette: [Character: NSColor] = [
    "L": color(0xBDB0FF), "D": color(0x8573EB), "f": color(0x5C4DB8), "k": color(0x14121F),
    "w": color(0xFFFFFF), "p": color(0xFF8CB3), "a": color(0x998CE6), "T": color(0xCCFFEB),
    "s": color(0xFFC82E), "r": color(0xFF4D6D), "z": color(0x8573EB), "g": color(0x2E2A44)
]

func sprite(_ face: Face) -> [[Character]] {
    var g = Array(repeating: Array(repeating: Character("."), count: 16), count: 16)
    func put(_ x: Int, _ y: Int, _ c: Character) { if x >= 0, x < 16, y >= 0, y < 16 { g[y][x] = c } }
    func row(_ y: Int, _ x0: Int, _ x1: Int, _ c: Character) { for x in x0...x1 { put(x, y, c) } }
    put(7, 2, "T")
    row(3, 7, 8, "a")
    row(4, 4, 11, "L")
    row(5, 3, 12, "L")
    for y in 6...11 { row(y, 2, 13, "L") }
    row(12, 4, 11, "L")
    put(3, 12, "D"); put(12, 12, "D")
    row(13, 4, 11, "D")
    row(14, 4, 5, "f"); row(14, 10, 11, "f")
    put(3, 9, "p"); put(12, 9, "p")

    func eyeOpen(_ x: Int) { put(x, 7, "w"); put(x + 1, 7, "k"); put(x, 8, "k"); put(x + 1, 8, "k") }
    func eyeHappy(_ x: Int) { put(x + 1, 7, "k"); put(x, 8, "k"); put(x + 2, 8, "k") }
    func eyeLine(_ x: Int) { put(x, 8, "k"); put(x + 1, 8, "k") }
    func eyeBig(_ x: Int) { put(x, 7, "k"); put(x + 1, 7, "k"); put(x, 8, "k"); put(x + 1, 8, "k"); put(x, 6, "w") }
    func eyeHeart(_ x: Int) { put(x, 7, "r"); put(x + 2, 7, "r"); put(x, 8, "r"); put(x + 1, 8, "r"); put(x + 2, 8, "r"); put(x + 1, 9, "r") }
    func grin() { row(10, 6, 9, "k"); put(5, 9, "k"); put(10, 9, "k") }
    func smallSmile() { row(10, 7, 8, "k") }

    switch face {
    case .happy:
        eyeOpen(4); eyeOpen(10); grin()
    case .wink:
        eyeOpen(4); eyeLine(10); row(10, 6, 9, "k"); put(5, 9, "k"); put(10, 9, "k"); put(7, 11, "p"); put(8, 11, "p")
    case .surprised:
        eyeBig(4); eyeBig(10)
        put(7, 10, "k"); put(8, 10, "k"); put(7, 11, "k"); put(8, 11, "k")
    case .love:
        eyeHeart(4); eyeHeart(10); smallSmile()
    case .cool:
        row(7, 3, 12, "g"); row(8, 3, 12, "g"); put(7, 7, "L"); put(8, 7, "L"); put(7, 8, "L"); put(8, 8, "L")
        put(4, 7, "w"); put(10, 7, "w")
        row(10, 6, 9, "k"); put(10, 9, "k")
    case .sleepy:
        eyeLine(4); eyeLine(10); put(7, 10, "k"); put(8, 10, "k"); put(7, 11, "k"); put(8, 11, "k")
        row(1, 12, 14, "z"); put(13, 2, "z"); row(3, 12, 14, "z")
    case .cheer:
        eyeHappy(4); eyeHappy(10)
        row(10, 6, 9, "k"); put(5, 9, "k"); put(10, 9, "k")
        for y in 7...9 { put(1, y, "L"); put(14, y, "L") }
        put(0, 5, "s"); put(15, 4, "s"); put(1, 2, "s"); put(14, 1, "s")
    }
    return g
}

func mascot(_ face: Face, center: CGPoint, pixel: CGFloat, lines: Bool) {
    let grid = sprite(face)
    let side = pixel * 16
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.setShouldAntialias(false)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -pixel * 1.4), blur: pixel * 2.2, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    color(0xBDB0FF).setFill()
    let silhouette = NSBezierPath()
    for (y, line) in grid.enumerated() {
        for (x, c) in line.enumerated() where c != "." && c != "z" && c != "s" {
            silhouette.appendRect(CGRect(x: -side / 2 + CGFloat(x) * pixel, y: side / 2 - CGFloat(y + 1) * pixel, width: pixel, height: pixel))
        }
    }
    silhouette.fill()
    ctx.restoreGState()

    for (y, line) in grid.enumerated() {
        for (x, c) in line.enumerated() {
            guard let fill = spritePalette[c] else { continue }
            fill.setFill()
            CGRect(x: -side / 2 + CGFloat(x) * pixel, y: side / 2 - CGFloat(y + 1) * pixel, width: pixel + 0.4, height: pixel + 0.4).fill()
        }
    }
    ctx.setShouldAntialias(true)

    if lines {
        color(0x1C1C1E, 0.25).setStroke()
        for i in 0..<3 {
            let line = NSBezierPath()
            let x = -side / 2 - pixel * 1.5 - CGFloat(i) * pixel * 1.1
            let y = pixel * 2 - CGFloat(i) * pixel * 1.4
            line.move(to: CGPoint(x: x, y: y))
            line.line(to: CGPoint(x: x - pixel * 2, y: y - pixel))
            line.lineWidth = 1.6
            line.lineCapStyle = .round
            line.stroke()
        }
    }
    ctx.restoreGState()
}

mascot(.happy, center: CGPoint(x: 96, y: 344), pixel: 5, lines: true)
mascot(.wink, center: CGPoint(x: 564, y: 350), pixel: 5, lines: false)
mascot(.surprised, center: CGPoint(x: 330, y: 376), pixel: 3.5, lines: false)
mascot(.love, center: CGPoint(x: 64, y: 192), pixel: 3.5, lines: false)
mascot(.cool, center: CGPoint(x: 600, y: 196), pixel: 3.5, lines: false)
mascot(.sleepy, center: CGPoint(x: 590, y: 70), pixel: 4, lines: false)
mascot(.cheer, center: CGPoint(x: 66, y: 66), pixel: 4, lines: false)

let dots = 14
let arcStart = CGPoint(x: appCenter.x + 78, y: appCenter.y + 18)
let arcEnd = CGPoint(x: folderCenter.x - 78, y: folderCenter.y + 18)
let control = CGPoint(x: (arcStart.x + arcEnd.x) / 2, y: appCenter.y + 78)
for i in 0...dots {
    let t = CGFloat(i) / CGFloat(dots)
    let x = (1 - t) * (1 - t) * arcStart.x + 2 * (1 - t) * t * control.x + t * t * arcEnd.x
    let y = (1 - t) * (1 - t) * arcStart.y + 2 * (1 - t) * t * control.y + t * t * arcEnd.y
    let r = 2.6 - 0.9 * abs(t - 0.5) * 2 * 0.6
    color(0x1C1C1E, 0.14 + 0.36 * t).setFill()
    NSBezierPath(ovalIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)).fill()
}

let head = CGPoint(x: arcEnd.x + 8, y: arcEnd.y - 4)
let heading = atan2(arcEnd.y - control.y, arcEnd.x - control.x)
color(0x1C1C1E, 0.55).setStroke()
let chevron = NSBezierPath()
for side in [-1.0, 1.0] {
    let a = heading + .pi + CGFloat(side) * 0.55
    chevron.move(to: head)
    chevron.line(to: CGPoint(x: head.x + cos(a) * 11, y: head.y + sin(a) * 11))
}
chevron.lineWidth = 2.4
chevron.lineCapStyle = .round
chevron.stroke()

func centered(_ text: NSAttributedString, y: CGFloat) {
    let s = text.size()
    text.draw(at: CGPoint(x: (size.width - s.width) / 2, y: y))
}

let heading1 = NSMutableAttributedString()
let font = NSFont.systemFont(ofSize: 25, weight: .bold)
heading1.append(NSAttributedString(string: "Drag ", attributes: [.font: font, .foregroundColor: color(0x1C1C1E)]))
heading1.append(NSAttributedString(string: "Notchy", attributes: [.font: font, .foregroundColor: color(0xF57C00)]))
heading1.append(NSAttributedString(string: " to Applications", attributes: [.font: font, .foregroundColor: color(0x1C1C1E)]))
centered(heading1, y: 66)

centered(
    NSAttributedString(
        string: "Then open it from your Applications folder",
        attributes: [.font: NSFont.systemFont(ofSize: 12.5, weight: .medium), .foregroundColor: color(0x1C1C1E, 0.5)]
    ),
    y: 40
)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: args[1]))
