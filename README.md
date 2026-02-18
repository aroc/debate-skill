# "Debate" agent skill

An agent skill that orchestrates debates between Claude and Codex until they reach consensus.

## Installation

```bash
npx skills add https://github.com/aroc/debate-skill --skill debate
```

## Usage

```bash
/debate should we use Redis or Memcached?
/debate review my proposed changes
/debate --quick is this approach correct?
```

## Flags

| Flag | Description |
|------|-------------|
| `--vs <claude\|codex>` | Choose opponent (default: opposite of current) |
| `--model <model>` | Opponent model (e.g., `opus`, `sonnet`, `o3`, `gpt-4.1`) |
| `--reasoning <low\|medium\|high>` | Codex thinking effort level |
| `--quick` | Single round only, skip iteration |

## How It Works

1. You ask a question or request a review
2. Claude formulates a proposal
3. Codex critiques it with a verdict: **AGREE**, **REVISE**, or **DISAGREE**
4. Models iterate until consensus (max 5 rounds)
5. Final agreed solution presented

If no consensus after 5 rounds, you get a structured summary of:
- Points of agreement
- Points of disagreement
- Root cause of the disagreement
- Recommended path forward

## Example Output

```
═══════════════════════════════════════════════
CONSENSUS DEBATE: Should we memoize this component?
Participants: Claude vs Codex
═══════════════════════════════════════════════

--- Round 1 ---
CLAUDE: The UserList component re-renders frequently. I propose
wrapping it with React.memo() and using useCallback for onSelect.

CODEX: The component receives a new array reference each render.
React.memo alone won't help - props will always appear different.
Verdict: REVISE - Also memoize the users array with useMemo.

--- Round 2 ---
CLAUDE: Updated proposal:
1. useMemo for users array in parent
2. React.memo on UserList
3. useCallback for onSelect

CODEX: This addresses the root cause. The memoization chain is complete.
Verdict: AGREE

═══════════════════════════════════════════════
CONSENSUS REACHED (Round 2)
═══════════════════════════════════════════════
Apply useMemo to the users array, wrap UserList in React.memo,
and use useCallback for event handlers.
```

## Examples

```bash
# Default: debate with the opposite model
/debate what's causing this test failure?

# Specify opponent and model
/debate --vs codex --model o3 review this architecture

# Quick sanity check (no iteration)
/debate --quick --vs claude is this SQL injection safe?

# High reasoning for thorough analysis
/debate --vs codex --reasoning high security review this auth flow
```

## License

MIT
