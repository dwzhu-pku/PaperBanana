import importlib.util
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
VALIDATOR_PATH = (
    REPO_ROOT
    / "docs"
    / "integration"
    / "wp007_voiceover_manual_templates"
    / "validate_completed_packet.py"
)


def _load_validator():
    spec = importlib.util.spec_from_file_location("wp007_voiceover_validator", VALIDATOR_PATH)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


VALIDATOR = _load_validator()
EXPECTED_ROUTE_IDS = [f"VO-{index:02d}" for index in range(1, 17)]


def _route_expected(route_id: str) -> str:
    if route_id == "VO-04":
        return (
            "Reference rows include search filter behavior, selected and unselected states, "
            "missing image warnings, the 10/10 selection cap, and selection limit disabled state"
        )
    if route_id == "VO-05":
        return (
            "Reference setup states include missing dataset, malformed ref.json, empty ref.json, "
            "and plot manual disabled behavior"
        )
    return "Expected semantic label and current state"


def _route_voiceover_output(route_id: str) -> str:
    if route_id == "VO-04":
        return (
            "Reference examples search filter result, selected row, unselected row, "
            "missing image, 10/10 cap, selection limit disabled"
        )
    if route_id == "VO-05":
        return (
            "Reference examples missing dataset, malformed ref.json, empty ref.json, "
            "plot manual disabled"
        )
    return f"Observed VoiceOver output for {route_id}"


def _route_notes(route_id: str) -> str:
    if route_id == "VO-04":
        return "search filter selected unselected missing image 10/10 selection limit disabled"
    if route_id == "VO-05":
        return "missing dataset malformed ref.json empty plot manual disabled"
    return "none"


def _write_valid_packet(packet_dir: Path, *, status: str = "pass") -> None:
    packet_dir.mkdir()
    packet_dir.joinpath("voiceover-speech-output.tsv").write_text(
        "\n".join(
            [
                "\t".join(VALIDATOR.VOICEOVER_COLUMNS),
                *[
                    "\t".join(
                        [
                            route_id,
                            f"Surface {route_id}",
                            f"{route_id}.1",
                            f"Control {route_id}",
                            _route_expected(route_id),
                            _route_voiceover_output(route_id),
                            status,
                            _route_notes(route_id),
                        ]
                    )
                    for route_id in EXPECTED_ROUTE_IDS
                ],
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    packet_dir.joinpath("keyboard-traversal.tsv").write_text(
        "\n".join(
            [
                "\t".join(VALIDATOR.KEYBOARD_COLUMNS),
                *[
                    "\t".join(
                        [
                            route_id,
                            f"Surface {route_id}",
                            f"{route_id}.1",
                            "Start focus",
                            "Tab",
                            "Expected end focus",
                            f"Actual end focus for {route_id}",
                            "visible focus ring present",
                            f"VoiceOver focus followed visible focus; {_route_notes(route_id)}",
                            status,
                            _route_notes(route_id),
                        ]
                    )
                    for route_id in EXPECTED_ROUTE_IDS
                ],
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    packet_dir.joinpath("environment.md").write_text(_environment_text(), encoding="utf-8")
    packet_dir.joinpath("cleanup.md").write_text(_cleanup_text(), encoding="utf-8")
    packet_dir.joinpath("defects.md").write_text(_defects_text(status=status), encoding="utf-8")


def _environment_text() -> str:
    return """# WP-007 Manual VoiceOver Environment

- Candidate SHA: dac44760c0ecec03e588b8984362f1e29a68520e
- Branch: integration/native-first-rc-native
- Worktree: /Users/jeff/Codex_projects/PaperBanana-native-integrated
- Build/install command: ./script/build_and_run.sh --release --install --no-open
- Installed app path: /Applications/PaperBanana.app
- Installed binary SHA-256: abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
- Bundle identifier/version/build: local.paperbanana.gui 0.1.0 1
- Date/time: 2026-06-23T15:02:17-0400 to 2026-06-23T15:45:00-0400
- macOS version/build: 27.0 26A5353q
- Hardware architecture: arm64
- Xcode version/build: Xcode 27.0 27A5194q
- VoiceOver state: on, reviewer heard speech output
- Audio/capture reliability: reliable
- Codex display placement: same physical display confirmed
- Temporary Application Support root: /tmp/paperbanana-wp007-support
- Synthetic checkout path: /tmp/paperbanana-wp007-checkout
- PaperBananaBench fixture path: /Users/jeff/Codex_projects/PaperBanana/data/PaperBananaBench
- Provider credentials enabled: no
- Live provider approval present: no
- No-spend dry-run mode used: yes
- Appearance: Dark
- Text size: default
- Increased Contrast: off
- Reduce Transparency: off
- Reduce Motion: off
- `secrets.json` read/copied/printed: no
- Provider key or auth header observed in UI/speech/logs: no
- Private manuscript/provider payload included in evidence: no
- Artifact directory: docs/integration/evidence/screenshots/20260623-wp007-manual
- Summary evidence file: docs/integration/evidence/20260623-wp007-manual-summary.md
"""


def _cleanup_text() -> str:
    return """# WP-007 Manual VoiceOver Cleanup

- PaperBanana app process running after cleanup: no
- Legacy backend process from this worktree running after cleanup: no
- VoiceOver helper process unexpectedly left by the test: no
- Temporary local HTTP server running after cleanup: no
- Temporary app-scoped appearance override restored: yes
- Temporary app-scoped text-size override restored: yes
- Temporary repository path override restored: yes
- Temporary Application Support root removed or archived: removed
- Synthetic checkout removed or archived: archived
- No live provider generation was started: confirmed
- No `codex exec` run was started: confirmed
- No provider secret, auth header, or private path was copied into evidence: confirmed
- No destructive cleanup/reset was performed on user data: confirmed

## Remaining Cleanup Exceptions

None.
"""


def _defects_text(*, status: str) -> str:
    rows = "\n".join(
        f"| {route_id} | {status} | none | no |" for route_id in EXPECTED_ROUTE_IDS
    )
    return f"""# WP-007 Manual VoiceOver Defects

## Route Disposition

| Route ID | Status | Defect or limitation ID | Release-owner acceptance required? |
|---|---|---|---|
{rows}

## Defect Log

No defects recorded in this synthetic validator fixture.

## Release Owner Acceptance

No accepted limitations in this synthetic validator fixture.
"""


def test_completed_packet_validator_accepts_complete_synthetic_packet(tmp_path):
    packet_dir = tmp_path / "complete"
    _write_valid_packet(packet_dir)

    result = VALIDATOR.validate_packet(packet_dir)

    assert result.errors == []
    assert result.open_routes == []


def test_completed_packet_validator_reports_open_but_structural_status(tmp_path):
    packet_dir = tmp_path / "open-routes"
    _write_valid_packet(packet_dir, status="not_run")

    result = VALIDATOR.validate_packet(packet_dir)

    assert result.errors == []
    assert result.open_routes == EXPECTED_ROUTE_IDS


def test_completed_packet_validator_rejects_missing_route(tmp_path):
    packet_dir = tmp_path / "missing-route"
    _write_valid_packet(packet_dir)
    voiceover = packet_dir / "voiceover-speech-output.tsv"
    lines = voiceover.read_text(encoding="utf-8").splitlines()
    voiceover.write_text("\n".join(line for line in lines if not line.startswith("VO-16\t")) + "\n")

    result = VALIDATOR.validate_packet(packet_dir)

    assert any("missing required routes ['VO-16']" in error for error in result.errors)


def test_completed_packet_validator_rejects_placeholders(tmp_path):
    packet_dir = tmp_path / "placeholder"
    _write_valid_packet(packet_dir)
    voiceover = packet_dir / "voiceover-speech-output.tsv"
    text = voiceover.read_text(encoding="utf-8")
    voiceover.write_text(
        text.replace("Observed VoiceOver output for VO-01", "<record actual spoken output>"),
        encoding="utf-8",
    )

    result = VALIDATOR.validate_packet(packet_dir)

    assert any("placeholder actual_spoken_output for VO-01" in error for error in result.errors)


def test_completed_packet_validator_rejects_unsafe_environment_values(tmp_path):
    packet_dir = tmp_path / "unsafe-environment"
    _write_valid_packet(packet_dir)
    environment = packet_dir / "environment.md"
    text = environment.read_text(encoding="utf-8")
    environment.write_text(
        text.replace("VoiceOver state: on, reviewer heard speech output", "VoiceOver state: off")
        .replace("Provider credentials enabled: no", "Provider credentials enabled: yes"),
        encoding="utf-8",
    )

    result = VALIDATOR.validate_packet(packet_dir)

    assert any("VoiceOver state" in error and "unsafe value" in error for error in result.errors)
    assert any("Provider credentials enabled" in error and "unsafe value" in error for error in result.errors)


def test_completed_packet_validator_rejects_live_cleanup_contradictions(tmp_path):
    packet_dir = tmp_path / "live-cleanup"
    _write_valid_packet(packet_dir)
    cleanup = packet_dir / "cleanup.md"
    text = cleanup.read_text(encoding="utf-8")
    cleanup.write_text(
        text.replace("No live provider generation was started: confirmed", "No live provider generation was started: no")
        .replace("No `codex exec` run was started: confirmed", "No `codex exec` run was started: no"),
        encoding="utf-8",
    )

    result = VALIDATOR.validate_packet(packet_dir)

    assert any("No live provider generation was started" in error for error in result.errors)
    assert any("No `codex exec` run was started" in error for error in result.errors)


def test_completed_packet_validator_rejects_pass_with_limitation_without_acceptance(tmp_path):
    packet_dir = tmp_path / "limitation-without-acceptance"
    _write_valid_packet(packet_dir)
    for file_name in ["voiceover-speech-output.tsv", "keyboard-traversal.tsv"]:
        path = packet_dir / file_name
        path.write_text(
            path.read_text(encoding="utf-8").replace("\tpass\t", "\tpass_with_limitation\t", 1),
            encoding="utf-8",
        )
    defects = packet_dir / "defects.md"
    defects.write_text(
        defects.read_text(encoding="utf-8").replace("| VO-01 | pass | none | no |", "| VO-01 | pass_with_limitation | none | yes |"),
        encoding="utf-8",
    )

    result = VALIDATOR.validate_packet(packet_dir)

    assert "VO-01" in result.open_routes
    assert any("requires a defect or limitation id" in error for error in result.errors)
    assert any("cannot use empty acceptance text" in error for error in result.errors)


def test_completed_packet_validator_rejects_route_disposition_mismatch(tmp_path):
    packet_dir = tmp_path / "disposition-mismatch"
    _write_valid_packet(packet_dir)
    defects = packet_dir / "defects.md"
    defects.write_text(
        defects.read_text(encoding="utf-8").replace("| VO-02 | pass | none | no |", "| VO-02 | not_run | none | no |"),
        encoding="utf-8",
    )

    result = VALIDATOR.validate_packet(packet_dir)

    assert any("status for VO-02 is 'not_run'" in error for error in result.errors)


def test_completed_packet_validator_rejects_missing_reference_route_coverage(tmp_path):
    packet_dir = tmp_path / "missing-reference-coverage"
    _write_valid_packet(packet_dir)
    voiceover = packet_dir / "voiceover-speech-output.tsv"
    voiceover.write_text(
        voiceover.read_text(encoding="utf-8").replace("missing image", "omitted-state"),
        encoding="utf-8",
    )
    keyboard = packet_dir / "keyboard-traversal.tsv"
    keyboard.write_text(
        keyboard.read_text(encoding="utf-8").replace("missing image", "omitted-state"),
        encoding="utf-8",
    )

    result = VALIDATOR.validate_packet(packet_dir)

    assert any("route VO-04" in error and "missing image" in error for error in result.errors)


def test_completed_packet_validator_scans_nested_text_sidecars_for_secrets(tmp_path):
    packet_dir = tmp_path / "nested-secret"
    _write_valid_packet(packet_dir)
    nested = packet_dir / "notes"
    nested.mkdir()
    nested.joinpath("review.md").write_text(
        "Do not archive this token: Bearer abcdefghijklmnop",
        encoding="utf-8",
    )

    result = VALIDATOR.validate_packet(packet_dir)

    assert any("notes/review.md" in error for error in result.errors)


def test_completed_packet_validator_cli_preserves_completion_boundary(tmp_path, capsys):
    packet_dir = tmp_path / "complete"
    _write_valid_packet(packet_dir)

    exit_code = VALIDATOR.main([str(packet_dir)])
    captured = capsys.readouterr()

    assert exit_code == 0
    assert "WP-007 packet structure valid." in captured.out
    assert "Human release review is still required." in captured.out
