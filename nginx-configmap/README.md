# NGINX Ingress Controller ConfigMap

academyfive 19+ targets the **F5/NGINX Inc. Kubernetes Ingress Controller**
(https://github.com/nginx/kubernetes-ingress), not the (EOL March 2026) community
`kubernetes/ingress-nginx` project. The Ingress resources rendered by this chart
use `nginx.org/*` annotations and rely on a few globals defined on the
controller's ConfigMap (notably `proxy_cache_path` for the asset cache, plus
log formats and gzip).

You have two ways to provide that ConfigMap:

## Option A — let the chart manage it (recommended for dedicated controllers)

Enable the bundled `nginxControllerConfig` subchart:

```yaml
nginxControllerConfig:
  enabled: true
  configMap:
    name: nginx-ingress         # must match the controller's -nginx-configmaps flag
    namespace: nginx-ingress
    data:
      # override individual keys here if needed
```

Helm now owns the ConfigMap. Customers extend via values overrides.

## Option B — apply it manually (for shared/multi-tenant controllers)

If multiple teams share the same controller, the controller's ConfigMap is
shared too and shouldn't be owned by the academyfive Helm release.

1. Find the ConfigMap name the controller is reading:
   ```shell
   kubectl get pods -n nginx-ingress
   kubectl -n nginx-ingress describe pod <controller-pod> | grep -- -nginx-configmaps
   ```
2. Edit `nginx-configmap.yaml` so `metadata.name` and `metadata.namespace`
   match.
3. Merge the keys in `data:` with whatever your shared controller config
   already contains (the asset cache needs `http-snippets` to define
   `proxy_cache_path keys_zone=nginxproxycache:...`), then apply:
   ```shell
   kubectl apply -f nginx-configmap.yaml
   ```

## Migrating from kubernetes/ingress-nginx

See [MIGRATION.md](../MIGRATION.md) at the repo root.
