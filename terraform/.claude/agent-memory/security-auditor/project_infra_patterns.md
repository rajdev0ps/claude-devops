---
name: project-infra-patterns
description: Recurring security patterns and known issues observed across audits of this project's Terraform and GitHub Actions configuration
metadata:
  type: project
---

This project uses S3 + CloudFront for a static site with GitHub OIDC for keyless CI/CD. Core infrastructure: main.tf, iam.tf, backend-infrastructure.tf, backend.tf, providers.tf, variables.tf, outputs.tf. GitHub Actions workflow: .github/workflows/deploy.yml.

**Known persistent findings as of 2026-05-27:**

1. Hardcoded AWS account ID (`025760030746`) in `backend.tf` line 3 — bucket name embeds real account ID in plain text.
2. CloudFront `viewer_certificate` uses `cloudfront_default_certificate = true` with no `minimum_protocol_version` set — defaults to TLSv1, which is deprecated; no `ssl_support_method` specified.
3. No CloudFront `logging_config` block — CloudFront access logs are not being captured.
4. No `aws_s3_bucket_versioning` on the site bucket (`aws_s3_bucket.site_bucket`) — accidental overwrites are not recoverable.
5. No CloudFront response headers policy — security headers (CSP, X-Frame-Options, HSTS, etc.) are not enforced.
6. OIDC trust policy uses `StringLike` for the `sub` claim — acceptable for branch-scoped deployments but note: `StringLike` allows wildcard expansion; the value here is exact so risk is low, but `StringEquals` would be stricter.
7. GitHub Actions action versions pinned to tag (`@v4`) not commit SHA — supply-chain risk if tag is moved.
8. `lifecycle { ignore_changes = [web_acl_id] }` on CloudFront — WAF not attached; ignore_changes silences plan noise but WAF remains absent.

**Confirmed secure (post-remediation):**
- All S3 public access blocks enabled (4-of-4 flags) on all buckets.
- OAC used (not legacy OAI) with sigv4 signing.
- HTTP→HTTPS redirect enforced (`redirect-to-https`).
- S3 bucket policy scoped to specific CloudFront distribution ARN via Condition.
- IAM policy scoped to specific S3 bucket ARN and specific CloudFront distribution ARN — no wildcards in actions or resources.
- OIDC trust policy scoped to specific repo (`rajdev0ps/Ultimate-Agentic-DevOps-with-Claude-Code`) and branch (`refs/heads/main`).
- No hardcoded credentials or secret keys.
- State bucket: versioning enabled, encryption enabled, public access blocked, access logging enabled.
- DynamoDB locks table: encryption enabled, PITR enabled.
- GitHub Actions uses OIDC (no long-lived keys), least-privilege workflow permissions (`id-token: write`, `contents: read`).

**Why:** Captures the delta between "confirmed safe" and "remaining findings" so future audits can focus efficiently on open issues.
**How to apply:** Use as a baseline to diff against. Any new resource additions should be checked against confirmed-secure patterns for parity.
