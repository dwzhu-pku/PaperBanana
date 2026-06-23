"""WP-108 quality decision report generator.

This module consumes a frozen WP-108 manifest and a completed human-review
report, validates them with the existing benchmark contract, and emits an
auditable go/no-go decision report. It does not score images, call providers,
or turn fixture output into a publication-quality claim.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from utils.wp108_benchmark_contract import (
    ContractError,
    validate_manifest,
    validate_report,
)


DECISION_SCHEMA_VERSION = "wp108.quality_decision.v1"
DEFAULT_ALLOWED_SCORE_SOURCES = {"adjudicated_human_review"}


class QualityDecisionError(ValueError):
    """Raised when a WP-108 quality decision report is malformed."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise QualityDecisionError(message)


def _load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise QualityDecisionError(f"{path}: invalid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise QualityDecisionError(f"{path}: top-level JSON value must be an object")
    return value


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _required_string(owner: dict[str, Any], field: str, context: str) -> str:
    value = owner.get(field)
    _require(isinstance(value, str) and bool(value.strip()), f"{context}.{field} must be a non-empty string")
    return value


def _required_number(owner: dict[str, Any], field: str, context: str) -> float:
    value = owner.get(field)
    _require(isinstance(value, (int, float)) and not isinstance(value, bool), f"{context}.{field} must be numeric")
    return float(value)


def _load_valid_inputs(
    *,
    manifest_path: Path,
    report_path: Path,
    check_paths: bool,
    no_provider: bool,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    manifest = _load_json(manifest_path)
    report = _load_json(report_path)
    manifest_contract = validate_manifest(
        manifest,
        manifest_path=manifest_path,
        check_paths=check_paths,
    )
    validate_report(
        report,
        manifest_contract=manifest_contract,
        mode="human_review",
        no_provider=no_provider,
    )
    return manifest, report, manifest_contract


def _rubric_thresholds(manifest: dict[str, Any]) -> dict[str, float]:
    thresholds: dict[str, float] = {}
    for dimension in manifest["rubric"]:
        dimension_id = _required_string(dimension, "id", "manifest.rubric[]")
        thresholds[dimension_id] = _required_number(dimension, "pass_threshold", f"manifest.rubric[{dimension_id}]")
    return thresholds


def _score_stats(report: dict[str, Any], rubric_ids: set[str]) -> dict[str, Any]:
    dimension_values: dict[str, list[float]] = {dimension_id: [] for dimension_id in sorted(rubric_ids)}
    case_statuses: dict[str, str] = {}
    case_critical_failures: list[dict[str, Any]] = []
    reviewer_critical_failures: list[dict[str, Any]] = []
    reviewer_count_by_case: dict[str, int] = {}
    score_sources_by_case: dict[str, str] = {}

    for result in report["case_results"]:
        case_id = _required_string(result, "case_id", "report.case_results[]")
        case_statuses[case_id] = _required_string(result, "status", f"report.case_results[{case_id}]")
        score_sources_by_case[case_id] = _required_string(result, "score_source", f"report.case_results[{case_id}]")
        scores = result["scores"]
        for dimension_id in rubric_ids:
            dimension_values[dimension_id].append(float(scores[dimension_id]))
        for failure in result.get("critical_failures", []):
            case_critical_failures.append({"case_id": case_id, "failure": failure})

        reviewers = result.get("reviewer_scores", [])
        reviewer_count_by_case[case_id] = len(reviewers)
        for reviewer in reviewers:
            reviewer_id = reviewer.get("reviewer_id", "")
            for failure in reviewer.get("critical_failures", []):
                reviewer_critical_failures.append(
                    {
                        "case_id": case_id,
                        "reviewer_id": reviewer_id,
                        "failure": failure,
                    }
                )

    dimension_averages = {
        dimension_id: sum(values) / len(values)
        for dimension_id, values in dimension_values.items()
        if values
    }
    all_scores = [value for values in dimension_values.values() for value in values]
    observed_mean = sum(all_scores) / len(all_scores)

    return {
        "dimension_averages": dimension_averages,
        "observed_mean_score": observed_mean,
        "case_statuses": case_statuses,
        "case_critical_failures": case_critical_failures,
        "reviewer_critical_failures": reviewer_critical_failures,
        "reviewer_count_by_case": reviewer_count_by_case,
        "score_sources_by_case": score_sources_by_case,
    }


def build_decision_report(
    *,
    manifest: dict[str, Any],
    report: dict[str, Any],
    manifest_contract: dict[str, Any],
    manifest_path: Path,
    report_path: Path,
) -> dict[str, Any]:
    rubric_thresholds = _rubric_thresholds(manifest)
    stats = _score_stats(report, manifest_contract["rubric_ids"])
    thresholds = manifest_contract["thresholds"]
    summary = report["summary"]

    dimension_results = {}
    blockers: list[str] = []
    for dimension_id, threshold in sorted(rubric_thresholds.items()):
        average = stats["dimension_averages"].get(dimension_id)
        passed = average is not None and average >= threshold
        dimension_results[dimension_id] = {
            "average": average,
            "pass_threshold": threshold,
            "passed": passed,
        }
        if not passed:
            blockers.append(f"dimension {dimension_id} average is below pass threshold")

    case_failures = stats["case_critical_failures"]
    reviewer_failures = stats["reviewer_critical_failures"]
    disallowed_score_sources = {
        case_id: score_source
        for case_id, score_source in stats["score_sources_by_case"].items()
        if score_source not in DEFAULT_ALLOWED_SCORE_SOURCES
    }
    non_passed_cases = [
        case_id
        for case_id, status in sorted(stats["case_statuses"].items())
        if status != "passed"
    ]
    if non_passed_cases:
        blockers.append(f"case status is not passed for: {', '.join(non_passed_cases)}")
    if case_failures:
        blockers.append("case-level critical failures are present")
    if reviewer_failures:
        blockers.append("reviewer-level critical failures are present")
    if disallowed_score_sources:
        blockers.append("non-adjudicated score sources are present")

    minimum_cases_passed = len(manifest_contract["case_ids"]) >= thresholds["minimum_cases"]
    mean_score_passed = stats["observed_mean_score"] >= float(thresholds["minimum_mean_score"])
    critical_failures_passed = len(case_failures) <= thresholds["max_critical_failures"]
    report_threshold_passed = summary.get("threshold_passed") is True

    if not minimum_cases_passed:
        blockers.append("manifest/report case count is below minimum_cases")
    if not mean_score_passed:
        blockers.append("observed mean score is below minimum_mean_score")
    if not critical_failures_passed:
        blockers.append("case-level critical failure count exceeds max_critical_failures")
    if not report_threshold_passed:
        blockers.append("validated report summary.threshold_passed is false")

    gate_passed = (
        report_threshold_passed
        and minimum_cases_passed
        and mean_score_passed
        and critical_failures_passed
        and all(result["passed"] for result in dimension_results.values())
        and not non_passed_cases
        and not case_failures
        and not reviewer_failures
        and not disallowed_score_sources
    )

    artifact_binding = report.get("artifact_binding", {})
    decision = {
        "schema_version": DECISION_SCHEMA_VERSION,
        "created_at_utc": datetime.now(UTC).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "manifest_id": manifest_contract["benchmark_id"],
        "source_head": artifact_binding.get("source_head", ""),
        "manifest_path": str(manifest_path),
        "report_path": str(report_path),
        "evaluation_mode": "human_review",
        "decision": "go" if gate_passed else "no_go",
        "gate_passed": gate_passed,
        "publication_quality_claimed": False,
        "provider_scoring_used": report.get("provider_scoring_used") is True,
        "thresholds": {
            "minimum_cases": thresholds["minimum_cases"],
            "minimum_mean_score": thresholds["minimum_mean_score"],
            "max_critical_failures": thresholds["max_critical_failures"],
            "dimension_pass_thresholds": rubric_thresholds,
            "allowed_score_sources": sorted(DEFAULT_ALLOWED_SCORE_SOURCES),
        },
        "observed": {
            "cases_total": len(manifest_contract["case_ids"]),
            "reported_mean_score": summary.get("mean_score"),
            "observed_mean_score": stats["observed_mean_score"],
            "report_threshold_passed": report_threshold_passed,
            "case_statuses": stats["case_statuses"],
            "dimension_results": dimension_results,
            "case_critical_failures": case_failures,
            "reviewer_critical_failures": reviewer_failures,
            "reviewer_count_by_case": stats["reviewer_count_by_case"],
            "score_sources_by_case": stats["score_sources_by_case"],
            "disallowed_score_sources": disallowed_score_sources,
        },
        "artifact_binding": artifact_binding,
        "blockers": blockers,
        "claim_boundary": (
            "This report is a deterministic decision over an already-completed "
            "WP-108 human_review report. It does not score images, call "
            "providers, repeat a benchmark subset, or by itself authorize a "
            "publication-quality claim."
        ),
    }
    validate_decision_report(decision, manifest=manifest, report=report)
    return decision


def validate_decision_report(decision: dict[str, Any], *, manifest: dict[str, Any], report: dict[str, Any]) -> None:
    _require(decision.get("schema_version") == DECISION_SCHEMA_VERSION, "decision.schema_version is unsupported")
    _require(decision.get("manifest_id") == manifest.get("benchmark_id"), "decision.manifest_id must match manifest")
    _require(decision.get("evaluation_mode") == "human_review", "decision.evaluation_mode must be human_review")
    _require(decision.get("publication_quality_claimed") is False, "decision.publication_quality_claimed must remain false")
    _required_string(decision, "claim_boundary", "decision")
    gate_passed = decision.get("gate_passed")
    _require(isinstance(gate_passed, bool), "decision.gate_passed must be boolean")
    expected_decision = "go" if gate_passed else "no_go"
    _require(decision.get("decision") == expected_decision, "decision.decision must match gate_passed")
    blockers = decision.get("blockers")
    _require(isinstance(blockers, list), "decision.blockers must be a list")
    if gate_passed:
        _require(not blockers, "passing decisions must not list blockers")
    else:
        _require(bool(blockers), "no_go decisions must list at least one blocker")

    observed = decision.get("observed")
    _require(isinstance(observed, dict), "decision.observed must be an object")
    observed_mean = observed.get("observed_mean_score")
    reported_mean = report.get("summary", {}).get("mean_score")
    _require(isinstance(observed_mean, (int, float)), "decision.observed.observed_mean_score must be numeric")
    _require(isinstance(reported_mean, (int, float)), "report.summary.mean_score must be numeric")
    _require(
        math.isclose(float(observed_mean), float(reported_mean), rel_tol=0.0, abs_tol=0.0001),
        "decision observed mean must match report summary mean",
    )
    dimension_results = observed.get("dimension_results")
    _require(isinstance(dimension_results, dict) and dimension_results, "decision.observed.dimension_results must be non-empty")
    expected_dimension_ids = {dimension["id"] for dimension in manifest["rubric"]}
    _require(set(dimension_results) == expected_dimension_ids, "decision dimensions must match manifest rubric")


def decide_command(args: argparse.Namespace) -> int:
    manifest_path = Path(args.manifest)
    report_path = Path(args.report)
    output_path = Path(args.output)
    manifest, report, manifest_contract = _load_valid_inputs(
        manifest_path=manifest_path,
        report_path=report_path,
        check_paths=args.check_paths,
        no_provider=args.no_provider,
    )
    decision = build_decision_report(
        manifest=manifest,
        report=report,
        manifest_contract=manifest_contract,
        manifest_path=manifest_path,
        report_path=report_path,
    )
    _write_json(output_path, decision)
    print(
        "WP-108 quality decision report written: "
        f"decision={decision['decision']} gate_passed={decision['gate_passed']} "
        f"publication_quality_claimed=false output={output_path}"
    )
    return 0


def validate_command(args: argparse.Namespace) -> int:
    manifest_path = Path(args.manifest)
    report_path = Path(args.report)
    decision_path = Path(args.decision)
    manifest, report, _ = _load_valid_inputs(
        manifest_path=manifest_path,
        report_path=report_path,
        check_paths=args.check_paths,
        no_provider=args.no_provider,
    )
    decision = _load_json(decision_path)
    validate_decision_report(decision, manifest=manifest, report=report)
    expected = build_decision_report(
        manifest=manifest,
        report=report,
        manifest_contract=validate_manifest(
            manifest,
            manifest_path=manifest_path,
            check_paths=args.check_paths,
        ),
        manifest_path=manifest_path,
        report_path=report_path,
    )
    for field in (
        "decision",
        "gate_passed",
        "publication_quality_claimed",
        "provider_scoring_used",
        "thresholds",
        "observed",
        "blockers",
        "artifact_binding",
    ):
        _require(decision.get(field) == expected[field], f"decision.{field} does not match recomputed decision")
    print(
        "WP-108 quality decision report contract passed: "
        f"decision={decision_path} gate_passed={decision['gate_passed']}"
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Build or validate WP-108 quality decision reports.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    decide = subparsers.add_parser("decide", help="write a decision report from a completed human-review report")
    decide.add_argument("--manifest", required=True, help="Path to WP-108 no-live manifest JSON")
    decide.add_argument("--report", required=True, help="Path to completed WP-108 human_review report JSON")
    decide.add_argument("--output", required=True, help="Path to write the quality decision JSON")
    decide.add_argument("--no-provider", action="store_true", help="Require provider_scoring_used=false")
    path_group = decide.add_mutually_exclusive_group()
    path_group.add_argument("--check-paths", action="store_true", help="Require manifest ground-truth paths to exist")
    path_group.add_argument("--no-path-check", action="store_true", help="Skip ground-truth path existence checks")
    decide.set_defaults(func=decide_command)

    validate = subparsers.add_parser("validate", help="validate an existing decision report")
    validate.add_argument("--manifest", required=True, help="Path to WP-108 no-live manifest JSON")
    validate.add_argument("--report", required=True, help="Path to completed WP-108 human_review report JSON")
    validate.add_argument("--decision", required=True, help="Path to WP-108 quality decision JSON")
    validate.add_argument("--no-provider", action="store_true", help="Require provider_scoring_used=false")
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
    except (QualityDecisionError, ContractError) as exc:
        print(f"WP-108 quality decision failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
