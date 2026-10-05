# ---------------------------------------------------------------------------------------------------------------------
# ROOT TERRAGRUNT CONFIGURATION
# All child terragrunt.hcl files inherit this configuration.
# ---------------------------------------------------------------------------------------------------------------------

# Generate the AWS provider configuration
# Only the AWS provider is declared here (the security-services module needs
# only AWS). This keeps the provider download small enough for CloudShell.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = {
      Project     = "ai-powered-secure-k8s"
      ManagedBy   = "terragrunt"
      Environment = "dev"
      SkipCleanup = "true"
    }
  }
}
EOF
}

# Local state backend (no S3 bucket / DynamoDB dependency — simplest for a POC).
# To use remote S3 state later, replace this block with a remote_state "s3" one.
remote_state {
  backend = "local"
  config = {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Local variables shared across all environments
locals {
  aws_region   = "ap-south-1"
  project_name = "ai-powered-secure-k8s"

  common_tags = {
    Project     = "ai-powered-secure-k8s"
    ManagedBy   = "terragrunt"
    Environment = "dev"
    SkipCleanup = "true"
  }
}

# Common inputs passed to all child modules
inputs = {
  aws_region   = local.aws_region
  project_name = local.project_name
  tags         = local.common_tags
}
