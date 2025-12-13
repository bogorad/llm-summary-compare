# ADR 002: Shared Prompts with Runtime Model Selection

## Status
Accepted

## Context
Each model comparison uses identical prompts - only the model varies. We need a clean way to manage prompts separately from the execution logic.

## Decision
Store prompts as markdown files in the `prompts/` directory:
- `prompts/summarizer.md` - System prompt for summarization task
- `prompts/judge.md` - System prompt for evaluation task

Markdown format allows for easy reading and editing with proper formatting (headers, lists, tables).

The script reads these at runtime and passes them to the OpenRouter API along with the model ID from `models.json`.

## Consequences
- Single point of maintenance for prompt instructions
- Easy to edit prompts without touching bash code
- Markdown formatting improves readability
- Model list managed in `models.json` with full OpenRouter IDs
- Adding new models requires only updating `models.json` (no code changes)
