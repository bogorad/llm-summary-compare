#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

MAX_MODELS=6
ALL_IDS=("A" "B" "C" "D" "E" "F")

# Dependency check
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required. Install with: apt install jq / brew install jq" >&2
    exit 1
fi

# Read fragment
FRAGMENT=$(cat fragment.txt)

# Read models (full OpenRouter model IDs)
mapfile -t MODELS < <(jq -r '.[]' models.json)
MODEL_COUNT=${#MODELS[@]}

if [[ $MODEL_COUNT -eq 0 ]]; then
    echo "Error: No models in models.json. Run ./select-models.sh first." >&2
    exit 1
fi
if [[ $MODEL_COUNT -gt $MAX_MODELS ]]; then
    echo "Error: Too many models ($MODEL_COUNT), maximum is $MAX_MODELS" >&2
    exit 1
fi

# Generate IDs for this run
IDS=("${ALL_IDS[@]:0:$MODEL_COUNT}")

# Helper: sanitize model ID for filename (google/gemini-pro -> google_gemini-pro)
sanitize_filename() {
    echo "$1" | tr '/' '_'
}

# Run summarizations in parallel
echo "Running $MODEL_COUNT model(s) in parallel..."
PIDS=()
for MODEL in "${MODELS[@]}"; do
    SAFE_NAME=$(sanitize_filename "$MODEL")
    opencode run --agent summarizer --model "openrouter/$MODEL" "$FRAGMENT" > "${SAFE_NAME}_summary.md" &
    PIDS+=($!)
done

# Wait and check for failures
FAILED=0
for PID in "${PIDS[@]}"; do
    if ! wait "$PID"; then
        FAILED=1
    fi
done
if [[ $FAILED -eq 1 ]]; then
    echo "Error: One or more summarization tasks failed" >&2
    exit 1
fi

# Anonymize - shuffle models and assign IDs
mapfile -t RANDOM_MODELS < <(printf '%s\n' "${MODELS[@]}" | shuf)
declare -A ID_TO_MODEL
for i in "${!RANDOM_MODELS[@]}"; do
    ID=${IDS[$i]}
    ID_TO_MODEL[$ID]=${RANDOM_MODELS[$i]}
done

# Create results.xml
echo "<results>" > results.xml
echo "<input><![CDATA[$FRAGMENT]]></input>" >> results.xml
echo "<summaries>" >> results.xml
for ID in "${IDS[@]}"; do
    MODEL=${ID_TO_MODEL[$ID]}
    SAFE_NAME=$(sanitize_filename "$MODEL")
    SUMMARY=$(cat "${SAFE_NAME}_summary.md")
    echo "<summary id=\"$ID\"><![CDATA[$SUMMARY]]></summary>" >> results.xml
done
echo "</summaries>" >> results.xml

# Build comparison prompt with all summaries
SUMMARIES=""
ID_LIST=""
for ID in "${IDS[@]}"; do
    MODEL=${ID_TO_MODEL[$ID]}
    SAFE_NAME=$(sanitize_filename "$MODEL")
    SUMMARY=$(cat "${SAFE_NAME}_summary.md")
    SUMMARIES="${SUMMARIES}Summary $ID:
$SUMMARY

"
    ID_LIST="${ID_LIST}${ID}, "
done
ID_LIST=${ID_LIST%, }  # Remove trailing comma

# Use Gemini as judge (via OpenRouter)
JUDGE_MODEL="openrouter/google/gemini-2.0-flash-001"

COMPARISON_PROMPT="You are evaluating summarization quality. Compare these $MODEL_COUNT summaries of the same source text.

Criteria:
- Accuracy (factual correctness vs source)
- Completeness (coverage of key points)
- Objectivity (no editorializing)
- Format adherence (HTML ul/li, bold tags)

Source text:
$FRAGMENT

$SUMMARIES
State which summary ($ID_LIST) is best and explain why. End your response with exactly one line: WINNER: X (where X is one of $ID_LIST)"

WINNER_OUTPUT=$(opencode run --model "$JUDGE_MODEL" "$COMPARISON_PROMPT")

# Extract winner ID
WINNER_ID=$(echo "$WINNER_OUTPUT" | grep -oE "WINNER: [A-${IDS[-1]}]" | tail -1 | cut -d' ' -f2)
if [[ -z "$WINNER_ID" ]]; then
    echo "Warning: Could not determine winner from judge output" >&2
    WINNER_ID="?"
    WINNER_MODEL="unknown"
else
    WINNER_MODEL=${ID_TO_MODEL[$WINNER_ID]}
fi

# Append winner and model mapping
echo "<winner id=\"$WINNER_ID\" model=\"$WINNER_MODEL\"><![CDATA[$WINNER_OUTPUT]]></winner>" >> results.xml
echo "<model_mapping>" >> results.xml
for ID in "${IDS[@]}"; do
    echo "  <map id=\"$ID\" model=\"${ID_TO_MODEL[$ID]}\"/>" >> results.xml
done
echo "</model_mapping>" >> results.xml
echo "</results>" >> results.xml

echo "Results written to results.xml"
echo "Winner: $WINNER_ID ($WINNER_MODEL)"