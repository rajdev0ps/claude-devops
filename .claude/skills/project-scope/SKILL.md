---
name: project-scope
description: Background knowledge about AWS service constraints and project conventions for this repository. Auto-loaded by Claude — not user-invocable.
user-invocable: false
---

## AWS Service Constraints for This Project

This is a static site hosted on S3 + CloudFront. Apply these constraints to
every suggestion involving AWS resources:

### Cost
- This is a POC — stay within AWS free tier where possible
- Do NOT suggest: WAF, WebACL, CloudFront managed rule groups (all cost money)
- Safe to suggest: CloudWatch alarms (10 free), SNS email (1000 free/month),
  S3 lifecycle rules (free), CloudFront response headers policy (free),
  AWS Budgets (2 free budgets per account)

### S3
- Site bucket is private — public access is always blocked
- Access is via CloudFront OAC only (sigv4 signing)
- Encryption: AES256 (SSE-S3)

### CloudFront
- Use OAC (Origin Access Control) — never legacy OAI
- HTTP must redirect to HTTPS (viewer_protocol_policy = redirect-to-https)
- Default root object: index.html
- 404 and 403 errors redirect to /index.html (SPA-style error handling)
- price_class = "PriceClass_100" (cheapest — US, Canada, Europe only)

### IAM / OIDC
- GitHub Actions uses OIDC — no long-lived access keys ever
- IAM roles must be scoped to specific repo AND branch
- Least privilege: only the permissions actually needed

### Terraform
- State backend: S3 + DynamoDB locking
- All resources tagged with common_tags from locals.tf
- Provider version pinned with ~> constraint
- Variables must have description, type, and validation where applicable

### Environments
- DEV and STG use the same AWS account (025760030746) for this POC
- Each environment has its own S3 bucket, CloudFront distribution, and IAM role
- State is stored under separate keys: {project}/{environment}/terraform.tfstate

### terraform destroy
- NEVER suggest or execute terraform destroy via any tool
- It is permanently blocked and must only be run manually via CLI
