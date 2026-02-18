#!/bin/bash
# invoke_other.sh - Invoke an AI model for debate
#
# Usage: ./invoke_other.sh --opponent <claude|codex> [--model <model>] [--reasoning <level>] "prompt text"
#
# Arguments:
#   --opponent   Which CLI to invoke: "claude" or "codex"
#   --model      Optional model override (e.g., "opus", "sonnet", "o3", "gpt-4.1")
#   --reasoning  Reasoning effort level for Codex: "low", "medium", "high" (default: from config)
#   prompt       The prompt text (last positional argument)
#
# Output file path is printed to stdout

set -e

# Parse arguments
OPPONENT=""
MODEL=""
REASONING=""
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
        --reasoning)
            REASONING="$2"
            shift 2
            ;;
        *)
            # Last argument is the prompt
            PROMPT="$1"
            shift
            ;;
    esac
done

# Use mktemp for output file to avoid race conditions
OUTPUT_FILE=$(mktemp /tmp/debate_response.XXXXXX)
TIMEOUT_SECONDS=120

# Cleanup function
cleanup() {
    rm -f "$PROMPT_FILE" 2>/dev/null || true
}
trap cleanup EXIT

# Validate opponent
if [ -z "$OPPONENT" ]; then
    echo "ERROR: --opponent is required (claude or codex)" >&2
    exit 1
fi

if [ "$OPPONENT" != "claude" ] && [ "$OPPONENT" != "codex" ]; then
    echo "ERROR: --opponent must be 'claude' or 'codex', got '$OPPONENT'" >&2
    exit 1
fi

# Validate model (alphanumeric, hyphens, underscores, dots only - prevent injection)
if [ -n "$MODEL" ]; then
    if ! [[ "$MODEL" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "ERROR: --model contains invalid characters: '$MODEL'" >&2
        exit 1
    fi
fi

# Validate reasoning (must be low, medium, or high)
if [ -n "$REASONING" ]; then
    if [ "$REASONING" != "low" ] && [ "$REASONING" != "medium" ] && [ "$REASONING" != "high" ]; then
        echo "ERROR: --reasoning must be 'low', 'medium', or 'high', got '$REASONING'" >&2
        exit 1
    fi
fi

# Check if CLI is available
if ! command -v "$OPPONENT" &> /dev/null; then
    echo "ERROR: $OPPONENT CLI not found. Please install it first." >&2
    echo "FALLBACK: $OPPONENT CLI not installed." > "$OUTPUT_FILE"
    exit 1
fi

echo "Invoking: $OPPONENT" >&2
if [ -n "$MODEL" ]; then
    echo "Model: $MODEL" >&2
fi
if [ -n "$REASONING" ]; then
    echo "Reasoning: $REASONING" >&2
fi

# Create a temporary file for the prompt
PROMPT_FILE=$(mktemp)
echo "$PROMPT" > "$PROMPT_FILE"

# Find timeout command (gtimeout on macOS via coreutils, timeout on Linux)
TIMEOUT_CMD=""
if command -v timeout &> /dev/null; then
    TIMEOUT_CMD="timeout"
elif command -v gtimeout &> /dev/null; then
    TIMEOUT_CMD="gtimeout"
fi

# Build command as array to avoid injection
run_codex() {
    local args=(exec --full-auto)

    if [ -n "$MODEL" ]; then
        args+=(-m "$MODEL")
    fi

    if [ -n "$REASONING" ]; then
        args+=(-c "model_reasoning_effort=$REASONING")
    fi

    args+=(-o "$OUTPUT_FILE")
    args+=("$(cat "$PROMPT_FILE")")

    if [ -n "$TIMEOUT_CMD" ]; then
        "$TIMEOUT_CMD" "$TIMEOUT_SECONDS" codex "${args[@]}" 2>&1
    else
        codex "${args[@]}" 2>&1
    fi
}

run_claude() {
    local args=(-p)

    if [ -n "$MODEL" ]; then
        args+=(--model "$MODEL")
    fi

    args+=("$(cat "$PROMPT_FILE")")

    if [ -n "$TIMEOUT_CMD" ]; then
        "$TIMEOUT_CMD" "$TIMEOUT_SECONDS" claude "${args[@]}" > "$OUTPUT_FILE" 2>&1
    else
        claude "${args[@]}" > "$OUTPUT_FILE" 2>&1
    fi
}

# Invoke the specified model
if [ "$OPPONENT" = "codex" ]; then
    run_codex || {
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ]; then
            echo "TIMEOUT: Did not respond within ${TIMEOUT_SECONDS}s" >> "$OUTPUT_FILE"
        else
            echo "ERROR: Codex invocation failed with exit code $EXIT_CODE" >> "$OUTPUT_FILE"
        fi
    }
else
    run_claude || {
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ]; then
            echo "TIMEOUT: Did not respond within ${TIMEOUT_SECONDS}s" >> "$OUTPUT_FILE"
        else
            echo "ERROR: Claude invocation failed with exit code $EXIT_CODE" >> "$OUTPUT_FILE"
        fi
    }
fi

# Check if we got a response
if [ ! -s "$OUTPUT_FILE" ]; then
    echo "WARNING: Empty response from $OPPONENT" > "$OUTPUT_FILE"
fi

echo "Response written to: $OUTPUT_FILE" >&2
echo "$OUTPUT_FILE"
