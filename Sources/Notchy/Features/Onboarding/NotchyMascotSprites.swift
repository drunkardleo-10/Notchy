import SwiftUI

enum NotchyPose: Equatable {
    case walk, wave, idle, cheer, scan, talk
}

enum NotchyMascotSprites {
    struct Layer {
        let x: Int
        let y: Int
        let pixels: [String]
    }

    static let columns = 16
    static let rows = 16

    static let palette: [Character: Color] = [
        "L": Color(red: 0.74, green: 0.69, blue: 1.0),
        "D": Color(red: 0.52, green: 0.45, blue: 0.92),
        "f": Color(red: 0.36, green: 0.30, blue: 0.72),
        "k": Color(red: 0.08, green: 0.07, blue: 0.14),
        "w": .white,
        "p": Color(red: 1.0, green: 0.55, blue: 0.70),
        "a": Color(red: 0.60, green: 0.55, blue: 0.90),
        "t": Color(red: 0.45, green: 0.95, blue: 0.80),
        "T": Color(red: 0.80, green: 1.0, blue: 0.92),
        "s": Color(red: 1.0, green: 0.86, blue: 0.35)
    ]

    static func frameDuration(for pose: NotchyPose) -> TimeInterval {
        pose == .walk || pose == .talk ? 0.14 : 0.28
    }

    static func frameCount(for pose: NotchyPose) -> Int {
        switch pose {
        case .walk: 4
        case .idle: 8
        default: 2
        }
    }

    static func layers(for pose: NotchyPose, frame: Int) -> [Layer] {
        switch pose {
        case .walk:
            let bob = frame % 2 == 1 ? -1 : 0
            let feet = frame % 2 == 0 ? (frame == 0 ? feetApart : feetCross) : feetStand
            return figure(y: 3 + bob, blink: false, glow: frame % 2 == 0, feet: feet, mouth: smile)
        case .talk:
            return figure(y: 3, blink: false, glow: frame == 0, feet: feetStand, mouth: frame == 0 ? smile : open)
        case .idle:
            return figure(y: 3, blink: frame == 5, glow: frame % 4 < 2, feet: feetStand, mouth: smile)
        case .wave:
            let arm = frame == 0
                ? Layer(x: 14, y: 6, pixels: [".L", "L.", "L."])
                : Layer(x: 14, y: 6, pixels: ["L.", "L.", "L."])
            return figure(y: 3, blink: false, glow: frame == 0, feet: feetStand, mouth: grin) + [arm]
        case .cheer:
            let hop = frame == 1 ? -2 : 0
            return figure(y: 3 + hop, blink: false, glow: true, feet: frame == 1 ? feetTucked : feetStand, mouth: grin) + [
                Layer(x: 0, y: 5 + hop, pixels: ["L", "L", "L"]),
                Layer(x: 15, y: 5 + hop, pixels: ["L", "L", "L"]),
                Layer(x: frame == 0 ? 1 : 0, y: frame == 0 ? 1 : 2, pixels: ["s"]),
                Layer(x: frame == 0 ? 14 : 15, y: frame == 0 ? 2 : 1, pixels: ["s"]),
                Layer(x: frame == 0 ? 2 : 13, y: 0, pixels: ["s"])
            ]
        case .scan:
            let wave = frame == 0
                ? Layer(x: 5, y: 0, pixels: ["t....t"])
                : Layer(x: 4, y: 0, pixels: ["t......t"])
            return figure(y: 3, blink: false, glow: true, feet: feetStand, mouth: smile, lookUp: true) + [wave]
        }
    }

    private static func figure(y: Int, blink: Bool, glow: Bool, feet: String, mouth: String, lookUp: Bool = false) -> [Layer] {
        let eyesTop = lookUp ? ".LLwkLLLLwkLL." : ".LLwkLLLLwkLL."
        let eyesBottom = lookUp ? ".LLLLLLLLLLLL." : ".LLkkLLLLkkLL."
        let eyes = blink
            ? [".LLLLLLLLLLLL.", ".LLkkLLLLkkLL."]
            : [eyesTop, eyesBottom]
        let body = [
            "......aa......",
            "...LLLLLLLL...",
            "..LLLLLLLLLL..",
            ".LLLLLLLLLLLL."
        ] + eyes + [
            ".LpLLLLLLLLpL.",
            mouth,
            ".LLLLLLLLLLLL.",
            "..DLLLLLLLLD..",
            "...DDDDDDDD...",
            feet
        ]
        return [
            Layer(x: 7, y: y - 1, pixels: [glow ? "T" : "t"]),
            Layer(x: 1, y: y, pixels: body)
        ]
    }

    private static let smile = ".LLLLLkkLLLLL."
    private static let grin = ".LLLLkwwkLLLL."
    private static let open = ".LLLLkkkkLLLL."
    private static let feetStand = "...ff....ff..."
    private static let feetApart = "..ff......ff.."
    private static let feetCross = "....ff..ff...."
    private static let feetTucked = "....ff..ff...."
}
