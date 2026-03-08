# Install PaperBanana as a Claude Code Skill

## One-Line Install
```bash
mkdir -p ~/.claude/skills/paperbanana && cp docs/SKILL.md ~/.claude/skills/paperbanana/SKILL.md
```

Now type `/paperbanana` in Claude Code to generate diagrams.

## What This Does
The skill teaches Claude Code how to use PaperBanana's storytelling pipeline to generate publication-quality diagrams. When you type `/paperbanana`, Claude will:
1. Accept your description of a concept
2. Run the 5-agent pipeline (Retriever -> Planner -> Stylist -> Visualizer -> Critic)
3. Return a publication-quality diagram

## Requirements
- PaperBanana installed (see install.sh or README)
- A Google Gemini API key
