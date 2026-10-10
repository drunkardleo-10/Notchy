import SwiftUI

struct BubbleShape: Shape {
    enum Tail { case leading, top }

    static let tailInset: CGFloat = 18

    let tail: Tail
    var radius: CGFloat = 12
    var tailSize: CGFloat = 7
    var tailInset: CGFloat = BubbleShape.tailInset

    func path(in rect: CGRect) -> Path {
        var body = rect
        switch tail {
        case .leading: body.origin.x += tailSize; body.size.width -= tailSize
        case .top: body.origin.y += tailSize; body.size.height -= tailSize
        }
        var path = Path(roundedRect: body, cornerRadius: radius, style: .continuous)
        var pointer = Path()
        switch tail {
        case .leading:
            let y = body.minY + min(tailInset, body.height / 2)
            pointer.move(to: CGPoint(x: body.minX + 1, y: y - tailSize))
            pointer.addLine(to: CGPoint(x: rect.minX, y: y))
            pointer.addLine(to: CGPoint(x: body.minX + 1, y: y + tailSize))
        case .top:
            let x = body.minX + tailInset
            pointer.move(to: CGPoint(x: x - tailSize, y: body.minY + 1))
            pointer.addLine(to: CGPoint(x: x, y: rect.minY))
            pointer.addLine(to: CGPoint(x: x + tailSize, y: body.minY + 1))
        }
        pointer.closeSubpath()
        path.addPath(pointer)
        return path
    }
}

struct SpeechBubble<Content: View>: View {
    enum Style { case light, dark }

    let tail: BubbleShape.Tail
    var style: Style = .dark
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .padding(tail == .leading ? .leading : .top, 7)
            .background(
                BubbleShape(tail: tail)
                    .fill(style == .light ? Color.white : Color.white.opacity(0.09))
            )
            .overlay(
                BubbleShape(tail: tail)
                    .stroke(Color.white.opacity(style == .light ? 0 : 0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(style == .light ? 0.3 : 0), radius: 10, y: 4)
    }
}

struct NotchyGuide: View {
    let pose: NotchyPose
    let title: String
    var message: String? = nil
    var cell: CGFloat = 2.4
    var reservedLines: Int? = nil

    @State private var typed = 0
    @State private var finished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var script: String { title + "\n" + (message ?? "") }
    private var typing: Bool { !finished && typed < script.count }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            NotchyMascot(pose: typing ? .talk : pose, cell: cell)
            SpeechBubble(tail: .leading) {
                ZStack(alignment: .topLeading) {
                    lines(title: title, message: message).opacity(0)
                    if finished {
                        lines(title: title, message: message)
                    } else {
                        lines(title: String(title.prefix(typed)),
                              message: message.map { String($0.prefix(max(0, typed - title.count - 1))) })
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: message)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: title) { await type() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, message].compactMap { $0 }.joined(separator: ". "))
    }

    private func lines(title: String, message: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            if let reservedLines {
                Text(message ?? "")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(reservedLines, reservesSpace: true)
                    .contentTransition(.opacity)
            } else if let message {
                Text(message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.6))
                    .contentTransition(.opacity)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func type() async {
        if reduceMotion {
            finished = true
            return
        }
        finished = false
        typed = 0
        while typed < script.count {
            try? await Task.sleep(for: .milliseconds(14))
            if Task.isCancelled { return }
            typed = min(script.count, typed + 2)
        }
        finished = true
    }
}
