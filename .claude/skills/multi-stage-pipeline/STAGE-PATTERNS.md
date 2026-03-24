# Stage Patterns Reference (DAG)

Reference for the Scope Analysis Agent to design appropriate DAG-based pipelines. Stages use `id`
and `dependsOn` to form a dependency graph. Independent stages run concurrently.

## Stage Types

| Type    | Purpose                           | Typical Actions                          |
| ------- | --------------------------------- | ---------------------------------------- |
| explore | Investigate, gather info, analyze | Read files, search, document findings    |
| plan    | Design, architect, strategize     | Create plans, identify changes, sequence |
| execute | Implement, write, create, modify  | Edit files, write code, create content   |
| verify  | Test, validate, review            | Run tests, check results, confirm        |
| custom  | User-defined purpose              | Varies                                   |

---

## Patterns by Task Type

### Bug Fix

**Simple Bug (low complexity):**

```
"explore" [] → "execute" ["explore"]
```

**Complex Bug (medium/high complexity):**

```
"explore-errors" []  ──┐
                        ├──→ "plan" ["explore-errors", "explore-code"] → "execute" ["plan"]
"explore-code"   []  ──┘
```

Both explore stages run in parallel, plan waits for both.

**Agent Focus Examples:**

- Error trace analysis
- Related code review
- Reproduction steps
- Impact assessment

---

### Feature

**Small Feature (low complexity):**

```
"explore" [] → "execute" ["explore"]
```

**Medium Feature (medium complexity):**

```
"explore-patterns" []  ──┐
                          ├──→ "plan" [...] → "execute" ["plan"]
"explore-integration" [] ─┘
```

**Large Feature (high complexity):**

```
"explore-api" []  ──┐
"explore-ui"  []  ──┼──→ "plan" ["explore-api", "explore-ui", "explore-data"]
"explore-data" [] ──┘         │
                              ├──→ "execute-backend"  ["plan"] ──┐
                              └──→ "execute-frontend" ["plan"] ──┼──→ "verify" ["execute-backend", "execute-frontend"]
                                                                 │
```

All 3 explore stages run concurrently. Both execute stages run concurrently after plan. Verify waits
for both executes.

**Agent Focus Examples:**

- Existing pattern analysis
- API structure review
- UI component patterns
- Data model investigation
- Backend implementation
- Frontend implementation
- Integration testing

---

### Refactor

**Small Refactor:**

```
"explore" [] → "execute" ["explore"]
```

**Large Refactor:**

```
"explore-arch"  [] ──┐
                      ├──→ "plan" [...] → "execute" ["plan"] → "verify" ["execute"]
"explore-usage" [] ──┘
```

**Agent Focus Examples:**

- Current architecture analysis
- Usage pattern mapping
- Dependency identification
- Migration planning
- Code restructuring
- Test verification

---

### Content

**Simple Content:**

```
"research" [] → "write" ["research"]
```

**Complex Content:**

```
"research-topic"   [] ──┐
                         ├──→ "outline" [...] → "write" ["outline"]
"research-sources" [] ──┘
```

**Agent Focus Examples:**

- Topic research
- Source gathering
- Outline creation
- Content writing
- Review and editing

---

### Research

**Simple Research:**

```
"investigate" [] (single stage, 1-2 agents)
```

**Complex Research:**

```
"explore-area-a" [] ──┐
"explore-area-b" [] ──┼──→ "synthesize" ["explore-area-a", "explore-area-b", "explore-area-c"]
"explore-area-c" [] ──┘
```

All exploration runs concurrently, synthesis waits for all.

**Agent Focus Examples:**

- Codebase exploration
- Documentation review
- Pattern analysis
- External research
- Synthesis and summary

---

### Migration

**Standard Migration:**

```
"audit-current" []  ──┐
                       ├──→ "plan" [...] → "migrate" ["plan"] → "verify" ["migrate"]
"audit-target"  []  ──┘
```

**Agent Focus Examples:**

- Current state audit
- Target requirements analysis
- Migration plan creation
- Data transformation
- Validation testing

---

### Integration

**API Integration:**

```
"explore-internal" [] ──┐
                         ├──→ "plan" [...] → "implement" ["plan"] → "verify" ["implement"]
"explore-external" [] ──┘
```

**Agent Focus Examples:**

- Internal API analysis
- External API documentation
- Integration design
- Connection implementation
- Error handling
- Integration testing

---

### Analysis

**Standard Analysis:**

```
"gather-data" [] → "analyze-report" ["gather-data"]
```

**Agent Focus Examples:**

- Data collection
- Pattern identification
- Performance profiling
- Security scanning
- Report generation

---

## DAG Design Criteria

**When to make stages independent (empty `dependsOn`):**

- They investigate different areas of the codebase
- They research different topics
- They implement independent subsystems (e.g., backend vs frontend)
- Their inputs come from different parent stages

**When to add a dependency:**

- Stage genuinely needs the OUTPUT of the parent stage
- Stage needs to synthesize findings from multiple parents
- Stage implements something designed by the parent plan stage
- Stage verifies work done by the parent execute stage

**Two levels of parallelism:**

1. **Stage-level parallelism** (DAG): Independent stages run concurrently
2. **Agent-level parallelism** (within stage): Multiple agents within one stage run concurrently

Use both — no artificial caps on either.

---

## Context Level Guidelines

| Scenario                               | Recommended Level |
| -------------------------------------- | ----------------- |
| Dependent stage is loosely coupled     | minimal           |
| Standard transition                    | summary (default) |
| Dependent stage builds heavily on this | detailed          |
| Execute after explore                  | summary           |
| Execute after plan                     | detailed          |
| Verify after execute                   | summary           |

---

## Anti-Patterns to Avoid

1. **Over-engineering**: Don't add stages that aren't needed
2. **False dependencies**: Don't add `dependsOn` when stages are truly independent — this serializes
   work unnecessarily
3. **Missing dependencies**: Don't omit `dependsOn` when a stage needs another's output — this
   causes agents to work without necessary context
4. **Vague stage purposes**: Each stage should have clear, specific purpose
5. **Linear chains when DAG is possible**: If two explore stages don't need each other's output,
   they should have no mutual dependency

---

## Customization

These patterns are starting points. Adapt based on:

- Specific task requirements
- Codebase complexity
- User preferences
- Risk factors
- Time constraints

Scale stages and agents to match the task.
