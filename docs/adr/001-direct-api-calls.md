# ADR 001: Direct OpenRouter API Calls

## Status
Accepted

## Context
We need to compare summarization quality across multiple AI models on the same text fragment. The system must run each model with identical prompts, capture outputs, and compare results objectively.

Using direct API calls avoids niche dependencies and simplifies distribution.

## Decision
Use direct curl calls to the OpenRouter API because:
- Zero niche dependencies (only standard tools: bash, curl, jq)
- Unified approach (same pattern as model selection)
- Transparent prompts (visible in plain text files)
- Better debugging (raw HTTP access via curl -v)

## Consequences
- Requires only OpenRouter API key (no additional tool installation)
- Prompts stored in `prompts/` directory as plain text
- JSON payload construction handled by jq
- Easy extension to additional models via `models.json`
