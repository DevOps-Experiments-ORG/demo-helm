# eks-security-baseline (Helm chart)

One Helm chart for the **in-cluster** security layer of your EKS cluster. It
installs **Kyverno** (the only open-source tool with no AWS-native equivalent)
and bundles the Kubernetes-native controls:

- Pod Security Admission labels (warn/audit, optionally enforce)
- Kyverno policies: no-privileged, non-root, resource limits, allowed
  registries, no `:latest`, drop-all-caps
- Network policies: default-deny + DNS allow
- PriorityClasses + ResourceQuota + LimitRange
- (optional) image-signature verification against your AWS Signer profile

> AWS-native controls — ECR scanning, Inspector, GuardDuty, AWS Signer,
> Security Hub — are enabled separately at the account level (you already did
> this). This chart does **not** manage them.

## Prerequisites (in CloudShell)

- `helm` and `kubectl` (CloudShell has both)
- kubeconfig pointed at the cluster:
  ```bash
  aws eks update-kubeconfig --name ai-powered-secure-k8s-cluster --region ap-south-1
  kubectl get nodes
  ```
- Network-policy enforcement on in the VPC CNI (one-time, needed for the
  network policies to take effect):
  ```bash
  aws eks update-addon --cluster-name ai-powered-secure-k8s-cluster \
    --region ap-south-1 --addon-name vpc-cni \
    --configuration-values '{"enableNetworkPolicy":"true"}' \
    --resolve-conflicts PRESERVE
  ```

## Install

```bash
cd eks-security/helm/eks-security-baseline

# 1. pull the Kyverno subchart
helm dependency update

# 2. (optional) render locally to eyeball the output first
helm template eks-security . --set appNamespace=<YOUR_APP_NS> | less

# 3. install — starts in AUDIT mode, nothing is blocked
helm install eks-security . \
  --namespace security --create-namespace \
  --set appNamespace=<YOUR_APP_NS>
```

Set your real namespace with `--set appNamespace=...` or edit `values.yaml`.

## Observe (audit mode), then enforce

```bash
# see what WOULD be blocked
kubectl get clusterpolicies
kubectl get policyreport -A

# once clean, flip everything to blocking:
helm upgrade eks-security . \
  --namespace security \
  --set appNamespace=<YOUR_APP_NS> \
  --set policyMode=Enforce \
  --set podSecurityAdmission.enforce=true
```

## Turn pieces on/off

Everything is a toggle in `values.yaml` (or `--set`):

| Value | Effect |
|---|---|
| `policyMode` | `Audit` (observe) or `Enforce` (block) for all Kyverno policies |
| `podSecurityAdmission.enforce` | `false` = warn only, `true` = block |
| `policies.*` | enable/disable each individual Kyverno policy |
| `networkPolicies.enabled` | default-deny + DNS allow |
| `priorityClasses.enabled` / `resourceQuota.enabled` | resource governance |
| `verifyImages.enabled` | signature verification (paste the Signer cert first) |

## Enable image-signature verification (later)

1. Get the AWS Signer root cert and paste it into
   `values.yaml -> verifyImages.signerRootCertPem`.
2. `--set verifyImages.enabled=true` and `helm upgrade`.

## Uninstall (clean teardown — great for a POC)

```bash
helm uninstall eks-security --namespace security
```

## Bumping versions

Kyverno chart version is pinned in `Chart.yaml` (`dependencies[].version`).
To upgrade: change it, run `helm dependency update`, then `helm upgrade`.
Chart supports Kubernetes >= 1.25, so your 1.35 is fine.
