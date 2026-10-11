import SwiftUI

enum MascotSpecies: String, CaseIterable {
    case claude, codex, devin, opencode, antigravity

    init(agent: String) {
        self = MascotSpecies(rawValue: agent) ?? .claude
    }

    var accent: Color {
        switch self {
        case .claude: MascotSprites.claudeOrange
        case .codex: Color(red: 0.62, green: 0.66, blue: 1.0)
        case .devin: Color(red: 0.20, green: 0.80, blue: 0.70)
        case .opencode: Color(white: 0.85)
        case .antigravity: Color(red: 0.36, green: 0.58, blue: 1.0)
        }
    }

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .devin: "Devin"
        case .opencode: "OpenCode"
        case .antigravity: "Antigravity"
        }
    }

    static let palette: [Character: Color] = [
        "a": Color(red: 0.86, green: 0.88, blue: 1.0),
        "A": Color(red: 0.55, green: 0.60, blue: 0.98),
        "d": Color(red: 0.20, green: 0.78, blue: 0.68),
        "D": Color(red: 0.05, green: 0.20, blue: 0.22),
        "e": Color(white: 0.80),
        "E": Color(white: 0.14),
        "b": Color(red: 0.32, green: 0.54, blue: 0.98),
        "B": Color(red: 0.08, green: 0.12, blue: 0.36)
    ]

    func body(armsUp: Bool, happy: Bool, legs: Int) -> [String] {
        switch self {
        case .claude: claude(armsUp: armsUp, happy: happy, legs: legs)
        case .codex: codex(armsUp: armsUp, happy: happy, legs: legs)
        case .devin: devin(armsUp: armsUp, happy: happy, legs: legs)
        case .opencode: opencode(armsUp: armsUp, happy: happy, legs: legs)
        case .antigravity: antigravity(armsUp: armsUp, happy: happy, legs: legs)
        }
    }

    private func feet(_ key: Character, legs: Int) -> String {
        let pattern = legs == 0 ? "..x.x....x.x.." : "...x.x....x.x."
        return pattern.replacingOccurrences(of: "x", with: String(key))
    }

    private func claude(armsUp: Bool, happy: Bool, legs: Int) -> [String] {
        let plain = "..oooooooooo.."
        let eyes = "..ookooookoo.."
        let mouth = happy ? "..ooowwwwooo.." : "..oooowwoooo.."
        let feet = feet("o", legs: legs)
        if armsUp {
            return ["o............o", "o............o", "oooooooooooooo", plain, eyes, mouth, plain, plain, feet]
        }
        return [plain, plain, eyes, mouth, "oooooooooooooo", plain, feet]
    }

    private func codex(armsUp: Bool, happy: Bool, legs: Int) -> [String] {
        let eyes = ".aaAkaaaaAkaa."
        let mouth = happy ? ".aaaakkkkaaaa." : ".aaaaakkaaaaa."
        let feet = feet("A", legs: legs)
        if armsUp {
            return ["a............a", "a............a", "aa..aaaaaa..aa", ".aaaaaaaaaaaa.", eyes, mouth, ".aaaaaaaaaaaa.", "..aaaaaaaaaa..", feet]
        }
        return ["....aaaaaa....", "..aaaaaaaaaa..", eyes, mouth, "aaaaaaaaaaaaaa", "..aaaaaaaaaa..", feet]
    }

    private func devin(armsUp: Bool, happy: Bool, legs: Int) -> [String] {
        let glow: Character = happy ? "g" : "c"
        let visor = "..dD\(glow)DDDD\(glow)Dd.."
        let feet = feet("d", legs: legs)
        if armsUp {
            return ["d.....Y......d", "d.....d......d", "dddddddddddddd", visor, "..dddddddddd..", "..ddDDDDDDdd..", "..dddddddddd..", "..dddddddddd..", feet]
        }
        return ["......Y.......", "......d.......", "..dddddddddd..", visor, "dddddddddddddd", "..dddddddddd..", feet]
    }

    private func opencode(armsUp: Bool, happy: Bool, legs: Int) -> [String] {
        let eyes = "..eEgEEEEgEe.."
        let mouth = happy ? "..eEEggggEEe.." : "..eEEEggEEEe.."
        let feet = feet("e", legs: legs)
        if armsUp {
            return ["e............e", "e............e", "eeeeeeeeeeeeee", "..eEEEEEEEEe..", eyes, mouth, "..eEEEEEEEEe..", "..eeeeeeeeee..", feet]
        }
        return ["..eeeeeeeeee..", "..eEEEEEEEEe..", eyes, mouth, "eeeeeeeeeeeeee", "..eeeeeeeeee..", feet]
    }

    private func antigravity(armsUp: Bool, happy: Bool, legs: Int) -> [String] {
        let visor = happy ? "..bBcBBBBcBb.." : "..bBWBBBBBBb.."
        let jets = legs == 0 ? "...OO....OO..." : "...YY....YY..."
        if armsUp {
            return ["b............b", "b............b", "bb..bbbbbb..bb", "..bbbbbbbbbb..", "..bBBBBBBBBb..", visor, "..bbbbbbbbbb..", "..bbbbbbbbbb..", jets]
        }
        return ["....bbbbbb....", "..bbbbbbbbbb..", "..bBBBBBBBBb..", visor, "bbbbbbbbbbbbbb", "..bbbbbbbbbb..", jets]
    }
}
