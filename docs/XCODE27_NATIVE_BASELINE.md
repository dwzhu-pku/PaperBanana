# PaperBanana Xcode 27 Native Baseline

PaperBanana keeps `project.yml` as the source of truth and checks in
`PaperBanana.xcodeproj` so the app remains easy to open and maintain in Xcode.
The checked-in project must be reproducible from the XcodeGen spec.

## Required Host

- Apple Silicon host: `arm64`
- Xcode: `/Applications/Xcode-beta.app/Contents/Developer`
- Expected Xcode: `Xcode 27.0`, build `27A5194q`
- Expected Swift: Apple Swift `6.4`
- Minimum macOS for Xcode 27 work: `26.4`

Set the toolchain before running local build or test commands:

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
```

## Baseline Guard

Run this before changing Xcode settings, SwiftPM pins, signing, deployment
targets, app-intent surfaces, or release packaging:

```bash
./script/xcode27_baseline_guard.sh
```

The guard verifies:

- the selected Xcode and Swift toolchain,
- Apple Silicon host architecture,
- macOS version floor,
- `PaperBanana.xcodeproj` drift against `project.yml`,
- Codex Xcode 27 host audit,
- Codex Xcode 27 project scan,
- canonical Xcode build proof for the native `PaperBanana` scheme.

For the repeated Xcode 27 smoke loop:

```bash
./script/xcode27_baseline_guard.sh --fast-tests
```

For the complete native and Python compatibility gate:

```bash
./script/test_all.sh
```

## Native Build And Install

Build and install the native macOS app without opening it:

```bash
./script/build_and_run.sh --release --install --no-open
```

Run only the baseline guard through the build script:

```bash
./script/build_and_run.sh --guard
```

## Drift Policy

If the drift check fails, regenerate and repair icon resources:

```bash
xcodegen generate --spec project.yml
bundle install
bundle exec ruby script/ensure_xcode_icon_resource.rb
./script/check_xcode_project_drift.sh
```

`Gemfile` pins the `xcodeproj` Ruby dependency used by
`script/ensure_xcode_icon_resource.rb`. The validation scripts prefer
`bundle exec ruby` when the bundle is installed and fall back to a Ruby that can
load `xcodeproj` on already-configured developer machines.

Do not manually edit `PaperBanana.xcodeproj` for durable build settings unless
the equivalent change is also made in `project.yml`.
