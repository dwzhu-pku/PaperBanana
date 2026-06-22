import json
import sqlite3
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
EXAMPLE_MANIFEST = REPO_ROOT / "docs" / "integration" / "wp108_no_live_manifest.example.json"


TINY_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01"
    b"\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4"
    b"\x89\x00\x00\x00\rIDATx\x9cc\xf8\xff\xff?\x00\x05"
    b"\xfe\x02\xfeA\x89\x81\xcd\x00\x00\x00\x00IEND\xaeB`\x82"
)


def _write_json(path: Path, payload: dict) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    return path


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _make_manifest(tmp_path: Path) -> Path:
    manifest = _load_json(EXAMPLE_MANIFEST)
    outputs = manifest["cases"][0]["expected_outputs"]
    if "provider_response_json" not in outputs:
        outputs.insert(outputs.index("provider_audit"), "provider_response_json")
    return _write_json(tmp_path / "manifest.json", manifest)


def _create_run_store(
    db_path: Path,
    *,
    run_id: str,
    call_id: str,
    run_dir: Path,
    request_json: Path,
    provider_request_json: Path,
    provider_response_json: Path,
    image_path: Path,
    metadata_json: Path,
) -> None:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(db_path)
    try:
        connection.executescript(
            """
            CREATE TABLE runs (
                id TEXT PRIMARY KEY,
                run_dir TEXT NOT NULL,
                request_path TEXT NOT NULL,
                provider_request_path TEXT NOT NULL DEFAULT '',
                raw_response_path TEXT NOT NULL DEFAULT '',
                artifact_path TEXT NOT NULL DEFAULT '',
                metadata_path TEXT NOT NULL DEFAULT '',
                provider_call_id TEXT NOT NULL DEFAULT ''
            );
            CREATE TABLE provider_calls (
                call_id TEXT PRIMARY KEY,
                run_id TEXT NOT NULL,
                status TEXT NOT NULL
            );
            CREATE TABLE provider_call_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                call_id TEXT NOT NULL,
                run_id TEXT NOT NULL,
                status TEXT NOT NULL
            );
            """
        )
        connection.execute(
            """
            INSERT INTO runs (
                id, run_dir, request_path, provider_request_path, raw_response_path,
                artifact_path, metadata_path, provider_call_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                run_id,
                str(run_dir),
                str(request_json),
                str(provider_request_json),
                str(provider_response_json),
                str(image_path),
                str(metadata_json),
                call_id,
            ),
        )
        connection.execute(
            "INSERT INTO provider_calls (call_id, run_id, status) VALUES (?, ?, ?)",
            (call_id, run_id, "succeeded"),
        )
        connection.execute(
            "INSERT INTO provider_call_events (call_id, run_id, status) VALUES (?, ?, ?)",
            (call_id, run_id, "succeeded"),
        )
        connection.commit()
    finally:
        connection.close()


def _make_synthetic_native_run(tmp_path: Path, *, include_metadata: bool = True, include_audit: bool = True) -> tuple[Path, Path, Path]:
    manifest_path = _make_manifest(tmp_path)
    repo_root = tmp_path / "fixture_repo"
    run_id = "native_generate_4K_20260622_130000"
    call_id = "swift-local-fixture-call"
    run_dir = repo_root / "results" / "native_runs" / run_id
    image_path = run_dir / "generated_4K.png"
    request_json = run_dir / "request.json"
    metadata_json = run_dir / "generated_4K.json"
    provider_request_json = run_dir / "provider_request.json"
    provider_response_json = run_dir / "generated_4K.provider_response.json"
    provider_audit_jsonl = repo_root / "results" / "provider_audit" / "provider_calls_20260622.jsonl"
    run_store_db = repo_root / "results" / "run_store" / "paperbanana_runs.sqlite"

    run_dir.mkdir(parents=True, exist_ok=True)
    image_path.write_bytes(TINY_PNG)
    _write_json(
        request_json,
        {
            "run_id": run_id,
            "workflow": "native_generate",
            "mode": "dry_run",
            "provider_spend": "none",
            "output_path": str(image_path),
            "provider_request_path": str(provider_request_json),
        },
    )
    if include_metadata:
        _write_json(
            metadata_json,
            {
                "run_id": run_id,
                "workflow": "native_generate",
                "provider_call_id": call_id,
                "provider_request_path": str(provider_request_json),
                "output_path": str(image_path),
                "usage_metadata": {"provider_spend": "none"},
            },
        )
    _write_json(
        provider_request_json,
        {
            "run_id": run_id,
            "call_id": call_id,
            "adapter": "swift_local",
            "mode": "dry_run",
            "provider_spend": "none",
            "prompt": "Synthetic no-live WP-108 artifact fixture.",
        },
    )
    _write_json(
        provider_response_json,
        {
            "run_id": run_id,
            "call_id": call_id,
            "provider": "swift_local",
            "provider_spend": "none",
            "message": "Synthetic no-live response.",
        },
    )
    if include_audit:
        provider_audit_jsonl.parent.mkdir(parents=True, exist_ok=True)
        provider_audit_jsonl.write_text(
            json.dumps(
                {
                    "event": "provider_call_started",
                    "run_id": run_id,
                    "call_id": call_id,
                    "provider": "swift_local",
                },
                sort_keys=True,
            )
            + "\n"
            + json.dumps(
                {
                    "event": "provider_call_finished",
                    "run_id": run_id,
                    "call_id": call_id,
                    "provider": "swift_local",
                    "success": True,
                },
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )
    _create_run_store(
        run_store_db,
        run_id=run_id,
        call_id=call_id,
        run_dir=run_dir,
        request_json=request_json,
        provider_request_json=provider_request_json,
        provider_response_json=provider_response_json,
        image_path=image_path,
        metadata_json=metadata_json,
    )

    run_map_path = _write_json(
        tmp_path / "run_map.json",
        {
            "schema_version": "wp108.no_live_run_map.v1",
            "manifest_id": "paperbanana-m1-no-live-contract",
            "provider_scoring_used": False,
            "publication_quality_claimed": False,
            "live_provider_used": False,
            "cases": [
                {
                    "case_id": "diagram-ref-1-contract",
                    "run_id": run_id,
                    "run_dir": str(run_dir),
                    "image_path": str(image_path),
                    "request_json": str(request_json),
                    "metadata_json": str(metadata_json),
                    "provider_request_json": str(provider_request_json),
                    "provider_response_json": str(provider_response_json),
                    "provider_audit_jsonl": str(provider_audit_jsonl),
                    "run_store_db": str(run_store_db),
                }
            ],
        },
    )
    return manifest_path, run_map_path, tmp_path / "report.json"


def _run_artifact_runner(manifest_path: Path, run_map_path: Path, report_path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            sys.executable,
            "-m",
            "utils.wp108_no_live_artifact_runner",
            "--manifest",
            str(manifest_path),
            "--run-map",
            str(run_map_path),
            "--report",
            str(report_path),
            "--no-path-check",
        ],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def test_complete_synthetic_native_run_emits_fixture_passed_report(tmp_path):
    manifest_path, run_map_path, report_path = _make_synthetic_native_run(tmp_path)

    result = _run_artifact_runner(manifest_path, run_map_path, report_path)

    assert result.returncode == 0, result.stderr
    assert "publication_quality_claimed=false" in result.stdout
    report = _load_json(report_path)
    assert report["publication_quality_claimed"] is False
    assert report["provider_scoring_used"] is False
    assert report["summary"]["threshold_passed"] is False
    assert report["case_results"][0]["status"] == "fixture_passed"
    assert report["case_results"][0]["scores"] == {}
    assert report["artifact_checks"]["cases"][0]["checked_outputs"] == [
        "image",
        "request_json",
        "metadata_json",
        "provider_request_json",
        "provider_response_json",
        "provider_audit",
        "run_store",
    ]

    contract = subprocess.run(
        [
            sys.executable,
            "-m",
            "utils.wp108_benchmark_contract",
            "validate",
            "--manifest",
            str(manifest_path),
            "--report",
            str(report_path),
            "--mode",
            "fixture",
            "--no-provider",
            "--no-path-check",
        ],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    assert contract.returncode == 0, contract.stderr


def test_missing_metadata_and_provider_audit_emit_fixture_failed_report(tmp_path):
    manifest_path, run_map_path, report_path = _make_synthetic_native_run(
        tmp_path,
        include_metadata=False,
        include_audit=False,
    )

    result = _run_artifact_runner(manifest_path, run_map_path, report_path)

    assert result.returncode == 1
    report = _load_json(report_path)
    assert report["publication_quality_claimed"] is False
    assert report["summary"]["threshold_passed"] is False
    case = report["case_results"][0]
    assert case["status"] == "fixture_failed"
    assert case["scores"] == {}
    assert any("metadata_json missing" in failure for failure in case["critical_failures"])
    assert any("provider_audit missing" in failure for failure in case["critical_failures"])


def test_runner_refuses_live_or_provider_scored_run_maps(tmp_path):
    manifest_path, run_map_path, report_path = _make_synthetic_native_run(tmp_path)
    run_map = _load_json(run_map_path)
    run_map["live_provider_used"] = True
    run_map["provider_scoring_used"] = True
    _write_json(run_map_path, run_map)

    result = _run_artifact_runner(manifest_path, run_map_path, report_path)

    assert result.returncode == 2
    assert "provider_scoring_used must be false" in result.stderr
    assert not report_path.exists()


def test_runner_source_does_not_import_provider_backed_evaluation_modules():
    source = (REPO_ROOT / "utils" / "wp108_no_live_artifact_runner.py").read_text(encoding="utf-8")
    forbidden = [
        "eval_toolkits",
        "generation_utils",
        "call_gemini",
        "call_openai",
        "call_claude",
        "requests",
        "ProviderClient",
    ]

    for phrase in forbidden:
        assert phrase not in source
