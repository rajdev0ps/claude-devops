#!/bin/bash
# PostToolUse hook — records every terraform apply to the deploy log
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$CMD" | grep -q "terraform apply"; then
  OS_USER=$(whoami 2>/dev/null || echo "unknown")
  HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
  IAM_ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "unavailable")

  PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] terraform apply executed | user=${OS_USER} | host=${HOSTNAME} | iam=${IAM_ARN}" \
    >> "$PROJECT_ROOT/.claude/deploy.log"
fi
