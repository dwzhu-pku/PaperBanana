import json
import subprocess
import sys
from hashlib import sha256
from pathlib import Path

from tests.test_wp108_no_live_artifact_runner import (
    _load_json,
    _make_synthetic_native_run,
    _run_generate_run_map,
    _write_json,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
PROVIDER_PAYLOAD_SENTINEL = "PROVIDER_PAYLOAD_SENTINEL_SHOULD_NOT_APPEAR_IN_REVIEW_CHAIN"


def _sha256_file(path: Path) -> str:
    digest = sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _run_packet_prepare(
    *,
    manifest_path: Path,
    run_map_path: Path,
    artifact_report_path: Path,
    packet_path: Path,
) -> subprocess.CompletedProcess[str]:
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
            str(artifact_report_path),
            "--source-head",
            "offline-chain-source-head",
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


def _run_packet_validate(manifest_path: Path, packet_path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
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


def _run_report_validate(manifest_path: Path, report_path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
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
            "human_review",
            "--no-provider",
            "--no-path-check",
        ],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def _run_decide(manifest_path: Path, report_path: Path, decision_path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            sys.executable,
            "-m",
            "utils.wp108_quality_decision",
            "decide",
            "--manifest",
            str(manifest_path),
            "--report",
            str(report_path),
            "--output",
            str(decision_path),
            "--no-provider",
            "--no-path-check",
        ],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def _run_decision_validate(
    manifest_path: Path,
    report_path: Path,
    decision_path: Path,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            sys.executable,
            "-m",
            "utils.wp108_quality_decision",
            "validate",
            "--manifest",
            str(manifest_path),
            "--report",
            str(report_path),
            "--decision",
            str(decision_path),
            "--no-provider",
            "--no-path-check",
        ],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def _completed_human_review_report(packet: dict, packet_path: Path) -> dict:
    case = packet["cases"][0]
    scores = {
        "semantic_faithfulness": 4.0,
        "visual_legibility": 3.0,
        "artifact_completeness": 3.5,
    }
    mean_score = sum(scores.values()) / len(scores)
    reviewer_scores = [
        {
            "reviewer_id": "reviewer-a",
            "completed_at_utc": "2026-06-22T17:15:00Z",
            "attestation": True,
            "scores": {
                "semantic_faithfulness": 4.0,
                "visual_legibility": 3.0,
                "artifact_completeness": 3.0,
            },
            "critical_failures": [],
        },
        {
            "reviewer_id": "reviewer-b",
            "completed_at_utc": "2026-06-22T17:16:00Z",
            "attestation": True,
            "scores": {
                "semantic_faithfulness": 4.0,
                "visual_legibility": 3.0,
                "artifact_completeness": 4.0,
            },
            "critical_failures": [],
        },
    ]

    return {
        "schema_version": "wp108.no_live_report.v1",
        "manifest_id": packet["manifest_id"],
        "evaluation_mode": "human_review",
        "provider_scoring_used": False,
        "publication_quality_claimed": False,
        "scoring_protocol": packet["scoring_protocol"],
        "artifact_binding": {
            "manifest_sha256": packet["artifact_binding"]["manifest_sha256"],
            "run_map_sha256": packet["artifact_binding"]["run_map_sha256"],
            "artifact_report_sha256": packet["artifact_binding"]["artifact_report_sha256"],
            "review_packet_sha256": _sha256_file(packet_path),
            "source_head": packet["source_head"],
        },
        "case_results": [
            {
                "case_id": case["case_id"],
                "status": "passed",
                "scores": scores,
                "score_source": "adjudicated_human_review",
                "scored_artifact": {
                    "run_id": case["run_id"],
                    "image_sha256": case["image_sha256"],
                    "artifact_check_status": case["artifact_check_status"],
                },
                "reviewer_scores": reviewer_scores,
                "critical_failures": [],
            }
        ],
        "summary": {
            "cases_total": 1,
            "mean_score": mean_score,
            "threshold_passed": True,
            "claim_boundary": (
                "Synthetic completed offline review report; not release evidence "
                "and not a publication-quality claim."
            ),
        },
    }


def test_wp108_offline_evidence_chain_preserves_binding_and_claim_boundary(tmp_path):
    manifest_path, _, _ = _make_synthetic_native_run(tmp_path)
    provider_response = (
        tmp_path
        / "fixture_repo"
        / "results"
        / "native_runs"
        / "native_generate_4K_20260622_130000"
        / "generated_4K.provider_response.json"
    )
    provider_payload = _load_json(provider_response)
    provider_payload["private_payload_sentinel"] = PROVIDER_PAYLOAD_SENTINEL
    _write_json(provider_response, provider_payload)

    run_map_path = tmp_path / "generated_run_map.json"
    artifact_report_path = tmp_path / "artifact_report.json"
    generated = _run_generate_run_map(
        manifest_path=manifest_path,
        repo_root=tmp_path / "fixture_repo",
        output_path=run_map_path,
        report_path=artifact_report_path,
    )
    assert generated.returncode == 0, generated.stderr
    artifact_report = _load_json(artifact_report_path)
    assert artifact_report["publication_quality_claimed"] is False
    assert artifact_report["provider_scoring_used"] is False
    assert artifact_report["case_results"][0]["status"] == "fixture_passed"

    packet_path = tmp_path / "human_review_packet.json"
    prepared = _run_packet_prepare(
        manifest_path=manifest_path,
        run_map_path=run_map_path,
        artifact_report_path=artifact_report_path,
        packet_path=packet_path,
    )
    assert prepared.returncode == 0, prepared.stderr
    assert "scores_blank=true" in prepared.stdout
    validated_packet = _run_packet_validate(manifest_path, packet_path)
    assert validated_packet.returncode == 0, validated_packet.stderr
    packet = _load_json(packet_path)
    assert packet["artifact_binding"]["manifest_sha256"] == _sha256_file(manifest_path)
    assert packet["artifact_binding"]["run_map_sha256"] == _sha256_file(run_map_path)
    assert packet["artifact_binding"]["artifact_report_sha256"] == _sha256_file(artifact_report_path)
    assert PROVIDER_PAYLOAD_SENTINEL not in packet_path.read_text(encoding="utf-8")

    human_review_path = tmp_path / "completed_human_review_report.json"
    human_review = _completed_human_review_report(packet, packet_path)
    _write_json(human_review_path, human_review)
    validated_report = _run_report_validate(manifest_path, human_review_path)
    assert validated_report.returncode == 0, validated_report.stderr
    assert PROVIDER_PAYLOAD_SENTINEL not in human_review_path.read_text(encoding="utf-8")

    decision_path = tmp_path / "quality_decision.json"
    decided = _run_decide(manifest_path, human_review_path, decision_path)
    assert decided.returncode == 0, decided.stderr
    assert "decision=go" in decided.stdout
    validated_decision = _run_decision_validate(manifest_path, human_review_path, decision_path)
    assert validated_decision.returncode == 0, validated_decision.stderr
    decision = _load_json(decision_path)
    assert decision["schema_version"] == "wp108.quality_decision.v1"
    assert decision["decision"] == "go"
    assert decision["gate_passed"] is True
    assert decision["provider_scoring_used"] is False
    assert decision["publication_quality_claimed"] is False
    assert decision["artifact_binding"]["review_packet_sha256"] == _sha256_file(packet_path)
    assert decision["observed"]["score_sources_by_case"] == {
        "diagram-ref-1-contract": "adjudicated_human_review"
    }
    assert decision["blockers"] == []
    assert PROVIDER_PAYLOAD_SENTINEL not in decision_path.read_text(encoding="utf-8")
