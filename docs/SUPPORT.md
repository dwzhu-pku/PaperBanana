# PaperBanana Support FAQ

This page collects the durable support answers for artifact links, demo access, provider choice, quota errors, third-party relays, local LLMs, and API-key hygiene.

## Hugging Face Artifacts And Demo

The public PaperBanana artifacts are:

- Paper page: https://huggingface.co/papers/2601.23265
- PaperBananaBench dataset: https://huggingface.co/datasets/dwzhu/PaperBananaBench
- Original PDF dataset: https://huggingface.co/datasets/dwzhu/PaperBananaDiagramPDFs
- Hosted demo Space: https://huggingface.co/spaces/dwzhu/PaperBanana

Maintainer clarification: PaperBanana is an orchestration framework around provider-hosted models plus the PaperBananaBench dataset. There is no separate PaperBanana model checkpoint required to run the released code or demo. Use the dataset, the Space, and the paper page above as the canonical public artifacts.

## Demo Availability

The hosted web demo is available on Hugging Face Spaces at https://huggingface.co/spaces/dwzhu/PaperBanana. The local Gradio app can be launched with:

```bash
python app.py
```

The Streamlit demo can be launched with:

```bash
streamlit run demo.py
```

The hosted Space and local apps still require a working provider route for generation. Configure OpenRouter or Google Gemini for the full diagram generation flow.

## Provider And Model Choice

PaperBanana separates text or vision-language reasoning from image generation:

- `defaults.main_model_name` is the text or vision-language route used by planner, stylist, and critic calls.
- `defaults.image_gen_model_name` is the image-generation route used by visualizer and polish calls.

Recommended full-flow setups:

- OpenRouter for unified hosted routing, using model names such as `openrouter/google/gemini-3.1-pro-preview` for text or vision-language calls and an image-capable model for image generation.
- Google Gemini direct API, using Gemini text and image generation models.
- OpenAI direct API for supported text routes and OpenAI image models where the code path explicitly calls OpenAI image generation.

Local OpenAI-compatible endpoints, including Ollama, are supported only for text-route calls through `local/<model>` or `ollama/<model>`. They are not a full image-generation backend. Keep `defaults.image_gen_model_name` pointed at a supported hosted image model if you need diagram rendering.

## Local OpenAI-Compatible Text Route

Use this route when a local or relay endpoint implements the OpenAI Chat Completions API.

Example `configs/model_config.yaml`:

```yaml
defaults:
  main_model_name: "local/qwen2.5:14b"
  image_gen_model_name: "gemini-3.1-flash-image-preview"

local_openai:
  base_url: "http://localhost:11434/v1"
  api_key: "ollama"
```

Equivalent environment variables:

```bash
export MAIN_MODEL_NAME="local/qwen2.5:14b"
export LOCAL_OPENAI_BASE_URL="http://localhost:11434/v1"
export LOCAL_OPENAI_API_KEY="ollama"
```

For Ollama specifically, `ollama/<model>` also works. If `LOCAL_OPENAI_BASE_URL` is not set, the `ollama/<model>` prefix defaults to `http://localhost:11434/v1`.

Example:

```bash
export MAIN_MODEL_NAME="ollama/llama3.1:8b"
```

This is text-route support. If the selected local model cannot interpret images, critic or multimodal planner steps that include image inputs may fail or produce weak responses. Local LLM support does not replace Gemini, OpenRouter, or other image-capable providers for actual image generation.

## Provider Quota, Billing, And Suspension

Quota and billing errors are returned by the upstream provider, not by PaperBanana. Common examples include:

- "You exceeded your current quota, please check your plan and billing details."
- Project suspension or Terms of Service enforcement messages from a cloud provider.
- Rate-limit or concurrency errors when generating many candidates in parallel.

Recommended response:

1. Check the provider console for billing status, quota limits, and suspension notices.
2. Reduce the number of parallel candidates or retries while testing.
3. Rotate to a different valid provider key only if your account policy permits it.
4. Contact the provider's support team for suspension appeals or billing corrections.

PaperBanana cannot override provider quota, billing, compliance, or account suspension decisions.

## Third-Party Relay And Base URL Caveats

Third-party relay keys are not interchangeable with official provider keys. If a relay advertises an OpenAI-compatible API, configure its base URL through `local_openai.base_url` or `LOCAL_OPENAI_BASE_URL` and route text calls with `local/<model>`.

Do not put a relay key into `google_api_key` unless the relay is actually compatible with the Google Gemini SDK endpoint used by this repository. A key that starts with `sk-` is usually not a Google API key.

Relay caveats:

- The relay must implement the specific endpoint used by the route. For `local/<model>`, this means OpenAI Chat Completions compatibility.
- Image generation compatibility is separate from text compatibility.
- Model names are relay-specific. Use the exact model id documented by the relay.
- The relay may add its own rate limits, logging, safety filters, billing rules, or availability limits.

## API-Key Rotation

Rotate an API key when it was pasted into an issue, chat, screenshot, notebook, shell history, or public file. Rotation means revoking the exposed key in the provider console and creating a new key.

Local setup guidance:

- Keep private keys in `configs/model_config.yaml`, environment variables, or a secrets manager.
- Do not commit `configs/model_config.yaml`.
- Do not paste live keys into GitHub issues or support threads.
- After rotation, restart the local app or server process so clients are
  reinitialized. Hosted users should not paste keys into the shared UI; the
  server operator must rotate and restart the hosted process.

## Troubleshooting Checklist

- Artifact or demo question: use the Hugging Face paper, dataset, PDF dataset, and Space links above.
- Need a checkpoint: no separate PaperBanana model checkpoint is required.
- Quota exceeded: resolve billing or quota in the provider console.
- Project suspended: contact the provider; PaperBanana cannot unsuspend provider projects.
- Relay key does not work: verify the base URL, route prefix, endpoint compatibility, and model id.
- Want Ollama: use `ollama/<model>` or `local/<model>` for text calls only, and keep an image-capable backend for `image_gen_model_name`.
