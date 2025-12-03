# kubectl + jq Query Reference for Converted Checks

## Quick Reference by Category

### 1. RBAC - Cluster Role Bindings

**Query: Who has cluster-admin?**
```bash
kubectl get clusterrolebindings -o json | \
  jq '.items[] | select(.roleRef.name=="cluster-admin") | 
  {name: .metadata.name, subjects: .subjects}'
```

**Query: Find system:masters group bindings**
```bash
kubectl get clusterrolebindings -o json | \
  jq '.items[] | select(.subjects[]? | select(.kind == "Group" and .name == "system:masters"))'
```

---

### 2. RBAC - Roles/ClusterRoles Permissions

**Query: Find roles with secrets access**
```bash
kubectl get roles,clusterroles -A -o json | \
  jq '.items[] | select(.rules[]? | select(.resources[]? == "secrets"))'
```

**Query: Find roles with wildcard (*) permissions**
```bash
kubectl get roles,clusterroles -A -o json | \
  jq '.items[] | select(.rules[]? | select(.verbs[]? == "*" or .resources[]? == "*"))'
```

**Query: Find roles with create pod permissions**
```bash
kubectl get roles,clusterroles -A -o json | \
  jq '.items[] | select(.rules[]? | select(.resources[]? == "pods" and (.verbs[]? | IN("create", "update", "patch"))))'
```

**Query: Find roles with Bind/Impersonate/Escalate verbs**
```bash
kubectl get roles,clusterroles -A -o json | \
  jq '.items[] | select(.rules[]? | select(.verbs[]? | IN("bind", "impersonate", "escalate")))'
```

---

### 3. Pod Security - SecurityContext Scanning

**Query: Find all privileged containers**
```bash
kubectl get pods -A -o json | \
  jq '.items[] | 
  select(.spec.containers[]?.securityContext.privileged==true or 
         .spec.initContainers[]?.securityContext.privileged==true) | 
  {namespace: .metadata.namespace, name: .metadata.name}'
```

**Query: Find pods with hostPID**
```bash
kubectl get pods -A -o json | \
  jq '.items[] | select(.spec.hostPID==true) | "\(.metadata.namespace)/\(.metadata.name)"'
```

**Query: Find pods with hostNetwork**
```bash
kubectl get pods -A -o json | \
  jq '.items[] | select(.spec.hostNetwork==true) | "\(.metadata.namespace)/\(.metadata.name)"'
```

**Query: Find pods with hostIPC**
```bash
kubectl get pods -A -o json | \
  jq '.items[] | select(.spec.hostIPC==true) | "\(.metadata.namespace)/\(.metadata.name)"'
```

**Query: Find pods with allowPrivilegeEscalation**
```bash
kubectl get pods -A -o json | \
  jq '.items[] | select(.spec.containers[]?.securityContext.allowPrivilegeEscalation==true) | 
  "\(.metadata.namespace)/\(.metadata.name)"'
```

---

### 4. Pod Security - Capabilities & Volumes

**Query: Find containers with NET_RAW capability**
```bash
kubectl get pods -A -o json | \
  jq '.items[] | select(.spec.containers[]?.securityContext.capabilities.add[]? == "NET_RAW") | 
  {namespace: .metadata.namespace, name: .metadata.name}'
```

**Query: Find pods with hostPath volumes**
```bash
kubectl get pods -A -o json | \
  jq '.items[] | select(.spec.volumes[]?.hostPath!=null) | 
  {namespace: .metadata.namespace, name: .metadata.name, 
   hostPaths: [.spec.volumes[] | select(.hostPath!=null) | .name]}'
```

**Query: Find pods with hostPorts**
```bash
kubectl get pods -A -o json | \
  jq '.items[] | select(.spec.containers[]?.ports[]?.hostPort!=null) | 
  {namespace: .metadata.namespace, name: .metadata.name, 
   containerPorts: [.spec.containers[] | select(.ports[]?.hostPort!=null)]}'
```

---

### 5. Pod Configuration

**Query: Find pods using default service account**
```bash
kubectl get pods -A -o json | \
  jq '.items[] | select(.spec.serviceAccountName=="default") | 
  "\(.metadata.namespace)/\(.metadata.name)"'
```

**Query: Find pods with automountServiceAccountToken enabled**
```bash
kubectl get pods -A -o json | \
  jq '.items[] | select(.spec.automountServiceAccountToken==true) | 
  {namespace: .metadata.namespace, name: .metadata.name}'
```

---

### 6. Policy & Network Resources

**Query: Count NetworkPolicies in cluster**
```bash
kubectl get networkpolicies -A -o json | \
  jq '.items | length'
```

**Query: List all NetworkPolicies by namespace**
```bash
kubectl get networkpolicies -A -o json | \
  jq '.items[] | {namespace: .metadata.namespace, name: .metadata.name, 
  podSelector: .spec.podSelector}'
```

**Query: Check for NetworkPolicies in specific namespace**
```bash
kubectl get networkpolicies -n production -o json | \
  jq '.items | length'
```

---

### 7. Namespace Management

**Query: Count custom namespaces**
```bash
kubectl get namespaces -o json | \
  jq '[.items[] | select(.metadata.name | IN("default","kube-system","kube-public","kube-node-lease") | not)] | length'
```

**Query: List all namespaces with labels**
```bash
kubectl get namespaces -o json | \
  jq '.items[] | {name: .metadata.name, labels: .metadata.labels}'
```

**Query: Find namespaces with Pod Security labels**
```bash
kubectl get namespaces -o json | \
  jq '.items[] | select(.metadata.labels | select(. != null) | 
  keys[] | startswith("pod-security.kubernetes.io")) | 
  {name: .metadata.name, labels: .metadata.labels}'
```

---

### 8. Pod Security Admission/Policies

**Query: Check for PodSecurityPolicy resources**
```bash
kubectl get podsecuritypolicies -o json | \
  jq '.items | length'
```

**Query: List all Pod Security Admission settings in namespaces**
```bash
kubectl get namespaces -o json | \
  jq '.items[] | {name: .metadata.name, 
  pss_labels: [.metadata.labels | to_entries[] | 
  select(.key | startswith("pod-security.kubernetes.io"))]} | 
  select(.pss_labels | length > 0)'
```

---

## Combining Queries

### Find pods that are both privileged AND using hostNetwork
```bash
kubectl get pods -A -o json | \
  jq '.items[] | select(
    (.spec.hostNetwork==true) and 
    (.spec.containers[]?.securityContext.privileged==true)
  ) | "\(.metadata.namespace)/\(.metadata.name)"'
```

### Find roles that grant multiple dangerous permissions
```bash
kubectl get roles,clusterroles -A -o json | \
  jq '.items[] | select(
    .rules[]? | select(
      (.verbs[]? | IN("*", "create", "update")) and 
      (.resources[]? | IN("secrets", "pods", "*"))
    )
  ) | "\(.kind): \(.metadata.name)"'
```

### Audit report: All security violations in one check
```bash
{
  privileged: (kubectl get pods -A -o json | jq '[.items[] | select(.spec.containers[]?.securityContext.privileged==true)] | length'),
  hostNetwork: (kubectl get pods -A -o json | jq '[.items[] | select(.spec.hostNetwork==true)] | length'),
  hostPID: (kubectl get pods -A -o json | jq '[.items[] | select(.spec.hostPID==true)] | length'),
  roleBindings: (kubectl get clusterrolebindings -o json | jq '[.items[] | select(.roleRef.name=="cluster-admin")] | length')
}
```

---

## Performance Tips

1. **Cache results for multiple checks**
```bash
PODS_JSON=$(kubectl get pods -A -o json)
echo "$PODS_JSON" | jq '.items[] | select(.spec.hostPID==true)'
echo "$PODS_JSON" | jq '.items[] | select(.spec.hostNetwork==true)'
```

2. **Use batch API requests**
```bash
kubectl get pods,deployments,statefulsets -A -o json
```

3. **Filter early with kubectl**
```bash
# Better: filter in kubectl first
kubectl get pods -A -o json --field-selector=status.phase=Running | jq '...'

# Avoid: get everything then filter
kubectl get pods -A -o json | jq 'select(.status.phase=="Running")'
```

---

## Debugging Tips

### Test jq syntax
```bash
# Write output to file first
kubectl get pods -A -o json > /tmp/pods.json

# Test jq gradually
cat /tmp/pods.json | jq '.items | length'
cat /tmp/pods.json | jq '.items[0]'
cat /tmp/pods.json | jq '.items[] | select(...)'
```

### Pretty print results
```bash
# For readability
kubectl get pods -A -o json | jq '.items[] | select(...) | {name: .metadata.name, ns: .metadata.namespace}'
```

### Check if empty result set
```bash
if [ -z "$(kubectl get pods -A -o json | jq '.items | select(length > 0)')" ]; then
  echo "No pods found"
fi
```

---

## Common Filter Patterns

```bash
# OR condition
jq '.items[] | select(.spec.hostPID==true or .spec.hostIPC==true)'

# AND condition  
jq '.items[] | select(.spec.hostNetwork==true and .spec.containers[]?.securityContext.privileged==true)'

# IN operator for multiple values
jq '.items[] | select(.spec.serviceAccountName | IN("default", "system:*"))'

# NOT operator
jq '.items[] | select(.metadata.namespace | IN("default","kube-system") | not)'

# Map and filter
jq '.items[] | {name: .metadata.name, containers: [.spec.containers[] | select(.securityContext.privileged==true)] | length}'
```
