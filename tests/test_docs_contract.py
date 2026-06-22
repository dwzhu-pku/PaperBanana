from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SUPPORT_DOC = (REPO_ROOT / "docs" / "SUPPORT.md").read_text(encoding="utf-8")
README = (REPO_ROOT / "README.md").read_text(encoding="utf-8")


def test_support_doc_contains_public_artifact_contract():
    assert "https://huggingface.co/papers/2601.23265" in SUPPORT_DOC
    assert "https://huggingface.co/datasets/dwzhu/PaperBananaBench" in SUPPORT_DOC
    assert "https://huggingface.co/spaces/dwzhu/PaperBanana" in SUPPORT_DOC
    assert "no separate PaperBanana model checkpoint is required" in SUPPORT_DOC


def test_support_doc_contains_provider_and_quota_contracts():
    required_phrases = [
        "Provider And Model Choice",
        "Local OpenAI-Compatible Text Route",
        "not a full image-generation backend",
        "Provider Quota, Billing, And Suspension",
        "Third-Party Relay And Base URL Caveats",
        "API-Key Rotation",
    ]

    for phrase in required_phrases:
        assert phrase in SUPPORT_DOC


def test_readme_links_durable_support_and_local_text_limits():
    assert "[docs/SUPPORT.md](docs/SUPPORT.md)" in README
    assert "no separate PaperBanana model checkpoint is required" in README
    assert "local/<model>" in README
    assert "ollama/<model>" in README
    assert "text-route support only" in README
