# ---------------------------------------------------------------------------------------------------------------------
# ROOT TERRAGRUNT CONFIGURATION
# All child terragrunt.hcl files inherit this configuration.
# ---------------------------------------------------------------------------------------------------------------------

# Generate the AWS provider configuration
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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
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

# Configure S3 backend for remote state
remote_state {
  backend = "s3"
  config = {
    bucket         = "ai-powered-secure-k8s-tfstate-2026"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
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
