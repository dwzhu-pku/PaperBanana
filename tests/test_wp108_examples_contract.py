import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST = REPO_ROOT / "docs" / "integration" / "wp108_no_live_manifest.example.json"
FIXTURE_REPORT = REPO_ROOT / "docs" / "integration" / "wp108_no_live_report.fixture.json"
REVIEW_PACKET = REPO_ROOT / "docs" / "integration" / "wp108_human_review_packet.example.json"
HUMAN_REVIEW_REPORT = REPO_ROOT / "docs" / "integration" / "wp108_human_review_report.example.json"
QUALITY_DECISION = REPO_ROOT / "docs" / "integration" / "wp108_quality_decision.example.json"


def _run_module(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, "-m", *args],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def test_checked_in_wp108_examples_are_validator_clean_without_quality_claims():
    fixture = _run_module(
        "utils.wp108_benchmark_contract",
        "validate",
        "--manifest",
        str(MANIFEST),
        "--report",
        str(FIXTURE_REPORT),
        "--mode",
        "fixture",
        "--no-provider",
        "--no-path-check",
    )
    assert fixture.returncode == 0, fixture.stderr

    packet = _run_module(
        "utils.wp108_human_review_packet",
        "validate",
        "--manifest",
        str(MANIFEST),
        "--packet",
        str(REVIEW_PACKET),
        "--no-path-check",
    )
    assert packet.returncode == 0, packet.stderr

    human_review = _run_module(
        "utils.wp108_benchmark_contract",
        "validate",
        "--manifest",
        str(MANIFEST),
        "--report",
        str(HUMAN_REVIEW_REPORT),
        "--mode",
        "human_review",
        "--no-provider",
        "--no-path-check",
    )
    assert human_review.returncode == 0, human_review.stderr

    decision = _run_module(
        "utils.wp108_quality_decision",
        "validate",
        "--manifest",
        str(MANIFEST),
        "--report",
        str(HUMAN_REVIEW_REPORT),
        "--decision",
        str(QUALITY_DECISION),
        "--no-provider",
        "--no-path-check",
    )
    assert decision.returncode == 0, decision.stderr

    combined_examples = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (FIXTURE_REPORT, REVIEW_PACKET, HUMAN_REVIEW_REPORT, QUALITY_DECISION)
    )
    assert '"publication_quality_claimed": false' in combined_examples
    assert '"provider_scoring_used": false' in combined_examples
