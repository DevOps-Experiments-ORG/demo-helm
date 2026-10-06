# Deploy with pure Helm commands (no bash script)

Everything is controlled from `eks-security-baseline/values.yaml`. You only run
`helm` commands.

## Why the first install is two commands (important)

Kyverno's policies (`ClusterPolicy`) need Kyverno's CRDs to already exist.
Helm validates ALL manifests before applying any, so a single `helm install`
cannot create the CRDs and the policies in the same release — it fails with
"no matches for kind ClusterPolicy". This is a Helm limitation; Kyverno's own
project splits them into two charts for the same reason.

So:
- **First time on a cluster = 2 commands** (install Kyverno, then add policies)
- **Every change after that = 1 command** (`helm upgrade`)

The two-step is a one-time bootstrap. Day-to-day is a single command.

---

## 0. One-time per shell: point kubectl at the cluster

Helm deploys to whatever cluster your kubeconfig points at. Use the values you
set in values.yaml (cluster.name / cluster.region):

```
aws eks update-kubeconfig --name ai-powered-secure-k8s-cluster --region ap-south-1
kubectl get nodes
```

Enable network policy once so the NetworkPolicy objects actually enforce:
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

## 2. FIRST INSTALL — step A: Kyverno + CRDs only

```
helm install eks-security . \
  --namespace security --create-namespace \
  --set installPolicies=false \
  --wait
```

## 3. FIRST INSTALL — step B: turn the policies on

CRDs now exist, so the policies validate and apply:

```
helm upgrade eks-security . \
  --namespace security \
  --set installPolicies=true
```

Bootstrap done. From here on it's always a single `helm upgrade`.

---

## Day-to-day: change anything via values.yaml, then ONE command

Edit `values.yaml`, then:

```
helm upgrade eks-security . --namespace security
```

| Want to change | Edit in values.yaml |
|---|---|
| Target cluster / region | `cluster.name`, `cluster.region` (then re-run step 0) |
| App namespace | `appNamespace` |
| Audit -> Enforce | `policyMode: Enforce` and `podSecurityAdmission.enforce: true` |
| ECR registry | `ecrRegistry` |
| Turn a policy off | `policies.<name>: false` |
| Keep policies installed | leave `installPolicies: true` |

## Label the app namespace for PSA (one kubectl command)

The namespace already exists, so label it directly:
```
kubectl label --overwrite namespace applications \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted
```

## Uninstall

```
helm uninstall eks-security --namespace security
```

---

## Note on "why not a single command?"

A true one-shot `helm install` (CRDs + Kyverno + policies together) is not
possible with plain Helm — see the explanation at the top. The alternatives
each have a cost:
- Helm **hooks** could force one command, but hooks aren't tracked as release
  resources, which breaks the clean `helm upgrade`/values workflow above.
- A **bash wrapper** (deploy.sh) runs both steps as one command, if you prefer
  that over two helm commands.

The two-command bootstrap keeps the values-driven `helm upgrade` workflow clean
and matches how Kyverno itself is installed.
