import copy
import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
EXAMPLE_MANIFEST = REPO_ROOT / "docs" / "integration" / "wp108_no_live_manifest.example.json"


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, payload: dict) -> Path:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    return path


def _valid_human_review_report() -> dict:
    manifest = _load(EXAMPLE_MANIFEST)
    return {
        "schema_version": "wp108.no_live_report.v1",
        "manifest_id": manifest["benchmark_id"],
        "evaluation_mode": "human_review",
        "provider_scoring_used": False,
        "publication_quality_claimed": False,
        "scoring_protocol": {
            "reviewer_policy_id": "paperbanana-wp108-human-review-v1",
            "scoring_mode": "human_review",
            "minimum_reviewers_per_case": 2,
            "adjudication_policy": "Synthetic fixture adjudicates final case scores after reviewer completion.",
            "score_scale": {"minimum": 0.0, "maximum": 4.0},
            "critical_failure_policy": "Critical failures prevent a quality pass.",
        },
        "artifact_binding": {
            "manifest_sha256": "a" * 64,
            "run_map_sha256": "b" * 64,
            "artifact_report_sha256": "c" * 64,
            "review_packet_sha256": "d" * 64,
            "source_head": "test-source-head",
        },
        "case_results": [
            {
                "case_id": "diagram-ref-1-contract",
                "status": "passed",
                "scores": {
                    "semantic_faithfulness": 4.0,
                    "visual_legibility": 3.0,
                    "artifact_completeness": 3.5,
                },
                "score_source": "adjudicated_human_review",
                "scored_artifact": {
                    "run_id": "native_generate_test",
                    "image_sha256": "e" * 64,
                    "artifact_check_status": "fixture_passed",
                },
                "reviewer_scores": [
                    {
                        "reviewer_id": "reviewer-a",
                        "completed_at_utc": "2026-06-22T00:00:00Z",
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
                        "completed_at_utc": "2026-06-22T00:01:00Z",
                        "attestation": True,
                        "scores": {
                            "semantic_faithfulness": 4.0,
                            "visual_legibility": 3.0,
                            "artifact_completeness": 4.0,
                        },
                        "critical_failures": [],
                    },
                ],
                "critical_failures": [],
            }
        ],
        "summary": {
            "cases_total": 1,
            "mean_score": 3.5,
            "threshold_passed": True,
            "claim_boundary": "Synthetic completed human-review fixture; not release evidence.",
        },
    }


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


def _run_validate(manifest_path: Path, report_path: Path, decision_path: Path) -> subprocess.CompletedProcess[str]:
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


def test_quality_decision_go_report_for_valid_completed_human_review(tmp_path):
    manifest_path = _write_json(tmp_path / "manifest.json", _load(EXAMPLE_MANIFEST))
    report_path = _write_json(tmp_path / "human_review.json", _valid_human_review_report())
    decision_path = tmp_path / "decision.json"

    result = _run_decide(manifest_path, report_path, decision_path)

    assert result.returncode == 0, result.stderr
    assert "decision=go" in result.stdout
    decision = _load(decision_path)
    assert decision["schema_version"] == "wp108.quality_decision.v1"
    assert decision["decision"] == "go"
    assert decision["gate_passed"] is True
    assert decision["publication_quality_claimed"] is False
    assert decision["provider_scoring_used"] is False
    assert decision["observed"]["dimension_results"]["semantic_faithfulness"]["passed"] is True
    assert decision["blockers"] == []

    validate = _run_validate(manifest_path, report_path, decision_path)
    assert validate.returncode == 0, validate.stderr
    assert "quality decision report contract passed" in validate.stdout


def test_quality_decision_blocks_dimension_below_pass_threshold_even_when_mean_passes(tmp_path):
    report = _valid_human_review_report()
    report["case_results"][0]["scores"] = {
        "semantic_faithfulness": 2.0,
        "visual_legibility": 4.0,
        "artifact_completeness": 4.0,
    }
    report["case_results"][0]["reviewer_scores"][0]["scores"] = copy.deepcopy(report["case_results"][0]["scores"])
    report["case_results"][0]["reviewer_scores"][1]["scores"] = copy.deepcopy(report["case_results"][0]["scores"])
    report["summary"]["mean_score"] = 10.0 / 3.0
    report["summary"]["threshold_passed"] = True
    manifest_path = _write_json(tmp_path / "manifest.json", _load(EXAMPLE_MANIFEST))
    report_path = _write_json(tmp_path / "human_review.json", report)
    decision_path = tmp_path / "decision.json"

    result = _run_decide(manifest_path, report_path, decision_path)

    assert result.returncode == 0, result.stderr
    decision = _load(decision_path)
    assert decision["decision"] == "no_go"
    assert decision["gate_passed"] is False
    assert decision["observed"]["dimension_results"]["semantic_faithfulness"]["passed"] is False
    assert "dimension semantic_faithfulness average is below pass threshold" in decision["blockers"]


def test_quality_decision_blocks_reviewer_critical_failures(tmp_path):
    report = _valid_human_review_report()
    report["case_results"][0]["reviewer_scores"][1]["critical_failures"] = [
        "Reviewer observed a semantic contradiction."
    ]
    manifest_path = _write_json(tmp_path / "manifest.json", _load(EXAMPLE_MANIFEST))
    report_path = _write_json(tmp_path / "human_review.json", report)
    decision_path = tmp_path / "decision.json"

    result = _run_decide(manifest_path, report_path, decision_path)

    assert result.returncode == 0, result.stderr
    decision = _load(decision_path)
    assert decision["decision"] == "no_go"
    assert decision["observed"]["reviewer_critical_failures"][0]["reviewer_id"] == "reviewer-b"
    assert "reviewer-level critical failures are present" in decision["blockers"]


def test_quality_decision_blocks_single_reviewer_score_source_by_default(tmp_path):
    report = _valid_human_review_report()
    report["case_results"][0]["score_source"] = "single_human_reviewer"
    manifest_path = _write_json(tmp_path / "manifest.json", _load(EXAMPLE_MANIFEST))
    report_path = _write_json(tmp_path / "human_review.json", report)
    decision_path = tmp_path / "decision.json"

    result = _run_decide(manifest_path, report_path, decision_path)

    assert result.returncode == 0, result.stderr
    decision = _load(decision_path)
    assert decision["decision"] == "no_go"
    assert decision["observed"]["disallowed_score_sources"] == {
        "diagram-ref-1-contract": "single_human_reviewer"
    }
    assert "non-adjudicated score sources are present" in decision["blockers"]


def test_quality_decision_validate_rejects_tampered_decision(tmp_path):
    manifest_path = _write_json(tmp_path / "manifest.json", _load(EXAMPLE_MANIFEST))
    report_path = _write_json(tmp_path / "human_review.json", _valid_human_review_report())
    decision_path = tmp_path / "decision.json"
    result = _run_decide(manifest_path, report_path, decision_path)
    assert result.returncode == 0, result.stderr
    decision = _load(decision_path)
    decision["observed"]["observed_mean_score"] = 0.0
    _write_json(decision_path, decision)

    validate = _run_validate(manifest_path, report_path, decision_path)

    assert validate.returncode == 1
    assert "observed mean must match" in validate.stderr


def test_quality_decision_rejects_provider_scored_report_in_no_provider_mode(tmp_path):
    report = _valid_human_review_report()
    report["provider_scoring_used"] = True
    manifest_path = _write_json(tmp_path / "manifest.json", _load(EXAMPLE_MANIFEST))
    report_path = _write_json(tmp_path / "human_review.json", report)
    decision_path = tmp_path / "decision.json"

    result = _run_decide(manifest_path, report_path, decision_path)

    assert result.returncode == 1
    assert "provider_scoring_used must be false" in result.stderr
    assert not decision_path.exists()
