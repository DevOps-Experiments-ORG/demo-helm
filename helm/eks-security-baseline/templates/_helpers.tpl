{{/* Common labels applied to every object this chart creates */}}
{{- define "eks-security-baseline.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: eks-security-baseline
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{/* Namespaces that must never be governed by these policies */}}
{{- define "eks-security-baseline.excludedNamespaces" -}}
- kube-system
- kube-node-lease
- kube-public
- kyverno
{{- end -}}
