# Prompt Engineering Models

A Claude skill that teaches effective prompt engineering across Claude's model family — covering techniques, agentic patterns, API configuration, and per-model guidance for Opus 4.6, Sonnet 4.6, and Haiku 4.5.

## Installation

**Claude.ai / desktop apps:** Upload the `.skill` file via **Settings → Features → Skills**.

**Claude Code:** Place the skill directory in `~/.claude/skills/`:
```bash
cp -r . ~/.claude/skills/prompt-engineering-models
```

## Building

Run `build.sh` from inside the `main/` directory to produce the `.skill` archive:

```bash
cd main
./build.sh
# Output: ../prompt-engineering-models.skill

# Custom output path:
./build.sh --output /path/to/output.skill
```

The script packages `SKILL.md` and the `references/` directory into a zip archive with `SKILL.md` at the archive root.

GitHub releases automatically produce the `.skill` file via the included Actions workflow.

## License

MIT — see [LICENSE](LICENSE).
