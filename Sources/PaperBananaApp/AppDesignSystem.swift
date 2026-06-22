import SwiftUI

enum AppDesignSystem {
    enum Spacing {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }

    enum Layout {
        static let sidebarWidth: CGFloat = 320
        static let activityRailWidth: CGFloat = 52
        static let sidebarRowHeight: CGFloat = 30
        static let sidebarHorizontalPadding: CGFloat = 14
        static let activityButtonSize: CGFloat = 34
    }

    enum Radius {
        static let control: CGFloat = 6
        static let panel: CGFloat = 8
        static let workbench: CGFloat = 10
    }

    enum Typography {
        static let title = Font.system(.title2, design: .rounded, weight: .semibold)
        static let headline = Font.system(.headline, design: .default, weight: .semibold)
        static let body = Font.system(.body, design: .default)
        static let caption = Font.system(.caption, design: .default)
    }

    enum SemanticColors {
        static let accent = Color.orange
        static let sidebarLabel = Color.primary.opacity(0.74)
        static let statusReady = Color.green
        static let statusStarting = Color.orange
        static let statusRecovered = Color.green
        static let statusFailed = Color.red
        static let statusCancelled = Color.gray
        static let statusTimedOut = Color.orange
    }

    enum Surfaces {
        static let content = Color(nsColor: .windowBackgroundColor)
        static let panel = Color(nsColor: .controlBackgroundColor)
        static let sidebar = Color(nsColor: .underPageBackgroundColor)
        static let activityRail = Color(nsColor: .controlBackgroundColor)
    }

    enum Motion {
        static let quick = Animation.easeInOut(duration: 0.12)

        static func standard(_ reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .easeInOut(duration: 0.18)
        }
    }
}

protocol AppFilterOption: CaseIterable, Hashable, Identifiable {
    var label: String { get }
}

struct PaperBananaAssistantPanel: View {
    let title: String
    let tasks: [PaperBananaAssistantTask]
    let input: String
    let context: String
    let imageURL: URL?

    @State private var selectedTask: PaperBananaAssistantTask
    @State private var result: PaperBananaAssistantResult?
    @State private var isRunning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        title: String,
        tasks: [PaperBananaAssistantTask],
        input: String,
        context: String = "",
        imageURL: URL? = nil
    ) {
        let availableTasks = tasks.isEmpty ? [PaperBananaAssistantTask.improvePrompt] : tasks
        self.title = title
        self.tasks = availableTasks
        self.input = input
        self.context = context
        self.imageURL = imageURL
        _selectedTask = State(initialValue: availableTasks[0])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: AppDesignSystem.Spacing.md) {
                Label(title, systemImage: "sparkles")
                    .font(AppDesignSystem.Typography.headline)
                Spacer(minLength: AppDesignSystem.Spacing.sm)
                Picker("Assistant task", selection: $selectedTask) {
                    ForEach(tasks, id: \.self) { task in
                        Text(task.label).tag(task)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 190)
                Button {
                    runAssistant()
                } label: {
                    Label(isRunning ? "Running" : "Run", systemImage: "play.circle")
                }
                .disabled(isRunning || !canRun)
            }

            if isRunning {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("PaperBanana assistant is running")
            }

            if let result {
                VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                    Text(result.usedFoundationModels ? "Foundation Models" : "Local fallback")
                        .font(AppDesignSystem.Typography.caption.weight(.semibold))
                        .foregroundStyle(result.usedFoundationModels ? AppDesignSystem.SemanticColors.statusReady : .secondary)
                    if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                        Text(fallbackReason)
                            .font(AppDesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Text(result.text)
                        .font(AppDesignSystem.Typography.caption)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AppDesignSystem.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppDesignSystem.Surfaces.content, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(AppDesignSystem.Spacing.md)
        .background(AppDesignSystem.Surfaces.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .animation(AppDesignSystem.Motion.standard(reduceMotion), value: isRunning)
        .animation(AppDesignSystem.Motion.standard(reduceMotion), value: result?.text)
    }

    private var canRun: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || imageURL != nil
    }

    private func runAssistant() {
        let task = selectedTask
        let inputSnapshot = input
        let contextSnapshot = context
        let imageSnapshot = imageURL
        isRunning = true
        result = nil

        Task {
            let assistantResult = await PaperBananaFoundationAssistant.run(
                task: task,
                input: inputSnapshot,
                imageURL: imageSnapshot,
                context: contextSnapshot
            )
            await MainActor.run {
                result = assistantResult
                isRunning = false
            }
        }
    }
}
