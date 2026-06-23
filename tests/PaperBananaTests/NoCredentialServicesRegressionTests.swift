import XCTest

final class NoCredentialServicesRegressionTests: XCTestCase {
    func testAppRootContainerDoesNotAutoStartLegacyBackend() throws {
        let repoRoot = Self.repoRoot()
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/AppRootContainer.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(
            source.contains("backend.start("),
            "AppRootContainer must not start the legacy Gradio backend during native app launch."
        )
        XCTAssertFalse(
            source.contains("backend.restart("),
            "AppRootContainer must not restart the legacy Gradio backend during native app launch."
        )
        XCTAssertTrue(
            source.contains("PaperBananaWindowPlacement.minimumUsableWindowWidth") &&
                source.contains("PaperBananaWindowPlacement.minimumUsableWindowHeight"),
            "AppRootContainer should share the AppKit window minimums instead of hard-coding a stale SwiftUI content minimum."
        )
        XCTAssertFalse(
            source.contains(".frame(minWidth: 1120"),
            "AppRootContainer must not keep the obsolete 1120-point minimum that clips wider native split views."
        )
    }

    func testRootChromeDoesNotExposeLegacyBackendControlsGlobally() throws {
        let repoRoot = Self.repoRoot()
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/RootView.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/PaperBananaApp.swift"),
            encoding: .utf8
        )
        let rootChrome = source.components(separatedBy: "private func applyPendingIntentDestination").first ?? source

        XCTAssertFalse(
            rootChrome.contains("backend.restart("),
            "RootView primary chrome must not expose global legacy backend restart controls."
        )
        XCTAssertFalse(
            rootChrome.contains(#"Label("Open in Browser""#),
            "RootView primary chrome must not expose global legacy Gradio browser controls."
        )
        XCTAssertFalse(
            source.contains("LegacyPipelineWorkspaceView"),
            "Root routing must not fall through to the legacy web pipeline."
        )
        XCTAssertFalse(
            source.contains("WebContainerView"),
            "Root routing must stay native and must not embed the legacy Gradio web view."
        )
        XCTAssertFalse(
            appSource.contains("Restart Legacy Backend"),
            "The app command menu must not promote legacy backend controls globally."
        )
    }

    func testRuntimeSidebarDoesNotSurfaceLegacyBackendStatus() throws {
        let repoRoot = Self.repoRoot()
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/RootSidebarView.swift"),
            encoding: .utf8
        )
        let projectSection = source.section(after: "private struct RootRuntimeBlock", before: "private struct RootSidebarCommandRow")

        XCTAssertTrue(
            projectSection.contains(#"Text("Native Ready")"#) &&
                projectSection.contains("AppDesignSystem.SemanticColors.statusReady"),
            "Root runtime sidebar should lead with native readiness."
        )
        XCTAssertFalse(
            projectSection.contains("Legacy backend"),
            "Root runtime sidebar must not promote legacy Gradio backend status."
        )
        XCTAssertFalse(
            projectSection.contains("statusText"),
            "Root runtime sidebar should not bind primary runtime state to the legacy backend."
        )
    }

    func testRootSidebarUsesBoundedCommandRailWithoutHorizontalContentForcing() throws {
        let repoRoot = Self.repoRoot()
        let rootSource = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/RootView.swift"),
            encoding: .utf8
        )
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/RootSidebarView.swift"),
            encoding: .utf8
        )
        let designSystem = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/AppDesignSystem.swift"),
            encoding: .utf8
        )
        let rootSidebar = source.section(after: "struct RootSidebarView", before: "private struct RootSidebarNavigationPane")
        let activityRail = source.section(after: "private struct RootActivityRail", before: "private struct RootActivityRailButton")
        let navigationPane = source.section(after: "private struct RootSidebarNavigationPane", before: "private struct RootActivityRail")

        XCTAssertTrue(
            rootSource.contains("RootSidebarView(settings: settings, selection: $selection)"),
            "RootView should delegate root navigation to the dedicated rebuilt sidebar component."
        )

        XCTAssertTrue(
            rootSource.contains(".frame(width: AppDesignSystem.Layout.sidebarWidth)"),
            "Root sidebar must be physically bounded to the design-system sidebar width."
        )
        XCTAssertTrue(
            rootSource.contains(".clipped()"),
            "Root sidebar must clip to its own column so rows cannot draw under the window edge."
        )
        XCTAssertTrue(
            designSystem.contains("static let sidebarWidth: CGFloat = 320") &&
                designSystem.contains("static let activityRailWidth: CGFloat = 52") &&
                designSystem.contains("static let activityButtonSize: CGFloat = 34"),
            "Root workbench geometry should be centralized in AppDesignSystem."
        )
        XCTAssertTrue(
            rootSidebar.contains("RootActivityRail(selection: $selection)") &&
                rootSidebar.contains("RootSidebarNavigationPane(settings: settings, selection: $selection)") &&
                rootSidebar.contains(".frame(width: AppDesignSystem.Layout.sidebarWidth)"),
            "Root sidebar should be a two-zone pro workbench shell with a compact activity rail and bounded navigation pane."
        )
        XCTAssertTrue(
            activityRail.contains(".frame(width: AppDesignSystem.Layout.activityRailWidth)") &&
                activityRail.contains("RootActivityRailButton") &&
                activityRail.contains(".promptStudio") &&
                activityRail.contains(".recoveredImages") &&
                activityRail.contains(".runDetails") &&
                activityRail.contains(".runLedger"),
            "Root activity rail should provide compact Nova-like access to major workbench areas."
        )
        XCTAssertTrue(
            source.contains("RootSidebarCommandRow"),
            "Root sidebar must use the rebuilt bounded command row, not the old selectable-row stack."
        )
        XCTAssertFalse(
            [rootSidebar, activityRail, navigationPane].contains { $0.contains(".frame(minWidth: 300") },
            "Sidebar child content must not force itself wider than the restored split column."
        )
        XCTAssertFalse(
            source.contains("NavigationSplitView"),
            "Root sidebar must not reintroduce inherited split-view sidebar geometry."
        )
        XCTAssertFalse(
            source.contains("List(selection:"),
            "Root sidebar must not reintroduce the source-list implementation that still clipped in the installed app."
        )
        XCTAssertFalse(
            source.contains("private struct SidebarSelectableRow"),
            "Root navigation must not use the custom button row that previously clipped under narrow restored columns."
        )
        XCTAssertFalse(
            source.contains("pipelineEvolution") || source.contains("Gradio Pipeline UI"),
            "Root sidebar must not expose the legacy Gradio pipeline as a primary destination."
        )
        XCTAssertTrue(
            source.contains("showSettingsWindow:") && source.contains(#"Text("Settings")"#),
            "Root sidebar should open the native macOS Settings scene instead of embedding settings in the main workbench."
        )
        XCTAssertTrue(
            designSystem.contains("sidebarSelectionFill") &&
                designSystem.contains("sidebarSelectionStroke") &&
                designSystem.contains("Color(nsColor: .selectedContentBackgroundColor)") &&
                source.contains("AppDesignSystem.Adaptive.sidebarSelectionFill") &&
                source.contains("AppDesignSystem.Adaptive.sidebarSelectionStroke") &&
                source.contains("@Environment(\\.colorScheme)"),
            "Root sidebar should use dedicated adaptive sidebar selection tokens so Light Mode selected rows stay visible at increased text size and minimum width."
        )
        XCTAssertFalse(
            source.contains("AppDesignSystem.Adaptive.selectionFill(contrast: colorSchemeContrast)") ||
                source.contains("AppDesignSystem.Adaptive.selectionStroke(contrast: colorSchemeContrast)"),
            "Root sidebar must not reuse the generic low-opacity selection token for primary navigation selection."
        )
    }

    func testArtifactLibraryUsesRebuiltScopeStripWithoutLegacyFilterSearchBar() throws {
        let repoRoot = Self.repoRoot()
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/ArtifactLibraryView.swift"),
            encoding: .utf8
        )
        let scopeStrip = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/WorkspaceScopeStrip.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains("WorkspaceScopeStrip"),
            "Artifact browser should use the shared rebuilt native scope strip."
        )
        XCTAssertTrue(
            scopeStrip.contains(".pickerStyle(.segmented)"),
            "Artifact scope should use a compact segmented native control."
        )
        XCTAssertTrue(
            scopeStrip.contains("WorkspaceSearchField"),
            "Artifact browser should use the bounded search field owned by the rebuilt workspace strip."
        )
        XCTAssertFalse(
            source.contains("ArtifactLibraryFilterBar"),
            "Artifact browser must not reintroduce the old filter/search wrapper."
        )
        XCTAssertFalse(
            source.contains("AppFilterSearchBar("),
            "Artifact browser must not use the legacy filter component that previously produced cluttered filter layout."
        )
        XCTAssertFalse(
            source.contains(#".searchable(text: $searchText"#),
            "Artifact browser should not show both toolbar search and inline search at the same time."
        )
    }

    func testRunAndLedgerWorkspacesUseRebuiltScopeStripsWithoutLegacyFilterSearchBar() throws {
        let repoRoot = Self.repoRoot()
        let runDetails = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/RunDetailsView.swift"),
            encoding: .utf8
        )
        let runList = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/RunDetailsRunListView.swift"),
            encoding: .utf8
        )
        let ledger = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/ProviderRunLedgerView.swift"),
            encoding: .utf8
        )
        let designSystem = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/AppDesignSystem.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(
            runDetails.contains("WorkspaceScopeStrip"),
            "Run Details should use the rebuilt shared native scope strip."
        )
        XCTAssertTrue(
            ledger.contains("WorkspaceScopeStrip"),
            "Run Ledger should use the rebuilt shared native scope strip."
        )
        XCTAssertTrue(
            ledger.contains("prefersStackedLayout: true"),
            "Run Ledger has too many scope segments for a single-row strip and must use the stacked workspace layout."
        )
        XCTAssertFalse(
            runDetails.contains(#".searchable(text: $searchText"#),
            "Run Details must not show both toolbar search and inline search at the same time."
        )
        XCTAssertFalse(
            ledger.contains(#".searchable(text: $searchText"#),
            "Run Ledger must not show both toolbar search and inline search at the same time."
        )
        XCTAssertFalse(
            runList.contains("RunDetailsFilterBar"),
            "Run Details must not reintroduce the old wrapper around the filter/search control."
        )
        XCTAssertFalse(
            ledger.contains("ProviderRunLedgerFilterBar"),
            "Run Ledger must not reintroduce the old wrapper around the filter/search control."
        )
        XCTAssertFalse(
            [runDetails, runList, ledger, designSystem].contains { $0.contains("AppFilterSearchBar(") || $0.contains("struct AppFilterSearchBar") },
            "The legacy AppFilterSearchBar must stay out of rebuilt workspaces and the design system."
        )
    }

    func testNativeKeyboardAndAccessibilityLandmarksRemainNamed() throws {
        let repoRoot = Self.repoRoot()
        let scopeStrip = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/WorkspaceScopeStrip.swift"),
            encoding: .utf8
        )
        let runList = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/RunDetailsRunListView.swift"),
            encoding: .utf8
        )
        let ledger = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/ProviderRunLedgerView.swift"),
            encoding: .utf8
        )
        let artifactLibrary = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/ArtifactLibraryView.swift"),
            encoding: .utf8
        )
        let artifactInspector = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/ArtifactInspectorComponents.swift"),
            encoding: .utf8
        )
        let promptStudio = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/NativePromptStudioView.swift"),
            encoding: .utf8
        )
        let referencePicker = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/ReferenceExamplePickerView.swift"),
            encoding: .utf8
        )
        let preflightSheet = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/NativeRunPreflightPlan.swift"),
            encoding: .utf8
        )
        let artifactCard = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/ArtifactLibraryPreviewComponents.swift"),
            encoding: .utf8
        )
        let workbench = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/WorkbenchComponents.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(scopeStrip.contains(".accessibilityIdentifier(searchAccessibilityIdentifier)"))
        XCTAssertTrue(scopeStrip.contains(".accessibilityValue(searchAccessibilityValue)"))
        XCTAssertTrue(runList.contains(#".accessibilityIdentifier("run-details-table")"#))
        XCTAssertTrue(runList.contains(#".accessibilityHint("Use the arrow keys to select a run and review its details.")"#))
        XCTAssertTrue(runList.contains(".accessibilityChildren"))
        XCTAssertTrue(runList.contains(#"identifier: "run-details-table-selection-summary""#))
        XCTAssertTrue(runList.contains(#"title: "Selected run""#))
        XCTAssertTrue(ledger.contains(#".accessibilityIdentifier("provider-run-ledger-table")"#))
        XCTAssertTrue(ledger.contains(#".accessibilityHint("Use the arrow keys to select a provider call and review its details.")"#))
        XCTAssertTrue(ledger.contains(".accessibilityChildren"))
        XCTAssertTrue(ledger.contains(#"identifier: "provider-run-ledger-table-selection-summary""#))
        XCTAssertTrue(ledger.contains(#"title: "Selected provider call""#))
        XCTAssertTrue(
            workbench.contains("struct NativeTableSelectionSummary") &&
                workbench.contains(".accessibilityLabel(title)") &&
                workbench.contains(".accessibilityValue(value)"),
            "Native tables should expose a shared selected-row summary that assistive technology can read when AppKit's AXOutline focus label is too terse."
        )
        XCTAssertTrue(artifactLibrary.contains(#".accessibilityIdentifier("artifact-grid")"#))
        XCTAssertTrue(artifactLibrary.contains(#".accessibilityIdentifier("artifact-card-\(artifact.relativePath)")"#))
        XCTAssertTrue(artifactLibrary.contains(#".accessibilityIdentifier("artifact-actions-\(artifact.relativePath)")"#))
        XCTAssertTrue(artifactLibrary.contains(#"Label("Artifact Actions", systemImage: "ellipsis.circle")"#))
        XCTAssertTrue(artifactLibrary.contains(#".accessibilityLabel("Artifact Actions")"#))
        XCTAssertTrue(artifactLibrary.contains("private func artifactActions(for artifact: PaperBananaArtifact)"))
        XCTAssertTrue(artifactLibrary.contains(#".buttonStyle(.plain)"#))
        XCTAssertFalse(
            artifactLibrary.contains(".onTapGesture {\n                            store.selectedArtifactID = artifact.id"),
            "Artifact cards should remain keyboard-activatable Buttons, not pointer-only tap targets."
        )
        XCTAssertTrue(artifactCard.contains(#".accessibilityHint("Selects this artifact for preview and actions.")"#))
        XCTAssertTrue(artifactCard.contains(".accessibilityAddTraits(isSelected ? [.isSelected] : [])"))
        XCTAssertTrue(
            artifactInspector.contains(#".padding(.bottom, AppDesignSystem.Spacing.lg)"#),
            "Artifact inspector scroll content should keep breathing room above the fixed action footer."
        )
        XCTAssertTrue(
            artifactInspector.contains(#".accessibilityLabel("Export Image")"#) &&
                artifactInspector.contains(#".accessibilityLabel("Export Bundle With Metadata")"#),
            "Compact artifact export buttons should expose descriptive accessibility labels."
        )
        XCTAssertTrue(
            artifactInspector.contains(#""Only image artifacts can be exported as images.""#) &&
                artifactInspector.contains(#".accessibilityLabel(artifact.wasNativeRefined ? "Refine Again" : "Refine Image")"#) &&
                artifactInspector.contains(#""Only image artifacts can be refined.""#),
            "Disabled artifact image/refine actions should explain their image-only requirement to assistive technology."
        )
        XCTAssertTrue(
            referencePicker.contains(#".accessibilityIdentifier("reference-examples-panel")"#) &&
                referencePicker.contains(#".accessibilityIdentifier("reference-examples-selection-summary")"#) &&
                referencePicker.contains(#".accessibilityIdentifier("reference-example-\(example.id)")"#),
            "Reference examples should expose stable panel, summary, and row landmarks for keyboard and VoiceOver review."
        )
        XCTAssertTrue(
            referencePicker.contains(".accessibilityAddTraits(isSelected ? [.isSelected] : [])") &&
                referencePicker.contains("Selection limit reached. Clear another example before selecting this one.") &&
                referencePicker.contains("Reference selection is disabled while a native run is active."),
            "Reference example rows should announce selected, running-disabled, and selection-limit states."
        )
        XCTAssertTrue(
            preflightSheet.contains(#".accessibilityIdentifier("native-run-preflight-sheet")"#) &&
                preflightSheet.contains(#".accessibilityLabel("\(plan.workflow) preflight confirmation")"#) &&
                preflightSheet.contains(".accessibilityValue(preflightAccessibilitySummary)"),
            "The native preflight sheet should expose a stable confirmation landmark and a concise run summary."
        )
        XCTAssertTrue(
            preflightSheet.contains(".accessibilityElement(children: .combine)") &&
                preflightSheet.contains(".accessibilityIdentifier(preflightRowIdentifier(title))") &&
                preflightSheet.contains(#".accessibilityIdentifier("native-run-preflight-paid-provider-warning")"#),
            "Preflight rows and spend warnings should be read as combined label/value elements rather than disconnected grid text."
        )
        XCTAssertTrue(
            preflightSheet.contains(#".accessibilityIdentifier("native-run-preflight-reveal-parent")"#) &&
                preflightSheet.contains(#".accessibilityIdentifier("native-run-preflight-cancel")"#) &&
                preflightSheet.contains(#".accessibilityIdentifier("native-run-preflight-confirm")"#) &&
                preflightSheet.contains(#".keyboardShortcut(.cancelAction)"#) &&
                preflightSheet.contains(#".keyboardShortcut(.defaultAction)"#),
            "Preflight footer actions should keep named keyboard-reachable controls."
        )
        XCTAssertTrue(promptStudio.contains("@FocusState private var focusedElement"))
        XCTAssertTrue(promptStudio.contains("enum PromptStudioFocusTarget"))
        XCTAssertTrue(promptStudio.contains(#".keyboardShortcut("r", modifiers: [.command, .option])"#))
        XCTAssertTrue(promptStudio.contains(#".keyboardShortcut("p", modifiers: [.command, .option])"#))
        XCTAssertTrue(promptStudio.contains(".focused($focusedElement, equals: .promptEditor)"))
        XCTAssertTrue(promptStudio.contains(".focused($focusedElement, equals: .runButton)"))
        XCTAssertTrue(promptStudio.contains(".onKeyPress(phases: .down)"))
        XCTAssertTrue(promptStudio.contains(#"keyPress.characters.lowercased()"#))
        XCTAssertTrue(
            promptStudio.contains("Press Command-Option-R to move keyboard focus to Run Controls.") &&
                promptStudio.contains("Press Command-Option-P to return to the prompt editor."),
            "Prompt Studio should expose an explicit keyboard path out of the multiline prompt editor because Tab is text input there."
        )
    }

    func testPromptStudioUsesNativeWorkbenchSectionsInsteadOfLegacyPanelStack() throws {
        let repoRoot = Self.repoRoot()
        let promptStudio = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/NativePromptStudioView.swift"),
            encoding: .utf8
        )
        let referencePicker = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/ReferenceExamplePickerView.swift"),
            encoding: .utf8
        )
        let workbench = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/WorkbenchComponents.swift"),
            encoding: .utf8
        )
        let designSystem = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/AppDesignSystem.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(
            promptStudio.contains("WorkbenchSection("),
            "Prompt Studio should use the rebuilt native workbench section component."
        )
        XCTAssertTrue(
            promptStudio.contains("WorkbenchOptionField"),
            "Prompt Studio run options should use shared native workbench option fields."
        )
        XCTAssertTrue(
            promptStudio.contains("promptEditorWorkspace") && promptStudio.contains("runStudioPanel"),
            "Prompt Studio should use the rebuilt editor/workbench plus run inspector anatomy."
        )
        XCTAssertTrue(
            promptStudio.contains(#".frame(minWidth: 500, idealWidth: 620)"#) &&
                promptStudio.contains(#".frame(minWidth: 360, idealWidth: 440)"#),
            "Prompt Studio should use the new bounded native workbench split widths."
        )
        XCTAssertTrue(
            promptStudio.contains("WorkbenchCommandBar") && promptStudio.contains("WorkbenchEditorSurface"),
            "Prompt Studio should use shared native command/editor workbench components."
        )
        XCTAssertTrue(
            promptStudio.contains(#""Output Preview""#) && promptStudio.contains("outputPreviewPanel"),
            "Prompt Studio should present output as a sectioned native preview panel."
        )
        XCTAssertTrue(
            promptStudio.contains("ReferenceExamplePickerView") && promptStudio.contains("referenceExamplesPanel"),
            "Prompt Studio should expose manual PaperBananaBench examples as a compact native workbench section."
        )
        XCTAssertTrue(
            promptStudio.contains("@State private var isDryRun") &&
                promptStudio.contains(#"Toggle("No-spend dry run""#) &&
                promptStudio.contains("executionMode: isDryRun ? .dryRun : .live") &&
                promptStudio.contains(#"isDryRun ? "Dry Run" : "Generate""#),
            "Prompt Studio should expose the native no-spend dry run path without routing users through a separate legacy planner surface."
        )
        XCTAssertTrue(
            promptStudio.contains(#""statistical plot""#),
            "Prompt Studio should keep the native statistical plot task available."
        )
        XCTAssertTrue(
            promptStudio.contains("ReferenceExampleBenchmarkTask(taskName: task)") &&
                promptStudio.contains("loadedReferenceBenchmarkTask") &&
                promptStudio.contains("nextBenchmarkTask != loadedReferenceBenchmarkTask"),
            "Prompt Studio should load task-specific reference examples without clearing compatible same-family selections."
        )
        XCTAssertFalse(
            promptStudio.contains(".onChange(of: task) { _ in\n            loadReferenceExamples(resetSelection: true)"),
            "Prompt Studio task label changes should not clear compatible same-family reference selections."
        )
        XCTAssertTrue(
            referencePicker.contains("Optional manual PaperBananaBench") &&
                referencePicker.contains("No \\(referenceTask.capitalizedDisplayName) Examples Found"),
            "Reference Examples should support both diagram and plot benchmark tasks."
        )
        XCTAssertFalse(
            referencePicker.contains("Manual Plot Examples Unavailable"),
            "Manual plot examples should no longer be hidden behind a disabled state."
        )
        XCTAssertTrue(
            designSystem.contains("struct AdaptiveMaterialSurface") &&
                designSystem.contains("accessibilityReduceTransparency") &&
                designSystem.contains("colorSchemeContrast") &&
                designSystem.contains("func appAdaptiveMaterialBackground"),
            "Adaptive material fallback policy should live in AppDesignSystem so WP-007 Reduce Transparency and Increased Contrast behavior stays centralized."
        )
        XCTAssertTrue(
            workbench.contains("appAdaptiveMaterialBackground") &&
                workbench.contains(".regularMaterial") &&
                workbench.contains(".thinMaterial"),
            "Workbench surfaces should use native system material through the shared adaptive design-system component."
        )
        XCTAssertFalse(
            workbench.contains(".fill(.regularMaterial)") ||
                workbench.contains(".fill(.thinMaterial)"),
            "Workbench surfaces should not own raw material fallback logic."
        )
        XCTAssertTrue(
            designSystem.contains("enum Radius"),
            "Reusable workbench chrome should draw from centralized design-system radius tokens."
        )
        XCTAssertFalse(
            promptStudio.contains(".paperPanel()"),
            "Prompt Studio must not fall back to the legacy stacked paper panel layout."
        )
        XCTAssertFalse(
            promptStudio.contains(#".frame(minWidth: 520, idealWidth: 640)"#) ||
                promptStudio.contains("private var controls") ||
                promptStudio.contains("private var resultPane"),
            "Prompt Studio must not restore the discarded controls/result-pane split."
        )
        XCTAssertFalse(
            promptStudio.contains("Color(nsColor: .separatorColor)"),
            "Prompt Studio should use semantic strokes rather than hard-coded separator colors."
        )
        XCTAssertFalse(
            promptStudio.contains("agent_selected_12"),
            "Native manual example selection should not revive the hard-coded legacy manual few-shot file."
        )
    }

    func testScopedNativeSurfacesUseAdaptiveMaterialPolicy() throws {
        let repoRoot = Self.repoRoot()
        let scopedMaterialFiles = [
            "Sources/PaperBananaApp/ArtifactLibraryPreviewComponents.swift",
            "Sources/PaperBananaApp/RootSidebarView.swift",
            "Sources/PaperBananaApp/WorkspaceScopeStrip.swift"
        ]

        for relativePath in scopedMaterialFiles {
            let source = try String(
                contentsOf: repoRoot.appendingPathComponent(relativePath),
                encoding: .utf8
            )

            XCTAssertTrue(
                source.contains("appAdaptiveMaterialBackground"),
                "\(relativePath) should use the centralized adaptive material helper."
            )
            XCTAssertFalse(
                source.contains(".background(.regularMaterial") ||
                    source.contains(".background(.thinMaterial") ||
                    source.contains(".fill(.regularMaterial") ||
                    source.contains(".fill(.thinMaterial"),
                "\(relativePath) must not bypass the centralized Reduce Transparency and Increased Contrast material policy."
            )
        }

        let workbench = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/WorkbenchComponents.swift"),
            encoding: .utf8
        )
        let settingsPanes = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/SettingsPanes.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(
            workbench.contains("AppDesignSystem.Adaptive.statusFill") &&
                workbench.contains("AppDesignSystem.Adaptive.statusStroke") &&
                settingsPanes.contains("AppDesignSystem.Adaptive.statusFill") &&
                settingsPanes.contains("AppDesignSystem.Adaptive.statusStroke"),
            "Status pills should use adaptive contrast tokens rather than fixed low-opacity fills."
        )
        XCTAssertFalse(
            workbench.contains(".background(tint.opacity(0.14)") ||
                settingsPanes.contains(".background(color.opacity(0.16)"),
            "Status pills must not rely on fixed low-opacity backgrounds in Increased Contrast."
        )
    }

    func testRefinementWorkspaceUsesNativeWorkbenchSectionsInsteadOfLegacyPanelStack() throws {
        let repoRoot = Self.repoRoot()
        let refinement = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/NativeRefinementWorkspaceView.swift"),
            encoding: .utf8
        )
        let optionBar = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/RefinementOptionBar.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(
            refinement.contains("WorkbenchSection("),
            "Refinement workspace should use rebuilt native workbench sections."
        )
        XCTAssertTrue(
            refinement.contains(#""Refinement Request""#) &&
                refinement.contains(#""Run Timeline""#) &&
                refinement.contains(#""Refined Output""#),
            "Refinement workspace should expose request, timeline, and output as native workbench sections."
        )
        XCTAssertTrue(
            optionBar.contains("WorkbenchOptionField"),
            "Refinement options should share the rebuilt workbench option field component."
        )
        XCTAssertTrue(
            refinement.contains(".controlSize(.small)"),
            "Refinement workspace actions should use compact native Mac controls."
        )
        XCTAssertFalse(
            refinement.contains(".paperPanel()"),
            "Refinement workspace must not fall back to the legacy stacked paper panel layout."
        )
        XCTAssertFalse(
            refinement.contains("Color(nsColor: .separatorColor)"),
            "Refinement workspace should use semantic strokes rather than hard-coded separator colors."
        )
    }

    func testRebuiltAppSourcesDoNotUseLegacyPanelOrFixedSeparatorStyling() throws {
        let repoRoot = Self.repoRoot()
        let sourceRoot = repoRoot.appendingPathComponent("Sources/PaperBananaApp", isDirectory: true)
        let forbiddenTerms = [
            ".paperPanel()",
            "struct PanelStyle",
            "func paperPanel",
            "Color(nsColor: .separatorColor)",
        ]

        let matches = try searchableFiles(at: sourceRoot).flatMap { file -> [String] in
            let text = try String(contentsOf: file, encoding: .utf8)
            return forbiddenTerms
                .filter { text.contains($0) }
                .map { "\(file.lastPathComponent): contains \($0)" }
        }

        XCTAssertTrue(
            matches.isEmpty,
            "The rebuilt native UI must use AppDesignSystem workbench components, not legacy panels or fixed separator colors:\n" +
                matches.joined(separator: "\n")
        )
    }

    func testSettingsSceneUsesDedicatedNativePanesAndQuarantinesLegacyControls() throws {
        let repoRoot = Self.repoRoot()
        let settingsRoot = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/SettingsView.swift"),
            encoding: .utf8
        )
        let panes = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/SettingsPanes.swift"),
            encoding: .utf8
        )
        let workspacePane = panes.section(after: "struct WorkspaceSettingsPane", before: "struct ProviderSettingsPane")
        let legacyPane = panes.section(after: "struct LegacySettingsPane", before: "private struct SettingsApplyRow")

        XCTAssertTrue(
            settingsRoot.contains("WorkspaceSettingsPane") &&
                settingsRoot.contains("ProviderSettingsPane") &&
                settingsRoot.contains("LegacySettingsPane"),
            "Settings should be split into dedicated native panes instead of a monolithic legacy settings view."
        )
        XCTAssertTrue(
            settingsRoot.contains(".scenePadding()"),
            "The Settings scene should use native scene padding instead of a fixed old panel frame."
        )
        XCTAssertTrue(
            settingsRoot.contains("TabView(selection: $selection)") &&
                settingsRoot.contains("SettingsPaneContent") &&
                settingsRoot.contains(".frame(maxWidth: 860") &&
                settingsRoot.contains(#".accessibilityIdentifier("paperbanana-settings-window")"#),
            "Settings should retain native tabbed preferences while constraining form width and exposing a named window landmark."
        )
        XCTAssertTrue(
            settingsRoot.contains(#".accessibilityIdentifier("settings-pane-\(pane.rawValue)")"#),
            "Every Settings tab should expose a stable pane accessibility identifier for keyboard and VoiceOver review."
        )
        XCTAssertFalse(
            settingsRoot.contains(".frame(width: 680, height: 520)") ||
                settingsRoot.contains("private var generalTab") ||
                settingsRoot.contains("private var diagnosticsTab"),
            "Settings must not restore the old fixed-size monolithic tab implementation."
        )
        XCTAssertTrue(
            workspacePane.contains(#"Section("Native Workspace")"#),
            "Settings Workspace should frame the checkout path as native workspace configuration."
        )
        XCTAssertTrue(
            workspacePane.contains("SettingsReadinessSummary(snapshot: settings.readinessSnapshot())") &&
                panes.contains("private struct SettingsReadinessSummary"),
            "Settings Workspace should present readiness as native form rows rather than nesting a workbench card in a Settings form."
        )
        XCTAssertFalse(
            workspacePane.contains("PaperBananaReadinessPanel(snapshot: settings.readinessSnapshot())"),
            "Settings Workspace should not embed the main workbench readiness card inside the grouped Settings form."
        )
        XCTAssertFalse(
            workspacePane.contains("Legacy Gradio"),
            "Settings Workspace must not lead with legacy Gradio configuration."
        )
        XCTAssertFalse(
            workspacePane.contains("serverPort"),
            "Legacy Gradio port configuration belongs in the isolated Legacy pane, not Workspace."
        )
        XCTAssertFalse(
            workspacePane.contains("Apply and Start Legacy Backend"),
            "Compatibility runtime start controls belong in the isolated Legacy pane, not Workspace."
        )
        XCTAssertTrue(
            legacyPane.contains("Legacy Gradio Compatibility") &&
                legacyPane.contains("Apply and Start Compatibility Runtime"),
            "The Legacy pane should keep explicit compatibility controls available without promoting them in primary workflows."
        )
        XCTAssertTrue(
            panes.contains("SettingsStatusPill"),
            "Settings provider state should use the rebuilt settings-specific status pill."
        )
        XCTAssertTrue(
            panes.contains("ViewThatFits(in: .horizontal)") &&
                panes.contains(#".accessibilityIdentifier("settings-workspace-repo-path")"#) &&
                panes.contains(#".accessibilityIdentifier("settings-secret-store-location")"#) &&
                panes.contains(#".accessibilityIdentifier("settings-google-api-key-field")"#) &&
                panes.contains(#".accessibilityIdentifier("settings-openrouter-api-key-field")"#) &&
                panes.contains(#".accessibilityIdentifier("settings-start-compatibility-runtime")"#),
            "Settings forms should use responsive action rows and named controls for accessibility and screenshot-state review."
        )
        XCTAssertTrue(
            workspacePane.contains(".help(settings.repoPath)") &&
                workspacePane.contains(#".accessibilityLabel("PaperBanana checkout")"#) &&
                workspacePane.contains(".accessibilityValue(settings.repoPath)"),
            "The Workspace checkout path should remain discoverable when visually truncated or selected."
        )
        XCTAssertTrue(
            panes.contains(".lineLimit(1)") &&
                panes.contains(".truncationMode(.middle)") &&
                panes.contains(".help(settings.secretStoreURL.path)") &&
                panes.contains(#".accessibilityLabel("Secret storage location")"#),
            "Long local secret-store paths should truncate visually while remaining discoverable and readable to assistive technology."
        )
    }

    func testSettingsAccessibilityAndAdaptiveSourceContractRemainsExplicit() throws {
        let repoRoot = Self.repoRoot()
        let settingsRoot = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/SettingsView.swift"),
            encoding: .utf8
        )
        let panes = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/SettingsPanes.swift"),
            encoding: .utf8
        )
        let designSystem = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/AppDesignSystem.swift"),
            encoding: .utf8
        )

        let paneWrapper = settingsRoot.section(after: "private struct SettingsPaneContent", before: "private enum SettingsPane")
        let workspacePane = panes.section(after: "struct WorkspaceSettingsPane", before: "struct ProviderSettingsPane")
        let providerPane = panes.section(after: "struct ProviderSettingsPane", before: "struct LegacySettingsPane")
        let providerActions = providerPane.section(after: "private func providerKeyActions", before: "private func providerSaveButton")
        let legacyPane = panes.section(after: "struct LegacySettingsPane", before: "private struct SettingsApplyRow")
        let legacyActions = legacyPane.section(after: "private var legacyCompatibilityActions", before: "private var applyLegacyButton")
        let diagnosticsActions = legacyPane.section(after: "private var diagnosticsActions", before: "private var runDiagnosticsButton")
        let readinessSummary = panes.section(after: "private struct SettingsReadinessSummary", before: "private struct SettingsReadinessStatusPill")

        XCTAssertTrue(settingsRoot.contains(#".accessibilityLabel("PaperBanana Settings")"#))
        XCTAssertTrue(settingsRoot.contains(".accessibilityValue(selection.subtitle)"))
        XCTAssertTrue(settingsRoot.contains(#".accessibilityIdentifier("paperbanana-settings-window")"#))

        XCTAssertTrue(paneWrapper.contains(#".accessibilityLabel("\(pane.title) settings")"#))
        XCTAssertTrue(paneWrapper.contains(".accessibilityValue(pane.subtitle)"))
        XCTAssertTrue(paneWrapper.contains(#".accessibilityIdentifier("settings-pane-\(pane.rawValue)")"#))

        XCTAssertTrue(workspacePane.contains(#".accessibilityIdentifier("settings-workspace-pane-form")"#))
        XCTAssertTrue(workspacePane.contains(#".accessibilityIdentifier("settings-workspace-repo-path")"#))
        XCTAssertTrue(workspacePane.contains(".help(settings.repoPath)"))
        XCTAssertTrue(workspacePane.contains(#".accessibilityLabel("PaperBanana checkout")"#))
        XCTAssertTrue(workspacePane.contains(".accessibilityValue(settings.repoPath)"))

        XCTAssertTrue(readinessSummary.contains(".lineLimit(row.id == .configuredPath ? 2 : 1)"))
        XCTAssertTrue(readinessSummary.contains(".truncationMode(.middle)"))
        XCTAssertTrue(readinessSummary.contains(".textSelection(.enabled)"))
        XCTAssertTrue(readinessSummary.contains(".help(row.value)"))
        XCTAssertTrue(readinessSummary.contains(".accessibilityElement(children: .combine)"))
        XCTAssertTrue(readinessSummary.contains(".accessibilityLabel(row.title)"))
        XCTAssertTrue(readinessSummary.contains(#".accessibilityValue("\(row.value). \(row.detail)")"#))

        XCTAssertTrue(providerPane.contains(#".accessibilityIdentifier("settings-provider-pane-form")"#))
        XCTAssertTrue(providerPane.contains(#"SecureField("Google API key", text: $settings.pendingGoogleAPIKey)"#))
        XCTAssertTrue(providerPane.contains(#"SecureField("OpenRouter API key", text: $settings.pendingOpenRouterAPIKey)"#))
        XCTAssertTrue(providerPane.contains(#".accessibilityIdentifier("settings-google-api-key-field")"#))
        XCTAssertTrue(providerPane.contains(#".accessibilityIdentifier("settings-openrouter-api-key-field")"#))
        XCTAssertTrue(providerPane.contains(#".accessibilityIdentifier("settings-secret-store-location")"#))
        XCTAssertTrue(providerPane.contains(#".accessibilityLabel("Secret storage location")"#))
        XCTAssertTrue(providerPane.contains(".accessibilityValue(settings.secretStoreURL.path)"))
        XCTAssertTrue(providerPane.contains(".lineLimit(1)") && providerPane.contains(".truncationMode(.middle)"))
        XCTAssertFalse(providerPane.contains(#"TextField("Google API key""#))
        XCTAssertFalse(providerPane.contains(#"TextField("OpenRouter API key""#))

        XCTAssertTrue(providerActions.contains("ViewThatFits(in: .horizontal)"))
        XCTAssertTrue(legacyActions.contains("ViewThatFits(in: .horizontal)"))
        XCTAssertTrue(diagnosticsActions.contains("ViewThatFits(in: .horizontal)"))
        XCTAssertTrue(legacyPane.contains(#".accessibilityIdentifier("settings-legacy-pane-form")"#))
        XCTAssertTrue(legacyPane.contains(#".accessibilityIdentifier("settings-legacy-server-port")"#))
        XCTAssertTrue(legacyPane.contains(#".accessibilityIdentifier("settings-run-diagnostics")"#))
        XCTAssertTrue(legacyPane.contains(#".accessibilityIdentifier("settings-copy-diagnostics")"#))

        XCTAssertTrue(panes.contains(#"@Environment(\.colorSchemeContrast)"#))
        XCTAssertTrue(panes.contains("AppDesignSystem.Adaptive.statusFill"))
        XCTAssertTrue(panes.contains("AppDesignSystem.Adaptive.statusStroke"))

        XCTAssertTrue(designSystem.contains("struct AdaptiveMaterialSurface"))
        XCTAssertTrue(designSystem.contains(#"@Environment(\.accessibilityReduceTransparency)"#))
        XCTAssertTrue(designSystem.contains("if reduceTransparency || colorSchemeContrast == .increased"))
        XCTAssertTrue(designSystem.contains("func appAdaptiveMaterialBackground"))
        XCTAssertTrue(designSystem.contains("static func statusFill"))
        XCTAssertTrue(designSystem.contains("static func statusStroke"))

        let settingsSource = settingsRoot + panes
        let forbiddenSettingsPatterns = [
            ".preferredColorScheme(",
            ".colorScheme(",
            #".environment(\.colorScheme"#,
            ".background(.regularMaterial",
            ".background(.thinMaterial",
            ".fill(.regularMaterial",
            ".fill(.thinMaterial",
            ".blur(",
            ".shadow(",
            "withAnimation(",
            "Animation.ease",
            "Animation.spring",
            "matchedGeometryEffect",
            "phaseAnimator",
            "keyframeAnimator",
            ".symbolEffect"
        ]
        let hits = forbiddenSettingsPatterns.filter { settingsSource.contains($0) }
        XCTAssertTrue(
            hits.isEmpty,
            "Settings must stay native/adaptive without custom appearance or motion bypasses: \(hits)"
        )
    }

    func testWorkspaceSettingsLowerContentRemainsScrollableAndTextSizeResilient() throws {
        let repoRoot = Self.repoRoot()
        let panes = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/SettingsPanes.swift"),
            encoding: .utf8
        )

        let workspacePane = panes.section(after: "struct WorkspaceSettingsPane", before: "struct ProviderSettingsPane")
        let applyRow = panes.section(after: "private struct SettingsApplyRow", before: "private struct SettingsReadinessSummary")
        let readinessSummary = panes.section(after: "private struct SettingsReadinessSummary", before: "private struct SettingsReadinessStatusPill")

        XCTAssertTrue(
            workspacePane.contains("Form {") &&
                workspacePane.contains(".formStyle(.grouped)") &&
                workspacePane.contains(#".accessibilityIdentifier("settings-workspace-pane-form")"#),
            "Workspace Settings must remain a native grouped Form with a stable accessibility identifier for focused Settings review."
        )

        let expectedOrder = [
            #"Section("Native Workspace")"#,
            #"Section("PaperBanana Readiness")"#,
            #"Section("Image Defaults")"#,
            #"Section("Codex Fallback")"#,
            "SettingsApplyRow"
        ]
        var previousIndex = workspacePane.startIndex
        for marker in expectedOrder {
            guard let range = workspacePane.range(of: marker, range: previousIndex..<workspacePane.endIndex) else {
                XCTFail("Workspace Settings should keep lower content reachable in native form order; missing marker: \(marker)")
                return
            }
            previousIndex = range.upperBound
        }

        let forbiddenWorkspaceLayout = [
            ".frame(height:",
            ".frame(width:",
            ".clipped()",
            ".scrollDisabled(true)"
        ]
        let workspaceLayoutHits = forbiddenWorkspaceLayout.filter { workspacePane.contains($0) }
        XCTAssertTrue(
            workspaceLayoutHits.isEmpty,
            "Workspace Settings must not add fixed/clipped/disabled-scroll layout that can hide lower content: \(workspaceLayoutHits)"
        )

        XCTAssertTrue(
            workspacePane.contains(".fixedSize(horizontal: false, vertical: true)") &&
                readinessSummary.contains(".fixedSize(horizontal: false, vertical: true)"),
            "Workspace explanatory and readiness detail text should remain vertically resilient for Increased Text Size."
        )

        XCTAssertTrue(
            workspacePane.contains(#".accessibilityIdentifier("settings-codex-model")"#) &&
                workspacePane.contains(#".accessibilityIdentifier("settings-codex-reasoning")"#) &&
                applyRow.contains(#".accessibilityIdentifier("settings-apply")"#),
            "Lower Workspace and Apply controls should keep stable identifiers for keyboard and VoiceOver traversal."
        )

        XCTAssertTrue(
            readinessSummary.contains(".accessibilityElement(children: .combine)") &&
                readinessSummary.contains(".accessibilityLabel(row.title)") &&
                readinessSummary.contains(#".accessibilityValue("\(row.value). \(row.detail)")"#) &&
                readinessSummary.contains(".help(row.value)"),
            "Readiness rows should remain combined, labelled, valued, and help-discoverable when lower Settings content is reviewed."
        )
    }

    func testPaperBananaReadinessSurfaceAppearsInSetupRunAndReviewWorkspaces() throws {
        let repoRoot = Self.repoRoot()
        let settingsPanes = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/SettingsPanes.swift"),
            encoding: .utf8
        )
        let promptStudio = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/NativePromptStudioView.swift"),
            encoding: .utf8
        )
        let refinement = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/NativeRefinementWorkspaceView.swift"),
            encoding: .utf8
        )
        let runDetails = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/RunDetailsView.swift"),
            encoding: .utf8
        )
        let runLedger = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/ProviderRunLedgerView.swift"),
            encoding: .utf8
        )
        let workbench = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/WorkbenchComponents.swift"),
            encoding: .utf8
        )
        let models = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/PaperBananaApp/PaperBananaModels.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(
            settingsPanes.contains(#"Section("PaperBanana Readiness")"#) &&
                settingsPanes.contains("SettingsReadinessSummary(snapshot: settings.readinessSnapshot())"),
            "Setup should expose PaperBanana readiness as a native Settings form section."
        )
        XCTAssertTrue(
            promptStudio.contains("PaperBananaReadinessPanel(") &&
                promptStudio.contains("settings.readinessSnapshot(requestedModel: model)"),
            "Run setup should show readiness for the selected generation model before execution."
        )
        XCTAssertTrue(
            refinement.contains("PaperBananaReadinessPanel(") &&
                refinement.contains("settings.readinessSnapshot(requestedModel: model)"),
            "Refinement runs should show readiness for the selected refinement model before execution."
        )
        XCTAssertTrue(
            runDetails.contains("PaperBananaReadinessPanel(snapshot: settings.readinessSnapshot())"),
            "Run review should keep the same readiness context in Run Details."
        )
        XCTAssertTrue(
            runLedger.contains("PaperBananaReadinessPanel(snapshot: settings.readinessSnapshot())"),
            "Provider-call review should keep the same readiness context in Run Ledger."
        )
        XCTAssertTrue(
            workbench.contains("struct PaperBananaReadinessPanel") &&
                workbench.contains("WorkbenchSection("),
            "Readiness must be a shared native workbench component instead of duplicated inline rows."
        )
        XCTAssertTrue(
            models.contains("struct PaperBananaReadinessSnapshot") &&
                models.contains(#""Configured Path""#) &&
                models.contains(#""Generation Key""#) &&
                models.contains(#""Backend Validity""#) &&
                models.contains(#""Deterministic Fallback""#),
            "Readiness state must explicitly model path, generation-key, backend-validity, and fallback behavior."
        )
    }

    func testNativeStoresDoNotAutoInvokeLegacyPythonProvider() throws {
        let repoRoot = Self.repoRoot()
        let storePaths = [
            "Sources/PaperBananaApp/NativeImageGenerationStore.swift",
            "Sources/PaperBananaApp/NativeRefinementStore.swift",
            "Sources/PaperBananaApp/NativeProviderRelays.swift",
        ]

        let matches = try storePaths.flatMap { path -> [String] in
            let fileURL = repoRoot.appendingPathComponent(path)
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            return ["LegacyPythonProviderClient", "NativeLegacyProviderRelay"]
                .filter { source.contains($0) }
                .map { "\(path): contains \($0)" }
        }

        XCTAssertTrue(
            matches.isEmpty,
            "Native generation/refinement stores must not silently fall back to Python provider execution:\n" +
                matches.joined(separator: "\n")
        )
    }

    func testNativeBuildScriptDoesNotStopLegacyBackendByDefault() throws {
        let repoRoot = Self.repoRoot()
        let script = try String(
            contentsOf: repoRoot.appendingPathComponent("script/build_and_run.sh"),
            encoding: .utf8
        )
        let cleanupGate = #"if [[ "$SHOULD_STOP_LEGACY_BACKEND" == "1" ]]; then"#

        XCTAssertTrue(
            script.contains("SHOULD_STOP_LEGACY_BACKEND=0"),
            "Native build/run must default to leaving the legacy Gradio backend alone."
        )
        XCTAssertTrue(
            script.contains("--stop-legacy-backend"),
            "Legacy backend cleanup should remain available only as an explicit build-script flag."
        )
        XCTAssertTrue(
            script.contains(cleanupGate),
            "Any legacy Gradio cleanup must be gated behind --stop-legacy-backend."
        )

        let nativeDefaultPath = script.components(separatedBy: cleanupGate).first ?? script
        XCTAssertFalse(
            nativeDefaultPath.contains("app.py"),
            "Default native build/test/install must not stop or inspect the legacy Python app.py backend."
        )
    }

    func testAppSourcesDoNotReintroduceSystemCredentialAPIs() throws {
        let repoRoot = Self.repoRoot()
        let forbiddenTerms = [
            "Sec" + "Item",
            "Key" + "chain",
            "Security" + "Agent",
            "find-" + "generic-password",
            "generic-" + "password",
        ]
        let scanRoots = [
            repoRoot.appendingPathComponent("Sources", isDirectory: true),
            repoRoot.appendingPathComponent("app.py", isDirectory: false),
            repoRoot.appendingPathComponent("agents", isDirectory: true),
            repoRoot.appendingPathComponent("paperbanana_gui", isDirectory: true),
            repoRoot.appendingPathComponent("script", isDirectory: true),
            repoRoot.appendingPathComponent("utils", isDirectory: true),
            repoRoot.appendingPathComponent("project.yml", isDirectory: false),
        ]

        let matches = try scanRoots.flatMap { root in
            try searchableFiles(at: root).flatMap { file -> [String] in
                let text = try String(contentsOf: file, encoding: .utf8)
                return forbiddenTerms
                    .filter { text.localizedCaseInsensitiveContains($0) }
                    .map { "\(file.path): contains \($0)" }
            }
        }

        XCTAssertTrue(matches.isEmpty, matches.joined(separator: "\n"))
    }

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func searchableFiles(at url: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return []
        }
        guard isDirectory.boolValue else {
            return [url]
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        return try enumerator.compactMap { candidate in
            guard let file = candidate as? URL else { return nil }
            let resourceValues = try file.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues.isRegularFile == true else { return nil }
            let supportedExtensions = ["swift", "py", "sh", "yml", "yaml", "json"]
            return supportedExtensions.contains(file.pathExtension.lowercased()) ? file : nil
        }
    }
}

private extension String {
    func section(after start: String, before end: String) -> String {
        guard let startRange = range(of: start) else { return "" }
        let remainder = self[startRange.upperBound...]
        guard let endRange = remainder.range(of: end) else { return String(remainder) }
        return String(remainder[..<endRange.lowerBound])
    }
}
