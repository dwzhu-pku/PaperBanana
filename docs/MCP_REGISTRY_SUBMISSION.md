# MCP Registry Submission Guide for PaperBanana

## Current Status

The MCP servers README repository (`modelcontextprotocol/servers`) is **no longer accepting PRs** to add
server links. All new servers must be published to the **MCP Registry** at
https://registry.modelcontextprotocol.io/ using the `mcp-publisher` CLI tool.

This document contains everything needed to publish PaperBanana to the official MCP Registry.

---

## Prerequisites

Before publishing, you need:

1. **PyPI package published** -- The MCP Registry only stores metadata; the actual package must be on PyPI.
   The existing `paperbanana` package by `llmsresearch` is version 0.1.2. You will need either:
   - Publishing rights to the existing `paperbanana` PyPI package, OR
   - A new package name (e.g., `paperbanana-storytelling` or `paperbanana-enhanced`)

2. **GitHub account** -- For authentication with the registry (your GitHub username: `stuinfla`)

3. **mcp-publisher CLI** -- Install it (see Step-by-Step below)

4. **Ownership verification string in README** -- PyPI packages require a hidden comment in the
   package README that the registry checks against

---

## server.json (The Registry Entry)

This is the file you will publish to the MCP Registry. Create this in your project root:

```json
{
  "$schema": "https://static.modelcontextprotocol.io/schemas/2025-12-11/server.schema.json",
  "name": "io.github.stuinfla/paperbanana",
  "title": "PaperBanana (Storytelling Pipeline)",
  "description": "Publication-quality academic diagrams and plots with visual metaphor discovery. Multi-agent pipeline (Retriever, Planner, Stylist, Visualizer, Critic) that finds real-world analogies before drawing, producing diagrams that communicate concepts in 5 seconds instead of 5 minutes. Enhanced fork of the PaperBanana framework by Peking University and Google Cloud AI Research. 93.5/100 avg quality vs 71.75 for standard approaches. Powered by Gemini 3 Pro models.",
  "repository": {
    "url": "https://github.com/stuinfla/paperbanana",
    "source": "github"
  },
  "version": "1.0.0",
  "packages": [
    {
      "registryType": "pypi",
      "identifier": "paperbanana",
      "version": "1.0.0",
      "transport": {
        "type": "stdio"
      },
      "environmentVariables": [
        {
          "description": "Google Gemini API key (free tier available at ai.google.dev)",
          "isRequired": true,
          "format": "string",
          "isSecret": true,
          "name": "GEMINI_API_KEY"
        }
      ]
    }
  ]
}
```

**Important:** Update `"identifier"` to match the actual PyPI package name you publish under.
If using the existing `paperbanana` package, you need publish rights from `llmsresearch`.
If creating a new package, update the identifier accordingly.

---

## PyPI README Verification String

The MCP Registry verifies PyPI package ownership by checking for a specific string in the
package README (which becomes the description on PyPI). Add this HTML comment anywhere in your
package's README.md:

```markdown
<!-- mcp-name: io.github.stuinfla/paperbanana -->
```

This string **must** match the `"name"` field in `server.json` exactly.

---

## Step-by-Step Submission Instructions

### 1. Install mcp-publisher

```bash
curl -L "https://github.com/modelcontextprotocol/registry/releases/latest/download/mcp-publisher_darwin_arm64.tar.gz" | tar xz mcp-publisher && sudo mv mcp-publisher /usr/local/bin/
```

Or via Homebrew:

```bash
brew install mcp-publisher
```

Verify installation:

```bash
mcp-publisher --help
```

### 2. Prepare the PyPI package

Make sure the PyPI package is published and includes the verification comment in its README:

```markdown
<!-- mcp-name: io.github.stuinfla/paperbanana -->
```

If the existing `paperbanana` pip package (by llmsresearch) is not under your control, you have
two options:

- **Option A:** Contact the llmsresearch maintainers and collaborate to publish the enhanced
  version under the existing package name. Add the mcp-name comment to their README.

- **Option B:** Publish under a new name (e.g., `paperbanana-storytelling`) and update the
  `identifier` in server.json to match.

### 3. Create server.json in your project root

Copy the server.json from the section above into your project root directory. Adjust the
version numbers to match whatever you publish to PyPI.

### 4. Authenticate with the MCP Registry

```bash
mcp-publisher login github
```

This opens a browser flow. Log in as your GitHub user (`stuinfla`). The server name
`io.github.stuinfla/paperbanana` requires authentication as the `stuinfla` GitHub user.

### 5. Publish

From the directory containing `server.json`:

```bash
mcp-publisher publish
```

Expected output:

```
Publishing to https://registry.modelcontextprotocol.io...
Successfully published
Server io.github.stuinfla/paperbanana version 1.0.0
```

### 6. Verify

```bash
curl "https://registry.modelcontextprotocol.io/v0.1/servers?search=io.github.stuinfla/paperbanana"
```

You should see your server metadata in the JSON response. It will also appear at
https://registry.modelcontextprotocol.io/ in the search results.

---

## What the Listing Highlights

| Field | Value |
|-------|-------|
| **Name** | PaperBanana (Storytelling Pipeline) |
| **Registry ID** | `io.github.stuinfla/paperbanana` |
| **Description** | Publication-quality academic diagrams with visual metaphor discovery. Multi-agent pipeline that finds real-world analogies before drawing. |
| **Category** | AI/ML Tools, Visualization |
| **Key differentiator** | Visual storytelling -- finds real-world metaphors before drawing, making diagrams that communicate concepts in 5 seconds instead of 5 minutes |
| **Quality score** | 93.5/100 avg vs 71.75 for standard approaches |
| **Tools** | `generate_diagram`, `generate_plot`, `about`, `setup_guide` |
| **Models** | Gemini 3 Pro Preview (reasoning) + Gemini 3 Pro Image Preview (image gen) |
| **Requirements** | Python 3.10+, Google Gemini API key (free tier available) |
| **Origin** | Enhanced fork of PaperBanana by Peking University + Google Cloud AI Research |
| **Package type** | PyPI |
| **Transport** | stdio |

---

## Key Differences from the Old README-Based Approach

The old approach (PRs to `modelcontextprotocol/servers` README) is **permanently closed**.
The new approach via the MCP Registry:

- No PR review process -- you publish directly using the CLI tool
- Metadata-only registry -- the actual package lives on PyPI/npm/etc.
- Ownership verified cryptographically (GitHub OAuth + PyPI README check)
- Appears in the searchable registry at registry.modelcontextprotocol.io
- Version updates are published the same way (bump version in server.json, re-publish)

---

## Checklist Before Publishing

- [ ] PyPI package is published and installable (`pip install paperbanana`)
- [ ] PyPI package README contains `<!-- mcp-name: io.github.stuinfla/paperbanana -->`
- [ ] MCP server actually works via stdio transport (`python -m paperbanana.mcp_server`)
- [ ] `server.json` is in the project root with correct version numbers
- [ ] `mcp-publisher` CLI is installed
- [ ] Authenticated via `mcp-publisher login github` as `stuinfla`
- [ ] All 4 tools work: `generate_diagram`, `generate_plot`, `about`, `setup_guide`
- [ ] GEMINI_API_KEY environment variable is documented
- [ ] Version numbers match between server.json and PyPI package
