---
name: tag-release
description: Create an annotated git tag in release-{env}-SHA-{sha} format and push it. Use after a confirmed successful deployment.
allowed-tools: Bash, Read
disable-model-invocation: true
argument-hint: "[dev|stg] [7-char-sha]"
---

Create and push an annotated release tag.

Use $ARGUMENTS:
- $0 = environment (must be "dev" or "stg" — reject anything else)
- $1 = 7-char commit SHA — if not provided, use: `git rev-parse --short=7 HEAD`

- [ ] Validate $0 is "dev" or "stg" — if not, STOP with usage message
- [ ] Resolve SHA: use $1 if provided, otherwise `git rev-parse --short=7 HEAD`
- [ ] Check tag does not already exist:
      `git tag -l "release-$0-SHA-$1"`
      If tag exists: STOP — "Tag already exists, tags are immutable — never overwrite"
- [ ] Create annotated tag:
      `git tag -a "release-$0-SHA-$1" -m "Deploy to $0 | sha=$1 | $(date -u)"`
- [ ] Push tag to origin:
      `git push origin "release-$0-SHA-$1"`
- [ ] Report: tag name, commit SHA it points to, timestamp

Never delete or overwrite an existing tag. Tags are permanent audit records.
