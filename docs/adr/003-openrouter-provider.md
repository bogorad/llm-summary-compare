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

### Judge Model Configuration
The judge uses `google/gemini-3-pro-preview` with specific OpenRouter API parameters:
- `provider.order: ["google-vertex"]` - Route to Google Vertex (google-ai-studio has aggressive rate limits)
- `provider.allow_fallbacks: false` - No fallback to other providers
- `reasoning.max_tokens: 16000` - Enable thinking/reasoning tokens for Gemini (note: Gemini uses `max_tokens`, not `effort`)

## Consequences
- Requires OpenRouter account and API key
- Model availability depends on OpenRouter's supported models
- Simplified credential management
- Judge evaluations use reasoning tokens (billed as output tokens)
