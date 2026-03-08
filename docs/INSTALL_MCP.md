# Install PaperBanana as an MCP Server

## Add to Claude Code
Add this to your project's `.mcp.json`:

```json
{
  "mcpServers": {
    "paperbanana": {
      "command": "python3",
      "args": ["-m", "mcp_server.server"],
      "cwd": "/path/to/paperbanana",
      "env": {
        "GOOGLE_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

Replace `/path/to/paperbanana` with where you cloned the repo and `your-api-key-here` with your Gemini API key.

## Available Tools
- `generate_diagram` -- Create a publication-quality diagram from text
- `generate_plot` -- Create a statistical plot from JSON data
- `about` -- Learn what PaperBanana does
- `setup_guide` -- Get setup help

## Get an API Key
Free at https://aistudio.google.com/apikey
