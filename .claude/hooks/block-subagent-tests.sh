#!/bin/bash
# Block subagents from running test suites — only the top-level agent can run tests.
# Subagents running tests in parallel crash the machine.

# Subagents set CLAUDE_AGENT_DEPTH > 0
if [ "${CLAUDE_AGENT_DEPTH:-0}" -gt 0 ]; then
  INPUT=$(cat)
  COMMAND=$(echo "$INPUT" | grep -o '"command"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')

  if [ -n "$COMMAND" ]; then
    # Block test suite commands
    if echo "$COMMAND" | grep -qE "(npm run test|npm test|npx vitest|vitest run|jest|npm run.*test)"; then
      echo "BLOCKED: Subagents cannot run test suites — they crash the machine when run in parallel. Only the top-level agent can run tests."
      exit 2
    fi
  fi
fi

exit 0
