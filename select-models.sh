#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_MODELS=6
MODELS_FILE="$SCRIPT_DIR/models.json"

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

# Show current models
if [[ -f "$MODELS_FILE" ]]; then
    echo "Current models:" >&2
    jq -r '.[]' "$MODELS_FILE" | sed 's/^/  /' >&2
    echo "" >&2
fi

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
    fzf --multi --no-sort \
        --prompt="Select models to ADD (TAB=select, ENTER=confirm, ESC=cancel): " \
        --header="Selected models will be merged with existing ones") || true

# Handle cancel/escape
if [[ -z "$SELECTED" ]]; then
    echo "No models selected, keeping existing." >&2
    exit 0
fi

# Merge with existing and dedupe
if [[ -f "$MODELS_FILE" ]]; then
    EXISTING=$(jq -r '.[]' "$MODELS_FILE")
    MERGED=$(printf '%s\n%s' "$EXISTING" "$SELECTED" | sort -u)
else
    MERGED="$SELECTED"
fi

COUNT=$(echo "$MERGED" | wc -l)
if [[ $COUNT -gt $MAX_MODELS ]]; then
    echo "Error: Total $COUNT models exceeds maximum of $MAX_MODELS" >&2
    exit 1
fi

# Write merged list
echo "$MERGED" | jq -R -s 'split("\n") | map(select(length > 0))' > "$MODELS_FILE"

echo "Saved $COUNT model(s) to models.json:" >&2
cat "$MODELS_FILE"
