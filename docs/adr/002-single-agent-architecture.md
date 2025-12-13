# ADR 002: Single Agent with Model Override

## Status
Accepted

## Context
Initially, separate agent files were created for each model. This led to code duplication since all agents had identical prompts.

## Decision
Use a single `summarizer.md` agent and specify the model at runtime using OpenCode's `--model` flag:
```bash
opencode run --agent summarizer --model openrouter/google/gemini-2.0-flash-001 "$FRAGMENT"
```

Models are stored as full OpenRouter IDs in `models.json` (e.g., `google/gemini-2.0-flash-001`), prefixed with `openrouter/` at runtime.

## Consequences
- Eliminates prompt duplication across agent files
- Single point of maintenance for summarization instructions
- Model list managed in `models.json` with full OpenRouter IDs
- Adding new models requires only updating `models.json` (no code changes)
- Interactive model selection via `select-models.sh`
