# PaperBanana Native Workbench Rebuild Brief

## Main Window Anatomy

PaperBanana uses a native macOS pro-tool workbench. The previous Gradio-derived
shell and piecemeal SwiftUI panels are being treated as discarded legacy UI, not
as the target design.

- Sidebar: fixed-width two-zone native workbench sidebar. A compact activity rail provides one-click access to major work areas, while a separate bounded navigation pane holds the app identity, runtime summary, sectioned commands, and Settings entry point. The shell must use native SwiftUI controls, semantic materials, explicit clipping, keyboard-accessible buttons, and no inherited split-view geometry.
- Detail: feature-owned workbench panes for recovered images, artifact library, run details, run ledger, generation, refinement, settings, and legacy diagnostics. Generation uses a reset Prompt Studio anatomy: compact command bar, large prompt editor workspace, right-side run inspector, sectioned output preview, and timeline.
- Workspace chrome: feature views use compact title/action rows plus `WorkspaceScopeStrip` for native segmented scope and search; no custom stacked "Filter" text columns.
- Window: minimum app size is enforced by AppKit window constraints, while the root view avoids child views that exceed the sidebar column width.

## Component Inventory

- `RootView`: high-level fixed sidebar/detail composition and destination routing only.
- `RootActivityRail`: compact icon-only workbench rail for major destinations and Settings, with stable width and native tooltips.
- `RootSidebarCommandRow`: one-icon, one-title command row with bounded geometry and semantic selected state in the navigation pane.
- `SidebarMetadataRow`: compact read-only runtime metadata row; not a navigation control.
- `WorkbenchSection`: appearance-adaptive native material section used for every rebuilt pane.
- `WorkbenchOptionField`: compact form field wrapper for generation and refinement options.
- `WorkbenchCommandBar`: compact native command strip for editor and run controls.
- `WorkbenchEditorSurface`: bounded prompt/editing surface that owns editor material, stroke, and spacing.
- `WorkbenchStatusPill`: semantic run-state capsule used in workbench toolbars.
- `WorkspaceScopeStrip`: native scope/search row used for artifact, run, and ledger filtering.
- `PaperBananaReadinessPanel`: shared first-class readiness surface for Setup,
  Run, and Review workspaces. It must show the configured checkout path,
  generation-key state, compatibility-backend validity, and deterministic
  fallback behavior without promoting the legacy backend as a native dependency.
- Feature views: own their internal grid, inspector, progress, recovery, and provider controls, but visual styling must route through the design system.

## Visual Acceptance Criteria

- Sidebar labels must never render behind, outside, or under the left edge of the window.
- Sidebar child content must not force a wider minimum width than the split column can restore.
- Sidebar command selection must be visible in Light Mode and Dark Mode, pointer-friendly, VoiceOver-readable, and keyboard navigable.
- Window restoration, movement, and resizing must not preserve an offscreen frame that hides the sidebar.
- No inherited split-view/sidebar machinery that can restore into a clipped column or draw rows outside the window edge.
- The overall feel should be strongly reminiscent of Nova as a high-quality native Mac pro tool: dense but readable, tool-oriented, fast, precise, multi-pane, workflow-focused, and restrained. This is a taste reference only; do not copy Panic/Nova trade dress, icons, screenshots, colors, or proprietary layout details.
- Legacy `paperPanel()` styling must not exist in production source.
- Workbench sections must render through system-adaptive materials or semantic fallback colors.
- Search/scope controls must not overlap, wrap single words vertically, or force the sidebar/detail split out of bounds.
- The main shell should read as a dense desktop production app: compact activity rail, calm navigation pane, strong inspector/content separation, no web-wrapper chrome, no marketing panels, no generic dashboard cards, and no oversized empty decoration.
- Prompt Studio must not restore the discarded `controls`/`resultPane` split, the old `520/640` control-column frame, or an unframed output pane.
- Prompt Studio reference examples must stay inside the right-side run panel as compact native configuration, not a gallery, modal-first flow, or new sidebar destination.
- Manual example rows must tolerate long benchmark ids, captions, and methodology summaries inside the 360-440 px run panel without horizontal scrolling or clipped controls.
- Selected manual references must be visibly counted before generation and must not compete with the primary Generate action.
- Setup, Run, and Review workspaces must expose the same PaperBanana readiness
  facts: configured path, generation key state, backend validity, and
  deterministic Codex fallback behavior.
- Missing generation keys must be presented as a deterministic no-provider-spend
  fallback path, not as an ambiguous silent failure.
- Backend validity must distinguish the optional legacy compatibility runtime
  from native generation/refinement readiness.

## Accessibility And Appearance

- Use semantic foreground styles and native list/sidebar materials.
- Preserve VoiceOver labels for every navigation row.
- Preserve reduced-motion behavior for destination changes.
- Avoid fixed light/dark colors in root navigation.
- Respect Reduce Transparency in workbench surfaces.
- Verify populated and empty states in both Light Mode and Dark Mode before declaring a slice complete.

## Relevant Apple Resources

- `/Users/jeff/Developer/Codex_Resources/README.md`
- `/Users/jeff/Developer/Codex_Resources/Apple/Design/macOS_27/HIG/References.md`
- Build macOS Apps `swiftui-patterns` sidebar guidance.
- Build macOS Apps `window-management` placement and restoration guidance.
- Nova public product page (`https://nova.app/`) as a high-level native pro-app reference for density, sidebar tooling, workflows, and settings depth.
