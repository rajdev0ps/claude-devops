variable "region" {
  description = "AWS region for deploying resources"
  type        = string
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "region must be a valid AWS region format e.g. us-east-1"
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{3,32}$", var.project_name))
    error_message = "project_name must be 3-32 lowercase letters, numbers, or hyphens"
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["dev", "stg", "prod", "devtest", "production"], var.environment)
    error_message = "environment must be one of: dev, stg, prod, devtest, production"
  }
}

variable "domain_name" {
  description = "Custom domain name for the CloudFront distribution (optional, leave empty for default CloudFront domain)"
  type        = string
  default     = ""
}

variable "existing_cloudfront_distribution_id" {
  description = "ID of existing CloudFront distribution to import (optional)"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository in owner/name format — used in OIDC trust condition"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$", var.github_repo))
    error_message = "github_repo must be in owner/name format e.g. rajdev0ps/claude-devops"
  }
}

variable "github_branch" {
  description = "GitHub branch scoped in the OIDC trust condition"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9/_.-]+$", var.github_branch))
    error_message = "github_branch must be a valid branch name"
  }
}

variable "github_ui_repo" {
  description = "GitHub repository for the UI code (agenticai-ui) — used in UI OIDC trust condition"
  type        = string
  default     = "rajdev0ps/agenticai-ui"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$", var.github_ui_repo))
    error_message = "github_ui_repo must be in owner/name format e.g. rajdev0ps/agenticai-ui"
  }
}

variable "owner_team" {
  description = "Team responsible for this environment — used in resource tags"
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Billing cost center code — used in resource tags"
  type        = string
  default     = "CC-001"
}

variable "cloudfront_price_class" {
  description = "CloudFront price class controlling which edge locations serve content"
  type        = string
  default     = "PriceClass_100"
  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "cloudfront_price_class must be one of: PriceClass_100, PriceClass_200, PriceClass_All"
  }
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm and budget notifications"
  type        = string
  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.alert_email))
    error_message = "alert_email must be a valid email address"
  }
}

variable "monthly_budget_limit" {
  description = "Monthly AWS spend limit in USD — alerts at 80% actual and 100% forecasted"
  type        = string
  default     = "10"
}
