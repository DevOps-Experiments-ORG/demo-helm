# ---------------------------------------------------------------------------------------------------------------------
# Security Services - Terragrunt Configuration
# AWS-native container security: ECR scanning, Inspector, GuardDuty, Signer, Security Hub
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../terraform-modules/security-services"
}

inputs = {
  enable_ecr_enhanced_scanning = true

  # Only these ECR repositories get ENHANCED scanning.
  # Leave the list empty ([]) to scan ALL repos instead.
  # Wildcards allowed, e.g. "my-app-*".
  ecr_scan_repositories = [
    "frontend",
    "cartservice",
    "checkoutservice",
  ]

  enable_inspector         = true
  inspector_resource_types = ["ECR", "EC2"]

  enable_guardduty = true

  enable_signer = true
  # NOTE: a previously cancelled Signer profile keeps its name reserved in AWS
  # for a while. Using a fresh name avoids the "already exists" conflict.
  signer_profile_name = "ecr_signing_profile_v2"

  enable_security_hub = true
}
