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
                            "Expected semantic label and current state",
                            f"Observed VoiceOver output for {route_id}",
                            status,
                            "none",
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
                            "VoiceOver focus followed visible focus",
                            status,
                            "none",
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


def test_completed_packet_validator_cli_preserves_completion_boundary(tmp_path, capsys):
    packet_dir = tmp_path / "complete"
    _write_valid_packet(packet_dir)

    exit_code = VALIDATOR.main([str(packet_dir)])
    captured = capsys.readouterr()

    assert exit_code == 0
    assert "WP-007 packet structure valid." in captured.out
    assert "Human release review is still required." in captured.out
