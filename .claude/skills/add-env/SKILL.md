---
name: add-env
description: Scaffold a new environment directory with ci.tfvars and backend.hcl.example. Delegates to the env-provisioner agent.
allowed-tools: Read, Write, Glob, Bash
disable-model-invocation: true
argument-hint: "[environment-name]"
---

Scaffold a new environment using the env-provisioner agent.

Use $ARGUMENTS:
- $0 = environment name (e.g. prod, uat)

- [ ] Validate $0 is provided — if missing, print usage and STOP:
      "Usage: /add-env [environment-name]  e.g. /add-env prod"
- [ ] Validate $0 is not already "dev" or "stg" (those already exist)
- [ ] Check environments/$0/ does not already exist — if it does, STOP:
      "Environment $0 already exists at environments/$0/"
- [ ] Use the env-provisioner agent to:
        - Create environments/$0/ci.tfvars
        - Create environments/$0/backend.hcl.example
        - Print full engineer checklist for remaining manual steps
- [ ] List all files created under environments/$0/
- [ ] Remind the engineer:
      "Run /validate-env $0 after completing the manual checklist steps before deploying"
