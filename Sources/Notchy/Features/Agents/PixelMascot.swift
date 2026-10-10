import SwiftUI

struct PixelMascot: View {
    let pose: MascotPose
    var cell: CGFloat = 2
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if animated && !reduceMotion {
                TimelineView(.periodic(from: .now, by: MascotSprites.frameDuration)) { context in
                    canvas(frame: Int(context.date.timeIntervalSinceReferenceDate / MascotSprites.frameDuration) % 2)
                }
            } else {
                canvas(frame: 0)
            }
        }
        .frame(width: CGFloat(MascotSprites.columns) * cell, height: CGFloat(MascotSprites.rows) * cell)
        .accessibilityHidden(true)
    }

    private func canvas(frame: Int) -> some View {
        Canvas { context, _ in
            for layer in MascotSprites.layers(for: pose, frame: frame) {
                for (row, line) in layer.pixels.enumerated() {
                    for (column, key) in line.enumerated() {
                        guard let color = MascotSprites.palette[key] else { continue }
                        let rect = CGRect(
                            x: CGFloat(layer.x + column) * cell,
                            y: CGFloat(layer.y + row) * cell,
                            width: cell,
                            height: cell
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
    }
}

enum MascotSprites {
    struct Layer {
        let x: Int
        let y: Int
        let pixels: [String]
    }

    static let columns = 24
    static let rows = 12
    static let frameDuration: TimeInterval = 0.24
    static let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)

    static let palette: [Character: Color] = [
        "o": claudeOrange,
        "k": Color(red: 0.13, green: 0.10, blue: 0.09),
        "w": .white,
        "U": Color(red: 0.27, green: 0.40, blue: 0.95),
        "N": Color(red: 0.17, green: 0.25, blue: 0.62),
        "p": Color(red: 0.93, green: 0.40, blue: 0.75),
        "g": Color(red: 0.30, green: 0.82, blue: 0.40),
        "G": Color(red: 0.12, green: 0.66, blue: 0.33),
        "m": Color(red: 0.85, green: 0.40, blue: 0.80),
        "W": Color(red: 0.95, green: 0.95, blue: 0.92),
        "l": Color(white: 0.6),
        "Y": Color(red: 0.98, green: 0.86, blue: 0.30),
        "y": Color(red: 0.88, green: 0.70, blue: 0.20),
        "r": Color(red: 0.55, green: 0.60, blue: 0.65),
        "O": Color(red: 0.98, green: 0.60, blue: 0.15),
        "v": Color(red: 0.60, green: 0.35, blue: 0.95),
        "P": Color(red: 0.45, green: 0.40, blue: 0.85),
        "q": Color(red: 0.30, green: 0.25, blue: 0.65),
        "c": Color(red: 0.45, green: 0.95, blue: 0.80)
    ]

    static func layers(for pose: MascotPose, frame: Int) -> [Layer] {
        let bounce = pose == .celebrating && frame == 1 ? -1 : 0
        let walking = pose != .celebrating
        let legs = walking ? frame : 0
        switch pose {
        case .thinking:
            let lift = frame == 1 ? 1 : 0
            return [
                Layer(x: 2, y: 3, pixels: body(armsUp: true, happy: false, legs: 0)),
                Layer(x: 0, y: 1 + lift, pixels: barbell)
            ]
        case .celebrating:
            return [
                Layer(x: 1, y: 3 + bounce, pixels: body(armsUp: true, happy: true, legs: legs)),
                Layer(x: 17, y: 1 + bounce, pixels: check),
                Layer(x: 16, y: frame == 0 ? 0 : 1, pixels: ["c"]),
                Layer(x: 23, y: frame == 0 ? 1 : 0, pixels: ["c"]),
                Layer(x: 23, y: 6, pixels: ["c"])
            ]
        case .coding:
            return [standing(legs), Layer(x: 15, y: 3, pixels: codeWindow)]
        case .reading:
            return [standing(legs), Layer(x: 16, y: 4 + (frame == 1 ? -1 : 0), pixels: page)]
        case .browsing:
            return [standing(legs), Layer(x: 16, y: 3, pixels: frame == 0 ? globe : globeTurned)]
        case .building:
            return [
                standing(legs),
                Layer(x: 2, y: 2, pixels: hardHat),
                Layer(x: 16, y: 4 + (frame == 1 ? 1 : 0), pixels: wrench)
            ]
        case .planning:
            return [
                standing(legs),
                Layer(x: 16, y: 3, pixels: checklist),
                Layer(x: 21, y: 0, pixels: frame == 0 ? sparkle : sparkleSmall)
            ]
        case .delegating:
            return [standing(legs), Layer(x: 15, y: 2, pixels: frame == 0 ? magic : magicAlt)]
        case .serving:
            return [standing(legs), Layer(x: 15, y: 3, pixels: frame == 0 ? servers : serversBlink)]
        case .alert:
            return [standing(0), Layer(x: 16, y: frame == 0 ? 1 : 0, pixels: bubble)]
        }
    }

    private static func standing(_ legs: Int) -> Layer {
        Layer(x: 1, y: 5, pixels: body(armsUp: false, happy: false, legs: legs))
    }

    private static func body(armsUp: Bool, happy: Bool, legs: Int) -> [String] {
        let plain = "..oooooooooo.."
        let eyes = "..ookooookoo.."
        let mouth = happy ? "..ooowwwwooo.." : "..oooowwoooo.."
        let feet = legs == 0 ? "..o.o....o.o.." : "...o.o....o.o."
        if armsUp {
            return ["o............o", "o............o", "oooooooooooooo", plain, eyes, mouth, plain, plain, feet]
        }
        return [plain, plain, eyes, mouth, "oooooooooooooo", plain, feet]
    }

    private static let barbell = [
        "UU..............UU",
        "UUrrrrrrrrrrrrrrUU",
        "UU..............UU"
    ]

    private static let check = [
        ".GGGG.",
        "GGGGGc",
        "GGGGcG",
        "GcGcGG",
        "GGcGGG",
        ".GGGG."
    ]

    private static let codeWindow = [
        "UUUUUUUUU",
        "UpUpUpUUU",
        "NNNNNNNNN",
        "NgNggggNN",
        "NNNNNNNNN",
        "NgNgggNNN",
        "NNNNNNNNN",
        "NNNNgNgNN"
    ]

    private static let page = [
        "WWWWW.",
        "WllWWW",
        "WWWWWW",
        "WlllWW",
        "WWWWWW",
        "WllWWW",
        "WWWWWW"
    ]

    private static let globe = [
        "..GGG..",
        ".GUUUG.",
        "GUmUmUG",
        "GUUmUUG",
        "GUmUmUG",
        ".GUUUG.",
        "..GGG.."
    ]

    private static let globeTurned = [
        "..GGG..",
        ".GUUUG.",
        "GmUmUUG",
        "GUmUUUG",
        "GmUmUUG",
        ".GUUUG.",
        "..GGG.."
    ]

    private static let hardHat = [
        "....YYYY....",
        "..YYYyYYYY..",
        "YYYYYYYYYYYY"
    ]

    private static let wrench = [
        "r.r",
        "rrr",
        ".r.",
        ".r.",
        ".r.",
        ".r."
    ]

    private static let checklist = [
        "p.OOOO",
        "p.OOO.",
        "......",
        "g.gggg",
        "g.ggg.",
        "......",
        "g.gggg",
        "g.gg.."
    ]

    private static let sparkle = [
        ".G.",
        "GGG",
        ".G."
    ]

    private static let sparkleSmall = [
        "...",
        ".G.",
        "..."
    ]

    private static let magic = [
        "..Y.....",
        ".YOY..Y.",
        "..Y..YOY",
        "......Y.",
        "...Y....",
        "..YOY...",
        "...vvvv.",
        "..vvvv.."
    ]

    private static let magicAlt = [
        "......Y.",
        "..Y..YOY",
        ".YOY..Y.",
        "..Y.....",
        "....Y...",
        "...YOY..",
        "...vvvv.",
        "..vvvv.."
    ]

    private static let servers = [
        "PPPPPPq",
        "PgPPPPq",
        "qqqqqqq",
        "PPPPPPq",
        "PgPPPPq",
        "qqqqqqq",
        "PPPPPPq",
        "PgPPPPq"
    ]

    private static let serversBlink = [
        "PPPPPPq",
        "PPPPPPq",
        "qqqqqqq",
        "PPPPPPq",
        "PgPPPPq",
        "qqqqqqq",
        "PPPPPPq",
        "PPPPPPq"
    ]

    private static let bubble = [
        "WWWWW",
        "WWOWW",
        "WWOWW",
        "WWOWW",
        "WWWWW",
        "WWOWW",
        "WWWWW",
        ".W..."
    ]
}
