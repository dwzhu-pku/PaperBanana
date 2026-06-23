"""WP-108 human-review packet generator.

This utility prepares an offline scorecard packet for already-validated native
run artifacts. It binds the manifest, run map, artifact-completeness report,
and generated image hashes so later reviewer scores can be traced to exact
outputs. It does not score images, call providers, or read provider payloads.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from utils.wp108_benchmark_contract import (
    ContractError,
    validate_manifest,
    validate_report,
)


PACKET_SCHEMA_VERSION = "wp108.human_review_packet.v1"
DEFAULT_REVIEWER_POLICY_ID = "paperbanana-wp108-human-review-v1"
DEFAULT_ADJUDICATION_POLICY = (
    "Reviewer score slots are intentionally blank. A later scored report must "
    "record completed reviewer scores and final adjudicated case scores."
)
DEFAULT_CRITICAL_FAILURE_POLICY = (
    "Any critical semantic, privacy, artifact-linkage, or non-recoverable "
    "rendering failure must be listed and prevents a quality pass."
)
DEFAULT_SCORE_SCALE = {"minimum": 0.0, "maximum": 4.0}


class ReviewPacketError(ValueError):
    """Raised when a WP-108 human-review packet is malformed."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ReviewPacketError(message)


def _load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ReviewPacketError(f"{path}: invalid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ReviewPacketError(f"{path}: top-level JSON value must be an object")
    return value


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _standard(path: Path) -> str:
    return str(path.expanduser().resolve(strict=False))


def _string(owner: dict[str, Any], field: str, context: str) -> str:
    value = owner.get(field)
    _require(isinstance(value, str) and bool(value.strip()), f"{context}.{field} must be a non-empty string")
    return value


def _hex_digest(owner: dict[str, Any], field: str, context: str) -> str:
    value = _string(owner, field, context)
    _require(len(value) == 64 and all(character in "0123456789abcdef" for character in value), f"{context}.{field} must be a lowercase sha256 digest")
    return value


def _artifact_case_by_id(report: dict[str, Any]) -> dict[str, dict[str, Any]]:
    artifact_checks = report.get("artifact_checks")
    _require(isinstance(artifact_checks, dict), "artifact report is missing artifact_checks")
    cases = artifact_checks.get("cases")
    _require(isinstance(cases, list) and cases, "artifact_checks.cases must be a non-empty list")

    by_id: dict[str, dict[str, Any]] = {}
    for index, case in enumerate(cases):
        context = f"artifact_checks.cases[{index}]"
        _require(isinstance(case, dict), f"{context} must be an object")
        case_id = _string(case, "case_id", context)
        _require(case_id not in by_id, f"{context}.case_id is duplicated: {case_id}")
        status = _string(case, "status", context)
        _require(status == "fixture_passed", f"{context}.status must be fixture_passed before human review")
        failures = case.get("artifact_failures")
        _require(isinstance(failures, list) and not failures, f"{context}.artifact_failures must be empty before human review")
        by_id[case_id] = case
    return by_id


def _artifact_path_for(case: dict[str, Any], output_name: str) -> Path:
    outputs = case.get("checked_outputs")
    files = case.get("checked_files")
    _require(isinstance(outputs, list) and isinstance(files, list), f"artifact case {case.get('case_id')} must include checked_outputs and checked_files")
    _require(len(outputs) == len(files), f"artifact case {case.get('case_id')} checked_outputs/files length mismatch")
    for index, name in enumerate(outputs):
        if name == output_name:
            raw_path = files[index]
            _require(isinstance(raw_path, str) and raw_path.strip(), f"artifact case {case.get('case_id')} has invalid path for {output_name}")
            path = Path(raw_path)
            _require(path.exists(), f"artifact case {case.get('case_id')} {output_name} path is missing: {path}")
            return path
    raise ReviewPacketError(f"artifact case {case.get('case_id')} has no checked output {output_name}")


def _blank_score_slots(*, rubric_ids: list[str], reviewer_count: int) -> list[dict[str, Any]]:
    return [
        {
            "reviewer_id": "",
            "completed_at_utc": "",
            "attestation": False,
            "scores": {rubric_id: None for rubric_id in rubric_ids},
            "critical_failures": [],
        }
        for _ in range(reviewer_count)
    ]


def build_review_packet(
    *,
    manifest: dict[str, Any],
    manifest_contract: dict[str, Any],
    manifest_path: Path,
    run_map: dict[str, Any],
    run_map_path: Path,
    artifact_report: dict[str, Any],
    artifact_report_path: Path,
    source_head: str,
    reviewer_count: int,
    reviewer_policy_id: str,
) -> dict[str, Any]:
    _require(run_map.get("manifest_id") == manifest_contract["benchmark_id"], "run_map.manifest_id must match manifest")
    _require(run_map.get("provider_scoring_used") is False, "run_map.provider_scoring_used must be false")
    _require(run_map.get("publication_quality_claimed") is False, "run_map.publication_quality_claimed must be false")
    _require(run_map.get("live_provider_used") is False, "run_map.live_provider_used must be false")
    validate_report(
        artifact_report,
        manifest_contract=manifest_contract,
        mode="fixture",
        no_provider=True,
    )

    _require(reviewer_count > 0, "reviewer_count must be positive")
    rubric = manifest["rubric"]
    rubric_ids = [dimension["id"] for dimension in rubric]
    artifact_cases = _artifact_case_by_id(artifact_report)
    manifest_case_by_id = {case["case_id"]: case for case in manifest["cases"]}

    cases: list[dict[str, Any]] = []
    for case_id in sorted(manifest_contract["case_ids"]):
        manifest_case = manifest_case_by_id[case_id]
        artifact_case = artifact_cases.get(case_id)
        _require(artifact_case is not None, f"artifact report is missing case {case_id}")
        image_path = _artifact_path_for(artifact_case, "image")
        cases.append(
            {
                "case_id": case_id,
                "task_type": manifest_case["task_type"],
                "split": manifest_case["split"],
                "content_ref": manifest_case["content_ref"],
                "visual_intent_ref": manifest_case["visual_intent_ref"],
                "path_to_gt_image": manifest_case["path_to_gt_image"],
                "run_id": artifact_case["run_id"],
                "image_path": _standard(image_path),
                "image_sha256": _sha256_file(image_path),
                "image_bytes": image_path.stat().st_size,
                "artifact_check_status": artifact_case["status"],
                "checked_outputs": artifact_case["checked_outputs"],
                "reviewer_score_slots": _blank_score_slots(
                    rubric_ids=rubric_ids,
                    reviewer_count=reviewer_count,
                ),
            }
        )

    packet = {
        "schema_version": PACKET_SCHEMA_VERSION,
        "manifest_id": manifest_contract["benchmark_id"],
        "created_at_utc": datetime.now(UTC).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "source_head": source_head,
        "scoring_protocol": {
            "reviewer_policy_id": reviewer_policy_id,
            "scoring_mode": "human_review",
            "minimum_reviewers_per_case": reviewer_count,
            "adjudication_policy": DEFAULT_ADJUDICATION_POLICY,
            "score_scale": DEFAULT_SCORE_SCALE,
            "critical_failure_policy": DEFAULT_CRITICAL_FAILURE_POLICY,
        },
        "artifact_binding": {
            "manifest_path": _standard(manifest_path),
            "manifest_sha256": _sha256_file(manifest_path),
            "run_map_path": _standard(run_map_path),
            "run_map_sha256": _sha256_file(run_map_path),
            "artifact_report_path": _standard(artifact_report_path),
            "artifact_report_sha256": _sha256_file(artifact_report_path),
        },
        "rubric": rubric,
        "cases": cases,
        "claim_boundary": (
            "This packet freezes review inputs only. Scores are blank, no "
            "provider scoring was performed, and no publication-quality claim "
            "is supported until completed reviewer scores are validated in a "
            "separate human_review report."
        ),
    }
    validate_review_packet(packet, manifest_contract=manifest_contract)
    return packet


def validate_review_packet(packet: dict[str, Any], *, manifest_contract: dict[str, Any]) -> None:
    _require(packet.get("schema_version") == PACKET_SCHEMA_VERSION, "packet.schema_version is unsupported")
    _require(packet.get("manifest_id") == manifest_contract["benchmark_id"], "packet.manifest_id must match manifest")
    _string(packet, "source_head", "packet")
    _string(packet, "claim_boundary", "packet")

    protocol = packet.get("scoring_protocol")
    _require(isinstance(protocol, dict), "packet.scoring_protocol must be an object")
    _string(protocol, "reviewer_policy_id", "packet.scoring_protocol")
    _require(protocol.get("scoring_mode") == "human_review", "packet.scoring_protocol.scoring_mode must be human_review")
    reviewer_count = protocol.get("minimum_reviewers_per_case")
    _require(isinstance(reviewer_count, int) and reviewer_count > 0, "packet.scoring_protocol.minimum_reviewers_per_case must be positive")
    _string(protocol, "adjudication_policy", "packet.scoring_protocol")
    _string(protocol, "critical_failure_policy", "packet.scoring_protocol")
    score_scale = protocol.get("score_scale")
    _require(isinstance(score_scale, dict), "packet.scoring_protocol.score_scale must be an object")
    minimum = score_scale.get("minimum")
    maximum = score_scale.get("maximum")
    _require(isinstance(minimum, (int, float)) and isinstance(maximum, (int, float)) and minimum < maximum, "packet.scoring_protocol.score_scale must have numeric minimum < maximum")

    binding = packet.get("artifact_binding")
    _require(isinstance(binding, dict), "packet.artifact_binding must be an object")
    for field in ("manifest_path", "run_map_path", "artifact_report_path"):
        _string(binding, field, "packet.artifact_binding")
    for field in ("manifest_sha256", "run_map_sha256", "artifact_report_sha256"):
        _hex_digest(binding, field, "packet.artifact_binding")

    rubric = packet.get("rubric")
    _require(isinstance(rubric, list) and rubric, "packet.rubric must be a non-empty list")
    rubric_ids = [dimension["id"] for dimension in rubric if isinstance(dimension, dict) and isinstance(dimension.get("id"), str)]
    _require(set(rubric_ids) == manifest_contract["rubric_ids"], "packet.rubric ids must match manifest")

    cases = packet.get("cases")
    _require(isinstance(cases, list) and cases, "packet.cases must be a non-empty list")
    seen: set[str] = set()
    for index, case in enumerate(cases):
        context = f"packet.cases[{index}]"
        _require(isinstance(case, dict), f"{context} must be an object")
        case_id = _string(case, "case_id", context)
        _require(case_id not in seen, f"{context}.case_id is duplicated: {case_id}")
        seen.add(case_id)
        _string(case, "run_id", context)
        _string(case, "image_path", context)
        _hex_digest(case, "image_sha256", context)
        _require(isinstance(case.get("image_bytes"), int) and case["image_bytes"] > 0, f"{context}.image_bytes must be positive")
        _require(case.get("artifact_check_status") == "fixture_passed", f"{context}.artifact_check_status must be fixture_passed")
        slots = case.get("reviewer_score_slots")
        _require(isinstance(slots, list) and len(slots) >= reviewer_count, f"{context}.reviewer_score_slots must include the minimum reviewer slots")
        for slot_index, slot in enumerate(slots):
            slot_context = f"{context}.reviewer_score_slots[{slot_index}]"
            _require(isinstance(slot, dict), f"{slot_context} must be an object")
            _require(slot.get("attestation") is False, f"{slot_context}.attestation must remain false in blank packets")
            scores = slot.get("scores")
            _require(isinstance(scores, dict), f"{slot_context}.scores must be an object")
            _require(set(scores) == set(rubric_ids), f"{slot_context}.scores keys must match rubric ids")
            _require(all(value is None for value in scores.values()), f"{slot_context}.scores must be blank")
            failures = slot.get("critical_failures")
            _require(isinstance(failures, list), f"{slot_context}.critical_failures must be a list")

    missing = sorted(manifest_contract["case_ids"] - seen)
    extra = sorted(seen - manifest_contract["case_ids"])
    _require(not missing, f"packet.cases is missing manifest cases: {missing}")
    _require(not extra, f"packet.cases contains unknown cases: {extra}")


def prepare_command(args: argparse.Namespace) -> int:
    manifest_path = Path(args.manifest)
    run_map_path = Path(args.run_map)
    artifact_report_path = Path(args.artifact_report)
    output_path = Path(args.output)
    manifest = _load_json(manifest_path)
    run_map = _load_json(run_map_path)
    artifact_report = _load_json(artifact_report_path)
    manifest_contract = validate_manifest(
        manifest,
        manifest_path=manifest_path,
        check_paths=args.check_paths,
    )
    packet = build_review_packet(
        manifest=manifest,
        manifest_contract=manifest_contract,
        manifest_path=manifest_path,
        run_map=run_map,
        run_map_path=run_map_path,
        artifact_report=artifact_report,
        artifact_report_path=artifact_report_path,
        source_head=args.source_head,
        reviewer_count=args.reviewer_count,
        reviewer_policy_id=args.reviewer_policy_id,
    )
    _write_json(output_path, packet)
    print(
        "WP-108 human-review packet prepared: "
        f"packet={output_path} cases={len(packet['cases'])} reviewer_slots={args.reviewer_count} "
        "scores_blank=true publication_quality_claimed=false"
    )
    return 0


def validate_command(args: argparse.Namespace) -> int:
    manifest_path = Path(args.manifest)
    packet_path = Path(args.packet)
    manifest = _load_json(manifest_path)
    packet = _load_json(packet_path)
    manifest_contract = validate_manifest(
        manifest,
        manifest_path=manifest_path,
        check_paths=args.check_paths,
    )
    validate_review_packet(packet, manifest_contract=manifest_contract)
    print(
        "WP-108 human-review packet contract passed: "
        f"manifest={manifest_path} packet={packet_path} cases={len(packet['cases'])}"
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Prepare or validate WP-108 offline human-review packets.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    prepare = subparsers.add_parser("prepare", help="prepare a blank reviewer score packet")
    prepare.add_argument("--manifest", required=True, help="Path to WP-108 no-live manifest JSON")
    prepare.add_argument("--run-map", required=True, help="Path to WP-108 no-live run-map JSON")
    prepare.add_argument("--artifact-report", required=True, help="Path to fixture-mode artifact report JSON")
    prepare.add_argument("--source-head", required=True, help="Source commit or release candidate identifier being reviewed")
    prepare.add_argument("--output", required=True, help="Path to write the review packet JSON")
    prepare.add_argument("--reviewer-count", type=int, default=2, help="Minimum blank reviewer slots per case")
    prepare.add_argument("--reviewer-policy-id", default=DEFAULT_REVIEWER_POLICY_ID, help="Reviewer policy identifier")
    path_group = prepare.add_mutually_exclusive_group()
    path_group.add_argument("--check-paths", action="store_true", help="Require manifest ground-truth paths to exist")
    path_group.add_argument("--no-path-check", action="store_true", help="Skip ground-truth path existence checks")
    prepare.set_defaults(func=prepare_command)

    validate = subparsers.add_parser("validate", help="validate a prepared review packet")
    validate.add_argument("--manifest", required=True, help="Path to WP-108 no-live manifest JSON")
    validate.add_argument("--packet", required=True, help="Path to WP-108 human-review packet JSON")
    path_group = validate.add_mutually_exclusive_group()
    path_group.add_argument("--check-paths", action="store_true", help="Require manifest ground-truth paths to exist")
    path_group.add_argument("--no-path-check", action="store_true", help="Skip ground-truth path existence checks")
    validate.set_defaults(func=validate_command)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except (ReviewPacketError, ContractError) as exc:
        print(f"WP-108 human-review packet failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
