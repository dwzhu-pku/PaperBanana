# PaperBanana FAQ

This page collects concise answers for common support and discussion threads.

## Where are the released artifacts?

- Hosted demo: [PaperBanana on Hugging Face Spaces](https://huggingface.co/spaces/dwzhu/PaperBanana)
- Benchmark dataset: [PaperBananaBench](https://huggingface.co/datasets/dwzhu/PaperBananaBench)
- Original diagram PDFs: [PaperBananaDiagramPDFs](https://huggingface.co/datasets/dwzhu/PaperBananaDiagramPDFs)
- Paper page: [PaperBanana on Hugging Face Papers](https://huggingface.co/papers/2601.23265)

For local reference retrieval or manual native reference selection, download the benchmark and place it at `data/PaperBananaBench/`. The native app and legacy tools can run without it, but runs will not use benchmark examples.

## Is there a web demo?

Yes. Use the hosted [Hugging Face Space](https://huggingface.co/spaces/dwzhu/PaperBanana). Space availability can vary with provider quota, Space capacity, and upstream model availability. For reproducible work, run the native macOS app or the legacy local tools with your own provider key.

## What should I do if a provider says quota exceeded?

Quota and billing limits are controlled by the provider account, not by PaperBanana. Recommended first steps:

- Check the provider dashboard for quota, billing, regional access, rate limits, and model availability.
- Lower candidate count, critic rounds, batch size, and parallel runs before retrying.
- Avoid tight retry loops after a 429, `RESOURCE_EXHAUSTED`, billing, or quota message.
- Switch to another configured provider only if your account and provider terms allow it.

The native app records provider attempts in **Run Details** and **Provider Ledger**. Check those views before submitting a support issue about missing outputs or unexpected spend.

## What should I do if a cloud project is suspended?

Stop automated retries from that project and review the provider's suspension notice, terms, acceptable-use policy, quota page, and billing page. PaperBanana maintainers cannot interpret or override account enforcement decisions. Use the provider's official support or appeal channel, and include only redacted PaperBanana run metadata if it helps explain the workload.

Do not post API keys, billing identifiers, account IDs, private prompts, or complete request payloads in public issues.

## Which model or provider should I choose?

PaperBanana's diagram workflow needs both strong text planning and an image-generation backend. The native app currently targets supported Google Gemini/Nano Banana routes, OpenRouter when retained, and the Codex fallback path. Legacy Python tools can also use configured YAML or environment credentials.

Third-party relay services usually require the matching base URL, model names, and provider settings. A key from a relay service should not be pasted under a different provider's official key field unless that relay is explicitly compatible with that route.

## Can I use Ollama or another local LLM?

Not as a complete image backend. Ollama and other local LLMs can help only where PaperBanana is using an explicitly configured OpenAI-compatible text route. They do not replace the native image-generation provider for diagram rendering or image refinement unless you add and test a separate image backend integration.

For statistical plots, some steps are text/code-oriented, but the pipeline still expects the configured provider contracts. Treat local LLM use as an advanced compatibility setup, not a supported no-key replacement for the full native app workflow.

## What if I accidentally posted an API key?

Revoke or rotate the exposed key in the provider dashboard immediately. Editing a GitHub comment is not enough because keys may be copied into notifications, logs, caches, or forks. After rotating, update your local environment variables, app Settings, or ignored `configs/model_config.yaml`.

When opening an issue, include redacted values such as `sk-...abcd`, provider name, model name, error code, run status, and whether the failing path is native macOS, Gradio, Streamlit, or CLI.

## How should I propose a large agent or prompt feature?

Open an issue or discussion before sending a large pull request. Include:

- The exact pipeline stage affected, such as Retriever, Planner, Stylist, Visualizer, Critic, or prompt templates.
- A minimal design summary and why it is preferable to a user-side prompt or fork.
- Before/after examples on a small reproducible set.
- Evaluation criteria, failure cases, and any added dependencies.
- A split plan for small pull requests with tests and docs.

Large changes such as new planner strategies, visual metaphor discovery, renderer modes, critic loops, or prompt overhauls are easier to review when they land behind a flag or mode and do not mix unrelated agent, UI, and dependency changes.
