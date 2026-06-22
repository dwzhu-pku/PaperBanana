#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/PaperBanana.xcodeproj"
PROJECT_SPEC="$ROOT_DIR/project.yml"
SCHEME="PaperBanana"
DESTINATION="platform=macOS,arch=arm64"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

cd "$ROOT_DIR"

[[ -f "$PROJECT_SPEC" ]] || fail "project.yml is missing; native Xcode source of truth is required"
[[ -d "$PROJECT_FILE" ]] || fail "PaperBanana.xcodeproj is missing"
[[ -f "$PROJECT_FILE/project.pbxproj" ]] || fail "PaperBanana.xcodeproj/project.pbxproj is missing"

"$ROOT_DIR/script/check_xcode_project_drift.sh"

list_json="$(mktemp)"
settings_json="$(mktemp)"
trap 'rm -f "$list_json" "$settings_json"' EXIT

xcodebuild -list -json -project "$PROJECT_FILE" >"$list_json"
xcodebuild \
  -showBuildSettings \
  -json \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$DESTINATION" >"$settings_json"

python3 - "$ROOT_DIR" "$list_json" "$settings_json" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
list_path = pathlib.Path(sys.argv[2])
settings_path = pathlib.Path(sys.argv[3])

def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)

with list_path.open("r", encoding="utf-8") as handle:
    project_listing = json.load(handle)["project"]

targets = set(project_listing.get("targets", []))
schemes = set(project_listing.get("schemes", []))
configurations = set(project_listing.get("configurations", []))

if project_listing.get("name") != "PaperBanana":
    fail(f"unexpected Xcode project name: {project_listing.get('name')!r}")
if "PaperBanana" not in targets:
    fail("native app target PaperBanana is missing")
if "PaperBananaTests" not in targets:
    fail("native test target PaperBananaTests is missing")
if "PaperBanana" not in schemes:
    fail("PaperBanana scheme is missing")
if not {"Debug", "Release"}.issubset(configurations):
    fail(f"expected Debug and Release configurations; got {sorted(configurations)}")

with settings_path.open("r", encoding="utf-8") as handle:
    settings_payload = json.load(handle)

app_settings = None
for entry in settings_payload:
    if entry.get("target") == "PaperBanana":
        app_settings = entry.get("buildSettings", {})
        break
if app_settings is None:
    fail("PaperBanana build settings were not returned by xcodebuild")

expected = {
    "PRODUCT_TYPE": "com.apple.product-type.application",
    "PRODUCT_BUNDLE_PACKAGE_TYPE": "APPL",
    "WRAPPER_EXTENSION": "app",
    "PRODUCT_NAME": "PaperBanana",
    "PRODUCT_BUNDLE_IDENTIFIER": "local.paperbanana.gui",
    "PLATFORM_NAME": "macosx",
    "SUPPORTED_PLATFORMS": "macosx",
    "MACOSX_DEPLOYMENT_TARGET": "13.0",
    "SWIFT_VERSION": "6.0",
    "EFFECTIVE_SWIFT_VERSION": "6",
    "SDK_VERSION": "27.0",
    "XCODE_PRODUCT_BUILD_VERSION": "27A5194q",
}
for key, value in expected.items():
    actual = app_settings.get(key)
    if actual != value:
        fail(f"{key} expected {value!r}, got {actual!r}")

if "arm64" not in app_settings.get("ARCHS", ""):
    fail(f"ARCHS must include arm64; got {app_settings.get('ARCHS')!r}")
if app_settings.get("EXECUTABLE_PATH") != "PaperBanana.app/Contents/MacOS/PaperBanana":
    fail(f"unexpected executable path: {app_settings.get('EXECUTABLE_PATH')!r}")
if app_settings.get("INFOPLIST_KEY_LSMinimumSystemVersion") != "13.0":
    fail("generated Info.plist minimum system version must remain macOS 13.0 for compatibility")

project_spec = (root / "project.yml").read_text(encoding="utf-8")
project_file = (root / "PaperBanana.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
build_script = (root / "script" / "build_and_run.sh").read_text(encoding="utf-8")

required_spec_fragments = [
    "type: application",
    "platform: macOS",
    "PaperBananaTests:",
    "tests/PaperBananaTests",
    "deploymentTarget: \"13.0\"",
    "SWIFT_VERSION: \"6.0\"",
    "sdk: libsqlite3.tbd",
    "PaperBanana/Resources/AppIcon.icon",
]
for fragment in required_spec_fragments:
    if fragment not in project_spec:
        fail(f"project.yml is missing required native project fragment: {fragment}")

required_project_fragments = [
    "com.apple.product-type.application",
    "local.paperbanana.gui",
    "libsqlite3.tbd",
    "PaperBananaTests",
    "Sources/PaperBananaApp",
    "Assets.xcassets",
    "AppIcon.icon",
]
for fragment in required_project_fragments:
    if fragment not in project_file:
        fail(f"PaperBanana.xcodeproj is missing required fragment: {fragment}")

if "xcodebuild" not in build_script or '-project "$PROJECT_FILE"' not in build_script:
    fail("script/build_and_run.sh must build through PaperBanana.xcodeproj")
if "swift build" in build_script:
    fail("script/build_and_run.sh must not fall back to a raw SwiftPM app build")
if "--install" not in build_script or "/Applications/${APP_NAME}.app" not in build_script:
    fail("script/build_and_run.sh must retain the native /Applications install path")

environment_file = root / ".codex" / "environments" / "environment.toml"
if environment_file.exists():
    environment_text = environment_file.read_text(encoding="utf-8")
    if "./script/build_and_run.sh" not in environment_text:
        fail(".codex/environments/environment.toml Run action must use script/build_and_run.sh")

print("PaperBanana native Xcode contract passed.")
PY
