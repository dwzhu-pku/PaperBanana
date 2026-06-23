"""Validate a completed WP-007 manual VoiceOver artifact packet.

This tool validates structure and placeholder removal only. It cannot prove
that VoiceOver actually spoke the recorded words and must not be used to mark
WP-007 complete without human review.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from dataclasses import dataclass
from pathlib import Path


EXPECTED_ROUTE_IDS = {f"VO-{index:02d}" for index in range(1, 17)}
ALLOWED_STATUS = {"pass", "pass_with_limitation", "fail", "not_run"}
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
REQUIRED_FILES = [
    "voiceover-speech-output.tsv",
    "keyboard-traversal.tsv",
    "environment.md",
    "defects.md",
    "cleanup.md",
]
REQUIRED_ENVIRONMENT_FIELDS = [
    "Candidate SHA",
    "Branch",
    "Worktree",
    "Build/install command",
    "Installed app path",
    "Installed binary SHA-256",
    "Bundle identifier/version/build",
    "Date/time",
    "macOS version/build",
    "Hardware architecture",
    "Xcode version/build",
    "VoiceOver state",
    "Audio/capture reliability",
    "Codex display placement",
    "Temporary Application Support root",
    "Synthetic checkout path",
    "PaperBananaBench fixture path",
    "Provider credentials enabled",
    "Live provider approval present",
    "No-spend dry-run mode used",
    "Appearance",
    "Text size",
    "Increased Contrast",
    "Reduce Transparency",
    "Reduce Motion",
    "`secrets.json` read/copied/printed",
    "Provider key or auth header observed in UI/speech/logs",
    "Private manuscript/provider payload included in evidence",
    "Artifact directory",
    "Summary evidence file",
]
REQUIRED_CLEANUP_FIELDS = [
    "PaperBanana app process running after cleanup",
    "Legacy backend process from this worktree running after cleanup",
    "VoiceOver helper process unexpectedly left by the test",
    "Temporary local HTTP server running after cleanup",
    "Temporary app-scoped appearance override restored",
    "Temporary app-scoped text-size override restored",
    "Temporary repository path override restored",
    "Temporary Application Support root removed or archived",
    "Synthetic checkout removed or archived",
    "No live provider generation was started",
    "No `codex exec` run was started",
    "No provider secret, auth header, or private path was copied into evidence",
    "No destructive cleanup/reset was performed on user data",
]
ENVIRONMENT_REQUIRED_VALUES = {
    "VoiceOver state": ("on",),
    "Audio/capture reliability": ("reliable",),
    "Codex display placement": ("same physical display", "confirmed"),
    "Provider credentials enabled": ("no",),
    "Live provider approval present": ("no",),
    "No-spend dry-run mode used": ("yes",),
    "`secrets.json` read/copied/printed": ("no",),
    "Provider key or auth header observed in UI/speech/logs": ("no",),
    "Private manuscript/provider payload included in evidence": ("no",),
}
ENVIRONMENT_FORBIDDEN_VALUES = {
    "VoiceOver state": ("off", "disabled"),
    "Audio/capture reliability": ("unreliable", "not reliable", "failed"),
    "Codex display placement": ("other display", "not same", "unconfirmed", "defect"),
    "Provider credentials enabled": ("yes", "enabled"),
    "Live provider approval present": ("yes", "approved"),
    "No-spend dry-run mode used": ("no", "disabled"),
    "`secrets.json` read/copied/printed": ("yes", "copied", "printed"),
    "Provider key or auth header observed in UI/speech/logs": ("yes", "observed"),
    "Private manuscript/provider payload included in evidence": ("yes", "included"),
}
CLEANUP_REQUIRED_VALUES = {
    "PaperBanana app process running after cleanup": ("no",),
    "Legacy backend process from this worktree running after cleanup": ("no",),
    "VoiceOver helper process unexpectedly left by the test": ("no",),
    "Temporary local HTTP server running after cleanup": ("no",),
    "No live provider generation was started": ("confirmed",),
    "No `codex exec` run was started": ("confirmed",),
    "No provider secret, auth header, or private path was copied into evidence": ("confirmed",),
    "No destructive cleanup/reset was performed on user data": ("confirmed",),
}
ROUTE_TEXT_REQUIREMENTS = {
    "VO-04": [
        ("search",),
        ("filter",),
        ("selected",),
        ("unselected",),
        ("missing image",),
        ("10/10",),
        ("selection limit",),
        ("disabled",),
    ],
    "VO-05": [
        ("missing dataset",),
        ("malformed",),
        ("ref.json",),
        ("empty",),
        ("plot",),
        ("manual",),
        ("disabled",),
    ],
}
FORBIDDEN_SECRET_PATTERNS = [
    re.compile(r"sk-[A-Za-z0-9_-]{16,}"),
    re.compile(r"AIza[0-9A-Za-z_-]{20,}"),
    re.compile(r"Bearer\s+[A-Za-z0-9._-]{12,}", re.IGNORECASE),
]
SKIP_SECRET_SCAN_SUFFIXES = {
    ".gif",
    ".heic",
    ".jpeg",
    ".jpg",
    ".mov",
    ".mp4",
    ".pdf",
    ".png",
    ".tiff",
    ".webp",
}


@dataclass(frozen=True)
class ValidationResult:
    errors: list[str]
    open_routes: list[str]

    @property
    def ok(self) -> bool:
        return not self.errors


def validate_packet(packet_dir: Path) -> ValidationResult:
    errors: list[str] = []
    open_routes: set[str] = set()

    if not packet_dir.exists() or not packet_dir.is_dir():
        return ValidationResult([f"Packet directory not found: {packet_dir}"], [])

    for file_name in REQUIRED_FILES:
        if not (packet_dir / file_name).is_file():
            errors.append(f"Missing required file: {file_name}")

    if errors:
        return ValidationResult(errors, [])

    errors.extend(_validate_tsv(packet_dir / "voiceover-speech-output.tsv", VOICEOVER_COLUMNS))
    errors.extend(_validate_tsv(packet_dir / "keyboard-traversal.tsv", KEYBOARD_COLUMNS))
    errors.extend(_validate_markdown_fields(packet_dir / "environment.md", REQUIRED_ENVIRONMENT_FIELDS))
    errors.extend(_validate_markdown_fields(packet_dir / "cleanup.md", REQUIRED_CLEANUP_FIELDS))
    errors.extend(_validate_environment_safety(packet_dir / "environment.md"))
    errors.extend(_validate_cleanup_safety(packet_dir / "cleanup.md"))
    voiceover_rows = _read_tsv(packet_dir / "voiceover-speech-output.tsv")[1]
    keyboard_rows = _read_tsv(packet_dir / "keyboard-traversal.tsv")[1]
    tsv_route_statuses = _aggregate_tsv_route_statuses(voiceover_rows + keyboard_rows)
    defect_errors, defect_open_routes = _validate_defects(
        packet_dir / "defects.md",
        tsv_route_statuses,
    )
    errors.extend(defect_errors)
    open_routes.update(defect_open_routes)
    errors.extend(_scan_for_obvious_secrets(packet_dir))
    errors.extend(_validate_route_specific_coverage(voiceover_rows + keyboard_rows))

    for row in voiceover_rows + keyboard_rows:
        if row.get("pass_fail") in {"fail", "not_run"}:
            open_routes.add(row.get("route_id", "<missing-route>"))
        if row.get("pass_fail") == "pass_with_limitation":
            open_routes.add(row.get("route_id", "<missing-route>"))

    return ValidationResult(errors, sorted(open_routes))


def _read_tsv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        return list(reader.fieldnames or []), list(reader)


def _validate_tsv(path: Path, expected_columns: list[str]) -> list[str]:
    errors: list[str] = []
    columns, rows = _read_tsv(path)
    if columns != expected_columns:
        errors.append(f"{path.name}: expected columns {expected_columns}, found {columns}")
        return errors

    if not rows:
        errors.append(f"{path.name}: no rows")
        return errors

    route_ids = {row.get("route_id", "") for row in rows}
    missing_routes = sorted(EXPECTED_ROUTE_IDS - route_ids)
    unknown_routes = sorted(route_ids - EXPECTED_ROUTE_IDS)
    if missing_routes:
        errors.append(f"{path.name}: missing required routes {missing_routes}")
    if unknown_routes:
        errors.append(f"{path.name}: unknown route ids {unknown_routes}")

    for index, row in enumerate(rows, start=2):
        route_id = row.get("route_id", "")
        status = row.get("pass_fail", "").strip()
        if status not in ALLOWED_STATUS:
            errors.append(f"{path.name}:{index}: invalid pass_fail for {route_id}: {status!r}")
        for column in expected_columns:
            value = (row.get(column) or "").strip()
            if not value:
                errors.append(f"{path.name}:{index}: blank {column} for {route_id}")
            elif _is_placeholder(value):
                errors.append(f"{path.name}:{index}: placeholder {column} for {route_id}")
        if "actual_spoken_output" in row and len(row["actual_spoken_output"].strip()) < 8:
            errors.append(f"{path.name}:{index}: actual_spoken_output too short for {route_id}")
        if "actual_end_focus" in row and len(row["actual_end_focus"].strip()) < 4:
            errors.append(f"{path.name}:{index}: actual_end_focus too short for {route_id}")

    return errors


def _validate_markdown_fields(path: Path, labels: list[str]) -> list[str]:
    errors: list[str] = []
    text = path.read_text(encoding="utf-8")
    for label in labels:
        match = re.search(rf"^- {re.escape(label)}:\s*(.+)$", text, re.MULTILINE)
        if not match:
            errors.append(f"{path.name}: missing field {label!r}")
            continue
        value = match.group(1).strip()
        if not value:
            errors.append(f"{path.name}: blank field {label!r}")
        elif _is_placeholder(value):
            errors.append(f"{path.name}: placeholder field {label!r}")
    return errors


def _validate_environment_safety(path: Path) -> list[str]:
    values = _markdown_values(path, REQUIRED_ENVIRONMENT_FIELDS)
    return _validate_required_and_forbidden_values(
        path,
        values,
        ENVIRONMENT_REQUIRED_VALUES,
        ENVIRONMENT_FORBIDDEN_VALUES,
    )


def _validate_cleanup_safety(path: Path) -> list[str]:
    values = _markdown_values(path, REQUIRED_CLEANUP_FIELDS)
    return _validate_required_values(path, values, CLEANUP_REQUIRED_VALUES)


def _markdown_values(path: Path, labels: list[str]) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    values: dict[str, str] = {}
    for label in labels:
        match = re.search(rf"^- {re.escape(label)}:\s*(.+)$", text, re.MULTILINE)
        if match:
            values[label] = match.group(1).strip()
    return values


def _validate_required_and_forbidden_values(
    path: Path,
    values: dict[str, str],
    required: dict[str, tuple[str, ...]],
    forbidden: dict[str, tuple[str, ...]],
) -> list[str]:
    errors = _validate_required_values(path, values, required)
    for label, blocked_terms in forbidden.items():
        value = values.get(label, "")
        normalized = _normalize_for_match(value)
        for term in blocked_terms:
            if term in normalized:
                errors.append(f"{path.name}: unsafe value for {label!r}: {value!r}")
                break
    return errors


def _validate_required_values(
    path: Path,
    values: dict[str, str],
    required: dict[str, tuple[str, ...]],
) -> list[str]:
    errors: list[str] = []
    for label, required_terms in required.items():
        value = values.get(label, "")
        normalized = _normalize_for_match(value)
        missing_terms = [term for term in required_terms if term not in normalized]
        if missing_terms:
            errors.append(
                f"{path.name}: field {label!r} must include {required_terms}, found {value!r}"
            )
    return errors


def _aggregate_tsv_route_statuses(rows: list[dict[str, str]]) -> dict[str, str]:
    statuses: dict[str, str] = {}
    for row in rows:
        route_id = row.get("route_id", "")
        status = row.get("pass_fail", "").strip()
        if route_id not in EXPECTED_ROUTE_IDS or status not in ALLOWED_STATUS:
            continue
        statuses[route_id] = _worst_status(statuses.get(route_id, "pass"), status)
    return statuses


def _worst_status(left: str, right: str) -> str:
    rank = {"pass": 0, "pass_with_limitation": 1, "not_run": 2, "fail": 3}
    return right if rank[right] > rank[left] else left


def _validate_defects(
    path: Path,
    tsv_route_statuses: dict[str, str],
) -> tuple[list[str], set[str]]:
    errors: list[str] = []
    open_routes: set[str] = set()
    text = path.read_text(encoding="utf-8")
    disposition_rows = []
    limitation_rows: list[tuple[str, str]] = []
    for line in text.splitlines():
        if not line.startswith("| VO-"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 4:
            errors.append(f"{path.name}: malformed route disposition row: {line}")
            continue
        route_id, status, defect_id, acceptance_required = cells[:4]
        disposition_rows.append(route_id)
        if route_id not in EXPECTED_ROUTE_IDS:
            errors.append(f"{path.name}: unknown route id {route_id}")
        if status not in ALLOWED_STATUS:
            errors.append(f"{path.name}: invalid status for {route_id}: {status!r}")
        expected_status = tsv_route_statuses.get(route_id)
        if expected_status is not None and status in ALLOWED_STATUS and status != expected_status:
            errors.append(
                f"{path.name}: status for {route_id} is {status!r}, "
                f"but TSV rows aggregate to {expected_status!r}"
            )
        if _is_placeholder(defect_id) or _is_placeholder(acceptance_required):
            errors.append(f"{path.name}: placeholder disposition for {route_id}")
        if status in {"fail", "not_run", "pass_with_limitation"}:
            open_routes.add(route_id)
        if status == "pass_with_limitation":
            limitation_rows.append((route_id, defect_id))
            if acceptance_required.lower() != "yes":
                errors.append(
                    f"{path.name}: pass_with_limitation for {route_id} requires release-owner acceptance"
                )
            if defect_id.lower() == "none":
                errors.append(
                    f"{path.name}: pass_with_limitation for {route_id} requires a defect or limitation id"
                )

    missing_routes = sorted(EXPECTED_ROUTE_IDS - set(disposition_rows))
    if missing_routes:
        errors.append(f"{path.name}: missing route disposition rows {missing_routes}")
    if limitation_rows:
        acceptance_text = _release_owner_acceptance_text(text)
        if "no accepted limitations" in acceptance_text.lower():
            errors.append(f"{path.name}: pass_with_limitation routes cannot use empty acceptance text")
        for route_id, defect_id in limitation_rows:
            if route_id not in acceptance_text or defect_id not in acceptance_text:
                errors.append(
                    f"{path.name}: release-owner acceptance must name {route_id} and {defect_id}"
                )

    return errors, open_routes


def _scan_for_obvious_secrets(packet_dir: Path) -> list[str]:
    errors: list[str] = []
    for path in packet_dir.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() in SKIP_SECRET_SCAN_SUFFIXES:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for pattern in FORBIDDEN_SECRET_PATTERNS:
            if pattern.search(text):
                errors.append(
                    f"{path.relative_to(packet_dir)}: possible provider secret matched {pattern.pattern!r}"
                )
    return errors


def _validate_route_specific_coverage(rows: list[dict[str, str]]) -> list[str]:
    errors: list[str] = []
    rows_by_route: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        rows_by_route.setdefault(row.get("route_id", ""), []).append(row)

    for route_id, required_groups in ROUTE_TEXT_REQUIREMENTS.items():
        route_text = _normalize_for_match(
            " ".join(
                " ".join(value for value in row.values() if value)
                for row in rows_by_route.get(route_id, [])
            )
        )
        for required_terms in required_groups:
            if not all(term in route_text for term in required_terms):
                errors.append(
                    f"route {route_id}: completed packet text must mention {required_terms}"
                )
    return errors


def _release_owner_acceptance_text(text: str) -> str:
    marker = "## Release Owner Acceptance"
    if marker not in text:
        return ""
    return text.split(marker, 1)[1]


def _normalize_for_match(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def _is_placeholder(value: str) -> bool:
    stripped = value.strip()
    return (
        stripped.startswith("<")
        and stripped.endswith(">")
        or "TODO" in stripped.upper()
        or "PLACEHOLDER" in stripped.upper()
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packet_dir", type=Path, help="Completed WP-007 artifact directory")
    args = parser.parse_args(argv)

    result = validate_packet(args.packet_dir)
    if result.ok:
        print("WP-007 packet structure valid.")
        if result.open_routes:
            print(
                "Open route dispositions remain: "
                + ", ".join(result.open_routes)
                + ". This does not close WP-007."
            )
        else:
            print("No open route dispositions found. Human release review is still required.")
        return 0

    for error in result.errors:
        print(f"ERROR: {error}", file=sys.stderr)
    if result.open_routes:
        print("Open routes: " + ", ".join(result.open_routes), file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
