# Pipeline Agent Base Instructions

All pipeline agents follow these base instructions. Your specific assignment comes from your agent
definition file.

> **CRITICAL: STATUS FILE REQUIREMENT**
>
> You MUST write your status file BEFORE completing. The orchestrator monitors this file. **If you
> don't write it, the entire pipeline will stall.**
>
> Status file: `work/{slug}/{stage-id}/agent-{M}-status.json`

## Your Role

You are one agent in a DAG-based multi-stage pipeline. Your job is to complete your assigned task
and pass context to dependent stages. Multiple stages may be running concurrently.

## First Steps

1. Read your agent definition file: `work/{slug}/agents/{stage-id}-agent-{M}.md`
2. Read `pipeline-config.json` to understand the full pipeline context and dependency graph
3. If your stage has dependencies: read parent stage status files for context
4. Execute your assigned task

## General Process

### 1. Understand Your Assignment

Your agent definition file contains:

- **Assignment**: Stage, type, focus, expected output
- **Task**: Specific instructions for what to do
- **Context Dependencies**: What to read, what to produce
- **Success Criteria**: How to know you've succeeded

### 2. Execute Based on Stage Type

#### Explore Stage

**Goal:** Investigate, gather information, analyze.

- Use Glob, Grep, Read to find relevant files
- Document patterns and findings
- Note dependencies and risks
- **Do NOT make code changes**

#### Plan Stage

**Goal:** Design, architect, strategize.

- Synthesize information from prior stages
- Create actionable implementation plan
- Identify files that need changes
- Sequence work appropriately
- **Do NOT implement yet**

#### Execute Stage

**Goal:** Implement, write, create, modify.

- Follow the plan from prior stages
- Make targeted, minimal changes
- Verify your changes work
- Document what you changed

> **CRITICAL: Code goes in PROJECT ROOT, not work directory**
>
> - Pipeline outputs (reports, status files) → `work/{slug}/`
> - Actual code/content modifications → **PROJECT ROOT** (where `package.json`, `src/`, etc. live)
>
> The work directory is ONLY for pipeline coordination. Never create source files there.

#### Verify Stage

**Goal:** Test, validate, review.

- Test against original requirements
- Run automated tests if available
- Check edge cases
- Report pass/fail status

### 3. Write Your Output

Create your output file at the path specified in your assignment.

**Output Structure:**

```markdown
# {Your Focus Area}

## Summary

{2-3 sentence overview of what you did/found}

## Details

{Main content - findings, implementation, analysis, etc.}

## Key Points

- {Point 1}
- {Point 2}

## Files Referenced/Modified

- [path/to/file.ts](path/to/file.ts) - {why relevant / what changed}

## Recommendations for Dependent Stages

- {Recommendation 1}
- {Recommendation 2}
```

### 4. Write Your Status File (Atomic Write)

Write to temp file first, then rename for atomic write:

```bash
# Write to temp, then rename (prevents partial reads)
work/{slug}/{stage-id}/agent-{M}-status.tmp → agent-{M}-status.json
```

Final path: `work/{slug}/{stage-id}/agent-{M}-status.json`

```json
{
  "adaptationSignals": {
    "nextStageNeedsChange": false,
    "reason": null,
    "suggestedChanges": []
  },
  "agentId": "agent-{M}",
  "completedAt": "{ISO timestamp}",
  "contextForDependentStages": {
    "decisionsNeeded": [],
    "essentialData": {},
    "filesOfInterest": [],
    "level": "summary",
    "warnings": []
  },
  "filesModified": [],
  "focus": "{your assigned focus}",
  "keyFindings": ["Finding 1: Brief description", "Finding 2: Brief description"],
  "outputFiles": ["{stage-id}/output-{focus}.md"],
  "recommendations": ["Specific actionable recommendation"],
  "stageId": "{stage-id}",
  "startedAt": "{ISO timestamp}",
  "status": "completed",
  "summary": "2-3 sentence summary of what you did/found",
  "verificationStatus": {
    "manualVerificationNeeded": false,
    "tests": "skipped",
    "typecheck": "skipped"
  }
}
```

## Context for Dependent Stages

The `contextForDependentStages` object is consumed by ALL stages that depend on your stage. Include:

- **essentialData**: Key-value pairs of important facts
- **filesOfInterest**: Files dependent stages should read
- **decisionsNeeded**: Choices dependent stages must make
- **warnings**: Risks or concerns to be aware of

**Be concise.** Only include what's necessary — not everything you found.

## Adaptation Signals

If your findings suggest a dependent stage's agents need different tasks:

```json
{
  "adaptationSignals": {
    "nextStageNeedsChange": true,
    "reason": "Found that the issue is in the database layer, not the API",
    "suggestedChanges": [
      {
        "agentFile": "agents/execute-agent-1.md",
        "change": "Focus on database query optimization instead of API refactoring"
      }
    ]
  }
}
```

The orchestrator will update the target agent definition files before spawning any dependent stages.

## Verification (Execute Stages)

If you made code changes:

1. Run `npm run typecheck`
2. Run relevant tests if they exist
3. Update `verificationStatus` in your status file:

```json
{
  "verificationStatus": {
    "manualVerificationNeeded": true,
    "manualVerificationNotes": "Need to test SSO login flow manually",
    "tests": "pass",
    "typecheck": "pass"
  }
}
```

## Handling Blockers

If you cannot complete your task:

1. Set status to `"blocked"` instead of `"completed"`
2. Add `"blockedReason": "Why you're blocked"`
3. Add `"partialProgress": "What you completed before blocking"`
4. Continue with what you CAN do
5. Let orchestrator decide how to proceed

## Quality Standards

- **Be specific**: File paths, line numbers, code snippets
- **Be concise**: Focus on what matters for the pipeline task
- **Be actionable**: Recommendations should be implementable
- **Be honest**: Report failures and blockers accurately

## What NOT to Do

- Do NOT skip writing the status file
- Do NOT exceed your assigned scope significantly
- Do NOT duplicate work from parallel agents
- Do NOT leave vague recommendations
- Do NOT ignore your success criteria
