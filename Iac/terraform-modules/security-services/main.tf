################################################################################
# Security Services Module
# AWS-native container security services for the EKS cluster:
#   - ECR enhanced (Inspector) scanning
#   - Amazon Inspector (ECR + EC2 nodes)
#   - GuardDuty (EKS audit logs + runtime monitoring)
#   - AWS Signer (image signing profile)
#   - Security Hub (aggregate findings)
#
# These are ACCOUNT/REGION-level services (not Kubernetes objects), which is
# why they belong in Terraform rather than the Helm chart.
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# 1. ECR enhanced, continuous scanning (Inspector-powered)
# ---------------------------------------------------------------------------
locals {
  # If no repos are listed, fall back to "*" (all repos). Otherwise use the
  # exact names/patterns provided.
  ecr_scan_filters = length(var.ecr_scan_repositories) > 0 ? var.ecr_scan_repositories : ["*"]
}

resource "aws_ecr_registry_scanning_configuration" "this" {
  count     = var.enable_ecr_enhanced_scanning ? 1 : 0
  scan_type = "ENHANCED"

  # One rule per repository name/pattern. Only these repos get ENHANCED,
  # continuous scanning; everything else stays on the registry default.
  dynamic "rule" {
    for_each = local.ecr_scan_filters
    content {
      scan_frequency = "CONTINUOUS_SCAN"
      repository_filter {
        filter      = rule.value
        filter_type = "WILDCARD"
      }
    }
  }
}

# ---------------------------------------------------------------------------
# 2. Amazon Inspector (ECR images + EC2 nodes)
# ---------------------------------------------------------------------------
resource "aws_inspector2_enabler" "this" {
  count          = var.enable_inspector ? 1 : 0
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = var.inspector_resource_types
}

# ---------------------------------------------------------------------------
# 3. GuardDuty + EKS protection (audit logs + runtime monitoring)
# ---------------------------------------------------------------------------
resource "aws_guardduty_detector" "this" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true
  # NOTE: the inline "datasources" block is deprecated in AWS provider v5.
  # Features (audit logs, runtime monitoring) are set via separate
  # aws_guardduty_detector_feature resources below.
}

# EKS Audit Log Monitoring
resource "aws_guardduty_detector_feature" "eks_audit_logs" {
  count       = var.enable_guardduty ? 1 : 0
  detector_id = aws_guardduty_detector.this[0].id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

# EKS Runtime Monitoring with the AWS-managed agent add-on
resource "aws_guardduty_detector_feature" "eks_runtime" {
  count       = var.enable_guardduty ? 1 : 0
  detector_id = aws_guardduty_detector.this[0].id
  name        = "EKS_RUNTIME_MONITORING"
  status      = "ENABLED"

  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = "ENABLED"
  }
}

# ---------------------------------------------------------------------------
# 4. AWS Signer signing profile (Notation / Notary v2 for ECR image signing)
# ---------------------------------------------------------------------------
resource "aws_signer_signing_profile" "this" {
  count       = var.enable_signer ? 1 : 0
  name        = var.signer_profile_name
  platform_id = "Notation-OCI-SHA384-ECDSA"
  tags        = var.tags
}

# ---------------------------------------------------------------------------
# 5. Security Hub + default standards + product integrations
# ---------------------------------------------------------------------------
resource "aws_securityhub_account" "this" {
  count = var.enable_security_hub ? 1 : 0
}

resource "aws_securityhub_product_subscription" "guardduty" {
  count = var.enable_security_hub && var.enable_guardduty ? 1 : 0
  depends_on = [
    aws_securityhub_account.this,
    aws_guardduty_detector.this, # ensure GuardDuty is enabled before subscribing
  ]
  product_arn = "arn:aws:securityhub:${data.aws_region.current.name}::product/aws/guardduty"
}

resource "aws_securityhub_product_subscription" "inspector" {
  count = var.enable_security_hub && var.enable_inspector ? 1 : 0
  depends_on = [
    aws_securityhub_account.this,
    aws_inspector2_enabler.this, # ensure Inspector is enabled before subscribing
  ]
  product_arn = "arn:aws:securityhub:${data.aws_region.current.name}::product/aws/inspector"
}
