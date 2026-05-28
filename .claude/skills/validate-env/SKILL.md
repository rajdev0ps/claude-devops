---
name: validate-env
description: Pre-flight checks for an environment before deploying — validates credentials, S3, CloudFront, Terraform state, and local config files.
allowed-tools: Bash, Read, Glob
disable-model-invocation: true
argument-hint: "[dev|stg]"
---

Run pre-flight checks for $0 environment. Report PASS/FAIL for each check.

Use $ARGUMENTS:
- $0 = environment name (dev or stg)

Checks:
- [ ] Local: environments/$0/ci.tfvars exists
- [ ] Local: environments/$0/backend.hcl exists
      (this file is gitignored — must be created manually from backend.hcl.example)
- [ ] AWS credentials:
      `aws sts get-caller-identity`
- [ ] Terraform init:
      `cd terraform && terraform init -backend-config=../environments/$0/backend.hcl -reconfigure`
- [ ] S3 bucket accessible:
      `aws s3 ls s3://$(cd terraform && terraform output -raw s3_bucket_name 2>/dev/null)`
- [ ] CloudFront deployed:
      `aws cloudfront get-distribution \
        --id $(cd terraform && terraform output -raw cloudfront_distribution_id 2>/dev/null) \
        --query "Distribution.Status" --output text`
      Expected value: "Deployed"

Print a summary table:
  Check                      | Result
  ---------------------------|-------
  ci.tfvars present          | PASS/FAIL
  backend.hcl present        | PASS/FAIL
  AWS credentials valid      | PASS/FAIL
  Terraform state reachable  | PASS/FAIL
  S3 bucket accessible       | PASS/FAIL
  CloudFront deployed        | PASS/FAIL

For each FAIL: print the exact cause and the fix required.
All checks must PASS before proceeding with a deploy.
