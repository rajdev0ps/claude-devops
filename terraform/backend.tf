# Backend values are intentionally omitted here to avoid leaking the AWS
# account ID into version control. Supply them at init time:
#   terraform init -backend-config=backend.hcl
terraform {
  backend "s3" {}
}
