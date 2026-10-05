# Environment-specific variables for dev
locals {
  environment = "dev"
  aws_region  = "ap-south-1"

  common_tags = {
    Project     = "ai-powered-secure-k8s"
    ManagedBy   = "terragrunt"
    Environment = "dev"
    SkipCleanup = "true"
  }
}
