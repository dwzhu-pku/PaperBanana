import AppKit
import SwiftUI

struct NativeRunPreflightPlan: Equatable, Identifiable {
    enum Workflow: String {
        case generation = "Generation"
        case refinement = "Refinement"
    }

    let workflow: String
    let providerLabel: String
    let modelLabel: String
    let credentialSource: String
    let spendSafetyLabel: String
    let resolution: String
    let aspectRatio: String
    let runID: String
    let runDirectoryURL: URL
    let outputURL: URL
    let requestURL: URL
    let logURL: URL
    let sourceURL: URL?
    let usesPaidProvider: Bool

    var id: String { runID }

    static func generation(request: NativeImageGenerationRequest, runID suppliedRunID: String? = nil) -> NativeRunPreflightPlan {
        let providerPlan = ImageProviderExecutionPlan(requestedModel: request.model, settings: request.settings)
        let isDryRun = request.executionMode == .dryRun
        let runID = suppliedRunID ?? makeGenerationRunID()
        let repoRoot = URL(fileURLWithPath: request.settings.repoPath, isDirectory: true)
        let runDirectory = repoRoot
            .appendingPathComponent("results/native_generate", isDirectory: true)
            .appendingPathComponent(runID, isDirectory: true)
        let outputURL = runDirectory
            .appendingPathComponent("generated_\(request.resolution)")
            .appendingPathExtension("png")
        return NativeRunPreflightPlan(
            workflow: Workflow.generation.rawValue,
            providerLabel: providerPlan.providerLabel,
            modelLabel: providerPlan.modelLabel,
            credentialSource: providerPlan.credentialSourceLabel,
            spendSafetyLabel: isDryRun ? "No provider API spend (local dry run)" : providerPlan.spendSafetyLabel,
            resolution: request.resolution,
            aspectRatio: request.aspectRatio,
            runID: runID,
            runDirectoryURL: runDirectory,
            outputURL: outputURL,
            requestURL: runDirectory.appendingPathComponent("request.json"),
            logURL: runDirectory.appendingPathComponent("events.jsonl"),
            sourceURL: nil,
            usesPaidProvider: !isDryRun && providerPlan.canSpendProviderCredits
        )
    }

    static func refinement(request: NativeRefinementRequest, runID suppliedRunID: String? = nil) -> NativeRunPreflightPlan {
        let providerPlan = ImageProviderExecutionPlan(requestedModel: request.model, settings: request.settings)
        let runID = suppliedRunID ?? makeRefinementRunID(sourceURL: request.sourceURL)
        let repoRoot = URL(fileURLWithPath: request.settings.repoPath, isDirectory: true)
        let runDirectory = repoRoot
            .appendingPathComponent("results/native_refine", isDirectory: true)
            .appendingPathComponent(runID, isDirectory: true)
        let outputURL = runDirectory
            .appendingPathComponent("\(safeFileStem(request.sourceURL.deletingPathExtension().lastPathComponent))_refined_\(request.resolution)")
            .appendingPathExtension("png")
        return NativeRunPreflightPlan(
            workflow: Workflow.refinement.rawValue,
            providerLabel: providerPlan.providerLabel,
            modelLabel: providerPlan.modelLabel,
            credentialSource: providerPlan.credentialSourceLabel,
            spendSafetyLabel: providerPlan.spendSafetyLabel,
            resolution: request.resolution,
            aspectRatio: request.aspectRatio,
            runID: runID,
            runDirectoryURL: runDirectory,
            outputURL: outputURL,
            requestURL: runDirectory.appendingPathComponent("request.json"),
            logURL: runDirectory.appendingPathComponent("events.jsonl"),
            sourceURL: request.sourceURL,
            usesPaidProvider: providerPlan.canSpendProviderCredits
        )
    }

    private static func makeGenerationRunID(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "native_generate_\(formatter.string(from: date))"
    }

    private static func makeRefinementRunID(sourceURL: URL, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "native_refine_\(safeFileStem(sourceURL.deletingPathExtension().lastPathComponent))_\(formatter.string(from: date))"
    }

    private static func safeFileStem(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let safeStem = String(value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return safeStem.isEmpty ? "artifact" : safeStem
    }
}

struct NativeRunPreflightSheet: View {
    let plan: NativeRunPreflightPlan
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(AppDesignSystem.Spacing.lg)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.lg) {
                    if plan.usesPaidProvider {
                        paidProviderWarning
                    }

                    runSummary
                    durableFiles
                }
                .padding(AppDesignSystem.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            Divider()

            footer
                .padding(AppDesignSystem.Spacing.lg)
        }
        .frame(minWidth: 680, idealWidth: 760, minHeight: 520)
        .background(AppDesignSystem.Surfaces.content)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(plan.workflow) preflight confirmation")
        .accessibilityValue(preflightAccessibilitySummary)
        .accessibilityIdentifier("native-run-preflight-sheet")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: AppDesignSystem.Spacing.md) {
            Image(systemName: plan.usesPaidProvider ? "creditcard.trianglebadge.exclamationmark" : "checkmark.shield")
                .font(.title2)
                .foregroundStyle(plan.usesPaidProvider ? AppDesignSystem.SemanticColors.statusStarting : AppDesignSystem.SemanticColors.statusReady)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                Text("Confirm \(plan.workflow)")
                    .font(AppDesignSystem.Typography.title)
                Text("PaperBanana will create a durable run folder before the provider request starts.")
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    private var paidProviderWarning: some View {
        Label {
            Text("This run can spend provider credits. Confirm the model, resolution, and output location before starting.")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(AppDesignSystem.Typography.body)
        .foregroundStyle(AppDesignSystem.SemanticColors.statusStarting)
        .padding(AppDesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppDesignSystem.SemanticColors.statusStarting.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppDesignSystem.SemanticColors.statusStarting.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Provider spend warning")
        .accessibilityValue("This run can spend provider credits. Confirm the model, resolution, and output location before starting.")
        .accessibilityIdentifier("native-run-preflight-paid-provider-warning")
    }

    private var runSummary: some View {
        WorkbenchSection("Run", systemImage: "play.rectangle", subtitle: "Provider, model, credential source, and requested output parameters.") {
            Grid(alignment: .leading, horizontalSpacing: AppDesignSystem.Spacing.lg, verticalSpacing: AppDesignSystem.Spacing.sm) {
                preflightRow("Workflow", plan.workflow)
                preflightRow("Provider", plan.providerLabel)
                preflightRow("Model", plan.modelLabel)
                preflightRow("Credential", plan.credentialSource)
                preflightRow("Spend Safety", plan.spendSafetyLabel)
                preflightRow("Resolution", plan.resolution)
                preflightRow("Aspect Ratio", plan.aspectRatio)
                preflightRow("Run ID", plan.runID, monospaced: true)
                if let sourceURL = plan.sourceURL {
                    preflightRow("Source", sourceURL.path, monospaced: true)
                }
            }
        }
    }

    private var durableFiles: some View {
        WorkbenchSection("Durable Files", systemImage: "folder.badge.gearshape", subtitle: "Created before provider execution so paid calls cannot disappear silently.") {
            Grid(alignment: .leading, horizontalSpacing: AppDesignSystem.Spacing.lg, verticalSpacing: AppDesignSystem.Spacing.sm) {
                preflightRow("Run Folder", plan.runDirectoryURL.path, monospaced: true)
                preflightRow("Output", plan.outputURL.path, monospaced: true)
                preflightRow("Request", plan.requestURL.path, monospaced: true)
                preflightRow("Event Log", plan.logURL.path, monospaced: true)
            }
        }
    }

    private func preflightRow(_ title: String, _ value: String, monospaced: Bool = false) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .font(monospaced ? .system(.caption, design: .monospaced) : AppDesignSystem.Typography.body)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityIdentifier(preflightRowIdentifier(title))
    }

    private var footer: some View {
        HStack(spacing: AppDesignSystem.Spacing.sm) {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([plan.runDirectoryURL.deletingLastPathComponent()])
            } label: {
                Label("Reveal Parent Folder", systemImage: "finder")
            }
            .help("Reveal the parent folder where this run will be created")
            .accessibilityLabel("Reveal parent folder")
            .accessibilityHint("Opens Finder at the folder that will contain this run.")
            .accessibilityIdentifier("native-run-preflight-reveal-parent")

            Spacer()

            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Cancel preflight")
                .accessibilityHint("Dismisses this confirmation without starting the run.")
                .accessibilityIdentifier("native-run-preflight-cancel")

            Button {
                onConfirm()
            } label: {
                Label(plan.usesPaidProvider ? "Confirm Paid Call" : "Start", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel(plan.usesPaidProvider ? "Confirm paid provider call" : "Start run")
            .accessibilityHint(plan.usesPaidProvider ? "Starts this run and may spend provider credits." : "Starts this run without provider API spend.")
            .accessibilityIdentifier("native-run-preflight-confirm")
        }
    }

    private var preflightAccessibilitySummary: String {
        "\(plan.providerLabel), \(plan.modelLabel), \(plan.spendSafetyLabel), \(plan.resolution), \(plan.aspectRatio), run \(plan.runID)."
    }

    private func preflightRowIdentifier(_ title: String) -> String {
        let slug = title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return "native-run-preflight-\(slug)"
    }
}
