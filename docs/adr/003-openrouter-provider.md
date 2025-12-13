# ADR 003: OpenRouter as Single Provider

## Status
Accepted

## Context
The comparison uses models from multiple providers (Google, xAI, OpenAI). Managing separate API keys and provider configurations adds complexity.

## Decision
Route all model requests through OpenRouter using model IDs in the format `provider/model-name` (e.g., `google/gemini-3-pro-preview`). This provides:
- Single API key management
- Unified billing
- Consistent API interface across providers

## Consequences
- Requires OpenRouter account and API key
- Model availability depends on OpenRouter's supported models
- Simplified credential management
