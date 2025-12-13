# Summarization Model Comparison

A portable bash tool to compare summarization capabilities of different AI models via the OpenRouter API.

See [docs/adr/](docs/adr/) for architecture decisions.

## Files

| File | Description |
|------|-------------|
| `models.json` | List of OpenRouter model IDs to test (1-6 models) |
| `fragment.txt` | Input text to summarize |
| `prompts/summarizer.md` | System prompt for summarization task |
| `prompts/judge.md` | System prompt for evaluation task |
| `select-models.sh` | Interactive model selector using OpenRouter API + fzf |
| `summarize_all.sh` | Main script that orchestrates the comparison |
| `flake.nix` | Nix devshell with all dependencies |

## Setup

### With Nix (recommended)
```bash
nix develop
```

### Manual
1. Configure OpenRouter API key via one of:
   - Docker secret: `/run/secrets/api_keys/openrouter`
   - Environment variable: `OPENROUTER_API_KEY`
2. Install dependencies: `jq`, `curl`, `fzf`, `bc`

## Usage

### Select Models
```bash
./select-models.sh
```
- Shows current models in `models.json`
- Fetches all available models from OpenRouter
- Select with fzf (TAB to select, ENTER to confirm, ESC to cancel)
- New selections are merged with existing models (deduplicated)

### Run Comparison
```bash
./summarize_all.sh
```

This will:
- Generate summaries using each model in parallel (direct API calls)
- Anonymize results with random IDs (A-F depending on model count)
- Compare using Gemini 3 Pro judge and determine winner
- Report per-model timing

## Output

| Path | Description |
|------|-------------|
| `work/*_summary.md` | Individual model summaries |
| `work/results.xml` | XML results with CDATA-escaped content |
| `RESULT.md` | Human-readable markdown report |

The comparison uses Gemini 3 Pro (`google/gemini-3-pro-preview`) to evaluate summaries based on accuracy, completeness, objectivity, and format adherence.