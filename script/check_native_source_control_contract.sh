#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

cd "$ROOT_DIR"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
  fail "PaperBanana must be inside a git worktree for native source-control checks."

required_paths=(
  ".gitignore"
  ".github/workflows/native-structural.yml"
  ".github/workflows/native-xcode27-full-gate.yml"
  ".github/workflows/python-tests.yml"
  ".codex/environments/environment.toml"
  "Package.swift"
  "project.yml"
  "README.md"
  "PaperBanana.xcodeproj/project.pbxproj"
  "PaperBanana.xcodeproj/project.xcworkspace/contents.xcworkspacedata"
  "PaperBanana/Assets.xcassets/Contents.json"
  "PaperBanana/Assets.xcassets/AccentColor.colorset/Contents.json"
  "PaperBanana/Resources/AppIcon.icon/icon.json"
  "PaperBanana/Resources/AppIcon.icon/Assets/Image.png"
  "PaperBanana/Resources/AppIcon.icon/Assets/PaperBanana-Dark.png"
  "PaperBanana/Resources/AppIcon.icon/Assets/PaperBanana-Light.png"
  "Sources/PaperBananaApp/PaperBananaApp.swift"
  "Sources/PaperBananaApp/RootView.swift"
  "Sources/PaperBananaApp/AppDesignSystem.swift"
  "Sources/PaperBananaApp/ProviderRuntime.swift"
  "Sources/PaperBananaApp/RunStore.swift"
  "Sources/PaperBananaApp/RunStoreProviderCalls.swift"
  "Sources/PaperBananaApp/ProviderRunLedgerScanner.swift"
  "Sources/PaperBananaApp/NativeImageGenerationStore.swift"
  "Sources/PaperBananaApp/NativeRefinementStore.swift"
  "Sources/PaperBananaApp/ReferenceExampleModels.swift"
  "Sources/PaperBananaApp/ReferenceExamplePickerView.swift"
  "Sources/PaperBananaApp/ReferenceExampleProvenance.swift"
  "Sources/PaperBananaApp/ReferenceExampleStore.swift"
  "docs/CI.md"
  "docs/integration/WP108_NO_LIVE_BENCHMARK_CONTRACT.md"
  "docs/integration/wp108_human_review_packet.example.json"
  "docs/integration/wp108_human_review_packet.schema.json"
  "docs/integration/wp108_no_live_manifest.example.json"
  "docs/integration/wp108_no_live_manifest.schema.json"
  "docs/integration/wp108_quality_decision.example.json"
  "docs/integration/wp108_quality_decision.schema.json"
  "docs/integration/wp108_no_live_report.fixture.json"
  "docs/integration/wp108_no_live_report.schema.json"
  "docs/integration/wp108_no_live_run_map.example.json"
  "docs/integration/wp108_no_live_run_map.schema.json"
  "docs/NATIVE_MACOS_TROUBLESHOOTING.md"
  "docs/XCODE27_NATIVE_BASELINE.md"
  "paperbanana_gui/__init__.py"
  "paperbanana_gui/codex_handoff.py"
  "paperbanana_gui/native_generate.py"
  "paperbanana_gui/native_refine.py"
  "utils/generation_utils.py"
  "utils/provider_audit.py"
  "tests/PaperBananaTests/ProviderRunLedgerTests.swift"
  "tests/PaperBananaTests/ReferenceExampleStoreTests.swift"
  "tests/PaperBananaTests/RunStoreTests.swift"
  "tests/PaperBananaTests/ProviderRuntimeTests.swift"
  "tests/test_codex_handoff.py"
  "tests/test_ci_contract.py"
  "tests/test_native_generate_cli.py"
  "tests/test_native_refine_cli.py"
  "tests/test_provider_audit_loss_protection.py"
  "tests/test_wp108_benchmark_contract.py"
  "tests/test_wp108_human_review_packet.py"
  "tests/test_wp108_no_live_artifact_runner.py"
  "tests/test_wp108_quality_decision.py"
  "tests/test_wp107_hosted_readiness_smoke.py"
  "utils/wp108_benchmark_contract.py"
  "utils/wp108_human_review_packet.py"
  "utils/wp108_no_live_artifact_runner.py"
  "utils/wp108_quality_decision.py"
  "utils/wp107_hosted_readiness_smoke.py"
  "script/build_and_run.sh"
  "script/check_native_source_control_contract.sh"
  "script/check_native_xcode_contract.sh"
  "script/check_xcode_project_drift.sh"
  "script/ensure_xcode_icon_resource.rb"
  "script/preflight_local_upgrade_rollback.sh"
  "script/test_all.sh"
  "script/xcode27_baseline_guard.sh"
)

durable_roots=(
  ".github/workflows"
  ".codex/environments"
  ".gitignore"
  "Package.swift"
  "project.yml"
  "README.md"
  "PaperBanana.xcodeproj"
  "PaperBanana/Assets.xcassets"
  "PaperBanana/Resources"
  "Sources/PaperBananaApp"
  "docs"
  "paperbanana_gui"
  "tests/PaperBananaTests"
  "tests/test_codex_handoff.py"
  "tests/test_ci_contract.py"
  "tests/test_native_generate_cli.py"
  "tests/test_native_refine_cli.py"
  "tests/test_provider_audit_loss_protection.py"
  "tests/test_wp108_benchmark_contract.py"
  "tests/test_wp108_human_review_packet.py"
  "tests/test_wp108_no_live_artifact_runner.py"
  "tests/test_wp108_quality_decision.py"
  "tests/test_wp107_hosted_readiness_smoke.py"
  "utils/generation_utils.py"
  "utils/provider_audit.py"
  "utils/wp108_benchmark_contract.py"
  "utils/wp108_human_review_packet.py"
  "utils/wp108_no_live_artifact_runner.py"
  "utils/wp108_quality_decision.py"
  "utils/wp107_hosted_readiness_smoke.py"
  "script/build_and_run.sh"
  "script/check_native_source_control_contract.sh"
  "script/check_native_xcode_contract.sh"
  "script/check_xcode_project_drift.sh"
  "script/ensure_xcode_icon_resource.rb"
  "script/preflight_local_upgrade_rollback.sh"
  "script/test_all.sh"
  "script/xcode27_baseline_guard.sh"
)

missing=()
unstaged=()
for path in "${required_paths[@]}"; do
  if [[ ! -e "$path" ]]; then
    missing+=("$path")
    continue
  fi
  if ! git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
    unstaged+=("$path")
  fi
done

untracked_durable_paths=()
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  untracked_durable_paths+=("$line")
done < <(git ls-files --others --exclude-standard -- "${durable_roots[@]}" | sort)

unstaged_durable_paths=()
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  unstaged_durable_paths+=("$line")
done < <(git diff --name-only -- "${durable_roots[@]}" | sort)

if (( ${#missing[@]} > 0 )); then
  printf 'ERROR: native Xcode contract paths are missing:\n' >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 1
fi

if (( ${#unstaged[@]} > 0 )); then
  printf 'ERROR: native Xcode contract paths are not tracked or staged in git:\n' >&2
  printf '  %s\n' "${unstaged[@]}" >&2
  printf '\nStage or commit these files before treating the native Xcode app as durable.\n' >&2
  exit 1
fi

if (( ${#untracked_durable_paths[@]} > 0 )); then
  printf 'ERROR: native Xcode support files are present but untracked:\n' >&2
  printf '  %s\n' "${untracked_durable_paths[@]}" >&2
  printf '\nStage or commit these files before treating the native Xcode app as durable.\n' >&2
  exit 1
fi

if (( ${#unstaged_durable_paths[@]} > 0 )); then
  printf 'ERROR: native Xcode support files have unstaged changes:\n' >&2
  printf '  %s\n' "${unstaged_durable_paths[@]}" >&2
  printf '\nStage or commit these files before treating the native Xcode app as durable.\n' >&2
  exit 1
fi

echo "PaperBanana native source-control contract passed."
