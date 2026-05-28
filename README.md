# Agentic AI Platform - Static Website on AWS

A professional **static HTML/CSS portfolio website** for an Agentic AI Platform, deployed to AWS S3 + CloudFront with Infrastructure as Code (Terraform) and automated CI/CD via GitHub Actions.

---

## 🎯 Project Overview

This is a full-stack DevOps project demonstrating:
- **Static Site Hosting** — Pure HTML5 + CSS3 (no JavaScript, no build step)
- **Infrastructure as Code** — Terraform manages S3, CloudFront, and OAC
- **Secure Access** — CloudFront Origin Access Control (OAC) for private S3 bucket
- **Automated Deployment** — GitHub Actions syncs content to S3 and invalidates CloudFront cache
- **Keyless CI/CD** — GitHub OIDC provider for AWS authentication (no long-lived keys)

---

## 📋 What's Included

```
├── index.html              # Main landing page
├── style.css               # Responsive styling (mobile-first)
├── privacy.html            # Privacy policy page
├── terms.html              # Terms of service page
├── terraform/              # Infrastructure as Code
│   ├── main.tf             # S3, CloudFront, OAC resources
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Output values
│   ├── providers.tf        # AWS provider config
│   ├── backend.tf          # Remote state (S3 + DynamoDB)
│   └── terraform.tfvars    # Environment values
├── .github/workflows/      # GitHub Actions CI/CD
└── CLAUDE.md              # Development guidelines
```

---

## 🏗️ Architecture

### Cloud Resources
- **S3 Bucket** — Private static site storage (petclinic-poc-devtest-site)
- **CloudFront Distribution** — CDN with custom error handling (404/403 → /index.html)
- **Origin Access Control (OAC)** — Secure S3 access (not legacy OAI)
- **Bucket Policy** — Restricts access to CloudFront only

### Deployment
```
Git Push to main
    ↓
GitHub Actions Workflow
    ↓
AWS OIDC Authentication (keyless)
    ↓
Sync to S3 + Invalidate CloudFront Cache
    ↓
Live on CloudFront CDN
```

---

## 🚀 Quick Start

### Prerequisites
- AWS Account with credentials configured
- Terraform 1.5+
- AWS CLI v2

### Deploy

1. **Configure AWS Credentials:**
   ```bash
   aws configure
   # Enter: Access Key, Secret Key, Region (us-east-1), Output Format (json)
   ```

2. **Initialize Terraform:**
   ```bash
   cd terraform
   terraform init
   ```

3. **Review & Apply Infrastructure:**
   ```bash
   terraform plan
   terraform apply
   ```

4. **Upload Site Files:**
   ```bash
   cd ..
   aws s3 sync . s3://petclinic-poc-devtest-site/ \
     --exclude "terraform/*" \
     --exclude ".git/*" \
     --exclude ".github/*" \
     --exclude "*.md" \
     --exclude ".claude/*"
   ```

5. **Test:**
   ```bash
   # Get CloudFront domain from terraform outputs
   terraform output cloudfront_domain_name
   ```

---

## 📊 Current Deployment

| Resource | Value |
|----------|-------|
| **CloudFront Domain** | `d3ijldrl5oi8h4.cloudfront.net` |
| **Distribution ID** | `E155Q8VSBBEKPZ` |
| **S3 Bucket** | `petclinic-poc-devtest-site` |
| **Region** | `us-east-1` |
| **Environment** | `devtest` |
| **Pricing** | Free tier (1 TB/month data transfer included) |

---

## 📝 Making Changes

### Update Website Content
1. Edit `index.html`, `style.css`, or other pages
2. Push to `main` branch
3. GitHub Actions automatically syncs to S3 and refreshes CloudFront

### Update Infrastructure
1. Edit `terraform/main.tf`
2. Run: `terraform plan` (review changes)
3. Run: `terraform apply` (deploy)

### Update Variables
Edit `terraform/terraform.tfvars` and re-apply:
```hcl
region       = "us-east-1"
project_name = "petclinic-poc"
environment  = "devtest"
domain_name  = ""  # Add custom domain here
```

---

## 🔐 Security

- ✅ **Private S3 Bucket** — No public access allowed
- ✅ **CloudFront OAC** — Modern Origin Access Control (not legacy OAI)
- ✅ **HTTPS Only** — Viewer protocol redirects HTTP → HTTPS
- ✅ **Keyless CI/CD** — GitHub OIDC (no AWS access keys stored)
- ✅ **IAM Role** — Least-privilege permissions for GitHub Actions

---

## 📋 Terraform Outputs

After `terraform apply`, view outputs:
```bash
cd terraform
terraform output

# Output:
# cloudfront_distribution_id = "E155Q8VSBBEKPZ"
# cloudfront_domain_name     = "d3ijldrl5oi8h4.cloudfront.net"
# s3_bucket_name             = "petclinic-poc-devtest-site"
# s3_bucket_arn              = "arn:aws:s3:::petclinic-poc-devtest-site"
```

---

## 🛠️ Maintenance

### Monitor CloudFront
```bash
aws cloudfront get-distribution --id E155Q8VSBBEKPZ --query 'Distribution.Status'
```

### Invalidate Cache (force refresh)
```bash
aws cloudfront create-invalidation --distribution-id E155Q8VSBBEKPZ --paths "/*"
```

### Check S3 Bucket Size
```bash
aws s3 ls s3://petclinic-poc-devtest-site/ --recursive --human-readable
```

### View Terraform State
```bash
cd terraform
terraform state list
terraform state show aws_s3_bucket.site_bucket
```

---

## 💰 Cost Estimates

**Monthly Cost (Free Tier Included):**
- S3 Storage: < $0.10 (minimal HTML/CSS files)
- CloudFront: **Free** (1 TB/month included, then ~$0.085/GB)
- Data Transfer: **Free** (within free tier limits)

**Total: ~$0 - $5/month** (for typical traffic)

---

## 🐛 Troubleshooting

### Access Denied from CloudFront
- Verify S3 bucket policy allows CloudFront service
- Check OAC is configured in CloudFront origin
- Invalidate CloudFront cache: `aws cloudfront create-invalidation ...`

### Site Not Updating
- Confirm files uploaded to S3: `aws s3 ls s3://petclinic-poc-devtest-site/`
- Invalidate CloudFront cache
- Wait 30-60 seconds for cache propagation

### Terraform State Issues
- Backend is commented out (use local state for dev)
- Uncomment `backend.tf` and run `terraform init -migrate-state` for remote state

---

## 💡 Running on a New Machine — Hook Setup Tips

The Claude Code safety hooks (`.claude/hooks/`) rely on **`jq`** for JSON parsing and **absolute paths** baked into `settings.json` and one hook script. Both must be updated whenever the project is cloned to a new machine or a different path.

---

### Files that need updating

| File | What to change |
|------|---------------|
| `.claude/settings.json` | All 3 hook command paths (lines with `bash 'S:/devops/...'`) |
| `.claude/hooks/post-tool-logger.sh` | Deploy log path (`>> 'S:/devops/...'`) |
| `.claude/hooks/pre-tool-guard.sh` | Debug log path (`>> /c/Users/raj/...`) |

---

### Windows (Git Bash)

**Step 1 — Install `jq`** (required; hooks use it to parse JSON input):

```bash
# Option A: download binary — no admin rights needed
mkdir -p ~/bin
curl -sL "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-windows-amd64.exe" \
  -o ~/bin/jq.exe

# Option B: Chocolatey — requires admin shell
choco install jq -y
```

**Step 2 — Update hook command paths in `.claude/settings.json`:**

Find the three occurrences of `bash 'S:/devops/Ultimate-Agentic-DevOps-with-Claude-Code/.claude/hooks/...'`
and replace `S:/devops/Ultimate-Agentic-DevOps-with-Claude-Code` with your actual project path using
forward slashes (Git Bash style), e.g. `C:/Users/yourname/projects/my-repo`:

```json
"command": "bash 'C:/Users/yourname/projects/my-repo/.claude/hooks/pre-tool-guard.sh'"
"command": "bash 'C:/Users/yourname/projects/my-repo/.claude/hooks/user-prompt-guard.sh'"
"command": "bash 'C:/Users/yourname/projects/my-repo/.claude/hooks/post-tool-logger.sh'"
```

**Step 3 — Update the deploy log path in `.claude/hooks/post-tool-logger.sh`:**

```bash
# change this line:
>> 'S:/devops/Ultimate-Agentic-DevOps-with-Claude-Code/.claude/deploy.log'

# to:
>> 'C:/Users/yourname/projects/my-repo/.claude/deploy.log'
```

**Step 4 — Update the debug log path in `.claude/hooks/pre-tool-guard.sh`:**

```bash
# change this line:
>> /c/Users/raj/hook-debug.log

# to (using your Windows username):
>> /c/Users/YOUR_USERNAME/hook-debug.log
```

---

### Linux / macOS

**Step 1 — Install `jq`:**

```bash
sudo apt-get install jq    # Debian / Ubuntu
sudo yum install jq        # RHEL / CentOS
sudo dnf install jq        # Fedora
brew install jq            # macOS (Homebrew)
```

**Step 2 — Update hook command paths in `.claude/settings.json`:**

Replace the Windows-style paths with the Linux absolute path to your project:

```json
"command": "bash '/home/yourname/projects/my-repo/.claude/hooks/pre-tool-guard.sh'"
"command": "bash '/home/yourname/projects/my-repo/.claude/hooks/user-prompt-guard.sh'"
"command": "bash '/home/yourname/projects/my-repo/.claude/hooks/post-tool-logger.sh'"
```

**Step 3 — Update the deploy log path in `.claude/hooks/post-tool-logger.sh`:**

```bash
# change this line:
>> 'S:/devops/Ultimate-Agentic-DevOps-with-Claude-Code/.claude/deploy.log'

# to:
>> '/home/yourname/projects/my-repo/.claude/deploy.log'
```

**Step 4 — Update the debug log path in `.claude/hooks/pre-tool-guard.sh`:**

```bash
# change this line:
>> /c/Users/raj/hook-debug.log

# to (any writable path):
>> /tmp/hook-debug.log
```

**Step 5 — Ensure hook scripts are executable** (Linux/macOS only):

```bash
chmod +x .claude/hooks/*.sh
```

---

### Verify hooks are working

After making the above changes, run these quick tests from within Claude Code:

```bash
# 1. PreToolUse hook — should be BLOCKED:
terraform destroy

# 2. PreToolUse hook — should be ALLOWED:
terraform validate

# 3. PostToolUse hook — simulate and check log:
echo '{"tool_input":{"command":"terraform apply"}}' | bash .claude/hooks/post-tool-logger.sh
cat .claude/deploy.log

# 4. UserPromptSubmit hook — simulate:
echo '{"prompt":"nuke everything"}' | bash .claude/hooks/user-prompt-guard.sh
# Expected output: {"decision": "block", "reason": "..."}
```

---

## 📚 Resources

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [S3 Origin Access Control](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)
- [GitHub OIDC in AWS](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)

---

## 📄 License

This project is part of the Ultimate Agentic DevOps initiative.

---

**Last Updated:** May 27, 2026  
**Project:** petclinic-poc | Environment: devtest
