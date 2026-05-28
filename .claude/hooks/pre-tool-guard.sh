#!/bin/bash
# PreToolUse hook — blocks dangerous Bash commands before they execute
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Debug: log hook invocations to a temp file (portable across machines)
echo "$(date): HOOK FIRED — CMD=$CMD" >> "${TMPDIR:-/tmp}/claude-hook-debug.log"

if echo "$CMD" | grep -qE "terraform destroy|terraform apply.*-auto-approve|aws s3 rm|aws s3 rb"; then
  echo '{"decision": "block", "reason": "Destructive command detected. Use /tf-destroy or /tf-apply commands for safety."}'
  exit 2
fi
