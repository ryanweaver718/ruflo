---
name: multi-stage-pipeline
description:
  Orchestrate dynamic research and implementation pipelines with DAG-based multi-stage agent
  coordination. Stages form a dependency graph — truly independent stages run in parallel.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task, TaskOutput, AskUserQuestion
---

# Multi-Stage Pipeline Orchestration

Generic, task-agnostic pipeline orchestrator with DAG-based stage execution and three configuration
modes. Stages form a dependency graph — truly independent stages run concurrently while dependent
stages wait only for their specific parents to complete.

> **CRITICAL: ORCHESTRATOR ROLE**
>
> You are the ORCHESTRATOR. You NEVER do research or implementation work yourself. Your job:
> Configure pipeline upfront, spawn agents, monitor progress, auto-advance stages.
>
> **NEVER WAIT FOR USER INPUT BETWEEN STAGES**
>
> After spawning agents, IMMEDIATELY begin monitoring. When agents complete, IMMEDIATELY spawn newly
> unblocked stages. The pipeline is FULLY AUTOMATED after setup.

## Commands

| Command                               | Action                                  |
| ------------------------------------- | --------------------------------------- |
| `/multi-stage-pipeline`               | Start new pipeline                      |
| `/multi-stage-pipeline resume`        | List active pipelines, select to resume |
| `/multi-stage-pipeline resume {slug}` | Resume specific pipeline                |
| `/multi-stage-pipeline status {slug}` | Show pipeline status without resuming   |
| `/multi-stage-pipeline list`          | List all pipelines (active + completed) |

---

## Command: /multi-stage-pipeline (New Pipeline)

### CRITICAL: One Question at a Time

**Ask ONE question per AskUserQuestion call.** Never combine multiple questions.

### Question Flow

#### Q1: Task Description (ALWAYS FIRST)

```
Describe your task or goal. Be as detailed or general as you like.
```

Let user type freely. Store as `task` in config.

#### Q2: Execution Mode Selection

```
How would you like to configure this pipeline?

A. Fully Autonomous
   - Scope agent analyzes your task
   - Pipeline determined and executed automatically

B. Guided Autonomous
   - Scope agent analyzes your task
   - You review/edit proposed pipeline before execution

C. Manual Definition
   - You define all stages and agents
   - System provides suggestions you can accept/override
```

---

## Mode A: Fully Autonomous

After Q2 selection:

1. Create work directory: `work/{task-slug}/`
2. Create initial `pipeline-config.json` with status "analyzing"
3. Spawn Scope Analysis Agent immediately
4. ACTIVELY poll for `scope-analysis.json` every 30s using Glob (never wait for notifications)
5. Scope agent writes:
   - `scope-analysis.json`
   - `agents/{stage-id}-agent-*.md` (all agent definitions)
6. Check if `skipPipeline.recommended: true` → execute directly without pipeline
7. Otherwise, begin execution (see Execution section)

---

## Mode B: Guided Autonomous

After Q2 selection:

1. Create work directory and initial config (status "analyzing")
2. Spawn Scope Analysis Agent
3. Read `scope-analysis.json` when complete
4. **IF `clarificationNeeded.needed: true`:**
   - Present clarifying questions from `suggestedQuestions`
   - After user answers, update scope analysis with answers
5. Present proposed pipeline to user with DAG visualization:

```
Based on your task, I recommend:

Task Type: {taskType}
Complexity: {complexity}

Proposed Pipeline ({N} stages):

  explore-api [id: "explore-api"] (2 agents)
    - Agent 1: {focus}
    - Agent 2: {focus}
  explore-ui [id: "explore-ui"] (1 agent)        ← runs parallel with explore-api
    - Agent 1: {focus}
  plan [id: "plan", dependsOn: ["explore-api", "explore-ui"]]
    - Agent 1: {focus}                            ← waits for BOTH explore stages
  execute [id: "execute", dependsOn: ["plan"]]
    - Agent 1: {focus}

Execution order:
  [explore-api] ──┐
                   ├──→ [plan] ──→ [execute]
  [explore-ui]  ──┘

Options:
A. Accept and Execute
B. Modify stages / dependencies
C. Modify agent assignments
D. Request re-analysis
```

6. If user modifies, update `agents/*.md` files accordingly
7. Begin execution

---

## Mode C: Manual Definition

After Q2 selection:

1. **Assess task clarity** - if vague/brainstormy, ask 2-4 clarifying questions first
2. **Q3: Number of Stages**

```
How many stages in your pipeline?

Based on your task, I suggest {N} stages.

(Enter any number)
```

3. **For each stage (Q4+):**

```
Stage "{id}" - What type?
- Explore - Investigate, gather information, analyze
- Plan - Design, architect, strategize
- Execute - Implement, write, create, modify
- Verify - Test, validate, review
- Custom - Define your own
```

After type:

```
Stage "{id}" ({type}) - How many agents?

(Enter any number — agents run in parallel)
```

If 2+ agents:

```
Stage "{id}" - Agent assignments:

Based on your task, I suggest:
- Agent 1: {suggested focus}
- Agent 2: {suggested focus}

Accept suggestions or customize?
```

4. **Dependencies (Q after all stages defined):**

```
Stage dependencies:

Which stages does each stage depend on?
Stages with no dependencies start immediately.
Stages with shared dependencies run in parallel.

Current stages: {list all stage IDs}

Based on your task, I suggest:
  "{id-1}": no dependencies (starts immediately)
  "{id-2}": no dependencies (starts immediately, parallel with {id-1})
  "{id-3}": depends on ["{id-1}", "{id-2}"]
  "{id-4}": depends on ["{id-3}"]

Accept suggestions or customize?
```

5. After all stages and dependencies configured, create `agents/*.md` files
6. Begin execution

---

## Pipeline Execution (All Modes) — THE MECHANICAL RULE

Once pipeline is configured, execution follows ONE simple rule repeated in a loop:

> **"Any pending stage whose `dependsOn` are all completed? Spawn it."**

```
LOOP:
  1. SCAN all stages in config
     - Find READY stages: status="pending" AND every stage in dependsOn has status="completed"
       (stages with empty dependsOn are ready immediately)
  2. IF ready stages found:
     a. For EACH ready stage:
        - Set status to "running" in config
        - Create stage directory: {stage-id}/
        - Re-read agent definitions from disk (parent may have signaled adaptations)
        - Spawn ALL agents for this stage in background (Task with run_in_background: true)
        - Store task IDs in config
  3. CHECK all currently-running stages for completion:
     a. Glob: work/{slug}/{stage-id}/agent-*-status.json (for each running stage)
     b. For each status file found → read it, update agent status in config
     c. For each running stage where ALL agents have status files:
        - Mark stage "completed" in config (or "failed" if all agents failed)
        - Check adaptation signals → update dependent agent definitions if needed
  4. IF any stages still "running" (not all agents done):
     a. sleep 30
     b. Go to step 1
  5. IF no stages "running" AND no stages "pending" → PIPELINE COMPLETE
  6. IF no stages "running" AND pending stages exist but NONE are ready → PIPELINE STUCK (report)
```

**That's it.** No quality gates. No rescoping. No complex state management. Just: scan, spawn what's
ready, check what's done, repeat.

---

## Agent Spawning

### Spawning Template

```
Task tool parameters:
- subagent_type: "general-purpose"
- model: "opus" (or user's configured default)
- run_in_background: true
- prompt: {assembled from agent definition file}

Store returned task ID in config: agents[N].taskId
```

> **CRITICAL: Reload agent definitions from disk before each stage.** Parent stages may have
> signaled adaptations. Always re-read `agents/{stage-id}-*.md` files fresh.

### Agent Prompt Assembly

For each agent, read their definition file and assemble:

```markdown
# Pipeline Agent

You are executing a task in a multi-stage pipeline.

## Your Assignment

{Read from work/{slug}/agents/{stage-id}-agent-{M}.md}

## Pipeline Context

- Pipeline Metadata Directory: work/{slug}/ (for reports, status files, coordination ONLY)
- **Project Root: /** (where ALL code/content modifications MUST go - src/, server/, etc.)
- Current Stage: "{stage-id}" ({total} total stages in pipeline)
- Your Agent ID: agent-{M}

**CRITICAL:** Never create source code or content files inside work/. That's only for pipeline
coordination.

## Parent Stage Context (if stage has dependencies)

{Assembled from {parent-stage-id}/agent-\*-status.json for EACH parent in dependsOn, based on
contextLevel}

## CRITICAL: Status File Requirement

You MUST write your status file BEFORE completing. Path:
work/{slug}/{stage-id}/agent-{M}-status.json

The orchestrator monitors this file. No status file = pipeline stalls.

See AGENT-BASE.md for format and requirements.

## Instructions

{READ AGENT-BASE.md with Read tool and EMBED full content here}
```

---

## Context Assembly

When spawning agents for a stage with dependencies, assemble context from ALL parent stages (every
stage listed in `dependsOn`):

### By Context Level

**minimal** (2-3 sentences):

```
Parent Stage "{parent-id}" Summary: {combined summaries from all agents in that parent stage}
```

**summary** (default):

```
Parent Stage "{parent-id}" Summary: {summaries}

Key Findings:
- {keyFindings from each agent, deduplicated}

Recommendations:
- {recommendations relevant to this stage}

Files of Interest:
- {filesOfInterest from parent agents}
```

Repeat for each parent stage. If a stage has multiple parents, include context from ALL of them,
clearly labeled by parent stage ID.

**detailed**:

```
{All of summary level, for each parent}

Detailed Outputs from "{parent-id}":
{First 50 lines of each outputFile from that parent stage}
```

---

## Scope Analysis Agent

Spawn with:

```
Task tool parameters:
- subagent_type: "general-purpose"
- model: "opus"
- run_in_background: true
- prompt: {content from AGENT-SCOPE.md + task context}
```

The scope agent:

1. Analyzes task
2. Writes `scope-analysis.json`
3. Creates `agents/` directory
4. Writes `agents/{stage-id}-agent-*.md` for ALL agents in pipeline

---

## Pipeline Completion

When all stages complete:

1. Update pipeline status to "completed" in config
2. Display summary with DAG visualization:

```
Pipeline Complete: {topic}

Execution Graph:
  [explore-api] ──┐
                   ├──→ [plan] ──→ [execute-backend] ──┐
  [explore-ui]  ──┘                                     ├──→ [verify]
                      [execute-frontend] ───────────────┘

Stages:
  ✓ explore-api: {purpose} ({agent count} agents)
  ✓ explore-ui: {purpose} ({agent count} agents)
  ✓ plan: {purpose} ({agent count} agents)
  ✓ execute-backend: {purpose} ({agent count} agents)
  ✓ execute-frontend: {purpose} ({agent count} agents)
  ✓ verify: {purpose} ({agent count} agents)

Output files:
  - {stage-id}/*.md (for each stage)

Files modified:
  - {aggregated from all agent status files}

Manual steps needed:
  - {any manualVerificationNeeded from agents}
```

---

## Command: /multi-stage-pipeline resume

1. Find active pipelines: `find work -name "pipeline-config.json"`
2. Filter by status != "completed"
3. Read config, identify which stages are running/pending/completed
4. Check which agents have status files across all running stages
5. Resume the LOOP from the Execution section (re-enter at step 1)

---

## Command: /multi-stage-pipeline status {slug}

Display without resuming:

```
Pipeline: {task}
Status: {status}
Mode: {executionMode}

Execution Graph:
  [explore-api] ──┐
                   ├──→ [plan] ──→ [execute]
  [explore-ui]  ──┘

Stages:
  explore-api [{status}]
     ✓ agent-1: {focus}
     ✓ agent-2: {focus}
  explore-ui [{status}]
     ✓ agent-1: {focus}
  plan [{status}]
     ⋯ agent-1: {focus}
  execute [pending]
     ○ agent-1: {focus}
```

---

## Failure Handling

**Agent retry:**

1. No status file after 10 min → check TaskOutput
2. Respawn once with same prompt
3. If fails again → mark agent failed, continue pipeline
4. If entire stage fails (all agents) → mark stage failed, skip dependent stages, report to user

**Pipeline with failures:**

```
Pipeline complete with {N} failures:
- Stage "{id}", agent-2: {focus} - failed ({reason})

Successful outputs:
- {stage-id}/*.md

Manual intervention needed for failed agents.
```

---

## File References

- `SCHEMAS.md` - JSON schemas for all config/status files
- `AGENT-SCOPE.md` - Scope analysis agent instructions
- `AGENT-BASE.md` - Generic agent template (all agents follow)
- `STAGE-PATTERNS.md` - Task type → stage pattern reference
