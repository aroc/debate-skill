# Debate Skill for Claude Code

Orchestrate a back-and-forth debate between two AI models (Claude and Codex) until they reach consensus on a technical decision, code review, or root cause analysis.

## Features

- **Consensus-driven**: Models iterate until they agree on a solution
- **Bidirectional**: Works when invoked from either Claude or Codex
- **Structured verdicts**: Clear AGREE/REVISE/DISAGREE outcomes
- **Quick mode**: Get a single round of feedback without iteration
- **Context-aware**: Automatically gathers git diffs and relevant code

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/debate-skill.git ~/projects/debate-skill

# Create symlink to Claude Code skills directory
mkdir -p ~/.claude/skills
ln -s ~/projects/debate-skill ~/.claude/skills/debate
```

## Requirements

- Claude Code CLI (`claude`)
- OpenAI Codex CLI (`codex`) - for cross-model debate
- Python 3.6+ (for verdict parsing)

## Usage

### Full Debate (Default)

```bash
# Review code changes
/debate review my proposed changes

# Debug a problem
/debate what's causing this test failure?

# Architecture decision
/debate should we use Redux or Context for state management?
```

### Choose Your Opponent

By default, the skill debates with the opposite model (Claude vs Codex). You can explicitly choose:

```bash
# Debate with Codex
/debate --vs codex should we use a monorepo?

# Debate with Claude (even from Claude - Claude vs Claude)
/debate --vs claude --model opus review this architecture

# Specify the opponent's model
/debate --vs codex --model o3 what's the best caching strategy?
```

### Available Models

**Claude CLI:**
- `opus` - Claude Opus (most capable)
- `sonnet` - Claude Sonnet (balanced)
- `haiku` - Claude Haiku (fastest)

**Codex CLI:**
- `o3` - OpenAI o3
- `gpt-4.1` - GPT-4.1
- (uses your Codex config default if not specified)

### Quick Mode

Get a single round of feedback without iterating to consensus:

```bash
/debate --quick is this approach correct?
/debate --quick --vs claude --model haiku sanity check this function
```

## How It Works

1. **User invokes** `/debate` with a topic and optional opponent/model
2. **Current model formulates** an initial proposal with analysis
3. **Opponent critiques** the proposal and provides a verdict:
   - `AGREE`: Proposal is sound
   - `REVISE`: Accept with specific changes
   - `DISAGREE`: Fundamental issues need addressing
4. **Models iterate** until consensus or max rounds (5)
5. **Final solution** presented to user

## Output Example

```
═══════════════════════════════════════════════
CONSENSUS DEBATE: Should we memoize this component?
Participants: Claude (opus) vs Codex (o3)
═══════════════════════════════════════════════

--- Round 1 ---
CLAUDE: The UserList component re-renders frequently due to parent
state changes. I propose wrapping it with React.memo() and using
useCallback for the onSelect handler.

CODEX: The component receives a new array reference on each render.
React.memo alone won't help - the props will always appear different.
REVISE: Also memoize the users array with useMemo in the parent.

--- Round 2 ---
CLAUDE: Updated proposal:
1. useMemo for users array in parent
2. React.memo on UserList
3. useCallback for onSelect

CODEX: This addresses the root cause. The memoization chain is complete.
AGREE: This will prevent unnecessary re-renders effectively.

═══════════════════════════════════════════════
CONSENSUS REACHED (Round 2)
═══════════════════════════════════════════════
Apply useMemo to the users array, wrap UserList in React.memo,
and use useCallback for event handlers.
```

## Configuration

The skill uses these defaults:
- **Max rounds**: 5
- **Timeout**: 120 seconds per model invocation
- **Output file**: `/tmp/debate_response.txt`

## Error Handling

- **CLI not found**: Falls back to self-critique mode
- **Timeout**: Reports partial results
- **No consensus**: Generates structured disagreement summary

## Files

- `SKILL.md` - Skill definition and orchestration instructions
- `scripts/invoke_other.sh` - Cross-model invocation script
- `scripts/parse_verdict.py` - Verdict extraction utility

## License

MIT
