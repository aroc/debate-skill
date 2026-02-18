---
name: debate
description: |
  Orchestrate a debate between Claude and Codex to reach consensus.
  Use when the user asks for a "second opinion", "debate", "consensus",
  "crosscheck", or wants another model to review a proposal or diff.
allowed-tools: Read, Glob, Grep, Bash
---

# Debate Skill

Orchestrate a back-and-forth debate between two AI models (Claude and Codex) until they reach consensus on a technical decision, code review, or root cause analysis.

## Activation

This skill activates when:
- User invokes `/debate [topic]`
- User asks for a "second opinion", "debate", "consensus", or "crosscheck"
- User wants another model to review a proposal, diff, or decision

## Arguments

- `--quick`: Single round only, get feedback without iterating to consensus
- Topic: Any technical question, code review request, or decision point

## Orchestration Steps

### Step 1: Gather Context

Based on the topic, gather relevant context:

```bash
# For code changes
git diff HEAD 2>/dev/null || git diff --staged 2>/dev/null

# For specific files, read them
# For architecture discussions, explore relevant code
```

### Step 2: Formulate Initial Proposal

As Claude, analyze the topic and formulate a clear proposal:

```
## Topic
[User's original question/request]

## Context
[Relevant code, diffs, or information]

## My Proposal
[Your analysis and recommendation]

## Key Points
- [Point 1]
- [Point 2]
- [Point 3]
```

### Step 3: Invoke Opposing Model

Use the invoke script to get the other model's critique:

```bash
bash /Users/ericanderson/projects/debate-skill/scripts/invoke_other.sh "
You are reviewing a proposal from Claude.

## Context
[Include gathered context]

## Proposal
[Claude's proposal]

## Your Task
Evaluate this proposal critically. Consider:
- Technical correctness
- Edge cases missed
- Alternative approaches
- Potential issues

End your response with exactly one verdict:
- AGREE: [confirmation and why]
- REVISE: [specific changes needed]
- DISAGREE: [fundamental issues]
"
```

### Step 4: Parse Verdict

```bash
python3 /Users/ericanderson/projects/debate-skill/scripts/parse_verdict.py /tmp/debate_response.txt
```

This returns: `AGREE|REVISE|DISAGREE` and the explanation.

### Step 5: Iterate Based on Verdict

**If AGREE:**
- Consensus reached! Present final solution to user.

**If REVISE:**
- Incorporate the suggested changes into your proposal
- Re-invoke the opposing model with the revised proposal
- Continue until AGREE or max rounds

**If DISAGREE:**
- Address the fundamental concerns raised
- Formulate a counter-proposal or clarification
- Re-invoke the opposing model
- Continue until AGREE or max rounds

### Step 6: Handle Max Rounds

If 5 rounds pass without consensus, generate a disagreement summary (see below).

## Quick Mode (--quick)

When `--quick` flag is present:
1. Formulate initial proposal
2. Get single critique from opposing model
3. Present both perspectives to user
4. Do NOT iterate - stop after one round regardless of verdict

## Output Format

Display the debate to the user in this format:

```
═══════════════════════════════════════════════
CONSENSUS DEBATE: [Topic]
═══════════════════════════════════════════════

--- Round 1 ---
CLAUDE: [proposal]

CODEX: [critique]
Verdict: [AGREE|REVISE|DISAGREE]

--- Round 2 --- (if needed)
CLAUDE: [revised proposal]

CODEX: [response]
Verdict: [AGREE|REVISE|DISAGREE]

═══════════════════════════════════════════════
CONSENSUS REACHED (Round N)
═══════════════════════════════════════════════
[Final agreed solution with key points]
```

## No Consensus Summary

When max rounds (5) reached without consensus:

```
═══════════════════════════════════════════════
NO CONSENSUS REACHED (5 rounds)
═══════════════════════════════════════════════

## Points of Agreement
- [Things both models agreed on]

## Points of Disagreement
- [Issue 1]: Claude thinks X, Codex thinks Y
- [Issue 2]: ...

## Root Cause of Disagreement
[Why consensus couldn't be reached - e.g., different assumptions,
missing information, genuinely valid competing approaches]

## Recommendation
[Best path forward given the disagreement]
═══════════════════════════════════════════════
```

## Error Handling

**CLI not installed:**
```bash
if ! command -v codex &> /dev/null && ! command -v claude &> /dev/null; then
    echo "Neither codex nor claude CLI found. Falling back to self-critique mode."
    # Provide self-critique instead
fi
```

**Network/timeout error:**
- Retry once
- If still fails, present partial results with note about the error

**Empty response:**
- Treat as implicit DISAGREE
- Request clarification in next round

## Prompt Templates

### Initial Critique Request

```
You are [Codex/Claude], reviewing a proposal from [Claude/Codex].

## Original Question
{user_topic}

## Context
{gathered_context}

## Proposal Being Reviewed
{proposal}

## Your Task
Critically evaluate this proposal. Consider:
1. Is the technical approach correct?
2. Are there edge cases or failure modes missed?
3. Are there better alternatives?
4. What are the risks or downsides?

Be constructive but thorough. If you agree, explain why it's solid.
If you have concerns, be specific about what should change.

End with exactly one of:
- AGREE: [your confirmation and reasoning]
- REVISE: [specific changes you recommend]
- DISAGREE: [fundamental issues that need addressing]
```

### Revision Request

```
You are [Codex/Claude], continuing a debate with [Claude/Codex].

## Original Question
{user_topic}

## Previous Exchange
{conversation_history}

## Latest Revision
{revised_proposal}

## Your Task
Evaluate whether the revision addresses your previous concerns.

End with exactly one of:
- AGREE: [if concerns are resolved]
- REVISE: [if minor issues remain]
- DISAGREE: [if fundamental issues persist]
```

## Implementation Notes

- Accumulate conversation history between rounds
- Each model should see the full debate context
- Keep proposals concise but complete
- Focus on technical merit, not rhetorical style
- Maximum response from opposing model: ~2000 tokens
