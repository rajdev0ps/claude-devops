---
name: scaffold-cicd
description: Generate GitHub Actions deploy workflow and OIDC IAM role for a given environment. Use when setting up CI/CD for a new environment.
allowed-tools: Read, Write, Glob
disable-model-invocation: true
argument-hint: "[aws-account-id] [environment]"
---

Generate GitHub Actions workflow and supporting documentation for deploying
to AWS using OIDC (no long-lived access keys).

Use $ARGUMENTS for required values:
- $0 = AWS account ID (12-digit number)
- $1 = environment name (dev or stg)

## What to Generate

1. `.github/workflows/deploy-{environment}.yml`
   - Trigger: push to branch `release-{environment}`
   - Steps: checkout → OIDC auth → S3 sync → CloudFront invalidation
   - Uses GitHub secrets: AWS_ROLE_ARN_{ENV} (uppercase)
   - Uses GitHub vars: S3_BUCKET_NAME_{ENV}, CLOUDFRONT_DISTRIBUTION_ID_{ENV}

2. Print post-generation checklist:
   - [ ] Add AWS_ROLE_ARN_{ENV} to GitHub repository secrets
   - [ ] Add S3_BUCKET_NAME_{ENV} to GitHub repository variables
   - [ ] Add CLOUDFRONT_DISTRIBUTION_ID_{ENV} to GitHub repository variables
   - [ ] Run terraform apply for the environment to provision the IAM OIDC role
   - [ ] Push a commit to release-{environment} to trigger the first deploy

## Rules
- Never hardcode AWS account IDs, bucket names, or distribution IDs in the workflow
- Always use GitHub secrets/vars for all environment-specific values
- OIDC auth only — never suggest storing AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY
- Pin all GitHub Actions to a specific version tag (e.g. actions/checkout@v4)
