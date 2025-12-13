# ADR 007: Dynamic Model Selection via OpenRouter API

## Status
Accepted

## Context
Hardcoding model names requires manual updates when adding new models. OpenRouter provides an API to list all available models dynamically.

## Decision
Create `select-models.sh` that:
1. Resolves API key from Docker secret (`/run/secrets/api_keys/openrouter`) or environment variable (`OPENROUTER_API_KEY`)
2. Fetches available models from OpenRouter's `/api/v1/models` endpoint
3. Presents all models in `fzf` for interactive multi-select
4. Writes selected models (up to 6) to `models.json`

## Consequences
- No hardcoded model lists to maintain
- Users can select any model available on OpenRouter
- Requires `fzf`, `jq`, and `curl` as dependencies
- Maximum of 6 models enforced to keep comparisons manageable
- API key must be configured before running
