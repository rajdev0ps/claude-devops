---
name: rollback
description: Roll back site content to the previous S3 object version and re-invalidate CloudFront. Use when a bad deploy needs reverting.
allowed-tools: Bash, Read
disable-model-invocation: true
argument-hint: "[dev|stg]"
---

Roll back site content for $0 environment using S3 object versioning.

- [ ] Get bucket name:
      `cd terraform && terraform output -raw s3_bucket_name`
- [ ] Get CloudFront distribution ID:
      `cd terraform && terraform output -raw cloudfront_distribution_id`
- [ ] Check versioning is active (list last 5 versions of index.html):
      `aws s3api list-object-versions --bucket <bucket> --prefix index.html --max-items 5`
- [ ] If no versions found: STOP — report "S3 versioning not active, rollback not possible"
- [ ] Show the last 3 versions with LastModified dates — ask engineer to confirm which version to restore
- [ ] Restore each changed file using the chosen version ID:
      `aws s3api copy-object \
        --bucket <bucket> \
        --copy-source "<bucket>/<key>?versionId=<prev-version-id>" \
        --key <key>`
      Repeat for: index.html, style.css, privacy.html, terms.html
- [ ] Invalidate CloudFront cache:
      `aws cloudfront create-invalidation --distribution-id <id> --paths "/*"`
- [ ] Report: files restored, CloudFront invalidation ID, version ID used

STOP immediately on any error. Never proceed past a failed step.
Do NOT run terraform destroy under any circumstances.
