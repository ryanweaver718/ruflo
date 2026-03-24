#!/bin/bash
# doppler-safe-run.sh — Run a command under doppler with secret redaction.
#
# Usage: .claude/hooks/doppler-safe-run.sh <command> [args...]
#
# 1. Fetches all Doppler secret VALUES
# 2. Builds a sed script that replaces every value with [REDACTED]
# 3. Runs `doppler run -- <command> [args...]`
# 4. Pipes stdout+stderr through the redaction filter
#
# This lets Claude run scripts that need R2/API credentials
# without ever seeing the actual secret values in output.

set -euo pipefail

# Ensure PATH includes brew paths (bash doesn't load shell profile)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if [ $# -eq 0 ]; then
  echo "Usage: doppler-safe-run.sh <command> [args...]"
  exit 1
fi

# --- Build redaction filter from Doppler secret values ---
# doppler secrets download outputs JSON: {"KEY": "value", ...}
# We extract values, escape them for sed, and build a replacement script.
REDACT_SED=$(mktemp)
trap 'rm -f "$REDACT_SED"' EXIT

# Use a subshell so pipefail doesn't abort the whole script if doppler fails
(doppler secrets download --no-file --format json 2>/dev/null || echo '{}') | \
  python3 -c "
import json, sys, re

raw = sys.stdin.read()
if not raw.strip():
    sys.exit(0)
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(0)
for key, val in data.items():
    val = str(val)
    # Skip empty values and very short ones (would cause false positives)
    if len(val) < 6:
        continue
    # Use | as sed delimiter to avoid issues with / in values
    # Escape: backslash first, then | and & (sed specials with | delimiter)
    escaped = val.replace('\\\\', '\\\\\\\\')
    escaped = escaped.replace('|', '\\\\|')
    escaped = escaped.replace('&', '\\\\&')
    # Escape regex metacharacters
    for ch in '.[]^*+?(){}$':
        escaped = escaped.replace(ch, '\\\\' + ch)
    # Skip if escaping produced something problematic
    if '\\n' in escaped or '\\r' in escaped:
        continue
    print(f's|{escaped}|[REDACTED]|g')
" > "$REDACT_SED"

# --- Run the command under doppler, filter output ---
doppler run -- "$@" 2>&1 | sed -l -f "$REDACT_SED"
