#!/usr/bin/env bash
# ============================================================================
# Verify the in-cluster security baseline (Kyverno + policies + PSA + netpol).
# Read-only — changes nothing. Run after deploy.sh.
#   bash verify.sh
# ============================================================================
set -uo pipefail

APP_NS="applications"
SEC_NS="security"
export PATH="$HOME/bin:$PATH"

echo "### 1. Helm releases (expect kyverno + eks-security deployed)"
helm list -n "$SEC_NS"

echo ""
echo "### 2. Kyverno pods (all should be Running)"
kubectl get pods -n "$SEC_NS"

echo ""
echo "### 3. Cluster policies (all READY=True)"
kubectl get clusterpolicies

echo ""
echo "### 4. Current policy MODE (Audit vs Enforce)"
echo "    validationFailureAction per policy:"
kubectl get clusterpolicies -o custom-columns='NAME:.metadata.name,ACTION:.spec.validationFailureAction' 2>/dev/null \
  || for p in $(kubectl get clusterpolicies -o name); do
       echo "  $p -> $(kubectl get $p -o jsonpath='{.spec.validationFailureAction}')"
     done

echo ""
echo "### 5. Pod Security Admission labels on '$APP_NS'"
kubectl get namespace "$APP_NS" -o jsonpath='{.metadata.labels}' | tr ',' '\n' | grep pod-security || echo "  (no PSA labels found)"
echo ""

echo ""
echo "### 6. Network policies in '$APP_NS' (expect default-deny + allow-dns)"
kubectl get networkpolicy -n "$APP_NS"

echo ""
echo "### 7. VPC CNI network-policy agent (expect aws-eks-nodeagent container)"
kubectl get pod -n kube-system -l k8s-app=aws-node \
  -o jsonpath='{.items[0].spec.containers[*].name}{"\n"}' 2>/dev/null \
  || echo "  (aws-node pods not found)"

echo ""
echo "### 8. PriorityClasses (expect critical-app / standard-app / best-effort)"
kubectl get priorityclasses | grep -E 'critical-app|standard-app|best-effort' || echo "  (none found)"

echo ""
echo "### 9. ResourceQuota + LimitRange in '$APP_NS'"
kubectl get resourcequota,limitrange -n "$APP_NS"

echo ""
echo "### 10. Policy reports — what WOULD be blocked (audit findings)"
kubectl get policyreport -A 2>/dev/null | head -30
echo ""
echo "    Fail counts per namespace (non-zero = violations to fix before enforce):"
kubectl get policyreport -A --no-headers 2>/dev/null \
  | awk '{print $1, "pass="$3, "fail="$4}' | grep -v 'fail=0' || echo "  No failures — safe to enforce."

echo ""
echo "============================================================"
echo " Verification complete."
echo " If section 10 shows no failures -> run: bash enforce.sh"
echo "============================================================"
