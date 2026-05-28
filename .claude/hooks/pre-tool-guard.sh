#!/bin/bash
# DO hook — blocks dangerous Bash commands before they execute

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Debug: log every invocation to verify hook is firing
echo "$(date): HOOK FIRED — CMD=$CMD" >> /c/Users/raj/hook-debug.log

if echo "$CMD" | grep -qE "terraform destroy|terraform apply.*-auto-approve|aws s3 rm|aws s3 rb"; then
  echo '{"decision": "block", "reason": "Destructive command detected. Use /tf-destroy or /tf-apply commands for safety."}'
  exit 2
fi
