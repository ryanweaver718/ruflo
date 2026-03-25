#!/bin/bash
# Hook: Block destructive git operations
# PreToolUse on Bash — prevents force push, hard reset, clean -f

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

[ -z "$COMMAND" ] && exit 0

if echo "$COMMAND" | grep -qE 'git\s+commit|git\s+push'; then
  echo '{"decision":"block","reason":"BLOCKED: Claude must NEVER commit or push. Only the user commits and pushes."}'
  exit 2
fi

if echo "$COMMAND" | grep -qE 'git\s+(checkout\s+-b|switch\s+-c|branch\s+[^-])'; then
  echo '{"decision":"block","reason":"BLOCKED: Claude must NEVER create branches. Only the user creates branches."}'
  exit 2
fi

if echo "$COMMAND" | grep -qE 'git\s+push.*--force|git\s+push.*-f\b|git\s+reset\s+--hard|git\s+clean\s+-f|git\s+branch\s+-D'; then
  echo "BLOCKED: Destructive git operation detected. Ask the user first."
  exit 2
fi

# Block doppler secrets get — values would be exposed in conversation context
if echo "$COMMAND" | grep -qE 'doppler\s+secrets\s+get'; then
  echo '{"decision":"block","reason":"Blocked: do not query Doppler secrets via CLI — values would be exposed in conversation context."}'
  exit 2
fi

exit 0
