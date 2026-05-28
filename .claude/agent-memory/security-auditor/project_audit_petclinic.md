---
name: project-audit-petclinic
description: Security audit findings from terraform/ directory for petclinic-poc devtest environment, updated on second audit 2026-05-28
metadata:
  type: project
---

## Audit 1 — 2026-05-27 (original scaffold)

**CRITICAL**
- Hardcoded AWS account ID (533267262133) in deploy.yml line 24
- Hardcoded CloudFront distribution IDs (E155Q8VSBBEKPZ in tfvars line 5, E3V6O6MRE2E21P in deploy.yml line 43)
- Hardcoded S3 bucket name (pravinmishradmi-site-production) in deploy.yml line 29
- No .gitignore — terraform.tfvars (containing distribution IDs) is committed to source control
- Terraform remote state backend is commented out — state stored locally, no encryption, no locking

**HIGH**
- S3 bucket policy missing aws:SourceArn condition — any CloudFront distribution in account can read bucket
- No CloudFront security headers response policy (missing CSP, X-Frame-Options, HSTS, etc.)
- OIDC IAM role not defined in Terraform (out-of-band, not auditable); trust policy scope unknown
- CloudFront uses default certificate (*.cloudfront.net) with no WAF — no DDoS/bot protection
- S3 bucket versioning not enabled
- S3 bucket server-side encryption not explicitly configured

**MEDIUM**
- CloudFront access logging not enabled
- S3 access logging not enabled
- 403 errors silently rewritten to 200/index.html — masks real access-control errors
- lifecycle { ignore_changes = [web_acl_id] } prevents WAF from ever being tracked in state
- No variable validation on region, environment, project_name
- GitHub Actions workflow region (eu-north-1) does not match tfvars region (us-east-1)

**LOW**
- provider version pinned to ~> 5.0 (minor versions unpinned)
- No outputs.tf sensitive = true on ARN output (low risk, ARN is semi-public)

---

## Audit 2 — 2026-05-28 (current state of terraform/)

**Status of Audit 1 findings:**
- Remote state backend: FIXED (backend.tf active with encrypt=true and DynamoDB locking)
- OIDC IAM role: FIXED (fully defined in iam.tf with scoped trust policy)
- S3 encryption: FIXED (AES256 SSE configured on site_bucket)
- S3 public access block: FIXED (all four flags enabled)
- OAC: FIXED (OAC used, not legacy OAI)
- aws:SourceArn condition in bucket policy: FIXED
- S3 versioning on site bucket: STILL MISSING
- CloudFront security headers: STILL MISSING
- CloudFront access logging: STILL MISSING
- S3 access logging on site bucket: STILL MISSING
- 403->200 custom error response: STILL PRESENT

**New CRITICAL findings (Audit 2):**
- backend.tf line 3: hardcoded AWS account ID (025760030746) in state bucket name

**New HIGH findings (Audit 2):**
- S3 site bucket: no versioning resource — deleted objects are unrecoverable
- No CloudFront response headers policy — security headers (HSTS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy) entirely absent
- No WAF WebACL attached to CloudFront — no rate limiting or bot protection

**New MEDIUM findings (Audit 2):**
- CloudFront access logging not enabled (no logging_config block)
- S3 site bucket logging not enabled
- terraform_logs bucket: bucket_key_enabled missing on SSE config (cost/performance, minor)
- S3 versioning on state bucket uses StringEquals status "Enabled" but MFA delete not enabled
- 403->200 rewrite still present (masks access-control errors)
- lifecycle { ignore_changes = [web_acl_id] } prevents WAF association from ever being tracked
- No variable validation blocks (region, environment, project_name)

**New LOW findings (Audit 2):**
- github_actions_role_arn output not marked sensitive=true (ARN exposes account ID)
- provider pinned to ~> 5.0 (patch versions float)
- No Environment tag on aws_s3_bucket_policy or aws_cloudfront_origin_access_control

**Why:** Backend and IAM are now well-structured. Remaining gap is entirely in observability (logging) and defense-in-depth (WAF, headers, versioning).
**How to apply:** Future audits should focus on logging, response headers policy, and WAF attachment as the last open risk surface for this project.
