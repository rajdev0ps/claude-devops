#!/bin/bash
# LOG hook — records every terraform apply to the deploy log

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$CMD" | grep -q "terraform apply"; then
  OS_USER=$(whoami 2>/dev/null || echo "unknown")
  HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
  IAM_ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "unavailable")

  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] terraform apply executed | user=${OS_USER} | host=${HOSTNAME} | iam=${IAM_ARN}" \
    >> 'S:/devops/Ultimate-Agentic-DevOps-with-Claude-Code/.claude/deploy.log'
fi
