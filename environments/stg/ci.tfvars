# CI variable values for STG environment.
# Safe to commit — contains no secrets or account IDs.
# Backend config (bucket name, account ID) is passed via GitHub Actions vars.

region       = "us-east-1"
project_name = "petclinic-poc"
environment  = "stg"

domain_name                         = ""
existing_cloudfront_distribution_id = ""
cloudfront_price_class              = "PriceClass_100"

github_repo   = "rajdev0ps/agenticai-infra"
github_branch = "release-stg"

owner_team  = "platform-team"
cost_center = "CC-001-STG"
