# WP-106 Real-Data Dry-Run Provenance Evidence

## Metadata

| Item | Value |
|---|---|
| Date | 2026-06-22 07:21 EDT |
| Branch | `integration/native-first-rc-native` |
| Source SHA | `b12d8cedf44f` |
| Product-code SHA | `1e77a8c43fc0` |
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Installed app | `/Applications/PaperBanana.app` |
| Benchmark checkout | `/Users/jeff/Codex_projects/PaperBanana` |
| Run folder | `/Users/jeff/Codex_projects/PaperBanana/results/native_generate/native_generate_20260622_072111` |

## Procedure

1. Installed the current Release app with:

   ```bash
   DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/build_and_run.sh --release --install
   ```

2. Seeded the app with:

   - `settings.repoPath=/Users/jeff/Codex_projects/PaperBanana`
   - `paperbanana.intent.destination=promptStudio`
   - synthetic non-sensitive prompt: `Create a dry-run scientific diagram showing the PaperBananaBench manual reference provenance flow.`

3. Launched `/Applications/PaperBanana.app`.
4. Used Accessibility automation to press:

   - `Reference example ref_1`
   - `No-spend dry run`
   - `Dry Run`
   - preflight `Start`

5. Inspected generated artifacts without copying benchmark images or provider payloads into this repository.
6. Deleted the transient intent defaults and quit the app.

## Observed Artifacts

The native dry run created:

```text
/Users/jeff/Codex_projects/PaperBanana/results/native_generate/native_generate_20260622_072111/events.jsonl
/Users/jeff/Codex_projects/PaperBanana/results/native_generate/native_generate_20260622_072111/generated_2K.json
/Users/jeff/Codex_projects/PaperBanana/results/native_generate/native_generate_20260622_072111/generated_2K.png
/Users/jeff/Codex_projects/PaperBanana/results/native_generate/native_generate_20260622_072111/generated_2K.provider_raw.bin
/Users/jeff/Codex_projects/PaperBanana/results/native_generate/native_generate_20260622_072111/generated_2K.provider_response.json
/Users/jeff/Codex_projects/PaperBanana/results/native_generate/native_generate_20260622_072111/prompt.txt
/Users/jeff/Codex_projects/PaperBanana/results/native_generate/native_generate_20260622_072111/provider_request.json
/Users/jeff/Codex_projects/PaperBanana/results/native_generate/native_generate_20260622_072111/request.json
```

Additional provider audit artifacts were created under the benchmark checkout:

```text
/Users/jeff/Codex_projects/PaperBanana/results/provider_audit/images/swift-codex-B274583D-96C5-4A89-844F-C9395FCA0F05_20260622_072112.png
/Users/jeff/Codex_projects/PaperBanana/results/provider_audit/provider_calls_20260622.jsonl
```

## Provenance Checks

| Artifact | Observed fields |
|---|---|
| `request.json` | `task=scientific diagram`, `model=__codex_gpt55_xhigh__`, `resolution=2K`, `aspect_ratio=16:9`, `reference_mode=manual_native_prompt_enrichment`, `reference_examples` count `1`, selected id `ref_1`, `image_path=images/$epsilon$-Seg Sparsely Supervised Semantic Segmentation of  Microscopy Data_diagram.jpg` |
| `generated_2K.json` | Same selected-reference record persisted in generated metadata with selected id `ref_1` and the same local image path. |
| `provider_request.json` | `adapter=swift_local`, `mode=dry_run`, `provider_spend=none`, `task=scientific diagram`, `model=__codex_gpt55_xhigh__`, `resolution=2K`, `aspect_ratio=16:9` |
| `generated_2K.provider_response.json` | `adapter=swift_local`, `mode=dry_run`, `provider_spend=none`, `run_id=native_generate_20260622_072111` |
| `events.jsonl` | Terminal event message: `Completed local dry run without provider spend.` |

## Secret Scan

A targeted scan over `request.json`, `generated_2K.json`, and `provider_request.json` found no `AIza`, `sk-`, `OPENROUTER_API_KEY`, or `GOOGLE_API_KEY` strings.

## Interpretation

This validates the native no-spend path for real local PaperBananaBench diagram data: a manually selected benchmark reference is carried into `request.json`, generated metadata, and provider request/response artifacts while the provider path stays local dry-run/no-spend. It also confirms the current preflight path can be exercised through the installed native app, not only through store-level tests.

## Remaining Limitations

- This validation selected one reference (`ref_1`); it did not validate search/filter or the 10-of-10 selection cap against the real dataset.
- It did not perform an approved live provider/fallback generation.
- It did not copy or preserve benchmark images into run folders, matching the v1 design.
- Provider audit JSONL schema was observed, but only run/file-level provenance and no-spend status were evaluated here.
