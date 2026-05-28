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
    # Restrict to specific repository and branch — set via variables
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/${var.github_branch}"]
    }
  }
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions_deploy" {
  name               = "${var.project_name}-${var.environment}-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  tags = local.common_tags
}

# Attach policy to role
resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "${var.project_name}-${var.environment}-github-deploy-policy"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_policy.json
}

# Output the role ARN for GitHub Actions secret
output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions (set as AWS_ROLE_ARN_DEV/STG secret in claude-devops)"
  value       = aws_iam_role.github_actions_deploy.arn
}

# ── UI Deployment Role (agenticai-ui repo) ────────────────────────────────────

# Minimal permissions for UI repo — S3 sync + CloudFront invalidation only
data "aws_iam_policy_document" "github_actions_ui_policy" {
  statement {
    sid    = "UISync"
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
    sid       = "UICloudFrontInvalidation"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.site_distribution.arn]
  }
}

# Trust scoped to agenticai-ui repo on release-dev or release-stg only
data "aws_iam_policy_document" "github_actions_ui_trust" {
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
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_ui_repo}:ref:refs/heads/release-*"]
    }
  }
}

resource "aws_iam_role" "github_actions_ui_deploy" {
  name               = "${var.project_name}-${var.environment}-ui-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_ui_trust.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "github_actions_ui_deploy" {
  name   = "${var.project_name}-${var.environment}-ui-deploy-policy"
  role   = aws_iam_role.github_actions_ui_deploy.id
  policy = data.aws_iam_policy_document.github_actions_ui_policy.json
}

output "github_actions_ui_role_arn" {
  description = "IAM role ARN for agenticai-ui GitHub Actions (set as AWS_ROLE_ARN_DEV/STG in agenticai-ui repo)"
  value       = aws_iam_role.github_actions_ui_deploy.arn
}
