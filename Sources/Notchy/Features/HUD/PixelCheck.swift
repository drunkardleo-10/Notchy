import SwiftUI

struct PixelCheck: View {
    var cell: CGFloat = 2.4
    var tint = Color(red: 0.30, green: 0.82, blue: 0.40)
    var shade = Color(red: 0.12, green: 0.66, blue: 0.33)

    private static let rows = [
        ".......hh",
        "......hhg",
        "h....hhg.",
        "hh..hhg..",
        ".hhhhg...",
        "..hhg....",
        "...g....."
    ]

    var body: some View {
        Canvas { context, _ in
            for (row, line) in Self.rows.enumerated() {
                for (column, key) in line.enumerated() where key != "." {
                    let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(key == "h" ? tint : shade))
                }
            }
        }
        .frame(width: CGFloat(Self.rows[0].count) * cell, height: CGFloat(Self.rows.count) * cell)
        .accessibilityHidden(true)
    }
}
