"""No-live WP-108 native artifact-completeness runner.

This module validates that already-created native run artifacts are complete
enough to be used by a later WP-108 quality evaluation. It intentionally does
not score images, call providers, or make publication-quality claims.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path
from typing import Any

from utils.wp108_benchmark_contract import (
    ContractError,
    validate_manifest,
    validate_report,
)


RUN_MAP_SCHEMA_VERSION = "wp108.no_live_run_map.v1"
DEFAULT_SECRET_MARKERS = (
    "GOOGLE_API_KEY",
    "OPENROUTER_API_KEY",
    "Authorization",
    "Bearer",
)
REQUIRED_RUN_MAP_PATHS = {
    "image": "image_path",
    "request_json": "request_json",
    "metadata_json": "metadata_json",
    "provider_request_json": "provider_request_json",
    "provider_response_json": "provider_response_json",
    "provider_audit": "provider_audit_jsonl",
    "run_store": "run_store_db",
}


class ArtifactRunnerError(ValueError):
    """Raised when the no-live artifact runner input is malformed."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ArtifactRunnerError(message)


def _load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ArtifactRunnerError(f"{path}: invalid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ArtifactRunnerError(f"{path}: top-level JSON value must be an object")
    return value


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _string(owner: dict[str, Any], field: str, context: str) -> str:
    value = owner.get(field)
    _require(isinstance(value, str) and bool(value.strip()), f"{context}.{field} must be a non-empty string")
    return value


def _resolve(path_base: Path, raw_path: str) -> Path:
    path = Path(raw_path)
    return path if path.is_absolute() else path_base / path


def _standard(path: Path) -> str:
    return str(path.expanduser().resolve(strict=False))


def _load_json_artifact(path: Path, failures: list[str], label: str) -> dict[str, Any] | None:
    if not path.exists():
        failures.append(f"{label} missing: {path}")
        return None
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        failures.append(f"{label} is not parseable JSON: {path}: {exc}")
        return None
    if not isinstance(value, dict):
        failures.append(f"{label} top-level value is not an object: {path}")
        return None
    return value


def _check_no_live_json_markers(payload: dict[str, Any], failures: list[str], label: str) -> None:
    mode = payload.get("mode") or payload.get("execution_mode")
    if isinstance(mode, str) and mode.lower() == "live":
        failures.append(f"{label} declares live mode")
    provider_spend = payload.get("provider_spend")
    if isinstance(provider_spend, str) and provider_spend.lower() != "none":
        failures.append(f"{label} provider_spend is not none: {provider_spend}")


def _check_image(path: Path, failures: list[str]) -> None:
    if not path.exists():
        failures.append(f"image missing: {path}")
        return
    try:
        header = path.read_bytes()[:12]
    except OSError as exc:
        failures.append(f"image cannot be read: {path}: {exc}")
        return
    if header.startswith(b"\x89PNG\r\n\x1a\n") or header.startswith(b"\xff\xd8\xff"):
        return
    failures.append(f"image is not PNG or JPEG by magic bytes: {path}")


def _scan_secret_markers(path: Path, markers: tuple[str, ...], failures: list[str]) -> None:
    if not path.exists():
        return
    try:
        data = path.read_bytes()
    except OSError as exc:
        failures.append(f"could not scan artifact for secret markers: {path}: {exc}")
        return
    for marker in markers:
        if marker and marker.encode("utf-8") in data:
            failures.append(f"forbidden marker {marker!r} persisted in {path}")


def _check_provider_audit(path: Path, run_id: str, failures: list[str]) -> None:
    _check_provider_audit_event(path, run_id=run_id, call_id=None, failures=failures)


def _check_provider_audit_event(path: Path, *, run_id: str, call_id: str | None, failures: list[str]) -> None:
    if not path.exists():
        failures.append(f"provider_audit missing: {path}")
        return
    matched_event = False
    parsed_lines = 0
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        failures.append(f"provider_audit cannot be read: {path}: {exc}")
        return
    for line_no, line in enumerate(lines, start=1):
        if not line.strip():
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError as exc:
            failures.append(f"provider_audit line {line_no} is invalid JSON: {exc}")
            continue
        parsed_lines += 1
        if not isinstance(payload, dict):
            continue
        if payload.get("run_id") == run_id or (call_id and payload.get("call_id") == call_id):
            matched_event = True
    if parsed_lines == 0:
        failures.append(f"provider_audit has no JSONL events: {path}")
    if not matched_event:
        label = f"run_id {run_id}" if not call_id else f"run_id {run_id} or call_id {call_id}"
        failures.append(f"provider_audit has no event for {label}: {path}")


def _check_run_store(
    path: Path,
    *,
    run_id: str,
    run_dir: Path,
    image_path: Path | None,
    request_json: Path | None,
    metadata_json: Path | None,
    provider_request_json: Path | None,
    provider_response_json: Path | None,
    failures: list[str],
) -> None:
    if not path.exists():
        failures.append(f"run_store missing: {path}")
        return
    try:
        connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    except sqlite3.Error as exc:
        failures.append(f"run_store cannot be opened read-only: {path}: {exc}")
        return
    try:
        cursor = connection.execute(
            """
            SELECT run_dir, request_path, provider_request_path, raw_response_path,
                   artifact_path, metadata_path, provider_call_id
            FROM runs
            WHERE id = ?
            """,
            (run_id,),
        )
        row = cursor.fetchone()
        if row is None:
            failures.append(f"run_store has no runs row for run_id {run_id}: {path}")
            return
        run_dir_value, request_value, provider_request_value, raw_response_value, artifact_value, metadata_value, call_id = row
        expected_paths = [
            ("run_dir", run_dir_value, run_dir),
            ("request_path", request_value, request_json),
            ("provider_request_path", provider_request_value, provider_request_json),
            ("raw_response_path", raw_response_value, provider_response_json),
            ("artifact_path", artifact_value, image_path),
            ("metadata_path", metadata_value, metadata_json),
        ]
        for field, actual, expected in expected_paths:
            if expected is None or not actual:
                continue
            if _standard(Path(actual)) != _standard(expected):
                failures.append(f"run_store {field} mismatch for {run_id}: {actual} != {expected}")

        provider_count = connection.execute(
            "SELECT COUNT(*) FROM provider_calls WHERE run_id = ?",
            (run_id,),
        ).fetchone()[0]
        if provider_count == 0:
            failures.append(f"run_store has no provider_calls row for run_id {run_id}")
        if call_id:
            event_count = connection.execute(
                "SELECT COUNT(*) FROM provider_call_events WHERE run_id = ? OR call_id = ?",
                (run_id, call_id),
            ).fetchone()[0]
            if event_count == 0:
                failures.append(f"run_store has no provider_call_events row for run_id {run_id}")
    except sqlite3.Error as exc:
        failures.append(f"run_store query failed for {path}: {exc}")
    finally:
        connection.close()


def _validate_run_map(
    run_map: dict[str, Any],
    *,
    manifest_contract: dict[str, Any],
) -> list[dict[str, Any]]:
    _require(run_map.get("schema_version") == RUN_MAP_SCHEMA_VERSION, "run_map.schema_version is unsupported")
    _require(run_map.get("manifest_id") == manifest_contract["benchmark_id"], "run_map.manifest_id must match manifest.benchmark_id")
    _require(run_map.get("provider_scoring_used") is False, "run_map.provider_scoring_used must be false")
    _require(run_map.get("publication_quality_claimed") is False, "run_map.publication_quality_claimed must be false")
    _require(run_map.get("live_provider_used") is False, "run_map.live_provider_used must be false")

    cases = run_map.get("cases")
    _require(isinstance(cases, list) and cases, "run_map.cases must be a non-empty list")

    expected_case_ids = manifest_contract["case_ids"]
    seen: set[str] = set()
    for index, case in enumerate(cases):
        context = f"run_map.cases[{index}]"
        _require(isinstance(case, dict), f"{context} must be an object")
        case_id = _string(case, "case_id", context)
        _require(case_id not in seen, f"{context}.case_id is duplicated: {case_id}")
        _require(case_id in expected_case_ids, f"{context}.case_id is not in manifest: {case_id}")
        _string(case, "run_id", context)
        _string(case, "run_dir", context)
        seen.add(case_id)

    missing = sorted(expected_case_ids - seen)
    _require(not missing, f"run_map.cases is missing manifest cases: {missing}")
    return cases


def _case_by_id(manifest: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {case["case_id"]: case for case in manifest["cases"]}


def _parse_case_run_pairs(raw_pairs: list[str] | None) -> dict[str, str]:
    _require(bool(raw_pairs), "at least one --case-run CASE_ID=RUN_ID mapping is required")
    pairs: dict[str, str] = {}
    for raw_pair in raw_pairs or []:
        case_id, separator, run_id = raw_pair.partition("=")
        _require(separator == "=", f"--case-run must use CASE_ID=RUN_ID syntax: {raw_pair}")
        case_id = case_id.strip()
        run_id = run_id.strip()
        _require(case_id != "", f"--case-run has an empty case id: {raw_pair}")
        _require(run_id != "", f"--case-run has an empty run id for case {case_id}")
        _require(case_id not in pairs, f"--case-run repeats case id {case_id}")
        pairs[case_id] = run_id
    return pairs


def _table_columns(connection: sqlite3.Connection, table: str) -> set[str]:
    try:
        rows = connection.execute(f"PRAGMA table_info({table})").fetchall()
    except sqlite3.Error as exc:
        raise ArtifactRunnerError(f"run_store could not inspect table {table}: {exc}") from exc
    return {str(row[1]) for row in rows}


def _select_columns(connection: sqlite3.Connection, table: str, columns: list[str], where: str, parameters: tuple[Any, ...]) -> dict[str, str] | None:
    available = _table_columns(connection, table)
    if not available:
        raise ArtifactRunnerError(f"run_store is missing table {table}")
    selected = [column for column in columns if column in available]
    if not selected:
        raise ArtifactRunnerError(f"run_store table {table} has none of the expected columns")
    sql = f"SELECT {', '.join(selected)} FROM {table} WHERE {where} LIMIT 1"
    try:
        cursor = connection.execute(sql, parameters)
        row = cursor.fetchone()
    except sqlite3.Error as exc:
        raise ArtifactRunnerError(f"run_store query failed for table {table}: {exc}") from exc
    if row is None:
        return None
    return {column: "" if row[index] is None else str(row[index]) for index, column in enumerate(selected)}


def _default_run_store(repo_root: Path) -> Path:
    return repo_root / "results" / "run_store" / "paperbanana_runs.sqlite"


def _read_run_store_record(run_store_db: Path, run_id: str) -> dict[str, str]:
    _require(run_store_db.exists(), f"run_store_db is missing: {run_store_db}")
    try:
        connection = sqlite3.connect(f"file:{run_store_db}?mode=ro", uri=True)
    except sqlite3.Error as exc:
        raise ArtifactRunnerError(f"run_store cannot be opened read-only: {run_store_db}: {exc}") from exc
    try:
        run_record = _select_columns(
            connection,
            "runs",
            [
                "id",
                "workflow",
                "status",
                "provider",
                "provider_kind",
                "run_dir",
                "request_path",
                "provider_request_path",
                "raw_response_path",
                "artifact_path",
                "metadata_path",
                "provider_call_id",
                "updated_at",
            ],
            "id = ?",
            (run_id,),
        )
        if run_record is None:
            raise ArtifactRunnerError(f"run_store has no runs row for run_id {run_id}: {run_store_db}")
        status = run_record.get("status", "")
        if status and status != "completed":
            raise ArtifactRunnerError(f"run_store run {run_id} has status {status}, not completed")

        call_id = run_record.get("provider_call_id", "")
        provider_call = None
        if call_id:
            provider_call = _select_columns(
                connection,
                "provider_calls",
                ["call_id", "run_id", "provider", "context", "status", "updated_at"],
                "call_id = ?",
                (call_id,),
            )
        if provider_call is None:
            provider_call = _select_columns(
                connection,
                "provider_calls",
                ["call_id", "run_id", "provider", "context", "status", "updated_at"],
                "run_id = ?",
                (run_id,),
            )
        if provider_call is None:
            raise ArtifactRunnerError(f"run_store has no provider_calls row for run_id {run_id}: {run_store_db}")
        provider_status = provider_call.get("status", "")
        if provider_status and provider_status != "succeeded":
            raise ArtifactRunnerError(f"run_store provider call for {run_id} has status {provider_status}, not succeeded")
        if not call_id:
            call_id = provider_call.get("call_id", "")
        _require(call_id != "", f"run_store provider call for {run_id} is missing call_id")
        run_record["provider_call_id"] = call_id
        run_record["provider_call_provider"] = provider_call.get("provider", "")
        run_record["provider_call_context"] = provider_call.get("context", "")
        run_record["provider_call_status"] = provider_status
        return run_record
    finally:
        connection.close()


def _candidate_provider_audit_paths(repo_root: Path, explicit_paths: list[Path] | None) -> list[Path]:
    candidates: list[Path] = []
    for path in explicit_paths or []:
        if path.is_dir():
            candidates.extend(sorted(path.glob("*.jsonl")))
        else:
            candidates.append(path)
    default_dir = repo_root / "results" / "provider_audit"
    if default_dir.exists():
        candidates.extend(sorted(default_dir.glob("*.jsonl")))

    unique: list[Path] = []
    seen: set[str] = set()
    for candidate in candidates:
        standard = _standard(candidate)
        if standard not in seen:
            seen.add(standard)
            unique.append(candidate)
    return unique


def _audit_path_matches(path: Path, *, run_id: str, call_id: str) -> bool:
    if not path.exists() or not path.is_file():
        return False
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return False
    for line in lines:
        if not line.strip():
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(payload, dict) and (payload.get("run_id") == run_id or payload.get("call_id") == call_id):
            return True
    return False


def _find_provider_audit_jsonl(repo_root: Path, run_id: str, call_id: str, explicit_paths: list[Path] | None = None) -> Path:
    for candidate in _candidate_provider_audit_paths(repo_root, explicit_paths):
        if _audit_path_matches(candidate, run_id=run_id, call_id=call_id):
            return candidate
    raise ArtifactRunnerError(f"no provider audit JSONL found for run_id {run_id} or call_id {call_id}")


def _required_path_fields_for_case(manifest_case: dict[str, Any]) -> dict[str, str]:
    fields: dict[str, str] = {}
    for output_name in manifest_case["expected_outputs"]:
        field_name = REQUIRED_RUN_MAP_PATHS.get(output_name)
        _require(field_name is not None, f"unsupported expected output in manifest: {output_name}")
        fields[output_name] = field_name
    return fields


def _run_map_case_from_record(
    *,
    case_id: str,
    manifest_case: dict[str, Any],
    record: dict[str, str],
    audit_path: Path,
    run_store_db: Path,
) -> dict[str, Any]:
    raw_paths = {
        "image_path": record.get("artifact_path", ""),
        "request_json": record.get("request_path", ""),
        "metadata_json": record.get("metadata_path", ""),
        "provider_request_json": record.get("provider_request_path", ""),
        "provider_response_json": record.get("raw_response_path", ""),
        "provider_audit_jsonl": str(audit_path),
        "run_store_db": str(run_store_db),
    }
    run_id = record.get("id", "") or record.get("run_id", "")
    _require(run_id != "", f"run_store record for case {case_id} is missing id")
    run_dir = record.get("run_dir", "")
    _require(run_dir != "", f"run_store record for {run_id} is missing run_dir")

    case_payload: dict[str, Any] = {
        "case_id": case_id,
        "run_id": run_id,
        "provider_call_id": record.get("provider_call_id", ""),
        "run_dir": _standard(Path(run_dir)),
    }

    for output_name, field_name in _required_path_fields_for_case(manifest_case).items():
        raw_path = raw_paths.get(field_name, "")
        _require(raw_path != "", f"run_store record for {run_id} is missing {field_name}")
        path = Path(raw_path)
        _require(path.exists(), f"mapped {output_name} path for {run_id} is missing: {path}")
        case_payload[field_name] = _standard(path)

    return case_payload


def build_run_map_from_native_runs(
    *,
    manifest: dict[str, Any],
    manifest_contract: dict[str, Any],
    repo_root: Path,
    case_run_ids: dict[str, str],
    run_store_db: Path | None = None,
    provider_audit_paths: list[Path] | None = None,
) -> dict[str, Any]:
    expected_case_ids = manifest_contract["case_ids"]
    supplied_case_ids = set(case_run_ids)
    missing = sorted(expected_case_ids - supplied_case_ids)
    extra = sorted(supplied_case_ids - expected_case_ids)
    _require(not missing, f"--case-run is missing manifest cases: {missing}")
    _require(not extra, f"--case-run has unknown manifest cases: {extra}")

    run_store = run_store_db or _default_run_store(repo_root)
    manifest_cases = _case_by_id(manifest)
    cases: list[dict[str, Any]] = []
    for manifest_case in manifest["cases"]:
        case_id = manifest_case["case_id"]
        run_id = case_run_ids[case_id]
        record = _read_run_store_record(run_store, run_id)
        call_id = record["provider_call_id"]
        audit_path = _find_provider_audit_jsonl(
            repo_root,
            run_id,
            call_id,
            explicit_paths=provider_audit_paths,
        )
        cases.append(
            _run_map_case_from_record(
                case_id=case_id,
                manifest_case=manifest_cases[case_id],
                record=record,
                audit_path=audit_path,
                run_store_db=run_store,
            )
        )

    return {
        "schema_version": RUN_MAP_SCHEMA_VERSION,
        "manifest_id": manifest_contract["benchmark_id"],
        "provider_scoring_used": False,
        "publication_quality_claimed": False,
        "live_provider_used": False,
        "cases": cases,
    }


def _path_for(case: dict[str, Any], field: str, base: Path) -> Path | None:
    value = case.get(field)
    if not isinstance(value, str) or not value.strip():
        return None
    return _resolve(base, value)


def _check_case(
    *,
    manifest_case: dict[str, Any],
    run_map_case: dict[str, Any],
    run_map_base: Path,
    secret_markers: tuple[str, ...],
) -> dict[str, Any]:
    failures: list[str] = []
    checked_outputs: list[str] = []
    checked_files: list[str] = []
    run_id = str(run_map_case["run_id"])
    run_dir = _resolve(run_map_base, str(run_map_case["run_dir"]))
    if not run_dir.exists():
        failures.append(f"run_dir missing: {run_dir}")

    paths_by_output: dict[str, Path | None] = {}
    for output_name, field_name in REQUIRED_RUN_MAP_PATHS.items():
        paths_by_output[output_name] = _path_for(run_map_case, field_name, run_map_base)

    for output_name in manifest_case["expected_outputs"]:
        checked_outputs.append(output_name)
        path = paths_by_output.get(output_name)
        if path is None:
            failures.append(f"run_map missing path field for expected output {output_name}")
            continue
        checked_files.append(str(path))
        if output_name == "image":
            _check_image(path, failures)
        elif output_name in {"request_json", "metadata_json", "provider_request_json", "provider_response_json"}:
            payload = _load_json_artifact(path, failures, output_name)
            if payload is not None:
                _check_no_live_json_markers(payload, failures, output_name)
        elif output_name == "provider_audit":
            call_id = run_map_case.get("provider_call_id")
            _check_provider_audit_event(
                path,
                run_id=run_id,
                call_id=call_id if isinstance(call_id, str) and call_id else None,
                failures=failures,
            )
        elif output_name == "run_store":
            _check_run_store(
                path,
                run_id=run_id,
                run_dir=run_dir,
                image_path=paths_by_output.get("image"),
                request_json=paths_by_output.get("request_json"),
                metadata_json=paths_by_output.get("metadata_json"),
                provider_request_json=paths_by_output.get("provider_request_json"),
                provider_response_json=paths_by_output.get("provider_response_json"),
                failures=failures,
            )
        else:
            failures.append(f"unsupported expected output in manifest: {output_name}")

    for path in {value for value in paths_by_output.values() if value is not None}:
        _scan_secret_markers(path, secret_markers, failures)

    return {
        "case_id": manifest_case["case_id"],
        "run_id": run_id,
        "checked_outputs": checked_outputs,
        "checked_files": checked_files,
        "artifact_failures": failures,
        "status": "fixture_passed" if not failures else "fixture_failed",
    }


def build_report(
    *,
    manifest: dict[str, Any],
    manifest_contract: dict[str, Any],
    run_map: dict[str, Any],
    run_map_path: Path,
    secret_markers: tuple[str, ...],
) -> dict[str, Any]:
    run_map_cases = _validate_run_map(run_map, manifest_contract=manifest_contract)
    manifest_cases = _case_by_id(manifest)
    artifact_cases = [
        _check_case(
            manifest_case=manifest_cases[str(run_case["case_id"])],
            run_map_case=run_case,
            run_map_base=run_map_path.parent,
            secret_markers=secret_markers,
        )
        for run_case in run_map_cases
    ]

    case_results = [
        {
            "case_id": artifact_case["case_id"],
            "status": artifact_case["status"],
            "scores": {},
            "critical_failures": artifact_case["artifact_failures"],
        }
        for artifact_case in artifact_cases
    ]
    report = {
        "schema_version": "wp108.no_live_report.v1",
        "manifest_id": manifest_contract["benchmark_id"],
        "evaluation_mode": "fixture",
        "provider_scoring_used": False,
        "publication_quality_claimed": False,
        "case_results": case_results,
        "summary": {
            "cases_total": len(manifest_contract["case_ids"]),
            "mean_score": None,
            "threshold_passed": False,
            "claim_boundary": (
                "No-live artifact completeness was checked only; no image quality, "
                "scientific correctness, reviewer scoring, provider scoring, or "
                "publication-quality threshold was evaluated."
            ),
        },
        "artifact_checks": {
            "schema_version": "wp108.no_live_artifact_checks.v1",
            "secret_markers_checked": len(secret_markers),
            "cases": artifact_cases,
        },
    }
    validate_report(report, manifest_contract=manifest_contract, mode="fixture", no_provider=True)
    return report


def run_command(args: argparse.Namespace) -> int:
    manifest_path = Path(args.manifest)
    run_map_path = Path(args.run_map)
    report_path = Path(args.report)

    manifest = _load_json(manifest_path)
    run_map = _load_json(run_map_path)
    manifest_contract = validate_manifest(manifest, manifest_path=manifest_path, check_paths=args.check_paths)
    markers = tuple(DEFAULT_SECRET_MARKERS + tuple(args.secret_marker or ()))
    report = build_report(
        manifest=manifest,
        manifest_contract=manifest_contract,
        run_map=run_map,
        run_map_path=run_map_path,
        secret_markers=markers,
    )
    _write_json(report_path, report)

    failed_cases = [result for result in report["case_results"] if result["status"] != "fixture_passed"]
    print(
        "WP-108 no-live artifact runner wrote report: "
        f"report={report_path} cases={len(report['case_results'])} failed_cases={len(failed_cases)} "
        "publication_quality_claimed=false"
    )
    return 1 if failed_cases else 0


def generate_run_map_command(args: argparse.Namespace) -> int:
    manifest_path = Path(args.manifest)
    output_path = Path(args.output)
    repo_root = Path(args.repo_root).expanduser().resolve(strict=False)
    run_store_db = Path(args.run_store).expanduser().resolve(strict=False) if args.run_store else None
    provider_audit_paths = [
        Path(path).expanduser().resolve(strict=False)
        for path in (args.provider_audit or [])
    ]

    manifest = _load_json(manifest_path)
    manifest_contract = validate_manifest(manifest, manifest_path=manifest_path, check_paths=args.check_paths)
    run_map = build_run_map_from_native_runs(
        manifest=manifest,
        manifest_contract=manifest_contract,
        repo_root=repo_root,
        case_run_ids=_parse_case_run_pairs(args.case_run),
        run_store_db=run_store_db,
        provider_audit_paths=provider_audit_paths,
    )
    _write_json(output_path, run_map)

    report_path = Path(args.report).expanduser().resolve(strict=False) if args.report else None
    if report_path is not None:
        markers = tuple(DEFAULT_SECRET_MARKERS + tuple(args.secret_marker or ()))
        report = build_report(
            manifest=manifest,
            manifest_contract=manifest_contract,
            run_map=run_map,
            run_map_path=output_path,
            secret_markers=markers,
        )
        _write_json(report_path, report)
        failed_cases = [result for result in report["case_results"] if result["status"] != "fixture_passed"]
        print(
            "WP-108 no-live run map generated and checked: "
            f"run_map={output_path} report={report_path} cases={len(report['case_results'])} "
            f"failed_cases={len(failed_cases)} publication_quality_claimed=false"
        )
        return 1 if failed_cases else 0

    print(
        "WP-108 no-live run map generated: "
        f"run_map={output_path} cases={len(run_map['cases'])} publication_quality_claimed=false"
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Validate WP-108 no-live native artifact completeness.")
    parser.add_argument("--manifest", required=True, help="Path to WP-108 no-live manifest JSON")
    parser.add_argument("--run-map", required=True, help="Path to WP-108 no-live run-map JSON")
    parser.add_argument("--report", required=True, help="Path to write the generated report JSON")
    parser.add_argument("--secret-marker", action="append", help="Additional forbidden marker to scan in mapped artifacts")
    path_group = parser.add_mutually_exclusive_group()
    path_group.add_argument("--check-paths", action="store_true", help="Require manifest ground-truth paths to exist")
    path_group.add_argument("--no-path-check", action="store_true", help="Skip ground-truth path existence checks")
    parser.set_defaults(func=run_command)
    return parser


def build_generate_run_map_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate a WP-108 no-live run map from native run-store records.")
    parser.add_argument("--manifest", required=True, help="Path to WP-108 no-live manifest JSON")
    parser.add_argument("--repo-root", required=True, help="Repository root that owns the native run artifacts")
    parser.add_argument("--case-run", action="append", required=True, help="Manifest case mapping in CASE_ID=RUN_ID form")
    parser.add_argument("--output", required=True, help="Path to write the generated run-map JSON")
    parser.add_argument("--run-store", help="Override the native run-store SQLite path")
    parser.add_argument("--provider-audit", action="append", help="Provider audit JSONL file or directory to scan before the default provider_audit directory")
    parser.add_argument("--report", help="Optional path to write an immediate artifact-completeness report")
    parser.add_argument("--secret-marker", action="append", help="Additional forbidden marker to scan when --report is used")
    path_group = parser.add_mutually_exclusive_group()
    path_group.add_argument("--check-paths", action="store_true", help="Require manifest ground-truth paths to exist")
    path_group.add_argument("--no-path-check", action="store_true", help="Skip ground-truth path existence checks")
    parser.set_defaults(func=generate_run_map_command)
    return parser


def main(argv: list[str] | None = None) -> int:
    raw_args = list(sys.argv[1:] if argv is None else argv)
    if raw_args[:1] == ["generate-run-map"]:
        parser = build_generate_run_map_parser()
        args = parser.parse_args(raw_args[1:])
    else:
        parser = build_parser()
        args = parser.parse_args(raw_args)
    try:
        return args.func(args)
    except (ArtifactRunnerError, ContractError) as exc:
        print(f"WP-108 no-live artifact runner failed: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
