---
name: feedback-recurring-patterns
description: Infrastructure patterns that repeatedly surface as security gaps in IaC reviews for this project type
metadata:
  type: feedback
---

Patterns observed across two audits (2026-05-27 and 2026-05-28):

1. S3 bucket policies for CloudFront OAC frequently omit `aws:SourceArn` condition, making them overly permissive within the account.
2. CloudFront distributions almost never have a response headers policy configured — security headers (HSTS, CSP, X-Frame-Options) are consistently missing.
3. Terraform remote backend is left commented out in new scaffolding — state defaults to local with no encryption or locking.
4. Hardcoded resource identifiers (account IDs, distribution IDs, bucket names) appear in CI/CD workflow files alongside Terraform, even when Terraform itself is clean.
5. No .gitignore means .tfvars files with environment-specific resource IDs are committed to source control.
6. OIDC IAM roles are created out-of-band (not in Terraform), making trust policy scope unauditable from the codebase alone.
7. 403->200 custom error responses on CloudFront are a consistent pattern that masks authorization failures.
8. Hardcoded AWS account IDs surface in backend.tf state bucket names even when the rest of the code is clean — always check backend.tf separately.
9. CloudFront logging and S3 site-bucket logging are never enabled by default in this scaffold — consistently the last gap even after other HIGH issues are resolved.
10. WAF WebACL is never attached by default; lifecycle { ignore_changes = [web_acl_id] } is present but the WebACL itself is never created.

**Why:** These are common scaffolding-time omissions that are low-friction to add at creation but rarely retrofitted.
**How to apply:** Always check these ten areas first on any new audit of this project's infrastructure. Patterns 8-10 are newly confirmed as of Audit 2 (2026-05-28).
