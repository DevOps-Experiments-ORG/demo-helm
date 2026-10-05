#!/usr/bin/env bash
# ============================================================================
# Flip the security baseline from AUDIT to ENFORCE (blocking) with one command.
# Run only after `kubectl get policyreport -A` shows no unexpected violations.
# ============================================================================
set -euo pipefail

APP_NS="applications"
RELEASE="eks-security"
SEC_NS="security"
CHART_DIR="$(cd "$(dirname "$0")/eks-security-baseline" && pwd)"

export PATH="$HOME/bin:$PATH"

echo "==> Switching Kyverno policies + PSA to ENFORCE"
helm upgrade "$RELEASE" "$CHART_DIR" \
  --namespace "$SEC_NS" \
  --set kyverno.enabled=false \
  --set appNamespace="$APP_NS" \
  --set policyMode=Enforce \
  --set podSecurityAdmission.enforce=true \
  --wait --timeout 3m

echo "==> Enforcing PSA on namespace '$APP_NS'"
kubectl label --overwrite namespace "$APP_NS" \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest

echo ""
echo "ENFORCE mode active. Verify a bad pod is now rejected:"
echo "  kubectl run bad --image=nginx:latest -n $APP_NS"
echo "  (should be blocked by disallow-latest-tag / restrict-image-registries)"
