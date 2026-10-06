variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ai-powered-secure-k8s"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# ---- feature toggles --------------------------------------------------------
variable "enable_ecr_enhanced_scanning" {
  description = "Enable ECR enhanced (Inspector-powered) continuous scanning"
  type        = bool
  default     = true
}

variable "ecr_scan_repositories" {
  description = <<-EOT
    List of ECR repository names to apply ENHANCED scanning to.
    - Empty list [] = scan ALL repositories (wildcard "*").
    - Named list   = scan ONLY those repos, e.g. ["frontend","cartservice"].
    Wildcards are allowed in each entry, e.g. "my-app-*".
  EOT
  type        = list(string)
  default     = []
}

variable "enable_inspector" {
  description = "Enable Amazon Inspector for the account"
  type        = bool
  default     = true
}

variable "inspector_resource_types" {
  description = "Resource types Inspector should scan (ECR, EC2, LAMBDA, LAMBDA_CODE)"
  type        = list(string)
  default     = ["ECR", "EC2"]
}

variable "enable_guardduty" {
  description = "Enable GuardDuty with EKS audit logs + runtime monitoring"
  type        = bool
  default     = true
}

variable "enable_signer" {
  description = "Create an AWS Signer signing profile for container image signing"
  type        = bool
  default     = true
}

variable "signer_profile_name" {
  description = "Name of the AWS Signer signing profile"
  type        = string
  default     = "ecr_signing_profile"
}

variable "enable_security_hub" {
  description = "Enable Security Hub and import findings from GuardDuty + Inspector"
  type        = bool
  default     = true
}
