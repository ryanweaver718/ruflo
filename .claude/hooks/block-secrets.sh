#!/bin/bash
# Block Claude from reading files that contain secrets.
# Secrets now live in Doppler — no .env or .dev.vars should exist on disk.
# This hook blocks any attempt to read/write/dump secret file patterns,
# query secrets via CLI tools, or dump environment variables.

# Get the tool input (JSON) from stdin
INPUT=$(cat)

# Extract the file path or command from the input
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
COMMAND=$(echo "$INPUT" | grep -o '"command"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')

# Patterns for secret files — ANY file matching these is blocked
SECRET_PATTERNS=('.env' '.dev.vars' 'credentials' '.pem' '.key' '.p8' '.cdn-derived-key' 'terraform.tfvars' 'firebase-private-key' '/certs/')

# Non-secret config files that match .env* — explicitly allowed
is_allowed_file() {
  local path="$1"
  [[ "$path" == *".env.production"* ]] && return 0
  [[ "$path" == *".env.staging"* ]] && return 0
  [[ "$path" == *".env.underground"* ]] && return 0
  [[ "$path" == *".env.development"* ]] && return 0
  [[ "$path" == *".env.example"* ]] && return 0
  [[ "$path" == *".env.tfvars.example"* ]] && return 0
  # block-secrets.sh itself should be readable
  [[ "$path" == *"block-secrets.sh"* ]] && return 0
  return 1
}

# Check file_path (Read/Edit/Write tools)
if [ -n "$FILE_PATH" ]; then
  for pattern in "${SECRET_PATTERNS[@]}"; do
    if [[ "$FILE_PATH" == *"$pattern"* ]]; then
      if is_allowed_file "$FILE_PATH"; then
        exit 0
      fi
      echo "BLOCKED: Cannot read/write secret files ($pattern). Secrets live in Doppler — use 'doppler secrets get KEY_NAME' to check values."
      exit 2
    fi
  done
fi

# Check Bash commands — block ANY command that references secret file patterns
if [ -n "$COMMAND" ]; then
  # Normalize: lowercase the command for case-insensitive matching on key patterns
  COMMAND_LOWER=$(echo "$COMMAND" | tr '[:upper:]' '[:lower:]')

  for pattern in "${SECRET_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qF "$pattern"; then
      # Allow commands that only reference the safe config files
      if echo "$COMMAND" | grep -qE "\.(env\.production|env\.staging|env\.underground|env\.development|env\.example|env\.tfvars\.example)"; then
        # But ONLY if they don't also reference a real secret file
        stripped=$(echo "$COMMAND" | sed -E 's/\.(env\.production|env\.staging|env\.underground|env\.development|env\.example|env\.tfvars\.example)//g')
        if ! echo "$stripped" | grep -qF "$pattern"; then
          exit 0
        fi
      fi
      echo "BLOCKED: Command references secret file pattern ($pattern). Secrets live in Doppler."
      exit 2
    fi
  done

  # =========================================================================
  # Block ALL Doppler access — ONLY 'doppler secrets --only-names' is allowed
  # =========================================================================
  #
  # Blocked: doppler secrets (bare — dumps all values)
  #          doppler secrets get/set/delete/upload/download (value access)
  #          doppler run (injects all secrets into subprocess)
  #          doppler configure (can leak project/config info)
  #          Any other doppler subcommand
  #
  # Allowed: doppler secrets --only-names (prints secret names, no values)
  #
  if echo "$COMMAND" | grep -qiE "doppler(\s|$)"; then
    # Allow the safe wrapper (redacts all secret values from output)
    if echo "$COMMAND" | grep -qE "doppler-safe-run\.sh"; then
      : # allowed — wrapper redacts all secret values before output reaches Claude
    # Only allow the exact pattern: doppler secrets --only-names (with optional -p/-c flags)
    elif echo "$COMMAND" | grep -qE "^doppler\s+secrets\s+--only-names(\s|$)"; then
      : # allowed — prints names only, no values
    elif echo "$COMMAND" | grep -qE "^doppler\s+secrets\s+(-[pc]\s+\S+\s+)*--only-names(\s|$)"; then
      : # allowed — with project/config flags before --only-names
    elif echo "$COMMAND" | grep -qE "^doppler\s+secrets\s+--only-names\s+(-[pc]\s+\S+\s*)*$"; then
      : # allowed — with project/config flags after --only-names
    else
      echo "BLOCKED: Cannot run Doppler commands from an AI session. Only 'doppler secrets --only-names' is allowed. Do everything else in a plain terminal."
      exit 2
    fi
  fi

  # =========================================================================
  # Block environment variable dumping commands
  # =========================================================================

  # Block: env, printenv, export (bare), set (bare), compgen -v, declare -x
  # These dump all environment variables which could contain injected secrets
  if echo "$COMMAND_LOWER" | grep -qE "(^|\||\;|\&\&|\$\()\s*(env|printenv)(\s|$|\|)"; then
    echo "BLOCKED: Cannot dump environment variables from an AI session — may expose secrets."
    exit 2
  fi
  # Block 'export' and 'export -p' with no arguments (dumps all exported vars)
  if echo "$COMMAND_LOWER" | grep -qE "(^|\||\;|\&\&|\$\()\s*export(\s+-p)?(\s*$|\s*\||\s*;|\s*&&)"; then
    echo "BLOCKED: Cannot dump exported variables from an AI session — may expose secrets."
    exit 2
  fi
  # Block 'set' with no arguments (dumps all shell variables)
  if echo "$COMMAND_LOWER" | grep -qE "(^|\||\;|\&\&|\$\()\s*set(\s*$|\s*\||\s*;)"; then
    echo "BLOCKED: Cannot dump shell variables from an AI session — may expose secrets."
    exit 2
  fi
  # Block compgen -v / compgen -e (lists variable names, can be used to fish for secrets)
  if echo "$COMMAND_LOWER" | grep -qE "compgen\s+-[ve]"; then
    echo "BLOCKED: Cannot enumerate shell variables from an AI session."
    exit 2
  fi
  # Block declare -x (dumps all exported variables with values)
  if echo "$COMMAND_LOWER" | grep -qE "declare\s+(-[a-zA-Z]*x|-x)"; then
    echo "BLOCKED: Cannot dump exported variables from an AI session — may expose secrets."
    exit 2
  fi

  # =========================================================================
  # Block echo/printf of secret variable references
  # =========================================================================

  # Block attempts to echo/printf/cat specific secret env vars
  if echo "$COMMAND" | grep -qE "(echo|printf|cat).*\\\$(CF_DEPLOY_TOKEN|CF_TERRAFORM_TOKEN|CF_API_TOKEN|CF_ACCESS_API_TOKEN|CLOUDFLARE_API_TOKEN|CF_BYPASS_SECRET|DEV_BYPASS_SECRET|CDN_MASTER_KEY|CACHE_PURGE_SECRET|AUDIO_HASH_SECRET)"; then
    echo "BLOCKED: Cannot print secret environment variables from an AI session."
    exit 2
  fi
  if echo "$COMMAND" | grep -qE "(echo|printf|cat).*\\\$\{(CF_DEPLOY_TOKEN|CF_TERRAFORM_TOKEN|CF_API_TOKEN|CF_ACCESS_API_TOKEN|CLOUDFLARE_API_TOKEN|CF_BYPASS_SECRET|DEV_BYPASS_SECRET|CDN_MASTER_KEY|CACHE_PURGE_SECRET|AUDIO_HASH_SECRET)"; then
    echo "BLOCKED: Cannot print secret environment variables from an AI session."
    exit 2
  fi

  # =========================================================================
  # Block other secret management CLIs
  # =========================================================================

  # Block wrangler secret list/get (exposes worker secrets)
  if echo "$COMMAND" | grep -qE "wrangler\s+secret\s+(list|get)"; then
    echo "BLOCKED: Cannot list/get worker secrets from an AI session. Do this in a plain terminal."
    exit 2
  fi

  # Block 1password, vault, aws secretsmanager, gcloud secrets, az keyvault
  if echo "$COMMAND_LOWER" | grep -qE "(^|\s)(op\s+(item|read|get)|vault\s+(kv|read|write)|aws\s+secretsmanager|gcloud\s+secrets|az\s+keyvault)"; then
    echo "BLOCKED: Cannot access secret management tools from an AI session."
    exit 2
  fi

  # =========================================================================
  # Block /proc and /dev access to environment (Linux containers)
  # =========================================================================

  if echo "$COMMAND" | grep -qE "/proc/[0-9]+/environ|/proc/self/environ"; then
    echo "BLOCKED: Cannot read process environment from /proc."
    exit 2
  fi

  # =========================================================================
  # Block git commands that could expose secrets from history
  # =========================================================================

  if echo "$COMMAND" | grep -qE "git\s+(log|show|diff).*\.(env|dev\.vars|tfvars|p8|pem|key)"; then
    echo "BLOCKED: Cannot access secret files from git history. Secrets have been rotated."
    exit 2
  fi
fi

exit 0
