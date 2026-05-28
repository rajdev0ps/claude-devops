---
name: feedback_backend-partial-config
description: backend.tf must use an empty backend "s3" block; all values go in terraform/backend.hcl which is gitignored
metadata:
  type: feedback
---

Always use a partial backend configuration for this project. `backend.tf` contains only an empty `backend "s3" {}` block. All real values (bucket, key, region, encrypt, dynamodb_table) live in `terraform/backend.hcl`.

**Why:** The bucket name embeds the AWS account ID. Hardcoding it in `backend.tf` leaks the account ID into version control (CRIT-01 security finding).

**How to apply:** When writing or updating `backend.tf`, never populate the `backend "s3"` block. Remind the developer to run `terraform init -backend-config=backend.hcl` instead of plain `terraform init`. Ensure `terraform/backend.hcl` is listed in `.gitignore` under the `# Sensitive` section.
