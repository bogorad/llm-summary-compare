# ADR 007: Dynamic Model Selection via OpenRouter API

## Status
Accepted

## Context
Hardcoding model names requires manual updates when adding new models. OpenRouter provides an API to list all available models dynamically.

## Decision
Create `select-models.sh` that:
1. Shows current models from `models.json`
2. Resolves API key from SOPS-nix secret file (`/run/secrets/api_keys/openrouter`) or environment variable (`OPENROUTER_API_KEY`)
3. Fetches available models from OpenRouter's `/api/v1/models` endpoint
4. Presents all models in `fzf` with `--no-sort` to maintain alphabetical order
5. Merges selected models with existing ones (deduplicated)
6. Validates total count does not exceed 8
7. ESC/cancel exits without modifying `models.json`

## Consequences
- No hardcoded model lists to maintain
- Users can select any model available on OpenRouter
- Additive selection model - easy to add models incrementally
- Cancel-safe - no changes on ESC
- Requires `fzf`, `jq`, and `curl` as dependencies
- Maximum of 8 models enforced to keep comparisons manageable
