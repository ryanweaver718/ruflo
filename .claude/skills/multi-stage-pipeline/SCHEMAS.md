# Multi-Stage Pipeline Schemas

## pipeline-config.json

Master configuration file at `work/{slug}/pipeline-config.json`.

Stages form a DAG (directed acyclic graph) via `id` and `dependsOn` fields. The orchestrator
computes execution order from dependencies — stages with satisfied dependencies run concurrently.

```json
{
  "createdAt": "ISO-8601 timestamp",
  "executionMode": "autonomous | guided | manual",
  "stages": [
    {
      "agents": [
        {
          "completedAt": "ISO timestamp or null",
          "focus": "What this agent does",
          "id": "agent-1",
          "outputFiles": ["paths to output files"],
          "startedAt": "ISO timestamp or null",
          "status": "pending | running | completed | failed | blocked",
          "taskId": "Task ID for monitoring (optional)"
        }
      ],
      "contextLevel": "minimal | summary | detailed",
      "customType": "optional - if type is custom",
      "dependsOn": [],
      "id": "explore-api",
      "purpose": "Human-readable purpose",
      "status": "pending | running | completed | failed",
      "type": "explore | plan | execute | verify | custom"
    },
    {
      "agents": [{ "...": "runs in parallel with explore-api" }],
      "dependsOn": [],
      "id": "explore-ui",
      "purpose": "Explore UI patterns",
      "status": "pending",
      "type": "explore"
    },
    {
      "agents": [{ "...": "waits for both explore stages" }],
      "dependsOn": ["explore-api", "explore-ui"],
      "id": "plan",
      "purpose": "Design implementation approach",
      "status": "pending",
      "type": "plan"
    }
  ],
  "status": "setup | analyzing | in_progress | paused | completed | failed",
  "task": "Full task description from user",
  "taskSlug": "kebab-case-slug"
}
```

---

## scope-analysis.json

Created by Scope Analysis Agent at `work/{slug}/scope-analysis.json`.

Stages include `id` and `dependsOn` to define the execution DAG.

```json
{
  "alternativeApproaches": [
    {
      "description": "Alternative pipeline structure",
      "tradeoffs": "Why you might choose this instead"
    }
  ],
  "clarificationNeeded": {
    "needed": false,
    "reason": "Why clarification is needed (if true)",
    "suggestedQuestions": ["Question 1?", "Question 2?"]
  },
  "complexity": "low | medium | high",
  "contextStrategy": {
    "explore-api->plan": "Pass API structure findings",
    "explore-ui->plan": "Pass UI pattern findings",
    "plan->execute": "Pass implementation plan with file targets"
  },
  "estimatedScope": {
    "codebaseAreas": ["area1", "area2"],
    "filesAffected": "1-5 | 5-15 | 15+",
    "hasExternalDependencies": false
  },
  "riskFactors": ["factor1", "factor2"],
  "skipPipeline": {
    "reason": "Why pipeline should be skipped (if true)",
    "recommended": false
  },
  "stages": [
    {
      "agentCount": 2,
      "agents": [
        {
          "focus": "What this agent investigates/does",
          "id": "agent-1",
          "outputDescription": "What artifact this produces"
        }
      ],
      "contextNeeded": "minimal | summary | detailed",
      "customType": "optional custom type name",
      "dependsOn": [],
      "id": "explore-api",
      "purpose": "Human-readable purpose",
      "rationale": "Why this stage is needed",
      "type": "explore | plan | execute | verify | custom"
    }
  ],
  "taskSummary": "Brief 1-2 sentence summary",
  "taskType": "bug_fix | feature | refactor | content | research | migration | integration | analysis | custom"
}
```

---

## Agent Status File

Each agent writes to `work/{slug}/{stage-id}/agent-{M}-status.json`.

```json
{
  "adaptationSignals": {
    "nextStageNeedsChange": false,
    "reason": "Why dependent stage needs adaptation (if true)",
    "suggestedChanges": [
      {
        "agentFile": "agents/{stage-id}-agent-1.md",
        "change": "Description of what to change"
      }
    ]
  },
  "agentId": "agent-1",
  "blockedReason": "Why blocked (if status is blocked)",
  "completedAt": "ISO timestamp",
  "contextForDependentStages": {
    "decisionsNeeded": ["Decision that dependent stage should make"],
    "essentialData": {
      "key1": "value1",
      "key2": "value2"
    },
    "filesOfInterest": ["path/to/relevant/file.ts"],
    "level": "minimal | summary | detailed",
    "warnings": ["Risk or concern to be aware of"]
  },
  "filesModified": ["src/path/to/modified-file.ts"],
  "focus": "What this agent was assigned",
  "keyFindings": ["Finding 1: Brief description", "Finding 2: Brief description"],
  "outputFiles": ["stage-id/output-focus.md"],
  "partialProgress": "What was completed before blocking",
  "recommendations": ["Specific actionable recommendation"],
  "stageId": "explore-api",
  "startedAt": "ISO timestamp",
  "status": "completed | failed | blocked",
  "summary": "2-3 sentence summary of what was done/found",
  "verificationStatus": {
    "manualVerificationNeeded": false,
    "manualVerificationNotes": "What needs manual verification",
    "tests": "pass | fail | skipped",
    "typecheck": "pass | fail | skipped"
  }
}
```

---

## Agent Definition File

Created by Scope Agent at `work/{slug}/agents/{stage-id}-agent-{M}.md`.

```markdown
# Agent: {stage-id}-agent-{M}

## Assignment

- Stage: "{stage-id}" ({type})
- Focus: {specific focus area}
- Output: {expected deliverable filename}

## Task

{Detailed instructions for what this agent should do}

{May include specific files to read, patterns to follow, etc.}

## Context Dependencies

- Reads: {parent stage outputs this agent needs, or "None - no dependencies"}
- Produces: {what this agent creates}

## Success Criteria

- {Criterion 1}
- {Criterion 2}

## Adaptation Notes

{Updated by orchestrator if parent stage requested changes} {Format: "Adapted on {date}: {what
changed and why}"}
```

---

## Directory Structure

Stage directories use the stage `id` (not a number) as their name:

```
work/{task-slug}/
├── pipeline-config.json        # Pipeline state and config (DAG structure)
├── scope-analysis.json         # Task analysis results (Modes A & B)
├── agents/                     # Agent definition files
│   ├── explore-api-agent-1.md
│   ├── explore-api-agent-2.md
│   ├── explore-ui-agent-1.md
│   ├── plan-agent-1.md
│   ├── execute-agent-1.md
│   └── ...
├── explore-api/                # Stage outputs (named by stage id)
│   ├── agent-1-status.json
│   ├── agent-2-status.json
│   ├── output-endpoints.md
│   └── output-schemas.md
├── explore-ui/                 # Ran in parallel with explore-api
│   ├── agent-1-status.json
│   └── output-components.md
├── plan/                       # Ran after both explore stages completed
│   ├── agent-1-status.json
│   └── output-plan.md
└── execute/
    └── ...
```

---

## Status Values Reference

| Status      | Context        | Meaning                            |
| ----------- | -------------- | ---------------------------------- |
| setup       | Pipeline       | Created but not started            |
| analyzing   | Pipeline       | Scope agent is analyzing task      |
| in_progress | Pipeline       | Pipeline actively running          |
| paused      | Pipeline       | Pipeline paused by user            |
| completed   | Pipeline/Agent | Finished successfully              |
| failed      | Pipeline/Agent | Failed after all retries           |
| pending     | Stage/Agent    | Not yet started                    |
| running     | Stage/Agent    | Currently executing                |
| blocked     | Agent          | Cannot proceed, needs intervention |

---

## Task Types Reference

| Task Type   | Description                                 |
| ----------- | ------------------------------------------- |
| bug_fix     | Fixing errors, crashes, incorrect behavior  |
| feature     | Adding new functionality                    |
| refactor    | Reorganizing code without changing behavior |
| content     | Writing, editing, generating text/docs      |
| research    | Investigation, learning, documentation      |
| migration   | Moving, transforming, upgrading systems     |
| integration | Connecting systems, APIs, services          |
| analysis    | Data analysis, performance review, security |
| custom      | User-defined task type                      |

---

## Context Levels Reference

| Level    | Content                        | When to Use                      |
| -------- | ------------------------------ | -------------------------------- |
| minimal  | Summary only (2-3 sentences)   | Independent stages, simple tasks |
| summary  | Key findings + recommendations | Most stage transitions (default) |
| detailed | Full output refs + summaries   | Complex dependencies             |

---

## Parent Stage Context Format

Agents receive context from ALL parent stages (every stage in `dependsOn`). Each parent is labeled
by its stage ID:

```
## Parent Stage Context

**From "{parent-stage-id}":**

Summary: {Combined summaries from all agents in that parent stage}

Key Findings:
- {Finding 1}
- {Finding 2}

Recommendations:
- {Recommendation 1}

Files of Interest:
- {path/to/file.ts}

Warnings:
- {Warning if any}

---

**From "{another-parent-id}":**

Summary: {Combined summaries from all agents in that parent stage}

{... same structure ...}
```
