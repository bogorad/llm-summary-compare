# Summarization Model Comparison

This project uses OpenCode to compare the summarization capabilities of different AI models on a provided text fragment.

See [docs/adr/](docs/adr/) for architecture decisions.

## Files

- `models.json`: List of OpenRouter model IDs to test (1-6 models)
- `fragment.txt`: Input text to summarize
- `select-models.sh`: Interactive model selector using OpenRouter API + fzf
- `summarize_all.sh`: Bash script that orchestrates the comparison
- `.opencode/agent/summarizer.md`: Single agent used with `--model` override
- `.opencode/command/`: Custom command to run the comparison
- `results.xml`: Output with anonymized summaries and winner analysis

## Setup

1. Install OpenCode: `curl -fsSL https://opencode.ai/install | bash`
2. Configure OpenRouter API key via one of:
   - Docker secret: `/run/secrets/api_keys/openrouter`
   - Environment variable: `OPENROUTER_API_KEY`
3. Install dependencies: `jq`, `curl`, `fzf`

## Usage

### Select Models
```bash
./select-models.sh
```
Fetches all available models from OpenRouter and lets you select up to 6 using fzf (TAB to select, ENTER to confirm).

### Run Comparison
```bash
opencode
/summarize-all
```
Or directly: `./summarize_all.sh`

This will:
- Generate summaries using each model in parallel
- Anonymize results with random IDs (A-F depending on model count)
- Compare them using Gemini and determine the best summarizer
- Save results to `results.xml`

## Output

- Individual summaries: `{provider}_{model}_summary.md`
- Combined results: `results.xml` with input, anonymized summaries, and winner

The comparison uses Gemini to evaluate which model produced the best summary based on accuracy, completeness, objectivity, and format adherence.