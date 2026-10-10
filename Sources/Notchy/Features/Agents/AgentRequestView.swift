import SwiftUI

struct AgentRequestView: View {
    let request: AgentRequest
    let respond: (AgentRequestCenter.Decision) -> Void

    var body: some View {
        Group {
            if case .questions(let questions) = request.content, !questions.isEmpty {
                AgentQuestionCard(request: request, questions: questions, respond: respond)
            } else {
                AgentPermissionCard(request: request, respond: respond)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .id(request.id)
    }
}

private enum RequestTheme {
    static let warning = Color(red: 0.93, green: 0.55, blue: 0.27)
    static let removedText = Color(red: 0.95, green: 0.62, blue: 0.58)
    static let removedFill = Color(red: 0.35, green: 0.12, blue: 0.08).opacity(0.55)
    static let addedText = Color(red: 0.42, green: 0.85, blue: 0.45)
    static let addedFill = Color(red: 0.08, green: 0.25, blue: 0.12).opacity(0.55)
    static let ask = ClaudeLogo.color
    static let optionFill = Color(red: 0.17, green: 0.09, blue: 0.07)
    static let optionHover = Color(red: 0.26, green: 0.14, blue: 0.10)
    static let badgeFill = Color(red: 0.36, green: 0.19, blue: 0.13)
    static let mono = Font.system(size: 11.5, design: .monospaced)
}

private struct RequestHeader: View {
    let title: String
    let tint: Color
    let symbol: String?
    let trailing: String
    let onTerminal: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            } else {
                ClaudeSpark(size: 13)
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            Spacer(minLength: 8)
            Text(trailing)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
            Button(action: onTerminal) {
                Image(systemName: "terminal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Answer in terminal")
            .accessibilityLabel("Answer in terminal")
        }
        .frame(height: 22)
    }
}

private struct AgentPermissionCard: View {
    let request: AgentRequest
    let respond: (AgentRequestCenter.Decision) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RequestHeader(title: "Permission Request", tint: .white.opacity(0.55), symbol: nil,
                          trailing: request.project, onTerminal: { respond(.terminal) })

            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RequestTheme.warning)
                Text(request.verb)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(RequestTheme.warning)
                Text(request.target)
                    .font(.system(size: 13, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            preview
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: 66, alignment: .top)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if case .diff(_, let added, let removed) = request.content {
                Text("+\(added) -\(removed)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(height: 12)
            }

            HStack(spacing: 10) {
                RequestButton(title: "Deny", shortcut: "N", prominent: false) { respond(.deny) }
                RequestButton(title: "Allow", shortcut: "Y", prominent: true) { respond(.allow) }
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch request.content {
        case .diff(let lines, _, _):
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(lines) { DiffRow(line: $0) }
                }
            }
        case .command(let command, let detail):
            VStack(alignment: .leading, spacing: 4) {
                Text("$ " + command)
                    .font(RequestTheme.mono)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(3)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }
            .padding(8)
        case .summary(let text):
            Text(text.isEmpty ? request.tool : text)
                .font(RequestTheme.mono)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(4)
                .padding(8)
        case .questions:
            EmptyView()
        }
    }
}

private struct DiffRow: View {
    let line: AgentDiffLine

    private var marker: String {
        switch line.kind {
        case .context: " "
        case .removed: "-"
        case .added: "+"
        }
    }

    private var tint: Color {
        switch line.kind {
        case .context: .white.opacity(0.42)
        case .removed: RequestTheme.removedText
        case .added: RequestTheme.addedText
        }
    }

    private var fill: Color {
        switch line.kind {
        case .context: .clear
        case .removed: RequestTheme.removedFill
        case .added: RequestTheme.addedFill
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(line.number.map(String.init) ?? "")
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 26, alignment: .trailing)
            Text(marker)
                .foregroundStyle(tint)
            Text(line.text)
                .foregroundStyle(tint)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(RequestTheme.mono)
        .padding(.trailing, 8)
        .frame(height: 18)
        .background(fill)
    }
}

private struct RequestButton: View {
    let title: String
    let shortcut: Character
    let prominent: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text("⌘\(String(shortcut))").font(.system(size: 10, weight: .medium)).opacity(0.5)
            }
            .foregroundStyle(prominent ? Color.black : Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(prominent ? Color.white.opacity(hovering ? 1 : 0.9) : Color.white.opacity(hovering ? 0.2 : 0.13))
            )
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(shortcut.lowercased().first ?? shortcut), modifiers: .command)
        .onHover { hovering = $0 }
        .animation(NotchAnimation.hover, value: hovering)
    }
}

private struct AgentQuestionCard: View {
    let request: AgentRequest
    let questions: [AgentQuestion]
    let respond: (AgentRequestCenter.Decision) -> Void

    @State private var index = 0
    @State private var answers: [String: String] = [:]
    @State private var selection: Set<String> = []

    private static let maxOptions = 4

    private var question: AgentQuestion { questions[min(index, questions.count - 1)] }

    private var options: [AgentQuestion.Option] { Array(question.options.prefix(Self.maxOptions)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RequestHeader(
                title: "Claude asks",
                tint: RequestTheme.ask,
                symbol: nil,
                trailing: questions.count > 1 ? "\(index + 1) of \(questions.count)" : request.project,
                onTerminal: { respond(.terminal) }
            )

            Text(question.text)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)

            VStack(spacing: 5) {
                ForEach(Array(options.enumerated()), id: \.offset) { offset, option in
                    QuestionOptionRow(
                        number: offset + 1,
                        option: option,
                        selected: selection.contains(option.label)
                    ) { choose(option) }
                }
                if question.multiSelect {
                    Button { submit(selection.sorted().joined(separator: ", ")) } label: {
                        Text("Submit ⌘↩")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 26)
                            .background(RequestTheme.ask, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(selection.isEmpty)
                    .opacity(selection.isEmpty ? 0.5 : 1)
                }
            }
        }
        .animation(NotchAnimation.state, value: index)
    }

    private func choose(_ option: AgentQuestion.Option) {
        guard question.multiSelect else {
            submit(option.label)
            return
        }
        if selection.contains(option.label) {
            selection.remove(option.label)
        } else {
            selection.insert(option.label)
        }
    }

    private func submit(_ answer: String) {
        answers[question.text] = answer
        selection = []
        if index + 1 < questions.count {
            index += 1
        } else {
            respond(.answer(answers))
        }
    }
}

private struct QuestionOptionRow: View {
    let number: Int
    let option: AgentQuestion.Option
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("⌘\(number)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 26, height: 20)
                    .background(RequestTheme.badgeFill, in: RoundedRectangle(cornerRadius: 5))
                Text(option.label)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                if !option.detail.isEmpty {
                    Text(option.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(RequestTheme.ask)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(hovering || selected ? RequestTheme.optionHover : RequestTheme.optionFill)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character(String(number))), modifiers: .command)
        .onHover { hovering = $0 }
        .animation(NotchAnimation.hover, value: hovering)
    }
}

struct AgentPromptGate<Content: View>: View {
    @ObservedObject var center: AgentRequestCenter
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            if let request = center.current {
                AgentRequestView(request: request) { center.respond(request, with: $0) }
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            } else {
                content
            }
        }
        .animation(NotchAnimation.state, value: center.current?.id)
    }
}
