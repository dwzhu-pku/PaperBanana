import copy
import json
import subprocess
import sys
from pathlib import Path

import pytest

from utils.wp108_benchmark_contract import validate_manifest, validate_report


REPO_ROOT = Path(__file__).resolve().parents[1]
EXAMPLE_MANIFEST = REPO_ROOT / "docs" / "integration" / "wp108_no_live_manifest.example.json"
EXAMPLE_REPORT = REPO_ROOT / "docs" / "integration" / "wp108_no_live_report.fixture.json"


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, payload: dict) -> Path:
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return path


def _valid_human_review_report() -> dict:
    report = _load(EXAMPLE_REPORT)
    report["evaluation_mode"] = "human_review"
    report["scoring_protocol"] = {
        "reviewer_policy_id": "paperbanana-wp108-human-review-v1",
        "scoring_mode": "human_review",
        "minimum_reviewers_per_case": 2,
        "adjudication_policy": "Test fixture adjudicates final case scores after reviewer completion.",
        "score_scale": {"minimum": 0.0, "maximum": 4.0},
        "critical_failure_policy": "Critical failures prevent a quality pass.",
    }
    report["artifact_binding"] = {
        "manifest_sha256": "a" * 64,
        "run_map_sha256": "b" * 64,
        "artifact_report_sha256": "c" * 64,
        "review_packet_sha256": "d" * 64,
        "source_head": "test-source-head",
    }
    report["case_results"][0].update(
        {
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
        }
    )
    report["summary"]["mean_score"] = 3.5
    report["summary"]["threshold_passed"] = True
    report["summary"]["claim_boundary"] = "Synthetic human-review fixture threshold passed; not release evidence."
    return report


def test_example_fixture_contract_validates_without_provider_or_path_check():
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "utils.wp108_benchmark_contract",
            "validate",
            "--manifest",
            str(EXAMPLE_MANIFEST),
            "--report",
            str(EXAMPLE_REPORT),
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

    assert result.returncode == 0, result.stderr
    assert "WP-108 no-live benchmark contract passed" in result.stdout


def test_fixture_report_cannot_claim_publication_quality(tmp_path):
    manifest = _load(EXAMPLE_MANIFEST)
    report = _load(EXAMPLE_REPORT)
    report["publication_quality_claimed"] = True

    manifest_path = _write_json(tmp_path / "manifest.json", manifest)
    report_path = _write_json(tmp_path / "report.json", report)

    result = subprocess.run(
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

    assert result.returncode == 1
    assert "publication_quality_claimed must be false" in result.stderr


def test_report_case_ids_must_match_manifest():
    manifest = _load(EXAMPLE_MANIFEST)
    report = _load(EXAMPLE_REPORT)
    report["case_results"][0]["case_id"] = "unknown-case"

    manifest_contract = validate_manifest(manifest, manifest_path=EXAMPLE_MANIFEST, check_paths=False)
    with pytest.raises(ValueError, match="missing manifest cases"):
        validate_report(report, manifest_contract=manifest_contract, mode="fixture", no_provider=True)


def test_check_paths_requires_ground_truth_file(tmp_path):
    manifest = _load(EXAMPLE_MANIFEST)
    manifest["cases"][0]["path_to_gt_image"] = "missing/ground-truth.png"
    manifest_path = _write_json(tmp_path / "manifest.json", manifest)

    with pytest.raises(ValueError, match="path_to_gt_image does not exist"):
        validate_manifest(manifest, manifest_path=manifest_path, check_paths=True)


def test_human_review_threshold_math_is_checked(tmp_path):
    manifest = _load(EXAMPLE_MANIFEST)
    report = _valid_human_review_report()

    manifest_contract = validate_manifest(manifest, manifest_path=EXAMPLE_MANIFEST, check_paths=False)
    validate_report(report, manifest_contract=manifest_contract, mode="human_review", no_provider=True)

    incorrect = copy.deepcopy(report)
    incorrect["summary"]["threshold_passed"] = False
    with pytest.raises(ValueError, match="threshold_passed does not match"):
        validate_report(incorrect, manifest_contract=manifest_contract, mode="human_review", no_provider=True)


def test_human_review_scores_require_reviewer_and_artifact_provenance():
    manifest = _load(EXAMPLE_MANIFEST)
    report = _valid_human_review_report()
    del report["scoring_protocol"]

    manifest_contract = validate_manifest(manifest, manifest_path=EXAMPLE_MANIFEST, check_paths=False)
    with pytest.raises(ValueError, match="scoring_protocol"):
        validate_report(report, manifest_contract=manifest_contract, mode="human_review", no_provider=True)


def test_human_review_reviewer_scores_must_attest_and_match_rubric():
    manifest = _load(EXAMPLE_MANIFEST)
    report = _valid_human_review_report()
    report["case_results"][0]["reviewer_scores"][0]["attestation"] = False

    manifest_contract = validate_manifest(manifest, manifest_path=EXAMPLE_MANIFEST, check_paths=False)
    with pytest.raises(ValueError, match="attestation"):
        validate_report(report, manifest_contract=manifest_contract, mode="human_review", no_provider=True)


def test_validator_does_not_import_provider_backed_eval_toolkit():
    source = (REPO_ROOT / "utils" / "wp108_benchmark_contract.py").read_text(encoding="utf-8")
    forbidden_imports = [
        "eval_toolkits",
        "generation_utils",
        "call_gemini",
        "call_openai",
        "call_claude",
    ]

    for phrase in forbidden_imports:
        assert phrase not in source
