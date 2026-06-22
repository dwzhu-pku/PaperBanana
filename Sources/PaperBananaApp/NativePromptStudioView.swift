import AppKit
import SwiftUI

struct NativePromptStudioView: View {
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject var generationStore: NativeImageGenerationStore
    let title: String

    @StateObject private var referenceStore = ReferenceExampleStore()
    @State private var prompt = ""
    @State private var model: ImageModelChoice
    @State private var resolution = "2K"
    @State private var aspectRatio = "16:9"
    @State private var task = "scientific diagram"
    @State private var selectedReferenceIDs = Set<String>()
    @State private var previewImage: NSImage?
    @State private var pendingPreflightPlan: NativeRunPreflightPlan?
    @State private var pendingGenerationRequest: NativeImageGenerationRequest?
    @State private var assistantResult: PaperBananaAssistantResult?
    @State private var assistantIsRunning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let resolutions = ["1K", "2K", "4K"]
    private let aspectRatios = ["1:1", "4:3", "3:2", "16:9", "9:16", "21:9"]
    private let tasks = ["scientific diagram", "publication figure", "workflow schematic", "concept art", "graphical abstract", "statistical plot"]

    init(
        settings: AppSettingsStore,
        generationStore: NativeImageGenerationStore,
        title: String = "Prompt Studio"
    ) {
        self.settings = settings
        self.generationStore = generationStore
        self.title = title
        _model = State(initialValue: settings.defaultImageModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            promptStudioToolbar
            Divider()
            HSplitView {
                promptEditorWorkspace
                    .frame(minWidth: 500, idealWidth: 620)
                runStudioPanel
                    .frame(minWidth: 360, idealWidth: 440)
            }
        }
        .background(AppDesignSystem.Surfaces.content)
        .onAppear {
            consumePendingIntentPrompt()
            loadReferenceExamples()
        }
        .onChange(of: settings.repoPath) { _ in
            loadReferenceExamples()
        }
        .onChange(of: generationStore.outputURL) { outputURL in
            loadPreview(from: outputURL)
        }
        .sheet(item: $pendingPreflightPlan) { plan in
            NativeRunPreflightSheet(
                plan: plan,
                onCancel: clearPendingPreflight,
                onConfirm: confirmPendingGeneration
            )
        }
        .animation(AppDesignSystem.Motion.standard(reduceMotion), value: generationStore.progress)
    }

    private var promptStudioToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AppDesignSystem.Spacing.md) {
                toolbarTitleBlock
                Spacer(minLength: AppDesignSystem.Spacing.lg)
                toolbarActions
            }

            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
                toolbarTitleBlock
                toolbarActions
            }
        }
        .padding(.horizontal, AppDesignSystem.Spacing.lg)
        .padding(.vertical, AppDesignSystem.Spacing.md)
    }

    private var toolbarTitleBlock: some View {
        HStack(spacing: AppDesignSystem.Spacing.md) {
            WorkbenchStatusPill(
                title: generationStore.isRunning ? "Running" : "Ready",
                systemImage: generationStore.isRunning ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill",
                tint: generationStore.isRunning ? AppDesignSystem.SemanticColors.statusStarting : AppDesignSystem.SemanticColors.statusReady
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppDesignSystem.Typography.title)
                Text(settings.repoPath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
    }

    private var toolbarActions: some View {
        HStack(spacing: AppDesignSystem.Spacing.sm) {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([nativeGenerateDirectory])
            } label: {
                Label("Reveal Runs", systemImage: "folder")
            }
            .help("Reveal the native generation results folder")

            if generationStore.isRunning {
                Button(role: .destructive) {
                    generationStore.cancel()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            }
        }
        .controlSize(.small)
    }

    private var promptEditorWorkspace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.lg) {
                promptEditorPanel
            }
            .padding(AppDesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(AppDesignSystem.Surfaces.content)
    }

    private var promptEditorPanel: some View {
        WorkbenchSection(
            "Prompt Editor",
            systemImage: "text.alignleft",
            subtitle: nil
        ) {
            promptEditorToolbar

            WorkbenchEditorSurface(minHeight: 360) {
                TextEditor(text: $prompt)
                    .font(AppDesignSystem.Typography.body)
                    .scrollContentBackground(.hidden)
                    .disabled(generationStore.isRunning)
                    .accessibilityLabel("Image generation prompt")
            }

            promptMetadata

            if let assistantResult {
                assistantReport(assistantResult)
            }
        }
    }

    private var promptEditorToolbar: some View {
        WorkbenchCommandBar {
            Picker("Task", selection: $task) {
                ForEach(tasks, id: \.self) { task in
                    Text(task.capitalized).tag(task)
                }
            }
            .frame(maxWidth: 230)
            .controlSize(.small)

            Divider()
                .frame(height: 18)

            Text("\(promptCharacterCount) chars")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer(minLength: AppDesignSystem.Spacing.sm)

            Button {
                improvePrompt()
            } label: {
                Label(assistantIsRunning ? "Improving" : "Improve", systemImage: "text.badge.sparkles")
            }
            .disabled(
                assistantIsRunning ||
                    generationStore.isRunning ||
                    prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .help("Use the local assistant for prompt cleanup")
            .controlSize(.small)
        }
    }

    private var promptMetadata: some View {
        HStack(spacing: AppDesignSystem.Spacing.md) {
            Label(task.capitalized, systemImage: "scope")
            Label(model.label, systemImage: "cpu")
            Label("\(resolution) \(aspectRatio)", systemImage: "rectangle.inset.filled")
        }
        .font(AppDesignSystem.Typography.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private func assistantReport(_ assistantResult: PaperBananaAssistantResult) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
            Label(
                assistantResult.usedFoundationModels ? "Foundation Models" : "Local fallback",
                systemImage: assistantResult.usedFoundationModels ? "apple.intelligence" : "gearshape"
            )
            .font(AppDesignSystem.Typography.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            Text(assistantResult.text)
                .font(AppDesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(8)

            if let fallbackReason = assistantResult.fallbackReason {
                Text(fallbackReason)
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(AppDesignSystem.SemanticColors.statusStarting)
                    .lineLimit(2)
            }
        }
        .padding(AppDesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppDesignSystem.Surfaces.content,
            in: RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var runStudioPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.lg) {
                PaperBananaReadinessPanel(
                    snapshot: settings.readinessSnapshot(requestedModel: model)
                )
                runControlPanel
                runConfigurationPanel
                referenceExamplesPanel
                outputPreviewPanel
                progressPanel
            }
            .padding(AppDesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(AppDesignSystem.Surfaces.panel)
    }

    private var runControlPanel: some View {
        WorkbenchSection(
            "Run Controls",
            systemImage: "play.rectangle",
            subtitle: nil
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppDesignSystem.Spacing.sm) {
                    runControlButtons
                }
                VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                    runControlButtons
                }
            }
            .controlSize(.small)

            if model != .codexFallback && settings.snapshot.googleAPIKey.isEmpty && settings.snapshot.openRouterAPIKey.isEmpty {
                Label("Provider key missing", systemImage: "key")
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(AppDesignSystem.SemanticColors.statusStarting)
            }

            if !selectedReferenceSelections.isEmpty {
                Label("\(selectedReferenceSelections.count) reference examples selected", systemImage: "quote.bubble")
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var runControlButtons: some View {
        Button {
            startGeneration()
        } label: {
            Label(generationStore.isRunning ? "Running" : "Generate", systemImage: "wand.and.sparkles")
        }
        .buttonStyle(.borderedProminent)
        .disabled(generationStore.isRunning || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .keyboardShortcut(.return, modifiers: [.command])

        Button {
            NSWorkspace.shared.activateFileViewerSelecting([nativeGenerateDirectory])
        } label: {
            Label("Reveal Runs", systemImage: "folder")
        }

        if generationStore.isRunning {
            Button(role: .destructive) {
                generationStore.cancel()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
        }
    }

    private var runConfigurationPanel: some View {
        WorkbenchSection(
            "Run Configuration",
            systemImage: "slider.horizontal.3",
            subtitle: nil
        ) {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
                modelPicker
                HStack(spacing: AppDesignSystem.Spacing.md) {
                    resolutionPicker
                    aspectRatioPicker
                }
            }
            .controlSize(.small)
        }
        .disabled(generationStore.isRunning)
    }

    private var referenceExamplesPanel: some View {
        ReferenceExamplePickerView(
            store: referenceStore,
            selectedIDs: $selectedReferenceIDs,
            task: task,
            isRunning: generationStore.isRunning
        )
    }

    private var promptCharacterCount: Int {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    private var progressPanel: some View {
        WorkbenchSection(
            "Run Timeline",
            systemImage: "waveform.path.ecg.rectangle",
            subtitle: "Every paid provider call is tracked before execution and surfaced here."
        ) {
            HStack {
                Text(generationStore.statusMessage)
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(generationStore.isStalled ? AppDesignSystem.SemanticColors.statusStarting : .secondary)
                    .textSelection(.enabled)
                Spacer()
                Text("\(generationStore.progress)%")
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(generationStore.progress), total: 100)
                .progressViewStyle(.linear)

            runFacts
            milestoneList
        }
    }

    private var runFacts: some View {
        Grid(alignment: .leading, horizontalSpacing: AppDesignSystem.Spacing.md, verticalSpacing: AppDesignSystem.Spacing.xs) {
            if !generationStore.runID.isEmpty {
                GridRow {
                    Text("Run").foregroundStyle(.secondary)
                    Text(generationStore.runID)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
            GridRow {
                Text("Elapsed").foregroundStyle(.secondary)
                Text(NativeRefinementStore.formatDuration(generationStore.elapsedSeconds))
                    .font(.system(.caption, design: .monospaced))
            }
            GridRow {
                Text("Last event").foregroundStyle(.secondary)
                Text(NativeRefinementStore.formatDuration(generationStore.secondsSinceLastEvent))
                    .font(.system(.caption, design: .monospaced))
            }
            if let runDirectoryURL = generationStore.runDirectoryURL {
                GridRow {
                    Text("Folder").foregroundStyle(.secondary)
                    Text(runDirectoryURL.path)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
            if let providerRequestURL = generationStore.providerRequestURL {
                GridRow {
                    Text("Provider request").foregroundStyle(.secondary)
                    Text(providerRequestURL.lastPathComponent)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
            if !generationStore.providerCallID.isEmpty {
                GridRow {
                    Text("Provider call").foregroundStyle(.secondary)
                    Text(generationStore.providerCallID)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
            if let rawResponseURL = generationStore.rawResponseURL {
                GridRow {
                    Text("Raw response").foregroundStyle(.secondary)
                    Text(rawResponseURL.lastPathComponent)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
            if let rawPayloadURL = generationStore.rawPayloadURL {
                GridRow {
                    Text("Raw payload").foregroundStyle(.secondary)
                    Text(rawPayloadURL.lastPathComponent)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
        }
        .font(AppDesignSystem.Typography.caption)
    }

    private var milestoneList: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
            ForEach(generationStore.milestones) { milestone in
                HStack(spacing: AppDesignSystem.Spacing.sm) {
                    Image(systemName: milestoneSymbol(milestone.state))
                        .foregroundStyle(milestoneColor(milestone.state))
                        .frame(width: 16)
                    Text(milestone.title)
                        .foregroundStyle(milestone.state == .pending ? .secondary : .primary)
                    Spacer()
                }
            }
        }
    }

    private var outputPreviewPanel: some View {
        WorkbenchSection(
            "Output Preview",
            systemImage: "photo",
            subtitle: existingOutputURL?.lastPathComponent
        ) {
            Group {
                if let previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, minHeight: 220, idealHeight: 280, maxHeight: 340)
                        .background(
                            AppDesignSystem.Surfaces.panel,
                            in: RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                                .stroke(.quaternary, lineWidth: 1)
                        }
                } else {
                    ArtifactEmptyStateView(
                        title: "No Image Yet",
                        systemImage: "photo",
                        description: "Generated images appear here after the native run completes."
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
            .frame(maxWidth: .infinity)

            outputActions
        }
    }

    private var outputActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppDesignSystem.Spacing.sm) {
                outputActionButtons
            }
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                outputActionButtons
            }
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var outputActionButtons: some View {
        if let outputURL = existingOutputURL {
            Button {
                NSWorkspace.shared.open(outputURL)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderedProminent)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([outputURL])
            } label: {
                Label("Reveal", systemImage: "finder")
            }
        }
        if let runDirectoryURL = generationStore.runDirectoryURL {
            Button {
                NSWorkspace.shared.open(runDirectoryURL)
            } label: {
                Label("Run Folder", systemImage: "folder")
            }
        }
        if let logURL = generationStore.logURL {
            Button {
                NSWorkspace.shared.open(logURL)
            } label: {
                Label("Log", systemImage: "doc.text")
            }
        }
        if let requestURL = generationStore.requestURL {
            Button {
                NSWorkspace.shared.open(requestURL)
            } label: {
                Label("Request", systemImage: "doc.badge.gearshape")
            }
        }
        if let providerRequestURL = generationStore.providerRequestURL {
            Button {
                NSWorkspace.shared.open(providerRequestURL)
            } label: {
                Label("Provider Request", systemImage: "doc.plaintext")
            }
        }
        if let metadataURL = generationStore.metadataURL {
            Button {
                NSWorkspace.shared.open(metadataURL)
            } label: {
                Label("Metadata", systemImage: "curlybraces")
            }
        }
        if let rawResponseURL = generationStore.rawResponseURL {
            Button {
                NSWorkspace.shared.open(rawResponseURL)
            } label: {
                Label("Raw Response", systemImage: "doc.zipper")
            }
        }
        if let rawPayloadURL = generationStore.rawPayloadURL {
            Button {
                NSWorkspace.shared.open(rawPayloadURL)
            } label: {
                Label("Raw Payload", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private var modelPicker: some View {
        WorkbenchOptionField("Model") {
            Picker("Model", selection: $model) {
                ForEach(ImageModelChoice.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            .labelsHidden()
            .accessibilityLabel("Image model")
        }
    }

    private var resolutionPicker: some View {
        WorkbenchOptionField("Resolution") {
            Picker("Resolution", selection: $resolution) {
                ForEach(resolutions, id: \.self) { value in
                    Text(value).tag(value)
                }
            }
            .labelsHidden()
            .accessibilityLabel("Resolution")
        }
    }

    private var aspectRatioPicker: some View {
        WorkbenchOptionField("Aspect Ratio") {
            Picker("Aspect Ratio", selection: $aspectRatio) {
                ForEach(aspectRatios, id: \.self) { value in
                    Text(value).tag(value)
                }
            }
            .labelsHidden()
            .accessibilityLabel("Aspect ratio")
        }
    }

    private var nativeGenerateDirectory: URL {
        URL(fileURLWithPath: settings.repoPath, isDirectory: true)
            .appendingPathComponent("results/native_generate", isDirectory: true)
    }

    private var existingOutputURL: URL? {
        guard let outputURL = generationStore.outputURL,
              FileManager.default.fileExists(atPath: outputURL.path)
        else {
            return nil
        }
        return outputURL
    }

    private func startGeneration() {
        settings.defaultImageModel = model
        settings.persistNonSecretSettings()
        let request = NativeImageGenerationRequest(
            prompt: prompt,
            model: model,
            resolution: resolution,
            aspectRatio: aspectRatio,
            task: task,
            settings: settings.snapshot,
            referenceExamples: selectedReferenceSelections
        )
        let plan = NativeRunPreflightPlan.generation(request: request)
        pendingGenerationRequest = request
        pendingPreflightPlan = plan
    }

    private func confirmPendingGeneration() {
        guard let request = pendingGenerationRequest,
              let plan = pendingPreflightPlan
        else {
            clearPendingPreflight()
            return
        }
        clearPendingPreflight()
        generationStore.start(request: request.withPreflightRunID(plan.runID)) { outputURL in
            Task { @MainActor in
                loadPreview(from: outputURL)
            }
        }
    }

    private func clearPendingPreflight() {
        pendingGenerationRequest = nil
        pendingPreflightPlan = nil
    }

    private func improvePrompt() {
        let currentPrompt = prompt
        assistantIsRunning = true
        assistantResult = nil
        Task {
            let result = await PaperBananaFoundationAssistant.run(
                task: .improvePrompt,
                input: currentPrompt,
                context: "Task: \(task). Resolution: \(resolution). Aspect ratio: \(aspectRatio)."
            )
            await MainActor.run {
                assistantResult = result
                prompt = result.text
                assistantIsRunning = false
            }
        }
    }

    private func consumePendingIntentPrompt() {
        let key = "paperbanana.intent.prompt"
        guard let pendingPrompt = UserDefaults.standard.string(forKey: key),
              pendingPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            return
        }
        prompt = pendingPrompt
        UserDefaults.standard.removeObject(forKey: key)
    }

    private var selectedReferenceSelections: [ReferenceExampleSelection] {
        guard !task.localizedCaseInsensitiveContains("plot") else { return [] }
        return referenceStore.selectedExamples(for: selectedReferenceIDs)
    }

    private func loadReferenceExamples() {
        referenceStore.load(repoRootPath: settings.repoPath)
        selectedReferenceIDs = ReferenceExampleSelection.limitedIDs(
            selectedReferenceIDs,
            orderedExamples: referenceStore.state.examples
        )
    }

    private func loadPreview(from outputURL: URL?) {
        guard let outputURL,
              FileManager.default.fileExists(atPath: outputURL.path),
              let image = NSImage(contentsOf: outputURL)
        else {
            previewImage = nil
            return
        }
        previewImage = image
    }

    private func milestoneSymbol(_ state: NativeRefinementMilestoneState) -> String {
        switch state {
        case .pending: "circle"
        case .active: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .recovered: "shippingbox.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .cancelled: "stop.circle.fill"
        case .timedOut: "clock.badge.exclamationmark.fill"
        }
    }

    private func milestoneColor(_ state: NativeRefinementMilestoneState) -> Color {
        switch state {
        case .pending: .secondary
        case .active: AppDesignSystem.SemanticColors.statusStarting
        case .completed: AppDesignSystem.SemanticColors.statusReady
        case .recovered: AppDesignSystem.SemanticColors.statusRecovered
        case .failed: AppDesignSystem.SemanticColors.statusFailed
        case .cancelled: AppDesignSystem.SemanticColors.statusCancelled
        case .timedOut: AppDesignSystem.SemanticColors.statusTimedOut
        }
    }
}
