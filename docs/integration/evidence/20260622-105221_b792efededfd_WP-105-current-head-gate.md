# WP-105 Current Product-Head Gate Evidence

## Summary

- **Product code under test:** `b792efededfd` (`Record Artifact Library scroll evidence`)
- **Branch/worktree:** `integration/native-first-rc-native` at `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- **Assessment time:** 2026-06-22 10:52 UTC
- **Scope:** Current-head aggregate native/Python/Xcode 27 gate and Release build/install proof after the Artifact Library intent and screenshot evidence commits.
- **Status:** **Passed with limitations.**

This pass ties the latest product-code head to the aggregate gate. It does not
claim final release readiness, hosted validation, live provider validation,
rollback validation, full keyboard/VoiceOver traversal, adaptive visual signoff,
or publication-quality evidence.

## Validation Commands

An initial aggregate run intentionally remains recorded because it exposed an
environment selection issue:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/test_all.sh
```

Result: **failed during Python collection** after the native source-control
contract, Xcode 27 baseline guard, and Xcode tests passed. The script selected
system Python `3.14.6`, which did not have `google.genai` installed:

```text
ModuleNotFoundError: No module named 'google.genai'
```

This was classified as an environment-selection failure, not a product-code
regression, because the documented WP-005 local gate uses
`PAPERBANANA_PYTHON=/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python`.
That venv was checked and imports `google.genai`.

The documented aggregate gate was then rerun:

```bash
PYTHONDONTWRITEBYTECODE=1 \
PAPERBANANA_PYTHON=/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
CODEX_XCODE27_BIN="$(command -v codex-xcode27)" \
  ./script/test_all.sh
```

Result: **passed**.

Observed output:

```text
PaperBanana native source-control contract passed.
PaperBanana Xcode 27 baseline guard passed.
Executed 154 tests, with 0 failures.
88 passed in 7.27s
status=passed halted=False
```

The proof stage wrote:

```text
.codex/xcode27/2026-06-22T10-50-19Z-proof.json
.codex/xcode27/2026-06-22T10-50-19Z-proof.md
```

The final Release build/install proof was rerun:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/build_and_run.sh --release --install --no-open
```

Result: **passed**.

Observed output:

```text
** BUILD SUCCEEDED **
PaperBanana installed at /Applications/PaperBanana.app
```

## Material Warnings

- The first `script/test_all.sh` invocation without `PAPERBANANA_PYTHON` failed
  because this checkout has no local `.venv` and system Python lacks project
  dependencies. The current local gate therefore depends on passing the documented
  `PAPERBANANA_PYTHON` value or creating a checkout-local environment.
- Xcode emitted the recurring non-failing diagnostics about `linkd`, Core
  Spotlight donation, and TextRecognition E5 bundles during tests.
- The aggregate script requests `-test-iterations 3 -retry-tests-on-failure`;
  the observed Xcode summary reported `154` executed tests with no failures and
  no retry/failure evidence.
- `.codex/xcode27` proof artifacts are ignored local logs. This evidence file
  records their paths rather than checking those generated logs into git.

## Remaining Required Evidence

- Full manual keyboard navigation and VoiceOver traversal, including live AX
  re-probe of Run Details and Provider Run Ledger selection-summary exposure,
  Settings, reference rows, artifact grid context menus, disabled states, and
  preflight sheets.
- Reduce Motion, Reduce Transparency, Increased Contrast, Increased Text Size,
  hover/focus, inactive-window, and remaining narrow-width visual review.
- Native real-data/provider/recovery E2E (`WP-106`) and quality baseline
  (`WP-108`) before release-quality claims.
- Repeat this gate on any later product-code SHA selected as the frozen release
  candidate.
