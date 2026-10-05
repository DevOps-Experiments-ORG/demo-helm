output "guardduty_detector_id" {
  description = "GuardDuty detector ID (empty if disabled)"
  value       = var.enable_guardduty ? aws_guardduty_detector.this[0].id : ""
}

output "signer_profile_arn" {
  description = "AWS Signer signing profile ARN (empty if disabled). Use with 'notation sign'."
  value       = var.enable_signer ? aws_signer_signing_profile.this[0].arn : ""
}

output "signer_profile_version_arn" {
  description = "AWS Signer signing profile VERSION ARN (empty if disabled)"
  value       = var.enable_signer ? aws_signer_signing_profile.this[0].version_arn : ""
}

output "ecr_scanning_type" {
  description = "ECR registry scan type that was configured"
  value       = var.enable_ecr_enhanced_scanning ? "ENHANCED" : "unmanaged"
}

output "inspector_resource_types" {
  description = "Resource types enabled in Amazon Inspector"
  value       = var.enable_inspector ? var.inspector_resource_types : []
}
