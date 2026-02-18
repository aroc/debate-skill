#!/bin/bash
# invoke_other.sh - Invoke an AI model for debate
#
# Usage: ./invoke_other.sh --opponent <claude|codex> [--model <model>] "prompt text"
#
# Arguments:
#   --opponent  Which CLI to invoke: "claude" or "codex"
#   --model     Optional model override (e.g., "opus", "sonnet", "o3", "gpt-4.1")
#   prompt      The prompt text (last positional argument)
#
# Output is written to /tmp/debate_response.txt

set -e

# Parse arguments
OPPONENT=""
MODEL=""
PROMPT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --opponent)
            OPPONENT="$2"
            shift 2
            ;;
        --model)
            MODEL="$2"
            shift 2
            ;;
        *)
            # Last argument is the prompt
            PROMPT="$1"
            shift
            ;;
    esac
done

OUTPUT_FILE="/tmp/debate_response.txt"
TIMEOUT_SECONDS=120

# Validate opponent
if [ -z "$OPPONENT" ]; then
    echo "ERROR: --opponent is required (claude or codex)" >&2
    exit 1
fi

if [ "$OPPONENT" != "claude" ] && [ "$OPPONENT" != "codex" ]; then
    echo "ERROR: --opponent must be 'claude' or 'codex', got '$OPPONENT'" >&2
    exit 1
fi

# Check if CLI is available
if ! command -v "$OPPONENT" &> /dev/null; then
    echo "ERROR: $OPPONENT CLI not found. Please install it first." >&2
    echo "FALLBACK: $OPPONENT CLI not installed." > "$OUTPUT_FILE"
    exit 1
fi

# Clean up any previous response
rm -f "$OUTPUT_FILE"

echo "Invoking: $OPPONENT" >&2
if [ -n "$MODEL" ]; then
    echo "Model: $MODEL" >&2
fi

# Create a temporary file for the prompt
PROMPT_FILE=$(mktemp)
echo "$PROMPT" > "$PROMPT_FILE"

# Helper function to run with optional timeout
run_with_timeout() {
    local cmd="$1"
    if command -v gtimeout &> /dev/null; then
        gtimeout "$TIMEOUT_SECONDS" bash -c "$cmd" || {
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 124 ]; then
                echo "TIMEOUT: Did not respond within ${TIMEOUT_SECONDS}s" >> "$OUTPUT_FILE"
            fi
            return $EXIT_CODE
        }
    else
        bash -c "$cmd"
    fi
}

# Invoke the specified model
if [ "$OPPONENT" = "codex" ]; then
    # Codex invocation - using exec for non-interactive mode
    # --full-auto approves all actions automatically
    # -o writes last message to file
    # -m specifies model
    MODEL_ARG=""
    if [ -n "$MODEL" ]; then
        MODEL_ARG="-m $MODEL"
    fi

    run_with_timeout "codex exec --full-auto $MODEL_ARG -o \"$OUTPUT_FILE\" \"\$(cat \"$PROMPT_FILE\")\"" 2>&1 || {
        EXIT_CODE=$?
        echo "ERROR: Codex invocation failed with exit code $EXIT_CODE" >> "$OUTPUT_FILE"
    }
else
    # Claude invocation - using -p for print mode (non-interactive)
    # --model specifies model
    MODEL_ARG=""
    if [ -n "$MODEL" ]; then
        MODEL_ARG="--model $MODEL"
    fi

    run_with_timeout "claude -p $MODEL_ARG \"\$(cat \"$PROMPT_FILE\")\"" > "$OUTPUT_FILE" 2>&1 || {
        EXIT_CODE=$?
        echo "ERROR: Claude invocation failed with exit code $EXIT_CODE" >> "$OUTPUT_FILE"
    }
fi

# Clean up
rm -f "$PROMPT_FILE"

# Check if we got a response
if [ ! -s "$OUTPUT_FILE" ]; then
    echo "WARNING: Empty response from $OPPONENT" > "$OUTPUT_FILE"
fi

echo "Response written to: $OUTPUT_FILE" >&2
echo "$OUTPUT_FILE"
