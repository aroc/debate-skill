#!/usr/bin/env python3
"""
parse_verdict.py - Extract verdict from debate response

Usage: python3 parse_verdict.py <response_file>
       python3 parse_verdict.py --text "response text"

Output format (JSON):
{
    "verdict": "AGREE|REVISE|DISAGREE|UNKNOWN",
    "explanation": "The explanation following the verdict",
    "raw_match": "The exact matched line"
}
"""

import sys
import re
import json
from pathlib import Path


def parse_verdict(text: str) -> dict:
    """
    Parse AGREE/REVISE/DISAGREE verdict from response text.

    Looks for patterns like:
    - AGREE: explanation
    - REVISE: explanation
    - DISAGREE: explanation

    Returns dict with verdict, explanation, and raw_match.
    """
    result = {
        "verdict": "UNKNOWN",
        "explanation": "",
        "raw_match": ""
    }

    if not text or not text.strip():
        result["explanation"] = "Empty response"
        return result

    # Normalize text - handle various line endings
    text = text.replace('\r\n', '\n').replace('\r', '\n')

    # Look for verdict patterns - check last portion of text first
    # (verdicts should appear at the end)
    lines = text.strip().split('\n')

    # Search from the end backwards
    verdict_pattern = re.compile(
        r'^[\s*-]*\*?\*?(AGREE|REVISE|DISAGREE)\*?\*?[:\s]+(.*)$',
        re.IGNORECASE | re.MULTILINE
    )

    # First try to find in the last 20 lines (where verdict should be)
    search_text = '\n'.join(lines[-20:]) if len(lines) > 20 else text

    matches = list(verdict_pattern.finditer(search_text))

    if matches:
        # Take the last match (most likely the actual verdict)
        match = matches[-1]
        verdict = match.group(1).upper()
        explanation = match.group(2).strip()

        # If explanation is short, try to get more context
        if len(explanation) < 10:
            # Look for continuation on next lines
            match_end = match.end()
            remaining = search_text[match_end:].strip()
            if remaining and not remaining.startswith(('AGREE', 'REVISE', 'DISAGREE')):
                # Take first paragraph of remaining text
                extra = remaining.split('\n\n')[0].strip()
                if extra:
                    explanation = f"{explanation} {extra}".strip()

        result["verdict"] = verdict
        result["explanation"] = explanation
        result["raw_match"] = match.group(0).strip()
        return result

    # Fallback: look for verdict words anywhere (less strict)
    fallback_pattern = re.compile(
        r'\b(AGREE|REVISE|DISAGREE)\b[:\s]*([^\n]*)',
        re.IGNORECASE
    )

    fallback_matches = list(fallback_pattern.finditer(text))
    if fallback_matches:
        match = fallback_matches[-1]
        result["verdict"] = match.group(1).upper()
        result["explanation"] = match.group(2).strip()
        result["raw_match"] = match.group(0).strip()
        return result

    # No verdict found
    result["explanation"] = "No clear verdict found in response"
    return result


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 parse_verdict.py <response_file>", file=sys.stderr)
        print("       python3 parse_verdict.py --text \"response text\"", file=sys.stderr)
        sys.exit(1)

    # Handle --text argument for inline text
    if sys.argv[1] == "--text":
        if len(sys.argv) < 3:
            print("Error: --text requires response text argument", file=sys.stderr)
            sys.exit(1)
        text = sys.argv[2]
    else:
        # Read from file
        filepath = Path(sys.argv[1])
        if not filepath.exists():
            print(json.dumps({
                "verdict": "UNKNOWN",
                "explanation": f"File not found: {filepath}",
                "raw_match": ""
            }))
            sys.exit(1)

        text = filepath.read_text(encoding='utf-8', errors='replace')

    result = parse_verdict(text)
    print(json.dumps(result, indent=2))

    # Exit with code based on verdict for easy shell scripting
    if result["verdict"] == "AGREE":
        sys.exit(0)
    elif result["verdict"] == "REVISE":
        sys.exit(1)
    elif result["verdict"] == "DISAGREE":
        sys.exit(2)
    else:
        sys.exit(3)


if __name__ == "__main__":
    main()
