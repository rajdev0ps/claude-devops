# GitHub OIDC Identity Provider (data source - already exists in account)
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# IAM Policy for GitHub Actions deployment
data "aws_iam_policy_document" "github_actions_policy" {
  statement {
    sid    = "S3Sync"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.site_bucket.arn,
      "${aws_s3_bucket.site_bucket.arn}/*"
    ]
  }

  statement {
    sid    = "CloudFrontInvalidation"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation"
    ]
    resources = [
      aws_cloudfront_distribution.site_distribution.arn
    ]
  }
}

# Trust policy for GitHub Actions OIDC
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Restrict to specific repository and main branch
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:rajdev0ps/Ultimate-Agentic-DevOps-with-Claude-Code:ref:refs/heads/main"]
    }
  }
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions_deploy" {
  name               = "github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Attach policy to role
resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "github-actions-deploy-policy"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_policy.json
}

# Output the role ARN for GitHub Actions secret
output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions (set as AWS_ROLE_ARN secret)"
  value       = aws_iam_role.github_actions_deploy.arn
}
