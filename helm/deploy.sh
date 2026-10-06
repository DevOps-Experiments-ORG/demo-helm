#!/usr/bin/env bash
# ============================================================================
# One-command deploy of the EKS in-cluster security baseline.
#
# Handles everything automatically:
#   - installs helm if missing (fresh CloudShell safe)
#   - points kubeconfig at the cluster
#   - enables VPC CNI network policy
#   - installs Kyverno CRDs + Kyverno FIRST (fixes the CRD ordering error)
#   - then installs your policies / PSA / network policies / quotas
#   - labels the existing app namespace for Pod Security Admission
#
# Usage (from the chart's parent folder, i.e. eks-security/helm):
#   bash deploy.sh
#
# Re-runnable. Safe to run again; it upgrades in place.
# ============================================================================
set -euo pipefail

# ---- config ----------------------------------------------------------------
RELEASE="eks-security"
SEC_NS="security"
CHART_DIR="$(cd "$(dirname "$0")/eks-security-baseline" && pwd)"
VALUES_FILE="$CHART_DIR/values.yaml"
KYVERNO_CHART_VERSION="3.5.3"

# Read cluster name/region/app namespace FROM values.yaml (single source of
# truth). Tiny YAML reader: picks the value after the key. No yq needed.
yval() { grep -E "^[[:space:]]*$1:" "$VALUES_FILE" | head -1 | sed -E 's/^[^:]*:[[:space:]]*//; s/["'"'"']//g; s/[[:space:]]*(#.*)?$//'; }

CLUSTER_NAME="$(yval 'name')"
AWS_REGION="$(yval 'region')"
APP_NS="$(yval 'appNamespace')"

echo "==> From values.yaml: cluster=$CLUSTER_NAME region=$AWS_REGION appNamespace=$APP_NS"

echo "==> Chart: $CHART_DIR"

# ---- 0. install helm if missing --------------------------------------------
if ! command -v helm >/dev/null 2>&1; then
  echo "==> helm not found, installing to \$HOME/bin"
  mkdir -p "$HOME/bin"
  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod +x /tmp/get_helm.sh
  HELM_INSTALL_DIR="$HOME/bin" USE_SUDO=false /tmp/get_helm.sh --no-sudo
  export PATH="$HOME/bin:$PATH"
fi
helm version

# ---- 1. kubeconfig ----------------------------------------------------------
echo "==> Pointing kubeconfig at $CLUSTER_NAME"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
kubectl config current-context
kubectl get nodes

# ---- 2. enable VPC CNI network policy (idempotent) --------------------------
echo "==> Enabling network policy in VPC CNI add-on"
aws eks update-addon --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" \
  --addon-name vpc-cni \
  --configuration-values '{"enableNetworkPolicy":"true"}' \
  --resolve-conflicts PRESERVE || echo "   (addon update skipped or already set)"

# ---- 3. install Kyverno FIRST so its CRDs exist -----------------------------
# This is the fix for the "no matches for kind ClusterPolicy" error: the CRDs
# must exist before Helm can validate your ClusterPolicy objects.
echo "==> Installing/upgrading Kyverno (brings in CRDs)"
helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install kyverno kyverno/kyverno \
  --version "$KYVERNO_CHART_VERSION" \
  --namespace "$SEC_NS" --create-namespace \
  --set admissionController.replicas=3 \
  --wait --timeout 5m

echo "==> Waiting for Kyverno CRDs to register"
for i in $(seq 1 30); do
  if kubectl get crd clusterpolicies.kyverno.io >/dev/null 2>&1; then
    echo "   CRDs ready."
    break
  fi
  echo "   waiting... ($i)"; sleep 5
done

# ---- 4. install the baseline chart WITHOUT its own Kyverno subchart ---------
# Kyverno is already installed above, so disable the subchart here and let this
# release manage only the policies / PSA / netpol / quotas.
echo "==> Resolving chart dependencies"
helm dependency build "$CHART_DIR" >/dev/null 2>&1 || helm dependency update "$CHART_DIR"

echo "==> Installing/upgrading the security baseline (policies, PSA, netpol, quotas)"
helm upgrade --install "$RELEASE" "$CHART_DIR" \
  --namespace "$SEC_NS" \
  --set kyverno.enabled=false \
  --set appNamespace="$APP_NS" \
  --wait --timeout 3m

# ---- 5. label the existing app namespace for PSA ----------------------------
echo "==> Labeling namespace '$APP_NS' for Pod Security Admission (warn+audit)"
kubectl label --overwrite namespace "$APP_NS" \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/warn-version=latest \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/audit-version=latest

# ---- 6. show status ---------------------------------------------------------
echo ""
echo "============================================================"
echo " DEPLOYED. Current state:"
echo "============================================================"
helm list -n "$SEC_NS"
echo "--- Kyverno pods ---"
kubectl get pods -n "$SEC_NS"
echo "--- Cluster policies (mode shown under ACTION) ---"
kubectl get clusterpolicies
echo ""
echo "Everything is in AUDIT mode - nothing is blocked yet."
echo "Observe violations:   kubectl get policyreport -A"
echo "When ready to ENFORCE: bash enforce.sh"
