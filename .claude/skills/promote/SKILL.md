---
name: promote
description: Promote release-dev to release-stg by merging the branch. Use after DEV has been verified and is ready for staging.
allowed-tools: Bash, Read
disable-model-invocation: true
argument-hint: "[dev]"
---

Promote release-dev → release-stg.

- [ ] Show what will be promoted:
      `git log release-stg..release-dev --oneline`
- [ ] If no commits ahead: STOP — report "Nothing to promote, release-dev is already merged into release-stg"
- [ ] Show the N commits that will be promoted
- [ ] Ask for explicit confirmation: "Promote these N commits to STG? (yes/no)"
      Do NOT proceed without a yes answer
- [ ] On confirmation:
      ```
      git checkout release-stg
      git merge release-dev --no-ff -m "Promote release-dev to release-stg"
      git push origin release-stg
      git checkout main
      ```
- [ ] Report: number of commits promoted, new HEAD SHA of release-stg, link to STG deploy workflow

Never force-push any branch. STOP on any error and report it.
Do NOT run terraform destroy under any circumstances.
