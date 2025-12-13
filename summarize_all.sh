#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

MAX_MODELS=6
ALL_IDS=("A" "B" "C" "D" "E" "F")
WORK_DIR="$SCRIPT_DIR/work"
TIMING_DIR=$(mktemp -d)
trap 'rm -rf "$TIMING_DIR"' EXIT

mkdir -p "$WORK_DIR"

OPENROUTER_API="https://openrouter.ai/api/v1/chat/completions"

# Dependency checks
for cmd in jq bc curl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd is required. Install with: apt install $cmd / brew install $cmd" >&2
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

# Read prompts
SUMMARIZER_PROMPT=$(cat prompts/summarizer.md)

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

# Helper: escape content for CDATA (split ]]> sequences)
escape_cdata() {
    sed 's/]]>/]]]]><![CDATA[>/g'
}

# Helper: call OpenRouter API
# Usage: call_openrouter MODEL SYSTEM_PROMPT USER_CONTENT
call_openrouter() {
    local model="$1"
    local system_prompt="$2"
    local user_content="$3"
    
    local payload
    payload=$(jq -n \
        --arg model "$model" \
        --arg sys "$system_prompt" \
        --arg user "$user_content" \
        '{
            model: $model,
            messages: [
                {role: "system", content: $sys},
                {role: "user", content: $user}
            ]
        }')
    
    local response
    response=$(curl -s -X POST "$OPENROUTER_API" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    # Check for API error
    if echo "$response" | jq -e '.error' &>/dev/null; then
        echo "API Error: $(echo "$response" | jq -r '.error.message // .error')" >&2
        return 1
    fi
    
    echo "$response" | jq -r '.choices[0].message.content'
}

# Run summarizations in parallel with timing
SCRIPT_START=$(date +%s)
echo "Running $MODEL_COUNT model(s) in parallel..."
PIDS=()
for MODEL in "${MODELS[@]}"; do
    SAFE_NAME=$(sanitize_filename "$MODEL")
    (
        START=$(date +%s.%N)
        call_openrouter "$MODEL" "$SUMMARIZER_PROMPT" "$FRAGMENT" > "$WORK_DIR/${SAFE_NAME}_summary.md"
        END=$(date +%s.%N)
        echo "$END - $START" | bc > "$TIMING_DIR/${SAFE_NAME}.time"
    ) &
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

# Create results.xml with proper CDATA escaping
echo "<results>" > "$WORK_DIR/results.xml"
echo -n "<input><![CDATA[" >> "$WORK_DIR/results.xml"
echo "$FRAGMENT" | escape_cdata >> "$WORK_DIR/results.xml"
echo "]]></input>" >> "$WORK_DIR/results.xml"
echo "<summaries>" >> "$WORK_DIR/results.xml"
for ID in "${IDS[@]}"; do
    MODEL=${ID_TO_MODEL[$ID]}
    SAFE_NAME=$(sanitize_filename "$MODEL")
    echo -n "<summary id=\"$ID\"><![CDATA[" >> "$WORK_DIR/results.xml"
    escape_cdata < "$WORK_DIR/${SAFE_NAME}_summary.md" >> "$WORK_DIR/results.xml"
    echo "]]></summary>" >> "$WORK_DIR/results.xml"
done
echo "</summaries>" >> "$WORK_DIR/results.xml"

# Build comparison prompt with all summaries
SUMMARIES=""
ID_LIST=""
for ID in "${IDS[@]}"; do
    MODEL=${ID_TO_MODEL[$ID]}
    SAFE_NAME=$(sanitize_filename "$MODEL")
    SUMMARY=$(cat "$WORK_DIR/${SAFE_NAME}_summary.md")
    SUMMARIES="${SUMMARIES}Summary $ID:
$SUMMARY

"
    ID_LIST="${ID_LIST}${ID}, "
done
ID_LIST=${ID_LIST%, }  # Remove trailing comma

# Read judge prompt and use Gemini as judge
JUDGE_PROMPT=$(cat prompts/judge.md)
JUDGE_MODEL="google/gemini-3-pro-preview"

JUDGE_USER_CONTENT="Source text:
$FRAGMENT

$SUMMARIES
Choose the best summary from: $ID_LIST"

echo "Running judge evaluation..."
# Judge call with provider routing and thinking enabled
# Note: google-ai-studio has aggressive rate limits; using google-vertex instead
JUDGE_PAYLOAD=$(jq -n \
    --arg model "$JUDGE_MODEL" \
    --arg sys "$JUDGE_PROMPT" \
    --arg user "$JUDGE_USER_CONTENT" \
    '{
        model: $model,
        messages: [
            {role: "system", content: $sys},
            {role: "user", content: $user}
        ],
        provider: {
            order: ["google-vertex"],
            allow_fallbacks: false
        },
        reasoning: {
            max_tokens: 16000
        }
    }')

JUDGE_RESPONSE=$(curl -s -X POST "$OPENROUTER_API" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$JUDGE_PAYLOAD")

if echo "$JUDGE_RESPONSE" | jq -e '.error' &>/dev/null; then
    echo "Judge API Error: $(echo "$JUDGE_RESPONSE" | jq -r '.error.message // .error')" >&2
    exit 1
fi

WINNER_OUTPUT=$(echo "$JUDGE_RESPONSE" | jq -r '.choices[0].message.content')

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
echo -n "<winner id=\"$WINNER_ID\" model=\"$WINNER_MODEL\"><![CDATA[" >> "$WORK_DIR/results.xml"
echo "$WINNER_OUTPUT" | escape_cdata >> "$WORK_DIR/results.xml"
echo "]]></winner>" >> "$WORK_DIR/results.xml"
echo "<model_mapping>" >> "$WORK_DIR/results.xml"
for ID in "${IDS[@]}"; do
    echo "  <map id=\"$ID\" model=\"${ID_TO_MODEL[$ID]}\"/>" >> "$WORK_DIR/results.xml"
done
echo "</model_mapping>" >> "$WORK_DIR/results.xml"
echo "</results>" >> "$WORK_DIR/results.xml"

SCRIPT_END=$(date +%s)
TOTAL_TIME=$((SCRIPT_END - SCRIPT_START))

# Generate RESULT.md
{
    echo "# Summarization Comparison Results"
    echo ""
    echo "## Winner: $WINNER_ID ($WINNER_MODEL)"
    echo ""
    echo "## Summaries"
    echo ""
    for ID in "${IDS[@]}"; do
        MODEL=${ID_TO_MODEL[$ID]}
        SAFE_NAME=$(sanitize_filename "$MODEL")
        echo "### Summary $ID: \`$MODEL\`"
        echo ""
        cat "$WORK_DIR/${SAFE_NAME}_summary.md"
        echo ""
    done
    echo "## Judge Evaluation"
    echo ""
    echo "$WINNER_OUTPUT"
    echo ""
    echo "## Timing"
    echo ""
    echo "| Model | Time |"
    echo "|-------|------|"
    for MODEL in "${MODELS[@]}"; do
        SAFE_NAME=$(sanitize_filename "$MODEL")
        if [[ -f "$TIMING_DIR/${SAFE_NAME}.time" ]]; then
            TIME=$(cat "$TIMING_DIR/${SAFE_NAME}.time")
            printf "| %s | %.1fs |\n" "$MODEL" "$TIME"
        fi
    done
    printf "| **Total (wall clock)** | **%ds** |\n" "$TOTAL_TIME"
} > RESULT.md

# Console output
echo ""
echo "=== Timing Report ==="
for MODEL in "${MODELS[@]}"; do
    SAFE_NAME=$(sanitize_filename "$MODEL")
    if [[ -f "$TIMING_DIR/${SAFE_NAME}.time" ]]; then
        TIME=$(cat "$TIMING_DIR/${SAFE_NAME}.time")
        printf "  %-40s %6.1fs\n" "$MODEL" "$TIME"
    fi
done
echo "  ----------------------------------------"
printf "  %-40s %6ds\n" "Total (wall clock)" "$TOTAL_TIME"
echo ""
echo "Results written to work/results.xml and RESULT.md"
echo "Winner: $WINNER_ID ($WINNER_MODEL)"