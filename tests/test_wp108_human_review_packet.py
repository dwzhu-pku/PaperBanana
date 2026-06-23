import json
import subprocess
import sys
from pathlib import Path

from utils.wp108_benchmark_contract import validate_manifest
from utils.wp108_human_review_packet import validate_review_packet


REPO_ROOT = Path(__file__).resolve().parents[1]
EXAMPLE_MANIFEST = REPO_ROOT / "docs" / "integration" / "wp108_no_live_manifest.example.json"

TINY_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01"
    b"\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4"
    b"\x89\x00\x00\x00\rIDATx\x9cc\xf8\xff\xff?\x00\x05"
    b"\xfe\x02\xfeA\x89\x81\xcd\x00\x00\x00\x00IEND\xaeB`\x82"
)


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, payload: dict) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    return path


def _make_review_inputs(tmp_path: Path, *, artifact_status: str = "fixture_passed") -> tuple[Path, Path, Path, Path]:
    manifest = _load(EXAMPLE_MANIFEST)
    manifest_path = _write_json(tmp_path / "manifest.json", manifest)
    image_path = tmp_path / "native_generate_20260622_072111" / "generated_2K.png"
    image_path.parent.mkdir(parents=True, exist_ok=True)
    image_path.write_bytes(TINY_PNG)
    provider_response = image_path.parent / "generated_2K.provider_response.json"
    provider_response.write_text("PROVIDER_PAYLOAD_SENTINEL_SHOULD_NOT_APPEAR", encoding="utf-8")

    run_map_path = _write_json(
        tmp_path / "run_map.json",
        {
            "schema_version": "wp108.no_live_run_map.v1",
            "manifest_id": manifest["benchmark_id"],
            "provider_scoring_used": False,
            "publication_quality_claimed": False,
            "live_provider_used": False,
            "cases": [
                {
                    "case_id": "diagram-ref-1-contract",
                    "run_id": "native_generate_20260622_072111",
                    "provider_call_id": "swift-codex-test",
                    "run_dir": str(image_path.parent),
                    "image_path": str(image_path),
                    "request_json": str(image_path.parent / "request.json"),
                    "metadata_json": str(image_path.parent / "generated_2K.json"),
                    "provider_request_json": str(image_path.parent / "provider_request.json"),
                    "provider_audit_jsonl": str(tmp_path / "provider_calls.jsonl"),
                    "run_store_db": str(tmp_path / "paperbanana_runs.sqlite"),
                }
            ],
        },
    )
    artifact_report_path = _write_json(
        tmp_path / "artifact_report.json",
        {
            "schema_version": "wp108.no_live_report.v1",
            "manifest_id": manifest["benchmark_id"],
            "evaluation_mode": "fixture",
            "provider_scoring_used": False,
            "publication_quality_claimed": False,
            "case_results": [
                {
                    "case_id": "diagram-ref-1-contract",
                    "status": artifact_status,
                    "scores": {},
                    "critical_failures": [] if artifact_status == "fixture_passed" else ["missing artifact"],
                }
            ],
            "summary": {
                "cases_total": 1,
                "mean_score": None,
                "threshold_passed": False,
                "claim_boundary": "Fixture artifact report for packet tests.",
            },
            "artifact_checks": {
                "schema_version": "wp108.no_live_artifact_checks.v1",
                "secret_markers_checked": 4,
                "cases": [
                    {
                        "case_id": "diagram-ref-1-contract",
                        "run_id": "native_generate_20260622_072111",
                        "checked_outputs": [
                            "image",
                            "request_json",
                            "metadata_json",
                            "provider_request_json",
                            "provider_audit",
                            "run_store",
                        ],
                        "checked_files": [
                            str(image_path),
                            str(image_path.parent / "request.json"),
                            str(image_path.parent / "generated_2K.json"),
                            str(image_path.parent / "provider_request.json"),
                            str(tmp_path / "provider_calls.jsonl"),
                            str(tmp_path / "paperbanana_runs.sqlite"),
                        ],
                        "artifact_failures": [] if artifact_status == "fixture_passed" else ["missing artifact"],
                        "status": artifact_status,
                    }
                ],
            },
        },
    )
    return manifest_path, run_map_path, artifact_report_path, provider_response


def _prepare_packet(manifest_path: Path, run_map_path: Path, report_path: Path, packet_path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            sys.executable,
            "-m",
            "utils.wp108_human_review_packet",
            "prepare",
            "--manifest",
            str(manifest_path),
            "--run-map",
            str(run_map_path),
            "--artifact-report",
            str(report_path),
            "--source-head",
            "test-source-head",
            "--output",
            str(packet_path),
            "--reviewer-count",
            "2",
            "--no-path-check",
        ],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def test_prepare_review_packet_binds_artifacts_without_scores_or_provider_payload(tmp_path):
    manifest_path, run_map_path, report_path, _ = _make_review_inputs(tmp_path)
    packet_path = tmp_path / "review_packet.json"

    result = _prepare_packet(manifest_path, run_map_path, report_path, packet_path)

    assert result.returncode == 0, result.stderr
    assert "scores_blank=true" in result.stdout
    packet = _load(packet_path)
    manifest_contract = validate_manifest(_load(manifest_path), manifest_path=manifest_path, check_paths=False)
    validate_review_packet(packet, manifest_contract=manifest_contract)
    assert packet["schema_version"] == "wp108.human_review_packet.v1"
    assert packet["cases"][0]["artifact_check_status"] == "fixture_passed"
    assert len(packet["cases"][0]["reviewer_score_slots"]) == 2
    assert set(packet["cases"][0]["reviewer_score_slots"][0]["scores"]) == {
        "semantic_faithfulness",
        "visual_legibility",
        "artifact_completeness",
    }
    assert all(value is None for value in packet["cases"][0]["reviewer_score_slots"][0]["scores"].values())
    assert "PROVIDER_PAYLOAD_SENTINEL_SHOULD_NOT_APPEAR" not in packet_path.read_text(encoding="utf-8")


def test_prepare_review_packet_rejects_failed_artifact_report(tmp_path):
    manifest_path, run_map_path, report_path, _ = _make_review_inputs(tmp_path, artifact_status="fixture_failed")
    packet_path = tmp_path / "review_packet.json"

    result = _prepare_packet(manifest_path, run_map_path, report_path, packet_path)

    assert result.returncode == 1
    assert "fixture_passed" in result.stderr
    assert not packet_path.exists()


def test_review_packet_cli_validate_rejects_mutated_image_digest(tmp_path):
    manifest_path, run_map_path, report_path, _ = _make_review_inputs(tmp_path)
    packet_path = tmp_path / "review_packet.json"
    result = _prepare_packet(manifest_path, run_map_path, report_path, packet_path)
    assert result.returncode == 0, result.stderr
    packet = _load(packet_path)
    packet["cases"][0]["image_sha256"] = "not-a-digest"
    _write_json(packet_path, packet)

    validate_result = subprocess.run(
        [
            sys.executable,
            "-m",
            "utils.wp108_human_review_packet",
            "validate",
            "--manifest",
            str(manifest_path),
            "--packet",
            str(packet_path),
            "--no-path-check",
        ],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )

    assert validate_result.returncode == 1
    assert "sha256" in validate_result.stderr
