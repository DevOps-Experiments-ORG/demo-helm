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

  enable_inspector         = true
  inspector_resource_types = ["ECR", "EC2"]

  enable_guardduty = true

  enable_signer       = true
  signer_profile_name = "ecr_signing_profile"

  enable_security_hub = true
}
