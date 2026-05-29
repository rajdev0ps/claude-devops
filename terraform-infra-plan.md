# Terraform Infrastructure Plan — Production Grade
## Research synthesis from 8 production references | AWS only | No Terragrunt

---

## Table of Contents

1. [Decision Matrix — Which Pattern to Use](#1-decision-matrix)
2. [Pattern A — Flat Files (Current State)](#2-pattern-a-flat-files)
3. [Pattern B — Modules + Environment Directories (Recommended)](#3-pattern-b-modules--environment-directories)
4. [Pattern C — Layered / Staged Architecture (EKS-Ready)](#4-pattern-c-layered--staged-architecture)
5. [Pattern D — Two-Repo Modules Split](#5-pattern-d-two-repo-modules-split)
6. [State Management Patterns](#6-state-management-patterns)
7. [Branching Strategy](#7-branching-strategy)
8. [CI/CD Pipeline Architecture](#8-cicd-pipeline-architecture)
9. [EKS-Specific Terraform Patterns](#9-eks-specific-terraform-patterns)
10. [Naming Conventions](#10-naming-conventions)
11. [Variable & Secret Management](#11-variable--secret-management)
12. [Security Non-Negotiables](#12-security-non-negotiables)
13. [Tool Stack](#13-tool-stack)
14. [Questions to Answer Before Phase B](#14-questions-to-answer-before-phase-b)
15. [Recommended Path Forward for This Project](#15-recommended-path-forward-for-this-project)

---

## 1. Decision Matrix

Choose the right pattern based on team size, environment count, and complexity:

```
Team Size     Environments    Complexity     Recommended Pattern
─────────────────────────────────────────────────────────────────
1–5 people    2–3             Low            A: Flat Files + Workspaces
1–5 people    2–4             Medium         B: Modules + Env Directories  ◄ YOU ARE HERE
5–25 people   2–12            Medium–High    B or C: Layered Architecture
10+ people    Any (EKS)       High           C: Layered / Staged Architecture
20+ people    10+             Very High      D: Two-Repo Split (Modules + Live)
```

**Key triggers to upgrade pattern:**
- Adding EKS → move to Pattern C (layered stages)
- Adding RDS, ElastiCache, more services → move to Pattern C
- Second team contributing infrastructure → move to Pattern B minimum
- Separate accounts per env → Pattern B/C with isolated backends
- 10+ environments → evaluate Pattern D (Terragrunt territory but achievable with plain TF)

---

## 2. Pattern A — Flat Files (Current State)

What you have now. Good for bootstrapping, not production.

```
terraform/
├── main.tf                     ← S3 + CloudFront mixed together
├── backend-infrastructure.tf   ← State bucket mixed with app infra
├── iam.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── backend.tf
├── locals.tf
├── monitoring.tf
├── budget.tf
└── [no modules directory]
```

### Diagram

```
┌─────────────────────────────────────┐
│           terraform/                │
│  ┌──────────────────────────────┐   │
│  │  main.tf                     │   │
│  │  (S3 + CloudFront + OAC +    │   │
│  │   lifecycle all in one file) │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │  backend-infrastructure.tf   │   │
│  │  (State S3 + DynamoDB)       │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │  iam.tf  monitoring.tf       │   │
│  │  budget.tf  locals.tf        │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
         All in one flat directory
         No module isolation
         No reusability
```

### Problems
- Cannot reuse S3+CloudFront logic for another project or environment variant
- `backend-infrastructure.tf` should be a one-time bootstrap, not alongside app infra
- Growing resource count will make this flat structure unmaintainable
- No way to version the static-site pattern independently
- `terraform apply` changes everything — no targeted component deploys

### When Pattern A is acceptable
- Solo dev, POC, <5 resources, throw-away infrastructure

---

## 3. Pattern B — Modules + Environment Directories (Recommended)

**Best fit for this project today.** Reusable modules + clean per-environment directories.

### Directory Structure

```
claude-devops/
├── .github/
│   └── workflows/
│       ├── deploy-dev.yml
│       └── deploy-stg.yml
│
├── environments/
│   ├── dev/
│   │   ├── main.tf           ← calls modules, dev-specific config
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── ci.tfvars         ← committed, no secrets
│   │   ├── terraform.tfvars  ← gitignored, full values
│   │   └── backend.hcl       ← gitignored, state config
│   └── stg/
│       └── [same structure]
│
├── terraform/
│   ├── modules/
│   │   ├── static-site/      ← S3 + CloudFront + OAC
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── versions.tf
│   │   └── state-backend/    ← State S3 + DynamoDB (bootstrap once)
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── versions.tf
│   │
│   ├── iam.tf                ← GitHub OIDC roles (env-specific, stays at root)
│   ├── monitoring.tf         ← CloudWatch + SNS (env-specific, stays at root)
│   ├── budget.tf             ← AWS Budget (env-specific, stays at root)
│   ├── locals.tf             ← common_tags
│   ├── variables.tf          ← all input variables
│   ├── outputs.tf            ← references module outputs
│   ├── providers.tf
│   └── backend.tf
│
└── docs/
    ├── project.txt
    └── terraform-infra-plan.md
```

### Diagram

```
environments/dev/main.tf
       │
       │  module "static_site" { source = "../../terraform/modules/static-site" }
       │  module "state_backend" { source = "../../terraform/modules/state-backend" }
       │
       ▼
terraform/modules/
  ┌─────────────────────┐   ┌──────────────────────┐
  │   static-site/      │   │   state-backend/      │
  │                     │   │                       │
  │  aws_s3_bucket      │   │  aws_s3_bucket        │
  │  aws_cloudfront_    │   │  (terraform state)    │
  │    distribution     │   │  aws_dynamodb_table   │
  │  aws_cloudfront_oac │   │  (locks)              │
  │  aws_s3_bucket_     │   │                       │
  │    lifecycle        │   │                       │
  └─────────────────────┘   └──────────────────────┘
         Reusable                   Bootstrap
         Versioned                  Run once
         Testable
```

### How environments/dev/main.tf looks

```hcl
# environments/dev/main.tf

terraform {
  required_version = ">= 1.5, < 2.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {}   # values from backend.hcl
}

provider "aws" {
  region = var.region
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner_team
    CostCenter  = var.cost_center
    Repository  = var.github_repo
  }
}

module "static_site" {
  source = "../../terraform/modules/static-site"

  project_name           = var.project_name
  environment            = var.environment
  common_tags            = local.common_tags
  cloudfront_price_class = var.cloudfront_price_class
}
```

### Benefits vs Pattern A
- Module can be reused for a second CDN endpoint (e.g. admin site)
- `terraform plan` in `environments/dev/` only affects DEV
- Module version can be pinned via `?ref=v1.2.0` Git tags
- Unit testable (Terratest can deploy just the module)
- `backend-infrastructure.tf` isolated in its own module, run once

---

## 4. Pattern C — Layered / Staged Architecture (EKS-Ready)

**Use this when adding EKS, RDS, or multiple interconnected services.**
Different infrastructure layers deployed independently with remote state chaining.

### Directory Structure

```
claude-devops/
├── terraform/
│   ├── 01-foundation/          ← State backend (run ONCE, all envs share this layer)
│   │   ├── main.tf             (S3 state bucket, DynamoDB, KMS key)
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── backend.tf          (local state only — bootstraps everything else)
│   │
│   ├── 02-networking/          ← VPC, Subnets, IGW, NAT, SGs
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── backend.tf          (remote state: networking/{env}/terraform.tfstate)
│   │
│   ├── 03-eks-cluster/         ← EKS cluster, node groups, OIDC provider, IAM
│   │   ├── main.tf
│   │   ├── node-groups.tf
│   │   ├── addons.tf
│   │   ├── iam.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── backend.tf          (remote state: eks/{env}/terraform.tfstate)
│   │
│   ├── 04-eks-addons/          ← Helm charts: LB controller, External Secrets, ArgoCD
│   │   ├── lb-controller.tf
│   │   ├── external-secrets.tf
│   │   ├── argocd.tf
│   │   ├── karpenter.tf
│   │   ├── variables.tf
│   │   └── backend.tf          (remote state: eks-addons/{env}/terraform.tfstate)
│   │
│   ├── 05-static-site/         ← S3 + CloudFront (current project)
│   │   ├── main.tf
│   │   ├── iam.tf
│   │   ├── monitoring.tf
│   │   ├── budget.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── backend.tf
│   │
│   └── modules/                ← Reusable building blocks
│       ├── vpc/
│       ├── eks-cluster/
│       ├── eks-irsa-role/      ← IRSA pattern module (used by every AWS-integrated pod)
│       ├── static-site/
│       └── state-backend/
│
└── environments/
    ├── dev/
    │   ├── 02-networking.tfvars
    │   ├── 03-eks-cluster.tfvars
    │   └── 05-static-site.tfvars
    └── stg/
        └── [same]
```

### Diagram — Remote State Chaining

```
  01-foundation/          02-networking/           03-eks-cluster/
  ┌─────────────┐         ┌─────────────┐          ┌─────────────┐
  │ State S3    │◄────────│ reads state │   ┌──────│ reads state │
  │ DynamoDB    │         │             │   │      │             │
  │ (local TF)  │         │ VPC ID      │───┤      │ EKS cluster │
  └─────────────┘         │ Subnet IDs  │   │      │ Node groups │
                          │ SG IDs      │   │      │ OIDC        │
                          └─────────────┘   │      └─────────────┘
                                 ▲          │             ▲
                                 │          │             │
                          environment       │      environment
                          /dev/ tfvars      │      /dev/ tfvars
                                            │
                                     04-eks-addons/
                                     ┌─────────────┐
                                     │ reads EKS   │
                                     │ outputs     │
                                     │             │
                                     │ LB Ctrl     │
                                     │ Ext Secrets │
                                     │ ArgoCD      │
                                     └─────────────┘

                      State files per layer per environment:
                      s3://state-bucket/
                      ├── networking/dev/terraform.tfstate
                      ├── networking/stg/terraform.tfstate
                      ├── eks/dev/terraform.tfstate
                      ├── eks/stg/terraform.tfstate
                      ├── eks-addons/dev/terraform.tfstate
                      └── static-site/dev/terraform.tfstate
```

### Remote State Data Source (EKS reading VPC)

```hcl
# In 03-eks-cluster/main.tf
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "terraform-state-${data.aws_caller_identity.current.account_id}-us-east-1"
    key    = "networking/${var.environment}/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_eks_cluster" "main" {
  name = "${var.project_name}-${var.environment}"
  vpc_config {
    subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids
  }
}
```

### Apply Order
```
terraform apply 01-foundation/   (once only)
terraform apply 02-networking/   (dev, then stg)
terraform apply 03-eks-cluster/  (depends on 02)
terraform apply 04-eks-addons/   (depends on 03)
terraform apply 05-static-site/  (independent — can run in parallel with 03+)
```

---

## 5. Pattern D — Two-Repo Modules Split

**For large teams (20+ engineers), multiple product teams using shared modules.**
Keep this in mind for future — do NOT implement until team grows.

```
github.com/your-org/terraform-modules/    ← Versioned reusable modules only
  modules/
    vpc/          v1.2.0
    eks-cluster/  v2.0.1
    static-site/  v1.5.0
    rds/          v1.0.0

github.com/your-org/infra-live/           ← Actual environment deployments
  environments/
    dev/
      main.tf   ← references modules by git tag
    stg/
    prod/
```

### Module versioning via Git tags

```hcl
module "vpc" {
  source = "git::https://github.com/your-org/terraform-modules.git//vpc?ref=vpc-v1.2.0"
  # Production pins exact tag
  # Dev can test: ?ref=vpc-v1.3.0-beta
}
```

### Diagram

```
terraform-modules repo                    infra-live repo
  ┌────────────────────┐                  ┌────────────────────────┐
  │ modules/           │                  │ environments/prod/      │
  │   vpc/ [v1.2.0]    │◄─────────────────│   source = ?ref=v1.2.0 │
  │   eks/ [v2.0.1]    │◄─────────────────│   source = ?ref=v2.0.1 │
  │   rds/ [v1.0.0]    │                  └────────────────────────┘
  └────────────────────┘                  ┌────────────────────────┐
  Tagged, versioned,                      │ environments/dev/       │
  tested independently                    │   source = ?ref=v1.3.0  │◄─ test new
  Via Release Please                      └────────────────────────┘    version
  Conventional Commits
```

**When to switch:** When multiple teams contribute modules, when you need staggered rollouts
(prod stays on v1.2.0 while dev/stg test v1.3.0), or when module count exceeds ~10.

---

## 6. State Management Patterns

### Single Backend per Environment (Current — Correct)

```
s3://terraform-state-{account-id}-{region}/
├── petclinic-poc/dev/terraform.tfstate
├── petclinic-poc/stg/terraform.tfstate
└── petclinic-poc/devtest/terraform.tfstate
```

### Multi-Layer Backend (Pattern C — EKS)

```
s3://terraform-state-{account-id}-{region}/
├── networking/dev/terraform.tfstate
├── networking/stg/terraform.tfstate
├── eks/dev/terraform.tfstate
├── eks/stg/terraform.tfstate
├── eks-addons/dev/terraform.tfstate
└── static-site/dev/terraform.tfstate
```

### State Key Naming Convention

```
{layer}/{environment}/terraform.tfstate

Examples:
  networking/dev/terraform.tfstate
  eks-cluster/dev/terraform.tfstate
  static-site/stg/terraform.tfstate
```

**CRITICAL RULE:** Every environment MUST have a unique state key.
Copy-paste of `backend.hcl` without updating the key is a top real-world disaster cause.
[Source: burakdede.com war stories — 4-hour prod rollback from this exact mistake]

### DynamoDB Lock Table

One table per AWS account is sufficient:
```hcl
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  server_side_encryption { enabled = true }
  point_in_time_recovery { enabled = true }
}
```

### Separate State Buckets per Account (Multi-Account)

When DEV and STG are in different AWS accounts:
```
Account A (DEV):  s3://terraform-state-{dev-account-id}-us-east-1/
Account B (STG):  s3://terraform-state-{stg-account-id}-us-east-1/
```

Physical impossibility of cross-account state contamination by design.
[Source: bohobot.com — core reason for separate backend per account]

---

## 7. Branching Strategy

### Simple (Current Project — Static Site)

```
main
  │
  ├──► feature/xyz ──► PR ──► main
  │
  ├──► release-dev  ──► auto-deploy to DEV
  │          │
  └──► release-stg  ──► manual-approve ──► deploy to STG
```

### Full (Adding EKS + Multiple Services)

```
feature/*  →  develop     →  staging     →  main
              (DEV auto)     (STG auto,      (PROD manual,
                              1 approval)     2 approvals)
```

### Trunk-Based (Recommended for IaC)

```
feature/* → main  (very short-lived branches, hours not days)
                │
                ├── path filter: environments/dev/**  → deploy dev
                └── path filter: environments/stg/**  → deploy stg
                                                          (manual approval)
```

**Trunk-based reduces merge conflicts** in infrastructure code — critical when
multiple engineers modify the same `.tf` files.
[Source: bohobot.com — "Scaled Trunk-Based Development"]

### Branch Protection Rules

| Branch | Min reviews | Checks required | Force push |
|---|---|---|---|
| main | 2 | CI must pass | Blocked |
| release-stg | 1 | CI must pass | Blocked |
| release-dev | 0 | CI must pass | Blocked |
| feature/* | 0 | None | Allowed |

---

## 8. CI/CD Pipeline Architecture

### Gold Standard Pipeline (every PR + every merge)

```
┌──────────────────────────────────────────────────────────────────────┐
│                          EVERY PR (validate)                         │
│                                                                      │
│  checkout → setup-terraform → fmt-check → validate → tflint →       │
│  checkov → tfsec → gitleaks                                          │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
                              │ passes
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      PR OPEN (plan)                                  │
│                                                                      │
│  OIDC auth → tf init (backend-config) →                              │
│  tf plan -out=tfplan.binary →                                        │
│  infracost diff (cost delta) →                                       │
│  upload plan artifact →                                              │
│  post plan summary to PR                                             │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
                              │ PR merged
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    MERGE TO BRANCH (apply)                           │
│                                                                      │
│  download plan artifact →                                            │
│  OIDC auth →                                                         │
│  tf init (same backend-config) →                                     │
│  tf apply tfplan.binary  ← NEVER re-run plan here                   │
│  tf output (capture for verify step)                                 │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
                              │ apply succeeded
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│                         VERIFY                                       │
│                                                                      │
│  HTTP smoke test → CF status check → git tag release-{env}-SHA-{sha}│
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Key CI/CD Non-Negotiables

1. **OIDC only** — never `AWS_ACCESS_KEY_ID` in secrets
2. **Path filtering** — only trigger affected environment on change
3. **Saved plan artifact** — apply uses EXACTLY what was reviewed, no fresh plan
4. **Separate pipeline files per environment** — `ci-dev.yml`, `ci-stg.yml`, `ci-prod.yml`
5. **Plugin cache** — cache `.terraform.d/plugin-cache` by `hashFiles('**/.terraform.lock.hcl')`
6. **Plan to PR** — always post the plan summary as a PR comment
7. **infracost** — post cost delta to PR (prevents surprise bills)

### Plugin Cache (Speeds Up CI by 60–80%)

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.terraform.d/plugin-cache
    key: terraform-${{ hashFiles('**/.terraform.lock.hcl') }}
    restore-keys: terraform-
```

### Environment-Specific Pipelines

```yaml
# deploy-dev.yml
on:
  push:
    branches: [release-dev]
    paths:                          # ONLY trigger if these paths changed
      - "environments/dev/**"
      - "terraform/modules/**"
      - "terraform/*.tf"
```

---

## 9. EKS-Specific Terraform Patterns

### Minimum EKS Stack (Cost-Optimized DEV)

```
Cost breakdown (us-east-1):
  EKS control plane:    $0.10/hr  = ~$73/mo
  2x t4g.small nodes:   $0.021/hr = ~$15/mo (ARM64 Graviton)
  No NAT Gateway:        $0        (public subnets only for dev)
  Total DEV:            ~$88/mo

Production additions:
  NAT Gateways (2x):   +$65/mo
  r6g node group:      +varies
```

### VPC Pattern for EKS

```hcl
module "vpc" {
  source = "./modules/vpc"

  name   = "${var.project_name}-${var.environment}"
  cidr   = "10.0.0.0/16"

  # EKS requires tags on subnets
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]   # prod only

  tags = merge(local.common_tags, {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  })

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"   # Required for ALB
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"  # Required for NLB
  }
}
```

### IRSA Pattern (IAM Roles for Service Accounts)

Every Kubernetes workload that needs AWS API access:

```
┌─────────────────────────────────────────────────────────┐
│                     EKS Cluster                          │
│                                                          │
│  ┌────────────────┐    assumes via OIDC    ┌──────────┐  │
│  │ K8s Pod        │─────────────────────►  │ IAM Role │  │
│  │ ServiceAccount │                        │ (IRSA)   │  │
│  │ annotated with │                        │          │  │
│  │ role ARN       │                        │ S3/ECR/  │  │
│  └────────────────┘                        │ SecretsM │  │
│                                            └──────────┘  │
└─────────────────────────────────────────────────────────┘
```

```hcl
module "irsa_ebs_csi" {
  source = "./modules/eks-irsa-role"

  cluster_name    = module.eks.cluster_name
  oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  policy_arns     = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
}
```

### EKS Add-ons via Terraform

```hcl
resource "aws_eks_addon" "coredns" {
  cluster_name      = aws_eks_cluster.main.name
  addon_name        = "coredns"
  addon_version     = "v1.11.3-eksbuild.1"   # Always pin exact version
  resolve_conflicts = "OVERWRITE"
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.37.0-eksbuild.1"
  service_account_role_arn = module.irsa_ebs_csi.role_arn
}
```

### Helm Charts via Terraform (for Cluster Add-Ons)

```hcl
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.11.0"          # Always pin
  namespace  = "kube-system"

  set { name = "clusterName",     value = module.eks.cluster_name }
  set { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn",
        value = module.irsa_lb_controller.role_arn }
}
```

### EKS Architecture Diagram (Production)

```
                     Internet
                        │
                 ┌──────┴──────┐
                 │  CloudFront │  (static site — separate)
                 └──────┬──────┘
                        │
                 ┌──────┴──────┐
                 │ Route53     │
                 └──────┬──────┘
                        │
                 ┌──────┴──────┐
                 │ ALB         │  ← AWS LB Controller (EKS addon)
                 └──────┬──────┘
                        │
┌───────────────────────┼────────────────────────────────┐
│  VPC 10.0.0.0/16      │                                 │
│                       │                                 │
│  Public Subnets       │                                 │
│  ┌────────────────────┴─────────────────┐               │
│  │ EKS Managed Node Group               │               │
│  │ (public)                             │               │
│  │                                      │               │
│  │  ┌──────────┐  ┌──────────┐         │               │
│  │  │ Pod      │  │ Pod      │  ...    │               │
│  │  │ Service  │  │ Service  │         │               │
│  │  │ Account  │  │ Account  │         │               │
│  │  └────┬─────┘  └────┬─────┘         │               │
│  └───────┼──────────────┼───────────────┘               │
│          │ IRSA         │ IRSA                          │
│          ▼              ▼                               │
│     IAM Role        IAM Role                            │
│     (S3 access)  (SecretsManager)                       │
└────────────────────────────────────────────────────────┘
     ▲                                ▲
     │                                │
AWS Secrets Manager          S3 Buckets / ECR
```

---

## 10. Naming Conventions

### Files (snake_case throughout)

```
GOOD:
  main.tf               ← primary resources
  variables.tf          ← all input variables
  outputs.tf            ← exported values
  providers.tf          ← provider configuration
  backend.tf            ← state backend (empty, values in backend.hcl)
  locals.tf             ← computed locals and common_tags
  iam.tf                ← IAM roles and policies
  monitoring.tf         ← CloudWatch, SNS
  budget.tf             ← AWS Budgets
  state_backend.tf      ← state infrastructure (rename from backend-infrastructure.tf)
  versions.tf           ← required_version + required_providers (in modules)

BAD:
  backend-infrastructure.tf   ← hyphen inconsistent with all others
  backendinfrastructure.tf    ← no separator
  terraform_state.tf          ← prefix redundant in terraform/ directory
```

### Resources (snake_case with project+env prefix)

```hcl
# GOOD — includes project and environment context
resource "aws_s3_bucket" "site_bucket" { ... }
resource "aws_iam_role" "github_actions_deploy" { ... }
resource "aws_cloudfront_distribution" "site_distribution" { ... }

# BAD — too generic, no context
resource "aws_s3_bucket" "bucket" { ... }
resource "aws_iam_role" "role" { ... }
```

### Resource names in AWS (interpolated)

```hcl
# Pattern: {project_name}-{environment}-{resource_type}
name = "${var.project_name}-${var.environment}-site"           # S3 bucket
name = "${var.project_name}-${var.environment}-oac"            # CloudFront OAC
name = "${var.project_name}-${var.environment}-github-deploy"  # IAM role
name = "${var.project_name}-${var.environment}-alerts"         # SNS topic
```

### Modules (snake_case directory names)

```
GOOD:
  modules/static-site/
  modules/state-backend/
  modules/eks-cluster/
  modules/eks-irsa-role/
  modules/vpc/
  modules/rds-postgres/

BAD:
  modules/StaticSite/
  modules/staticsite/
  modules/static_site_module/
```

### Variables (snake_case, descriptive)

```hcl
GOOD:
  project_name
  environment
  cloudfront_price_class
  github_repo
  monthly_budget_limit

BAD:
  projectName        ← camelCase
  env                ← too abbreviated
  cf_price           ← unclear abbreviation
  ENVIRONMENT        ← uppercase
```

### State Key Naming

```
{layer}/{environment}/terraform.tfstate

Examples:
  static-site/dev/terraform.tfstate
  networking/prod/terraform.tfstate
  eks-cluster/stg/terraform.tfstate
```

---

## 11. Variable & Secret Management

### Hierarchy (lowest to highest priority)

```
defaults in variables.tf
    │
    ▼
environment ci.tfvars (committed, no secrets)
    │
    ▼
local terraform.tfvars (gitignored, full values including overrides)
    │
    ▼
-var flags in CLI / CI environment variables
    │
    ▼
TF_VAR_* environment variables
```

### What goes where

| Value | Where | Committed |
|---|---|---|
| Region, project_name, environment | `ci.tfvars` | Yes |
| github_repo, github_branch | `ci.tfvars` | Yes |
| cloudfront_price_class, owner_team | `ci.tfvars` | Yes |
| alert_email | `ci.tfvars` | Yes (non-secret) |
| State bucket name | `backend.hcl` | NO — gitignored |
| AWS account ID | `backend.hcl` | NO — gitignored |
| RDS passwords | AWS Secrets Manager | Never in TF vars |
| API keys | AWS Secrets Manager or SSM | Never in TF vars |

### Secrets — Never in Terraform Variables

```
WRONG: variable "db_password" { default = "MyS3cur3Pass!" }
RIGHT: Use aws_secretsmanager_secret + data source lookup
       Or inject via K8s External Secrets Operator → Secrets Manager
```

### Sensitive Output Values

```hcl
output "github_actions_role_arn" {
  description = "IAM role ARN — set as GitHub secret"
  value       = aws_iam_role.github_actions_deploy.arn
  sensitive   = true   # will not print in apply output or state json
}
```

---

## 12. Security Non-Negotiables

```
╔══════════════════════════════════════════════════════════════════╗
║              SECURITY NON-NEGOTIABLES (ALL SOURCES AGREE)       ║
╠══════════════════════════════════════════════════════════════════╣
║  1. Pin ALL provider versions with ~> constraints                ║
║  2. Remote state: S3 + DynamoDB + encryption + versioning        ║
║  3. OIDC for CI/CD — NEVER AWS_ACCESS_KEY_ID in secrets          ║
║  4. IAM least privilege — no wildcards in actions or resources   ║
║  5. Static analysis in EVERY PR: tfsec + checkov + gitleaks      ║
║  6. No secrets in .tfvars or state files                         ║
║  7. Branch protection + required reviews for prod                ║
║  8. terraform destroy: NEVER automated — CLI only by engineer    ║
║  9. OIDC trust scoped to SPECIFIC repo + branch                  ║
║ 10. .terraform.lock.hcl COMMITTED to git (reproducible builds)   ║
╚══════════════════════════════════════════════════════════════════╝
```

### OIDC Trust (Least Privilege)

```hcl
# WRONG — trusts all branches of all repos
values = ["repo:*:*"]

# WRONG — trusts all branches
values = ["repo:rajdev0ps/claude-devops:*"]

# CORRECT — specific repo + specific branch
values = ["repo:rajdev0ps/claude-devops:ref:refs/heads/release-dev"]

# CORRECT — specific repo + release branches only (agenticai-ui)
values = ["repo:rajdev0ps/agenticai-ui:ref:refs/heads/release-*"]
```

---

## 13. Tool Stack

### Must-Have (Free, Open Source)

| Tool | Purpose | When |
|---|---|---|
| `terraform fmt -check` | Style enforcement | Every PR |
| `terraform validate` | Syntax check | Every PR |
| `tflint` | Semantic lint (unused vars, bad instance types) | Every PR |
| `checkov` | IaC security policy (500+ AWS rules) | Every PR |
| `tfsec` | Terraform security scanner | Every PR |
| `gitleaks` | Secret scanning in commits | Every PR |
| `terraform-docs` | Auto-generate module documentation | Pre-commit |
| `pre-commit` | Local hooks before git commit | Local dev |

### Should-Have (Free Tier Available)

| Tool | Purpose | When |
|---|---|---|
| `infracost` | Cost delta in PRs ($0 for open source) | Every PR |
| Terratest (Go) | Integration testing real infra | Module releases |

### Configuration Files to Add

```yaml
# .tflint.hcl
plugin "aws" {
  enabled = true
  version = "0.35.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rules {
  terraform_required_version = { enabled = true }
  terraform_naming_convention = { enabled = true }
}
```

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.1
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
      - id: terraform_checkov
      - id: terraform_docs
        args: ["--hook-config=--path-to-file=README.md"]
```

---

## 14. Questions to Answer Before Phase B

These decisions shape the entire structure. Answer them before the module refactor:

### Architecture Decisions

**Q1 — When are you adding EKS?**
- [ ] This quarter → implement Pattern C (layered) now, skip Pattern B
- [ ] Next quarter → implement Pattern B now, plan migration to C
- [ ] No EKS planned → Pattern B is the final state

**Q2 — How many AWS services beyond S3+CloudFront?**
- [ ] Just static site + maybe RDS → Pattern B sufficient
- [ ] Full microservices (EKS + RDS + ElastiCache + SQS) → Pattern C is required

**Q3 — Will DEV and STG ever be in separate AWS accounts?**
- [ ] Yes (already planned) → implement separate state buckets per account now
- [ ] Not yet but likely → design for it now (easy to split later with Pattern B/C)
- [ ] No, always same account → current setup is fine

**Q4 — Will other teams contribute Terraform modules?**
- [ ] Yes → consider Pattern D (modules repo) as the target state
- [ ] No, single team → Pattern B/C is sufficient

**Q5 — Do you need module versioning/pinning?**
- [ ] Yes (stability gates between dev and prod) → local module paths for now, git tags later
- [ ] No → local `./modules/` paths are fine

### Naming & Conventions

**Q6 — Current naming: `backend-infrastructure.tf` should be renamed to what?**
- [ ] `state_backend.tf` at root level (stays flat)
- [ ] Move contents into `modules/state-backend/` and call it from root

**Q7 — Should `environments/` live at repo root or inside `terraform/`?**
- [ ] Repo root (current position — good for multi-layer future)
- [ ] Inside `terraform/` (simpler for single-service project)

**Q8 — Module call location — where should environments/dev/main.tf live?**
- [ ] Keep `environments/dev/` referencing `../../terraform/modules/` (current plan)
- [ ] Move all environment TF to `terraform/environments/dev/` (everything under terraform/)

### EKS Planning

**Q9 — ARM64 (Graviton) or x86_64 for EKS nodes?**
- [ ] ARM64 (t4g/m7g/c7g) — 25-40% cheaper, requires ARM-compatible container images
- [ ] x86_64 (t3/m6i) — broader compatibility, higher cost

**Q10 — Public or private subnets for EKS nodes?**
- [ ] Public subnets only (dev cost optimization, no NAT Gateway ~$65/mo savings)
- [ ] Private subnets with NAT (production standard, adds ~$65/mo per AZ)

**Q11 — GitOps with ArgoCD or push-based deployments?**
- [ ] ArgoCD (GitOps pull model) — declarative, self-healing, audit trail
- [ ] GitHub Actions push (current model extended to K8s) — simpler to start
- [ ] Both (ArgoCD for K8s workloads, GitHub Actions for infra)

---

## 15. Recommended Path Forward for This Project

### Immediate (Phase B — Clean up current state)

```
Priority 1: Clean up repo
  ✓ Remove images/ empty folder
  ✓ Remove terraform/tfplan binary from git
  ✓ Remove terraform/.claude/ nested directory (move content to root .claude/)
  ✓ Rename backend-infrastructure.tf → state_backend.tf
  ✓ Move project.txt + project-modernisation.txt → docs/

Priority 2: Module structure
  [ ] Create terraform/modules/static-site/
      (move main.tf S3+CloudFront resources into it)
  [ ] Create terraform/modules/state-backend/
      (move state_backend.tf resources into it)
  [ ] Update root main.tf to call modules
  [ ] Run terraform state mv for changed resource addresses
  [ ] Add .tflint.hcl + .pre-commit-config.yaml
  [ ] Add terraform-docs to each module (README.md auto-generated)

Priority 3: Docs
  [ ] Create docs/ directory
  [ ] Add this plan to docs/
  [ ] terraform-docs output per module
```

### Short-Term (Once EKS decision is made)

```
If EKS Q1:
  [ ] Adopt Pattern C (layered architecture)
  [ ] Create terraform/02-networking/ (VPC module)
  [ ] Create terraform/03-eks-cluster/ (EKS module)
  [ ] Create terraform/04-eks-addons/ (Helm releases)
  [ ] Static site becomes terraform/05-static-site/
  [ ] Update CI/CD to run layers in dependency order

If no EKS planned:
  [ ] Pattern B is production-ready for this project
  [ ] Add infracost to CI pipeline
  [ ] Add pre-commit hooks for local dev
```

### Target Architecture Diagram (Pattern B — This Project)

```
    GitHub (claude-devops)
         │
         ├── push to release-dev
         │          │
         │          ▼
         │   GitHub Actions (deploy-dev.yml)
         │   validate → plan → apply → verify → tag
         │          │
         │          ▼
         │   AWS Account (025760030746)
         │   ┌─────────────────────────────────────────────────┐
         │   │  DEV Environment                                 │
         │   │  ┌──────────────┐    ┌──────────────────────┐   │
         │   │  │ S3 Bucket    │◄───│ CloudFront DEV       │   │
         │   │  │ (private)    │OAC │ (PriceClass_100)     │   │
         │   │  └──────────────┘    └──────────────────────┘   │
         │   │                                                  │
         │   │  ┌──────────────────────────────────────────┐   │
         │   │  │ CloudWatch Alarms + SNS + Budget          │   │
         │   │  └──────────────────────────────────────────┘   │
         │   │                                                  │
         │   │  Terraform State: S3 + DynamoDB                  │
         │   └─────────────────────────────────────────────────┘
         │
         └── push to release-stg
                    │
                    ▼
             [same pipeline, stg environment]


    GitHub (agenticai-ui)
         │
         └── push to release-dev/release-stg
                    │
                    ▼
             S3 sync → CF invalidation → tag
             (UI-scoped IAM role, no TF access)
```

---

*Sources: blog.praveshsudha.com | bohobot.com | terrateam.io | burakdede.com |
firefly.ai | aws.plainenglish.io | github.com/stacksimplify | github.com/pravinmishraaws*

*Last updated: 2026-05-29 | Terraform 1.14.4 | AWS Provider ~> 5.0*
