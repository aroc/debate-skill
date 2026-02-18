#!/bin/bash
# invoke_other.sh - Invoke the opposing AI model for debate
#
# Usage: ./invoke_other.sh "prompt text"
#
# Detects which model is currently running and invokes the other.
# Output is written to /tmp/debate_response.txt

set -e

PROMPT="$1"
OUTPUT_FILE="/tmp/debate_response.txt"
TIMEOUT_SECONDS=120

# Clean up any previous response
rm -f "$OUTPUT_FILE"

# Detect current model and set opposing CLI
# Claude sets CLAUDE_SESSION_ID, Codex sets different env vars
if [ -n "$CLAUDE_SESSION_ID" ] || [ -n "$CLAUDE_CODE_ENTRYPOINT" ]; then
    CURRENT="claude"
    OTHER_NAME="Codex"

    # Check if codex CLI is available
    if command -v codex &> /dev/null; then
        OTHER_CLI="codex"
    else
        echo "ERROR: codex CLI not found. Please install it or use self-critique mode." >&2
        echo "FALLBACK: Running self-critique instead." > "$OUTPUT_FILE"
        exit 1
    fi
else
    CURRENT="codex"
    OTHER_NAME="Claude"

    # Check if claude CLI is available
    if command -v claude &> /dev/null; then
        OTHER_CLI="claude"
    else
        echo "ERROR: claude CLI not found. Please install it or use self-critique mode." >&2
        echo "FALLBACK: Running self-critique instead." > "$OUTPUT_FILE"
        exit 1
    fi
fi

echo "Current model: $CURRENT" >&2
echo "Invoking: $OTHER_NAME" >&2

# Create a temporary file for the prompt
PROMPT_FILE=$(mktemp)
echo "$PROMPT" > "$PROMPT_FILE"

# Invoke the opposing model
if [ "$OTHER_CLI" = "codex" ]; then
    # Codex invocation - using exec for non-interactive mode
    # --full-auto approves all actions automatically
    # -o writes last message to file
    if command -v gtimeout &> /dev/null; then
        gtimeout "$TIMEOUT_SECONDS" codex exec --full-auto -o "$OUTPUT_FILE" "$(cat "$PROMPT_FILE")" 2>&1 || {
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 124 ]; then
                echo "TIMEOUT: Codex did not respond within ${TIMEOUT_SECONDS}s" > "$OUTPUT_FILE"
            else
                # Don't overwrite - codex may have written partial output
                echo "ERROR: Codex invocation failed with exit code $EXIT_CODE" >> "$OUTPUT_FILE"
            fi
        }
    else
        # No timeout available, run without timeout
        codex exec --full-auto -o "$OUTPUT_FILE" "$(cat "$PROMPT_FILE")" 2>&1 || {
            EXIT_CODE=$?
            echo "ERROR: Codex invocation failed with exit code $EXIT_CODE" >> "$OUTPUT_FILE"
        }
    fi
else
    # Claude invocation - using -p for print mode (non-interactive)
    # Use gtimeout on macOS (from coreutils) or skip timeout if not available
    if command -v gtimeout &> /dev/null; then
        gtimeout "$TIMEOUT_SECONDS" claude -p "$(cat "$PROMPT_FILE")" > "$OUTPUT_FILE" 2>&1 || {
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 124 ]; then
                echo "TIMEOUT: Claude did not respond within ${TIMEOUT_SECONDS}s" > "$OUTPUT_FILE"
            else
                echo "ERROR: Claude invocation failed with exit code $EXIT_CODE" >> "$OUTPUT_FILE"
            fi
        }
    else
        # No timeout available, run without timeout
        claude -p "$(cat "$PROMPT_FILE")" > "$OUTPUT_FILE" 2>&1 || {
            EXIT_CODE=$?
            echo "ERROR: Claude invocation failed with exit code $EXIT_CODE" >> "$OUTPUT_FILE"
        }
    fi
fi

# Clean up
rm -f "$PROMPT_FILE"

# Check if we got a response
if [ ! -s "$OUTPUT_FILE" ]; then
    echo "WARNING: Empty response from $OTHER_NAME" > "$OUTPUT_FILE"
fi

echo "Response written to: $OUTPUT_FILE" >&2
echo "$OUTPUT_FILE"
