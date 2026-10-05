#!/usr/bin/env bash
# ============================================================================
# ONE-COMMAND DEPLOY — full EKS security baseline
#
#   Part 1 (Terragrunt): AWS account services
#                        ECR scanning, Inspector, GuardDuty, Signer, Security Hub
#   Part 2 (Helm):       In-cluster security
#                        Kyverno + policies, PSA, network policies, quotas
#
# Usage (from the demo-helm repo root):
#   bash deploy-all.sh                 # deploy both
#   bash deploy-all.sh --skip-aws      # Helm only (AWS already set up)
#   bash deploy-all.sh --skip-helm     # Terragrunt only
#
# Re-runnable. Safe to run again; both parts upgrade in place.
# ============================================================================
set -uo pipefail

# ---- config (edit here if deploying to a different cluster) -----------------
AWS_REGION="ap-south-1"
TG_DIR="Iac/terragrunt-resources/dev/security-services"
HELM_DIR="helm"

SKIP_AWS=false
SKIP_HELM=false
for arg in "$@"; do
  case "$arg" in
    --skip-aws)  SKIP_AWS=true ;;
    --skip-helm) SKIP_HELM=true ;;
  esac
done

ROOT="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HOME/bin:$PATH"

# ============================================================================
# PART 1 — AWS services via Terragrunt
# ============================================================================
if [ "$SKIP_AWS" = false ]; then
  echo "############################################################"
  echo "# PART 1/2 — AWS services (Terragrunt)"
  echo "############################################################"

  # install terraform if missing
  if ! command -v terraform >/dev/null 2>&1; then
    echo "==> terraform not found, installing to \$HOME/bin"
    mkdir -p "$HOME/bin"
    TF_VER="1.9.8"
    curl -fsSL -o /tmp/tf.zip "https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_amd64.zip"
    unzip -o /tmp/tf.zip -d "$HOME/bin" >/dev/null
  fi

  # install terragrunt if missing
  if ! command -v terragrunt >/dev/null 2>&1; then
    echo "==> terragrunt not found, installing to \$HOME/bin"
    mkdir -p "$HOME/bin"
    TG_VER="0.67.16"
    curl -fsSL -o "$HOME/bin/terragrunt" \
      "https://github.com/gruntwork-io/terragrunt/releases/download/v${TG_VER}/terragrunt_linux_amd64"
    chmod +x "$HOME/bin/terragrunt"
  fi

  terraform version
  terragrunt --version

  echo "==> Applying security-services (Terragrunt)"
  ( cd "$ROOT/$TG_DIR" && terragrunt init -upgrade && terragrunt apply -auto-approve )

  echo "==> AWS services done."
else
  echo "==> Skipping AWS services (--skip-aws)"
fi

# ============================================================================
# PART 2 — In-cluster security via Helm
# ============================================================================
if [ "$SKIP_HELM" = false ]; then
  echo ""
  echo "############################################################"
  echo "# PART 2/2 — In-cluster security (Helm)"
  echo "############################################################"
  bash "$ROOT/$HELM_DIR/deploy.sh"
else
  echo "==> Skipping Helm (--skip-helm)"
fi

echo ""
echo "============================================================"
echo " ALL DONE."
echo "   AWS services : $([ "$SKIP_AWS" = true ] && echo skipped || echo deployed)"
echo "   In-cluster   : $([ "$SKIP_HELM" = true ] && echo skipped || echo deployed)"
echo " Verify:  bash $HELM_DIR/verify.sh   (or read $HELM_DIR/VERIFY-COMMANDS.md)"
echo " Enforce: bash $HELM_DIR/enforce.sh"
echo "============================================================"
