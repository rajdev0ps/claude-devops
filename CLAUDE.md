# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Static HTML/CSS portfolio website deployed to AWS using S3 + CloudFront, provisioned with Terraform, and automated via GitHub Actions.

## Architecture

### Application (Static Site)
- **index.html** — Agentic AI Platform landing page (Navbar, Hero, Feature cards, Stats)
- **style.css** — All styling (~435 lines), mobile-first responsive (breakpoints: 1200px, 768px)
- **privacy.html / terms.html** — Standalone pages with inline styles
- **images/** — Static assets directory (currently empty; index.html references image.png at root)
- Pure HTML5 + CSS3, no JavaScript, no build step


### Infrastructure (`terraform/`)
- AWS S3 bucket for static site hosting (private, OAC-based access)
- CloudFront distribution as CDN with S3 origin
- GitHub OIDC provider + IAM role for keyless CI/CD auth
- Terraform state stored in S3 backend with DynamoDB locking
- All resources tagged with `Project` and `Environment`

### CI/CD (`.github/workflows/`)
- GitHub Actions workflow triggers on push to `main`
- Syncs site files to S3, then invalidates CloudFront cache
- Uses OIDC for AWS authentication (no long-lived keys)

## MCP Servers (`.mcp.json`)

> Config file: `.mcp.json` at project root. Enabled servers are listed in `.claude/settings.local.json` under `enabledMcpjsonServers`.

Two MCP servers are configured for Claude Code:
- **aws** (`awslabs.aws-api-mcp-server`) — Direct AWS API access for querying and managing resources
- **terraform** (`hashicorp/terraform-mcp-server`) — Terraform operations via Docker, workspace mounted at `/workspace`

AWS credentials and region are configured in `.claude/settings.local.json` (gitignored), not in `.mcp.json`. This keeps secrets out of version control and provides a single source of truth for all tools.

## Custom Agents (`.claude/agents/`)

This project has 7 specialized subagents. Use them by name when delegating tasks:
- **tf-writer** — generates Terraform code (Read/Write/Bash, runs fmt+validate after writing)
- **security-auditor** — audits TF for security issues (Read-only, Sonnet)
- **cost-optimizer** — reviews infra cost including absent price_class (Read-only, Haiku)
- **drift-detector** — detects state drift via terraform plan (Bash, Haiku)
- **release-manager** — git tagging + branch promotion release-dev→release-stg (Bash, Sonnet)
- **env-provisioner** — bootstraps new environment directories and checklists (Write, Sonnet)
- **pipeline-validator** — audits .github/workflows/*.yml for DevSecOps compliance (Read, Haiku)

## Skills (`.claude/skills/`)

All infrastructure and deployment tasks are handled via skills. Do not write Terraform or CI/CD code manually — use the appropriate skill. Action skills have `disable-model-invocation: true` (manual only). The `project-scope` skill has `user-invocable: false` (auto-loaded by Claude as background knowledge).

```
# Infrastructure
/scaffold-terraform [region] [name]  → Generate all Terraform files (uses tf-writer agent)
/scaffold-cicd [account-id] [env]    → Generate GitHub Actions workflow + OIDC IAM role
/tf-plan                             → Run terraform plan + risk analysis
/tf-apply                            → Run terraform apply + verify outputs
/infra-status                        → Health dashboard of all resources
/infra-audit                         → Parallel security + cost + drift audit (forked context)

# Deployment
/deploy                              → Sync S3 + invalidate CloudFront (current devtest env)
/validate-env [dev|stg]             → Pre-flight checks before deploying to an environment
/rollback [dev|stg]                  → Restore previous S3 version + invalidate CloudFront

# Release management
/promote [dev]                       → Merge release-dev → release-stg (with confirmation)
/tag-release [dev|stg] [sha]        → Create annotated release-{env}-SHA-{sha} git tag

# Environment management
/add-env [name]                      → Scaffold new environment directory + backend template
/setup-gh-actions [create|validate]  → Create or validate CI workflow

# AI / Claude Code
project-scope                        → Background knowledge: AWS constraints (auto-loaded)
/commit                              → Auto-generate commit message (built-in)
/compact                             → Compress long conversation context (built-in)

# NOTE: terraform destroy is ALWAYS blocked — run manually via CLI only
```

## Commands

```bash
# Terraform
cd terraform && terraform init
cd terraform && terraform plan
cd terraform && terraform apply

# Local preview
open index.html

# Manual S3 sync (CI does this automatically)
aws s3 sync . s3://$BUCKET_NAME --exclude "terraform/*" --exclude ".git/*" --exclude ".github/*" --exclude "*.md" --exclude ".claude/*"
```

## Safety Layers
1. **UserPromptSubmit hook** — catches destructive intent ("delete all", "nuke", "wipe") before Claude starts
2. **PreToolUse hook** — blocks dangerous commands (terraform destroy, aws s3 rm) at execution time
3. **Permissions** — auto-allows safe reads, blocks IAM and rm -rf
4. **PostToolUse hook** — logs all terraform apply executions to `.claude/deploy.log`

## Conventions
- Terraform files use `terraform/` directory with standard layout (main.tf, variables.tf, outputs.tf)
- GitHub Actions uses OIDC — no stored AWS access keys
- All infrastructure changes go through Terraform — never modify AWS resources manually
- Site content changes deploy automatically via GitHub Actions on push to main