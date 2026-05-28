variable "region" {
  description = "AWS region for deploying resources"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (production, staging, development)"
  type        = string
  default     = "production"
}

variable "domain_name" {
  description = "Custom domain name for the CloudFront distribution (optional)"
  type        = string
  default     = ""
}

variable "existing_cloudfront_distribution_id" {
  description = "ID of existing CloudFront distribution to import (optional)"
  type        = string
  default     = ""
}
