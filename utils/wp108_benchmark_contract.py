"""No-live WP-108 benchmark contract validator.

This module intentionally avoids importing the provider-backed evaluation
toolkit. It validates benchmark manifests and reports only; it does not score
images or call model providers.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any


MANIFEST_SCHEMA_VERSION = "wp108.no_live_manifest.v1"
REPORT_SCHEMA_VERSION = "wp108.no_live_report.v1"
ALLOWED_TASK_TYPES = {"diagram", "plot"}
ALLOWED_OUTPUTS = {
    "image",
    "request_json",
    "metadata_json",
    "provider_request_json",
    "provider_response_json",
    "provider_audit",
    "run_store",
}
ALLOWED_MODES = {"fixture", "human_review", "provider_scored"}
ALLOWED_RESULT_STATUSES = {
    "not_scored",
    "fixture_passed",
    "fixture_failed",
    "passed",
    "failed",
}


class ContractError(ValueError):
    """Raised when a manifest or report violates the WP-108 contract."""


def _load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ContractError(f"{path}: invalid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ContractError(f"{path}: top-level JSON value must be an object")
    return value


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractError(message)


def _required_string(owner: dict[str, Any], field: str, context: str) -> str:
    value = owner.get(field)
    _require(isinstance(value, str) and bool(value.strip()), f"{context}.{field} must be a non-empty string")
    return value


def _resolve_manifest_path(manifest_path: Path, raw_path: str) -> Path:
    path = Path(raw_path)
    return path if path.is_absolute() else manifest_path.parent / path


def validate_manifest(manifest: dict[str, Any], *, manifest_path: Path, check_paths: bool) -> dict[str, Any]:
    _require(manifest.get("schema_version") == MANIFEST_SCHEMA_VERSION, "manifest.schema_version is unsupported")
    benchmark_id = _required_string(manifest, "benchmark_id", "manifest")
    _required_string(manifest, "claim_boundary", "manifest")

    cases = manifest.get("cases")
    _require(isinstance(cases, list) and cases, "manifest.cases must be a non-empty list")

    case_ids: set[str] = set()
    for index, case in enumerate(cases):
        context = f"manifest.cases[{index}]"
        _require(isinstance(case, dict), f"{context} must be an object")
        case_id = _required_string(case, "case_id", context)
        _require(case_id not in case_ids, f"{context}.case_id is duplicated: {case_id}")
        case_ids.add(case_id)

        task_type = _required_string(case, "task_type", context)
        _require(task_type in ALLOWED_TASK_TYPES, f"{context}.task_type must be one of {sorted(ALLOWED_TASK_TYPES)}")
        _required_string(case, "split", context)
        _required_string(case, "content_ref", context)
        _required_string(case, "visual_intent_ref", context)
        gt_path = _required_string(case, "path_to_gt_image", context)
        _require(case.get("non_private_fixture") is True, f"{context}.non_private_fixture must be true")

        expected_outputs = case.get("expected_outputs")
        _require(isinstance(expected_outputs, list) and expected_outputs, f"{context}.expected_outputs must be non-empty")
        unknown_outputs = sorted(set(expected_outputs) - ALLOWED_OUTPUTS)
        _require(not unknown_outputs, f"{context}.expected_outputs contains unsupported values: {unknown_outputs}")

        if check_paths:
            resolved = _resolve_manifest_path(manifest_path, gt_path)
            _require(resolved.exists(), f"{context}.path_to_gt_image does not exist: {resolved}")

    rubric = manifest.get("rubric")
    _require(isinstance(rubric, list) and rubric, "manifest.rubric must be a non-empty list")
    rubric_ids: set[str] = set()
    for index, dimension in enumerate(rubric):
        context = f"manifest.rubric[{index}]"
        _require(isinstance(dimension, dict), f"{context} must be an object")
        dimension_id = _required_string(dimension, "id", context)
        _require(dimension_id not in rubric_ids, f"{context}.id is duplicated: {dimension_id}")
        rubric_ids.add(dimension_id)
        _required_string(dimension, "name", context)
        _required_string(dimension, "scale", context)
        threshold = dimension.get("pass_threshold")
        _require(isinstance(threshold, (int, float)), f"{context}.pass_threshold must be numeric")

    thresholds = manifest.get("thresholds")
    _require(isinstance(thresholds, dict), "manifest.thresholds must be an object")
    minimum_cases = thresholds.get("minimum_cases")
    minimum_mean_score = thresholds.get("minimum_mean_score")
    max_critical_failures = thresholds.get("max_critical_failures")
    _require(isinstance(minimum_cases, int) and minimum_cases > 0, "manifest.thresholds.minimum_cases must be a positive integer")
    _require(isinstance(minimum_mean_score, (int, float)), "manifest.thresholds.minimum_mean_score must be numeric")
    _require(
        isinstance(max_critical_failures, int) and max_critical_failures >= 0,
        "manifest.thresholds.max_critical_failures must be a non-negative integer",
    )

    return {
        "benchmark_id": benchmark_id,
        "case_ids": case_ids,
        "rubric_ids": rubric_ids,
        "thresholds": thresholds,
    }


def _score_values(report: dict[str, Any], rubric_ids: set[str], *, mode: str) -> list[float]:
    values: list[float] = []
    for index, result in enumerate(report.get("case_results", [])):
        context = f"report.case_results[{index}]"
        scores = result.get("scores", {})
        if mode != "fixture":
            _require(isinstance(scores, dict) and scores, f"{context}.scores must be present for {mode}")
            missing = sorted(rubric_ids - set(scores))
            _require(not missing, f"{context}.scores is missing rubric dimensions: {missing}")
        if scores:
            _require(isinstance(scores, dict), f"{context}.scores must be an object")
            unknown = sorted(set(scores) - rubric_ids)
            _require(not unknown, f"{context}.scores contains unknown rubric dimensions: {unknown}")
            for dimension_id, value in scores.items():
                _require(isinstance(value, (int, float)), f"{context}.scores.{dimension_id} must be numeric")
                values.append(float(value))
    return values


def validate_report(
    report: dict[str, Any],
    *,
    manifest_contract: dict[str, Any],
    mode: str,
    no_provider: bool,
) -> None:
    _require(report.get("schema_version") == REPORT_SCHEMA_VERSION, "report.schema_version is unsupported")
    _require(report.get("manifest_id") == manifest_contract["benchmark_id"], "report.manifest_id must match manifest.benchmark_id")
    _require(report.get("evaluation_mode") == mode, "report.evaluation_mode must match --mode")
    _require(mode in ALLOWED_MODES, f"--mode must be one of {sorted(ALLOWED_MODES)}")

    if no_provider:
        _require(report.get("provider_scoring_used") is False, "report.provider_scoring_used must be false with --no-provider")
    if no_provider or mode == "fixture":
        _require(
            report.get("publication_quality_claimed") is False,
            "report.publication_quality_claimed must be false for fixture/no-provider validation",
        )

    case_results = report.get("case_results")
    _require(isinstance(case_results, list) and case_results, "report.case_results must be a non-empty list")
    report_case_ids: set[str] = set()
    critical_failures = 0
    for index, result in enumerate(case_results):
        context = f"report.case_results[{index}]"
        _require(isinstance(result, dict), f"{context} must be an object")
        case_id = _required_string(result, "case_id", context)
        _require(case_id not in report_case_ids, f"{context}.case_id is duplicated: {case_id}")
        report_case_ids.add(case_id)
        status = _required_string(result, "status", context)
        _require(status in ALLOWED_RESULT_STATUSES, f"{context}.status must be one of {sorted(ALLOWED_RESULT_STATUSES)}")
        failures = result.get("critical_failures", [])
        _require(isinstance(failures, list), f"{context}.critical_failures must be a list")
        critical_failures += len(failures)

    expected_case_ids = manifest_contract["case_ids"]
    missing = sorted(expected_case_ids - report_case_ids)
    extra = sorted(report_case_ids - expected_case_ids)
    _require(not missing, f"report.case_results is missing manifest cases: {missing}")
    _require(not extra, f"report.case_results contains unknown cases: {extra}")

    summary = report.get("summary")
    _require(isinstance(summary, dict), "report.summary must be an object")
    _require(summary.get("cases_total") == len(expected_case_ids), "report.summary.cases_total must equal manifest case count")
    _require(isinstance(summary.get("threshold_passed"), bool), "report.summary.threshold_passed must be boolean")

    values = _score_values(report, manifest_contract["rubric_ids"], mode=mode)
    if values:
        observed_mean = sum(values) / len(values)
        reported_mean = summary.get("mean_score")
        _require(isinstance(reported_mean, (int, float)), "report.summary.mean_score must be numeric when scores are present")
        _require(math.isclose(float(reported_mean), observed_mean, rel_tol=0.0, abs_tol=0.0001), "report.summary.mean_score does not match case scores")
        thresholds = manifest_contract["thresholds"]
        expected_threshold = (
            len(expected_case_ids) >= thresholds["minimum_cases"]
            and observed_mean >= float(thresholds["minimum_mean_score"])
            and critical_failures <= thresholds["max_critical_failures"]
        )
        _require(
            summary["threshold_passed"] == expected_threshold,
            "report.summary.threshold_passed does not match manifest thresholds",
        )
    else:
        _require(summary.get("mean_score") is None, "report.summary.mean_score must be null when no scores are present")
        _require(summary["threshold_passed"] is False, "fixture/no-score reports cannot pass the quality threshold")


def validate_command(args: argparse.Namespace) -> int:
    manifest_path = Path(args.manifest)
    report_path = Path(args.report)
    manifest = _load_json(manifest_path)
    report = _load_json(report_path)

    manifest_contract = validate_manifest(
        manifest,
        manifest_path=manifest_path,
        check_paths=args.check_paths,
    )
    validate_report(
        report,
        manifest_contract=manifest_contract,
        mode=args.mode,
        no_provider=args.no_provider,
    )

    print(
        "WP-108 no-live benchmark contract passed: "
        f"manifest={manifest_path} report={report_path} mode={args.mode} "
        f"cases={len(manifest_contract['case_ids'])} check_paths={args.check_paths}"
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Validate WP-108 no-live benchmark contract files.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate = subparsers.add_parser("validate", help="validate a manifest/report pair")
    validate.add_argument("--manifest", required=True, help="Path to WP-108 no-live manifest JSON")
    validate.add_argument("--report", required=True, help="Path to WP-108 no-live report JSON")
    validate.add_argument("--mode", required=True, choices=sorted(ALLOWED_MODES), help="Expected report evaluation mode")
    validate.add_argument("--no-provider", action="store_true", help="Require provider_scoring_used=false")
    path_group = validate.add_mutually_exclusive_group()
    path_group.add_argument("--check-paths", action="store_true", help="Require manifest ground-truth paths to exist")
    path_group.add_argument("--no-path-check", action="store_true", help="Skip ground-truth path existence checks")
    validate.set_defaults(func=validate_command)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if not args.check_paths:
        args.check_paths = False
    try:
        return args.func(args)
    except ContractError as exc:
        print(f"WP-108 benchmark contract failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
