#!/bin/bash
# UserPromptSubmit hook — catches destructive intent in user prompts
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')

if echo "$PROMPT" | grep -iqE "delete all|destroy everything|remove all resources|wipe|nuke|drop all"; then
  echo '{"decision": "block", "reason": "Destructive intent detected. Please use /tf-destroy for controlled infrastructure teardown."}'
fi
