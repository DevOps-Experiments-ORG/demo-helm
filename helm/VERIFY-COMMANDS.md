# Verification Commands (copy-paste one by one)

Read-only checks for the in-cluster security setup. Nothing here changes the
cluster. Run each block in CloudShell and compare to "Expected".

---

## 1. Helm releases

```
helm list -n security
```
Expected: `kyverno` and `eks-security` both `deployed`.

---

## 2. Kyverno pods

```
kubectl get pods -n security
```
Expected: all pods `Running` (admission x3, background, cleanup, reports).

---

## 3. Cluster policies exist and are ready

```
kubectl get clusterpolicies
```
Expected: 6 policies, all `READY = True`:
disallow-latest-tag, disallow-privileged-containers, require-drop-all-capabilities,
require-resource-limits, require-run-as-non-root, restrict-image-registries.

---

## 4. Which mode are the policies in? (Audit vs Enforce)

```
kubectl get clusterpolicies -o custom-columns='NAME:.metadata.name,ACTION:.spec.validationFailureAction'
```
Expected now: `Audit` (nothing blocked). After enforce.sh: `Enforce`.

---

## 5. Pod Security Admission labels on the app namespace

```
kubectl get namespace applications -o jsonpath='{.metadata.labels}'
```
Expected: contains `pod-security.kubernetes.io/warn=restricted` and `audit=restricted`.

---

## 6. Network policies in the app namespace

```
kubectl get networkpolicy -n applications
```
Expected: `default-deny-all` and `allow-dns-egress`.

---

## 7. VPC CNI network-policy agent is running

```
kubectl get pod -n kube-system -l k8s-app=aws-node -o jsonpath='{.items[0].spec.containers[*].name}'
```
Expected: list includes `aws-eks-nodeagent` (means network policy enforcement is active).

---

## 8. PriorityClasses

```
kubectl get priorityclasses
```
Expected: `critical-app`, `standard-app`, `best-effort` present.

---

## 9. ResourceQuota + LimitRange in the app namespace

```
kubectl get resourcequota,limitrange -n applications
```
Expected: `app-quota` and `app-limits`.

---

## 10. Policy reports — what WOULD be blocked (the important one)

```
kubectl get policyreport -A
```
Look at the FAIL column. Non-zero = violations to fix before enforcing.

See the actual failing rules in the app namespace:
```
kubectl describe policyreport -n applications | grep -i -A3 fail | head -40
```

---

## When all looks good — flip to enforce

```
bash enforce.sh
```

Then test a bad pod is rejected:
```
kubectl run bad --image=nginx:latest -n applications
```
Expected: blocked by disallow-latest-tag / restrict-image-registries.
