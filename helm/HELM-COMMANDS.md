# Deploy with pure Helm commands (no bash script)

Everything is controlled from `eks-security-baseline/values.yaml`. You only run
`helm` commands.

## 0. One-time per shell: point kubectl at the cluster

Helm deploys to whatever cluster your kubeconfig points at. Set it once using
the values you put in values.yaml (cluster.name / cluster.region):

```
aws eks update-kubeconfig --name ai-powered-secure-k8s-cluster --region ap-south-1
kubectl get nodes
```

(Also enable network policy once so the NetworkPolicy objects actually enforce:)
```
aws eks update-addon --cluster-name ai-powered-secure-k8s-cluster --region ap-south-1 \
  --addon-name vpc-cni --configuration-values '{"enableNetworkPolicy":"true"}' \
  --resolve-conflicts PRESERVE
```

## 1. Pull the Kyverno dependency

```
cd eks-security-baseline
helm dependency update
```

## 2. Install — STEP A: Kyverno + CRDs only

The policies need Kyverno's CRDs to exist first. So the first install brings up
Kyverno with policies turned OFF (one flag):

```
helm install eks-security . \
  --namespace security --create-namespace \
  --set installPolicies=false \
  --wait
```

## 3. Install — STEP B: turn the policies on

Now the CRDs exist, enable the policies with an upgrade:

```
helm upgrade eks-security . \
  --namespace security \
  --set installPolicies=true
```

That's it. Two Helm commands, no bash.

## Change anything via values.yaml

Edit `values.yaml` then re-run step 3 (`helm upgrade`). Examples:

| Want to change | Edit in values.yaml |
|---|---|
| Target cluster / region | `cluster.name`, `cluster.region` (then re-run step 0) |
| App namespace | `appNamespace` |
| Audit -> Enforce | `policyMode: Enforce` and `podSecurityAdmission.enforce: true` |
| ECR registry | `ecrRegistry` |
| Turn a policy off | `policies.<name>: false` |

Then:
```
helm upgrade eks-security . --namespace security
```

## Label the app namespace for PSA (one kubectl command)

Because the namespace already exists, label it directly:
```
kubectl label --overwrite namespace applications \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted
```
(Enforce later by setting it to enforce=restricted, or via values + upgrade.)

## Uninstall

```
helm uninstall eks-security --namespace security
```
