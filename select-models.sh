#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_MODELS=6

# Dependency checks
for cmd in curl jq fzf; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd is required. Install with:" >&2
        case "$cmd" in
            curl) echo "  apt install curl / brew install curl" >&2 ;;
            jq)   echo "  apt install jq / brew install jq" >&2 ;;
            fzf)  echo "  apt install fzf / brew install fzf" >&2 ;;
        esac
        exit 1
    fi
done

# API key resolution
if [[ -f /run/secrets/api_keys/openrouter ]]; then
    OPENROUTER_API_KEY=$(cat /run/secrets/api_keys/openrouter)
elif [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
    echo "Error: OpenRouter API key not found." >&2
    echo "Set OPENROUTER_API_KEY or create /run/secrets/api_keys/openrouter" >&2
    exit 1
fi

# Fetch models from OpenRouter
echo "Fetching models from OpenRouter..." >&2
MODELS_JSON=$(curl -s -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    "https://openrouter.ai/api/v1/models")

# Check for API error
if echo "$MODELS_JSON" | jq -e '.error' &>/dev/null; then
    echo "Error from OpenRouter API:" >&2
    echo "$MODELS_JSON" | jq -r '.error.message // .error' >&2
    exit 1
fi

# Extract model IDs and present in fzf
SELECTED=$(echo "$MODELS_JSON" | jq -r '.data[].id' | sort | \
    fzf --multi --prompt="Select up to $MAX_MODELS models (TAB to select, ENTER to confirm): " \
        --header="Use TAB to select multiple models, ENTER when done")

# Validate selection
if [[ -z "$SELECTED" ]]; then
    echo "No models selected." >&2
    exit 1
fi

COUNT=$(echo "$SELECTED" | wc -l)
if [[ $COUNT -gt $MAX_MODELS ]]; then
    echo "Error: Selected $COUNT models, maximum is $MAX_MODELS" >&2
    exit 1
fi

# Write to models.json
echo "$SELECTED" | jq -R -s 'split("\n") | map(select(length > 0))' > "$SCRIPT_DIR/models.json"

echo "Saved $COUNT model(s) to models.json:" >&2
cat "$SCRIPT_DIR/models.json"
