import csv
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CONTRACT = (
    REPO_ROOT / "docs" / "integration" / "WP007_MANUAL_VOICEOVER_ARTIFACT_CONTRACT.md"
)
TEMPLATE_DIR = REPO_ROOT / "docs" / "integration" / "wp007_voiceover_manual_templates"
README = TEMPLATE_DIR / "README.md"
VOICEOVER_TEMPLATE = TEMPLATE_DIR / "voiceover-speech-output.template.tsv"
KEYBOARD_TEMPLATE = TEMPLATE_DIR / "keyboard-traversal.template.tsv"
VALIDATOR = TEMPLATE_DIR / "validate_completed_packet.py"

EXPECTED_ROUTE_IDS = {f"VO-{index:02d}" for index in range(1, 17)}
VOICEOVER_COLUMNS = [
    "route_id",
    "surface",
    "step",
    "control_or_row",
    "expected_minimum",
    "actual_spoken_output",
    "pass_fail",
    "notes",
]
KEYBOARD_COLUMNS = [
    "route_id",
    "surface",
    "step",
    "start_focus",
    "key_sequence",
    "expected_end_focus",
    "actual_end_focus",
    "visible_focus_state",
    "voiceover_focus_state",
    "pass_fail",
    "notes",
]


def _read_tsv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        return list(reader.fieldnames or []), list(reader)


def test_wp007_contract_preserves_manual_claim_boundary_and_required_files():
    contract = CONTRACT.read_text(encoding="utf-8")
    readme = README.read_text(encoding="utf-8")
    combined = f"{contract}\n{readme}"

    required_phrases = [
        "Status: prepared artifact contract, not traversal evidence",
        "cannot validate that VoiceOver actually spoke the recorded words",
        "Automated checks must not mark WP-007 complete",
        "do not close WP-007",
        "do not launch the app",
        "start live generation",
        "call a provider",
        "same physical display as Codex",
        "completed run must be reviewed by a human",
        "voiceover-speech-output.tsv",
        "keyboard-traversal.tsv",
        "environment.md",
        "defects.md",
        "cleanup.md",
        "voiceover-speech-output.template.tsv",
        "keyboard-traversal.template.tsv",
        "environment.template.md",
        "defects.template.md",
        "cleanup.template.md",
        "validate_completed_packet.py",
        "provider secrets",
        "auth headers",
        "raw provider payloads",
        "WP-007/T-021 remains open",
    ]

    for phrase in required_phrases:
        assert phrase in combined


def test_voiceover_template_has_every_required_route_and_exact_columns():
    columns, rows = _read_tsv(VOICEOVER_TEMPLATE)

    assert columns == VOICEOVER_COLUMNS
    assert {row["route_id"] for row in rows} == EXPECTED_ROUTE_IDS
    assert len(rows) == len(EXPECTED_ROUTE_IDS)
    assert all(row["actual_spoken_output"].startswith("<record actual") for row in rows)
    assert all(row["pass_fail"] == "<pass|pass_with_limitation|fail|not_run>" for row in rows)


def test_keyboard_template_has_every_required_route_and_exact_columns():
    columns, rows = _read_tsv(KEYBOARD_TEMPLATE)

    assert columns == KEYBOARD_COLUMNS
    assert {row["route_id"] for row in rows} == EXPECTED_ROUTE_IDS
    assert len(rows) == len(EXPECTED_ROUTE_IDS)
    assert all(row["actual_end_focus"].startswith("<record actual") for row in rows)
    assert all(row["visible_focus_state"].startswith("<record visible") for row in rows)
    assert all(row["voiceover_focus_state"].startswith("<record VoiceOver") for row in rows)
    assert all(row["pass_fail"] == "<pass|pass_with_limitation|fail|not_run>" for row in rows)


def test_contract_route_table_and_templates_share_route_ids():
    contract = CONTRACT.read_text(encoding="utf-8")
    _, voiceover_rows = _read_tsv(VOICEOVER_TEMPLATE)
    _, keyboard_rows = _read_tsv(KEYBOARD_TEMPLATE)

    for route_id in EXPECTED_ROUTE_IDS:
        assert f"| {route_id} |" in contract

    voiceover_ids = [row["route_id"] for row in voiceover_rows]
    keyboard_ids = [row["route_id"] for row in keyboard_rows]
    assert voiceover_ids == keyboard_ids


def test_templates_do_not_contain_completed_manual_observations():
    template_text = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (VOICEOVER_TEMPLATE, KEYBOARD_TEMPLATE)
    )

    assert "<record actual spoken output during manual run>" in template_text
    assert "<record actual ending focus during manual run>" in template_text
    assert "VoiceOver spoke:" not in template_text
    assert "pass\t" not in template_text
    assert "pass_with_limitation\t" not in template_text


def test_wp007_contract_documents_completed_packet_validator_boundary():
    combined = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (CONTRACT, README, VALIDATOR)
    )

    required_phrases = [
        "Completed Packet Validation",
        "validate_completed_packet.py",
        "structurally reviewable",
        "does not close WP-007",
        "cannot verify the spoken output",
        "must not be used to mark",
        "Human release review is still required",
    ]
    for phrase in required_phrases:
        assert phrase in combined
